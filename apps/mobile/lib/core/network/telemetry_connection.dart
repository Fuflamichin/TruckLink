import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
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
/// - Automatic device identification
///
/// Device identification is optional and must
/// never interrupt the telemetry connection.
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

  /// WebSocket is connected, even if ETS2/ATS
  /// is not currently producing telemetry.
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
      // ======================================
      // OPEN NATIVE WEBSOCKET
      // ======================================

      // We keep the original WebSocket.connect
      // because customClient is important
      // for the TCP connection timeout.
      final attempt = WebSocket.connect(uri.toString(), customClient: client);

      // If a timed-out or cancelled attempt
      // finishes later, close that socket.
      //
      // This prevents old attempts from
      // leaving orphaned connections behind.
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
              // The main connection attempt
              // handles errors.
            },
          )
          .ignore();

      final socket = await attempt.timeout(
        connectionTimeout,
        onTimeout: () {
          acceptSocket = false;

          // Abort the underlying operation.
          client.close(force: true);

          throw TimeoutException('Windows Hub connection timed out');
        },
      );

      // ======================================
      // CHECK WHETHER ATTEMPT IS CURRENT
      // ======================================

      if (!_isCurrent(generation)) {
        acceptSocket = false;

        socket.close().ignore();

        return;
      }

      // ======================================
      // ENABLE CONNECTION MONITORING
      // ======================================

      socket.pingInterval = pingInterval;

      _socket = socket;
      _host = cleanHost;

      // ======================================
      // LISTEN FOR GAME TELEMETRY
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

      // ======================================
      // CONNECTION ESTABLISHED
      // ======================================

      // Waiting for ETS2 / ATS does NOT
      // mean the WebSocket connection failed.
      _setStatus(
        TelemetryConnectionStatus.waiting,
        'Подключено. Ожидание телеметрии ETS2 / ATS...',
      );

      // ======================================
      // NEW: SEND DEVICE INFORMATION
      // ======================================

      // Run independently.
      //
      // Do not await device_info_plus here:
      // it must not delay receiving telemetry.
      //
      // A failure to detect the model must
      // never disconnect the WebSocket.
      unawaited(_sendDeviceHello(socket, generation));
    } catch (error) {
      acceptSocket = false;

      if (!_isCurrent(generation)) {
        return;
      }

      // ======================================
      // FAIL FAST
      // ======================================

      // Do not await socket closure here.
      // It previously caused long/hung attempts.
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
  // NEW: SEND DEVICE HELLO
  // ==========================================

  /// Sends a small optional service message
  /// to the Windows Hub after connection.
  ///
  /// Example:
  ///
  /// {
  ///   "type": "client_hello",
  ///   "version": 1,
  ///   "name": "Samsung SM-S921B",
  ///   "platform": "Android"
  /// }
  ///
  /// This message is separate from
  /// TruckSnapshot and does not change
  /// the existing telemetry protocol.
  Future<void> _sendDeviceHello(WebSocket socket, int generation) async {
    String platform = Platform.isAndroid
        ? 'Android'
        : Platform.isIOS
        ? 'iOS'
        : Platform.operatingSystem;

    String deviceName = Platform.isAndroid
        ? 'Android-устройство'
        : Platform.isIOS
        ? 'iPhone / iPad'
        : 'TruckLink Device';

    // ========================================
    // READ DEVICE INFORMATION
    // ========================================

    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;

        final manufacturer = _cleanDeviceLabel(
          androidInfo.manufacturer,
          maxLength: 32,
        );

        final model = _cleanDeviceLabel(androidInfo.model, maxLength: 48);

        if (model.isNotEmpty) {
          if (manufacturer.isEmpty ||
              model.toLowerCase().startsWith(manufacturer.toLowerCase())) {
            deviceName = model;
          } else {
            final formattedManufacturer = _capitalize(manufacturer);

            deviceName = '$formattedManufacturer $model';
          }
        }

        platform = 'Android';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;

        final model = _cleanDeviceLabel(iosInfo.model, maxLength: 48);

        if (model.isNotEmpty) {
          deviceName = model;
        }

        platform = 'iOS';
      }
    } catch (error) {
      // Do not interrupt the connection.
      //
      // Even if device_info_plus is unavailable,
      // we can send a generic device name.
      debugPrint(
        'TruckLink: device info unavailable: '
        '$error',
      );
    }

    // ========================================
    // VALIDATE CONNECTION BEFORE SENDING
    // ========================================

    // Device information might have taken
    // some time to load.
    //
    // The user could have disconnected
    // or started another connection attempt
    // during that time.
    if (!_isCurrent(generation) ||
        !identical(_socket, socket) ||
        socket.readyState != WebSocket.open) {
      return;
    }

    // ========================================
    // BUILD CLIENT HELLO MESSAGE
    // ========================================

    final safeName = _cleanDeviceLabel(deviceName, maxLength: 64);

    final safePlatform = _cleanDeviceLabel(platform, maxLength: 20);

    final message = jsonEncode({
      'type': 'client_hello',
      'version': 1,
      'name': safeName.isEmpty ? 'TruckLink Device' : safeName,
      'platform': safePlatform,
    });

    // ========================================
    // SEND WITHOUT DISCONNECTING ON ERROR
    // ========================================

    try {
      socket.add(message);

      debugPrint(
        'TruckLink: device identification sent: '
        '$safeName ($safePlatform)',
      );
    } catch (error) {
      // Identification is optional.
      // Telemetry continues normally.
      debugPrint(
        'TruckLink: cannot send device hello: '
        '$error',
      );
    }
  }

  // ==========================================
  // NEW: CLEAN DEVICE NAME
  // ==========================================

  /// Prevents control characters and very
  /// long strings from reaching Windows Hub.
  String _cleanDeviceLabel(String value, {required int maxLength}) {
    final cleaned = value
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.length <= maxLength) {
      return cleaned;
    }

    return cleaned.substring(0, maxLength);
  }

  // ==========================================
  // NEW: FORMAT MANUFACTURER NAME
  // ==========================================

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }

    return value[0].toUpperCase() + value.substring(1);
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

      // The Windows Hub continues sending
      // exactly the same snapshot format.
      final nextSnapshot = decodeSnapshot(message);

      // Only keep the most recent frame.
      _pendingSnapshot = nextSnapshot;

      _lastReceivedAt = DateTime.now();

      // Avoid notifying the entire UI
      // for every WebSocket packet.
      _updateTimer ??= Timer(uiUpdateInterval, _publishPendingSnapshot);
    } catch (error) {
      // Invalid protocol data means this
      // connection is not suitable for TruckLink.
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

    if (pending == null) {
      return;
    }

    _pendingSnapshot = null;
    _snapshot = pending;

    _status = TelemetryConnectionStatus.connected;

    _statusMessage = 'Телеметрия ETS2 / ATS активна';

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

    if (lastReceived == null) {
      return;
    }

    final elapsed = DateTime.now().difference(lastReceived);

    if (elapsed > telemetryTimeout) {
      _clearTelemetry();

      _setStatus(
        TelemetryConnectionStatus.stale,
        'Нет новых данных от ETS2 / ATS',
      );
    }
  }

  // ==========================================
  // CONNECTION LOST
  // ==========================================

  void _handleConnectionLost(int generation, String message) {
    if (!_isCurrent(generation)) {
      return;
    }

    // Invalidate callbacks belonging
    // to this socket.
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

    // Asynchronous cleanup must never keep
    // the UI in connecting state indefinitely.
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
