import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:network_protocol/network_protocol.dart';
import 'package:telemetry_core/telemetry_core.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum TelemetryConnectionStatus {
  disconnected,
  connecting,
  waiting,
  connected,
  stale,
  error,
}

/// Manages the connection between TruckLink Mobile
/// and the Windows telemetry hub.
///
/// Networking is independent of the widget tree.
/// Screens can subscribe to this controller without
/// managing WebSocket connections themselves.
class TelemetryConnection extends ChangeNotifier {
  TelemetryConnection() {
    _watchdog = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkFreshness(),
    );
  }

  static const int serverPort = 8787;

  static const Duration connectionTimeout = Duration(seconds: 5);

  static const Duration telemetryTimeout = Duration(seconds: 4);

  // Maximum frequency of notifications to the UI.
  // Incoming packets can arrive more frequently.
  static const Duration uiUpdateInterval = Duration(milliseconds: 100);

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  Timer? _watchdog;
  Timer? _updateTimer;

  TruckSnapshot? _snapshot;
  TruckSnapshot? _pendingSnapshot;

  DateTime? _lastReceivedAt;

  TelemetryConnectionStatus _status = TelemetryConnectionStatus.disconnected;

  String _statusMessage = 'Нет подключения к ПК';
  String? _host;

  int _generation = 0;
  bool _disposed = false;

  // ==========================================
  // PUBLIC STATE
  // ==========================================

  TruckSnapshot? get snapshot => _snapshot;

  TelemetryConnectionStatus get status => _status;

  String get statusMessage => _statusMessage;

  String? get connectedHost => _host;

  DateTime? get lastReceivedAt => _lastReceivedAt;

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
    final address = InternetAddress.tryParse(host.trim());

    if (address == null || address.type != InternetAddressType.IPv4) {
      _setStatus(
        TelemetryConnectionStatus.error,
        'Введите корректный IPv4-адрес ПК',
      );
      return;
    }

    final generation = ++_generation;

    await _closeCurrentConnection();

    if (!_isCurrent(generation)) return;

    _clearTelemetry();

    _setStatus(
      TelemetryConnectionStatus.connecting,
      'Подключение к Windows Hub...',
    );

    WebSocketChannel? channel;

    try {
      channel = WebSocketChannel.connect(
        Uri(scheme: 'ws', host: host.trim(), port: serverPort),
      );

      _channel = channel;

      await channel.ready.timeout(connectionTimeout);

      if (!_isCurrent(generation)) {
        await channel.sink.close();
        return;
      }

      _host = host.trim();

      _setStatus(
        TelemetryConnectionStatus.waiting,
        'Подключено. Ожидание данных ETS2...',
      );

      _subscription = channel.stream.listen(
        (message) {
          if (_isCurrent(generation)) {
            _handleMessage(message);
          }
        },
        onDone: () {
          _handleConnectionLost(generation, 'Соединение с Windows Hub закрыто');
        },
        onError: (Object error) {
          _handleConnectionLost(generation, 'Ошибка соединения: $error');
        },
        cancelOnError: true,
      );
    } catch (error) {
      if (!_isCurrent(generation)) return;

      await _closeCurrentConnection();

      if (!_isCurrent(generation)) return;

      _clearTelemetry();

      _setStatus(
        TelemetryConnectionStatus.error,
        'Не удалось подключиться: $error',
      );
    }
  }

  // ==========================================
  // RECEIVE TELEMETRY
  // ==========================================

  void _handleMessage(dynamic message) {
    try {
      if (message is! String) {
        throw const FormatException('Expected text telemetry message');
      }

      final snapshot = decodeSnapshot(message);

      // Keep only the latest telemetry frame.
      // Intermediate frames are not needed for
      // displaying the current truck state.
      _pendingSnapshot = snapshot;
      _lastReceivedAt = DateTime.now();

      if (_updateTimer == null) {
        _updateTimer = Timer(uiUpdateInterval, _publishPendingSnapshot);
      }
    } catch (error) {
      _clearTelemetry();

      _setStatus(TelemetryConnectionStatus.error, 'Ошибка данных: $error');
    }
  }

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
  // WATCHDOG
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

    _generation++;

    unawaited(_closeCurrentConnection());

    _clearTelemetry();
    _host = null;

    _setStatus(TelemetryConnectionStatus.error, message);
  }

  // ==========================================
  // DISCONNECT
  // ==========================================

  Future<void> disconnect() async {
    ++_generation;

    await _closeCurrentConnection();

    if (_disposed) return;

    _clearTelemetry();
    _host = null;

    _setStatus(
      TelemetryConnectionStatus.disconnected,
      'Отключено от Windows Hub',
    );
  }

  Future<void> _closeCurrentConnection() async {
    final subscription = _subscription;
    final channel = _channel;

    _subscription = null;
    _channel = null;

    try {
      await subscription?.cancel();
    } catch (_) {
      // Already closed.
    }

    try {
      await channel?.sink.close();
    } catch (_) {
      // Already closed.
    }
  }

  // ==========================================
  // STATE HELPERS
  // ==========================================

  void _clearTelemetry() {
    _updateTimer?.cancel();
    _updateTimer = null;

    _snapshot = null;
    _pendingSnapshot = null;
    _lastReceivedAt = null;
  }

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
    _disposed = true;
    _generation++;

    _watchdog?.cancel();
    _updateTimer?.cancel();

    unawaited(_closeCurrentConnection());

    super.dispose();
  }
}
