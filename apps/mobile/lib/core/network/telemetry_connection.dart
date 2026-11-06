import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:network_protocol/network_protocol.dart';
import 'package:telemetry_core/telemetry_core.dart';

// ============================================
// CONNECTION STATUS
// ============================================

enum TelemetryConnectionStatus {
  disconnected,
  connecting,
  waiting,
  connected,
  stale,
  error,
}

// ============================================
// TELEMETRY CONNECTION
// ============================================

/// Shared connection to TruckLink Windows Hub.
///
/// Uses native dart:io WebSocket on Android/iOS.
///
/// Features:
/// - Bounded connection attempts
/// - Fast cleanup without awaiting socket closure
/// - Protection against outdated connection attempts
/// - WebSocket ping/pong monitoring
/// - Telemetry freshness watchdog
/// - Throttled UI notifications
class TelemetryConnection extends ChangeNotifier {
  TelemetryConnection() {
    _watchdog = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkFreshness(),
    );
  }

  // ==========================================
  // CONFIGURATION
  // ==========================================

  static const int serverPort = 8787;

  /// Limit for establishing the TCP connection.
  static const Duration tcpTimeout = Duration(seconds: 4);

  /// Overall limit, including the WebSocket
  /// handshake after TCP connection.
  static const Duration connectionTimeout = Duration(seconds: 5);

  /// How long telemetry may remain unchanged.
  static const Duration telemetryTimeout = Duration(seconds: 4);

  /// Check that the Windows Hub is still alive.
  static const Duration pingInterval = Duration(seconds: 10);

  /// At most ten UI updates per second.
  static const Duration uiUpdateInterval = Duration(milliseconds: 100);

  // ==========================================
  // NETWORK STATE
  // ==========================================

  HttpClient? _httpClient;
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;

  Timer? _watchdog;
  Timer? _updateTimer;

  int _generation = 0;
  bool _disposed = false;

  // ==========================================
  // TELEMETRY STATE
  // ==========================================

  TruckSnapshot? _snapshot;
  TruckSnapshot? _pendingSnapshot;

  DateTime? _lastReceivedAt;

  TelemetryConnectionStatus _status = TelemetryConnectionStatus.disconnected;

  String _statusMessage = 'Нет подключения к ПК';
  String? _host;

  // ==========================================
  // PUBLIC GETTERS
  // ==========================================

  TruckSnapshot? get snapshot => _snapshot;

  TelemetryConnectionStatus get status => _status;

  String get statusMessage => _statusMessage;

  String? get connectedHost => _host;

  DateTime? get lastReceivedAt => _lastReceivedAt;

  /// WebSocket is connected, even if ETS2 is
  /// not currently producing telemetry.
  bool get isConnected {
    return _status == TelemetryConnectionStatus.waiting ||
        _status == TelemetryConnectionStatus.connected ||
        _status == TelemetryConnectionStatus.stale;
  }

  bool get hasLiveData {
    return _status == TelemetryConnectionStatus.connected && _snapshot != null;
  }

  // ==========================================
  // CONNECT
  // ==========================================

  Future<void> connect(String host) async {
    if (_disposed) return;

    final cleanHost = host.trim();

    // Every attempt gets its own generation ID.
    // Old connection callbacks cannot affect
    // the currently active attempt.
    final generation = ++_generation;

    // Important: cleanup is synchronous.
    // We do not wait for a pending socket to close.
    _stopTransport();
    _clearTelemetry();

    _host = null;

    // ========================================
    // VALIDATE HOST
    // ========================================

    final address = InternetAddress.tryParse(cleanHost);

    if (address == null || address.type != InternetAddressType.IPv4) {
      _setStatus(
        TelemetryConnectionStatus.error,
        'Введите корректный IPv4-адрес компьютера',
      );
      return;
    }

    // ========================================
    // START CONNECTION
    // ========================================

    _setStatus(
      TelemetryConnectionStatus.connecting,
      'Подключение к $cleanHost:$serverPort...',
    );

    final client = HttpClient()..connectionTimeout = tcpTimeout;

    _httpClient = client;

    var acceptSocket = true;

    final uri = Uri(scheme: 'ws', host: cleanHost, port: serverPort);

    try {
      // Start a real WebSocket connection.
      //
      // The custom HttpClient controls TCP timeout.
      // Future.timeout controls the overall handshake.
      final attempt = WebSocket.connect(uri.toString(), customClient: client);

      // If a timed-out or cancelled attempt finishes
      // later, immediately close its socket.
      //
      // This prevents old attempts from leaving
      // orphaned connections behind.
      attempt
          .then<void>(
            (lateSocket) {
              if (!acceptSocket ||
                  !_isCurrent(generation) ||
                  !identical(_httpClient, client)) {
                lateSocket.close().ignore();
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              // The main connection attempt handles errors.
            },
          )
          .ignore();

      final socket = await attempt.timeout(
        connectionTimeout,
        onTimeout: () {
          acceptSocket = false;

          // Abort the underlying TCP/HTTP operation.
          client.close(force: true);

          throw TimeoutException('Windows Hub connection timed out');
        },
      );

      // ======================================
      // CHECK WHETHER ATTEMPT IS STILL VALID
      // ======================================

      if (!_isCurrent(generation)) {
        acceptSocket = false;
        socket.close().ignore();
        return;
      }

      // Enable ping/pong to detect a broken link.
      socket.pingInterval = pingInterval;

      _socket = socket;
      _host = cleanHost;

      // ======================================
      // LISTEN FOR TELEMETRY
      // ======================================

      _subscription = socket.listen(
        (dynamic message) {
          if (_isCurrent(generation)) {
            _handleMessage(generation, message);
          }
        },
        onDone: () {
          _handleConnectionLost(generation, 'Соединение с Windows Hub закрыто');
        },
        onError: (Object error) {
          _handleConnectionLost(
            generation,
            'Соединение с Windows Hub потеряно',
          );
        },
        cancelOnError: true,
      );

      // Connection is established.
      //
      // Waiting for ETS2 does NOT mean the
      // WebSocket connection has failed.
      _setStatus(
        TelemetryConnectionStatus.waiting,
        'Подключено. Ожидание телеметрии ETS2...',
      );
    } catch (error) {
      acceptSocket = false;

      if (!_isCurrent(generation)) {
        return;
      }

      // ======================================
      // FAIL FAST
      // ======================================

      // Do not await socket closure here.
      // It was the cause of long/hung attempts.
      _stopTransport();
      _clearTelemetry();

      _host = null;

      _setStatus(
        TelemetryConnectionStatus.error,
        _connectionErrorMessage(error, cleanHost),
      );
    }
  }

  // ==========================================
  // HUMAN-READABLE CONNECTION ERRORS
  // ==========================================

  String _connectionErrorMessage(Object error, String host) {
    if (error is TimeoutException) {
      return 'ПК не ответил за '
          '${connectionTimeout.inSeconds} секунд. '
          'Проверь IP-адрес и Windows Hub.';
    }

    if (error is SocketException) {
      return 'Не удалось подключиться к '
          '$host:$serverPort. '
          'Проверь адрес ПК и запущен ли сервер.';
    }

    if (error is WebSocketException || error is HttpException) {
      return 'Сервер $host:$serverPort '
          'не принял WebSocket-подключение.';
    }

    return 'Ошибка подключения: $error';
  }

  // ==========================================
  // RECEIVE TELEMETRY
  // ==========================================

  void _handleMessage(int generation, dynamic message) {
    try {
      if (message is! String) {
        throw const FormatException('Expected text telemetry message');
      }

      final nextSnapshot = decodeSnapshot(message);

      // Only keep the most recent frame.
      _pendingSnapshot = nextSnapshot;
      _lastReceivedAt = DateTime.now();

      // Avoid notifying the entire UI for
      // every WebSocket packet.
      _updateTimer ??= Timer(uiUpdateInterval, _publishPendingSnapshot);
    } catch (error) {
      // Invalid protocol data means this connection
      // is not suitable for TruckLink.
      _handleConnectionLost(generation, 'Ошибка формата телеметрии: $error');
    }
  }

  // ==========================================
  // PUBLISH LATEST FRAME
  // ==========================================

  void _publishPendingSnapshot() {
    _updateTimer = null;

    if (_disposed) return;

    final pending = _pendingSnapshot;

    if (pending == null) return;

    _pendingSnapshot = null;
    _snapshot = pending;

    _status = TelemetryConnectionStatus.connected;
    _statusMessage = 'Телеметрия ETS2 активна';

    _notify();
  }

  // ==========================================
  // TELEMETRY WATCHDOG
  // ==========================================

  void _checkFreshness() {
    if (_disposed) return;

    if (_status != TelemetryConnectionStatus.connected) {
      return;
    }

    final lastReceived = _lastReceivedAt;

    if (lastReceived == null) return;

    final elapsed = DateTime.now().difference(lastReceived);

    if (elapsed > telemetryTimeout) {
      _clearTelemetry();

      _setStatus(TelemetryConnectionStatus.stale, 'Нет новых данных от ETS2');
    }
  }

  // ==========================================
  // CONNECTION LOST
  // ==========================================

  void _handleConnectionLost(int generation, String message) {
    if (!_isCurrent(generation)) return;

    // Invalidate callbacks belonging to this socket.
    ++_generation;

    _stopTransport();
    _clearTelemetry();

    _host = null;

    _setStatus(TelemetryConnectionStatus.error, message);
  }

  // ==========================================
  // MANUAL DISCONNECT
  // ==========================================

  Future<void> disconnect() async {
    if (_disposed) return;

    ++_generation;

    _stopTransport();
    _clearTelemetry();

    _host = null;

    _setStatus(
      TelemetryConnectionStatus.disconnected,
      'Отключено от Windows Hub',
    );
  }

  // ==========================================
  // FAST TRANSPORT CLEANUP
  // ==========================================

  /// Releases network resources without blocking
  /// navigation or another connection attempt.
  ///
  /// Important: do not await subscription.cancel()
  /// or socket.close() while connecting.
  void _stopTransport() {
    final subscription = _subscription;
    final socket = _socket;
    final client = _httpClient;

    _subscription = null;
    _socket = null;
    _httpClient = null;

    // Asynchronous cleanup must never keep the
    // UI in the connecting state indefinitely.
    subscription?.cancel().ignore();

    socket?.close().ignore();

    // Force-close pending connection attempts.
    client?.close(force: true);
  }

  // ==========================================
  // TELEMETRY CLEANUP
  // ==========================================

  void _clearTelemetry() {
    _updateTimer?.cancel();
    _updateTimer = null;

    _snapshot = null;
    _pendingSnapshot = null;
    _lastReceivedAt = null;
  }

  // ==========================================
  // STATUS HELPERS
  // ==========================================

  void _setStatus(TelemetryConnectionStatus status, String message) {
    if (_disposed) return;

    if (_status == status && _statusMessage == message) {
      return;
    }

    _status = status;
    _statusMessage = message;

    _notify();
  }

  bool _isCurrent(int generation) {
    return !_disposed && generation == _generation;
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  // ==========================================
  // DISPOSE
  // ==========================================

  @override
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    ++_generation;

    _watchdog?.cancel();
    _watchdog = null;

    _updateTimer?.cancel();
    _updateTimer = null;

    _stopTransport();
    _clearTelemetry();

    super.dispose();
  }
}
