import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:network_protocol/network_protocol.dart';
import 'package:network_protocol/job_protocol.dart';
import 'package:network_protocol/job_lifecycle_protocol.dart';
import 'package:telemetry_core/telemetry_core.dart';
import 'package:telemetry_core/job_telemetry.dart';

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

class TelemetryConnection extends ChangeNotifier {
  TelemetryConnection() {
    _watchdog = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkFreshness(),
    );
  }

  // ==========================================
  // CONNECTION SETTINGS
  // ==========================================

  static const int serverPort = 8787;

  static const Duration tcpTimeout = Duration(seconds: 4);

  static const Duration connectionTimeout = Duration(seconds: 5);

  static const Duration telemetryTimeout = Duration(seconds: 4);

  static const Duration pingInterval = Duration(seconds: 10);

  static const Duration uiUpdateInterval = Duration(milliseconds: 100);

  // ==========================================
  // NETWORK
  // ==========================================

  HttpClient? _httpClient;
  WebSocket? _socket;

  StreamSubscription<dynamic>? _subscription;

  Timer? _watchdog;
  Timer? _updateTimer;

  int _generation = 0;
  bool _disposed = false;

  // ==========================================
  // TRUCK TELEMETRY
  // ==========================================

  TruckSnapshot? _snapshot;
  TruckSnapshot? _pendingSnapshot;

  DateTime? _lastReceivedAt;

  // ==========================================
  // JOB TELEMETRY
  // ==========================================

  TruckLinkJobTelemetry? _activeJob;

  JobLifecycleEventKind? _lastJobEvent;

  // ==========================================
  // STATUS
  // ==========================================

  TelemetryConnectionStatus _status = TelemetryConnectionStatus.disconnected;

  String _statusMessage = 'Нет подключения к ПК';

  String? _host;

  // ==========================================
  // PUBLIC GETTERS
  // ==========================================

  TruckSnapshot? get snapshot => _snapshot;

  TruckLinkJobTelemetry? get activeJob => _activeJob;

  bool get hasActiveJob => _activeJob != null;

  JobLifecycleEventKind? get lastJobEvent => _lastJobEvent;

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
    if (_disposed) return;

    final cleanHost = host.trim();

    // Ignore callbacks from all earlier
    // connection attempts.
    final generation = ++_generation;

    _stopTransport();
    _clearTelemetry();

    _host = null;

    // ========================================
    // VALIDATE ADDRESS
    // ========================================

    final address = InternetAddress.tryParse(cleanHost);

    if (address == null || address.type != InternetAddressType.IPv4) {
      _setStatus(
        TelemetryConnectionStatus.error,
        'Введите корректный IPv4-адрес '
        'компьютера',
      );
      return;
    }

    // ========================================
    // CONNECTING
    // ========================================

    _setStatus(
      TelemetryConnectionStatus.connecting,
      'Подключение к '
      '$cleanHost:$serverPort...',
    );

    final client = HttpClient()..connectionTimeout = tcpTimeout;

    _httpClient = client;

    var acceptSocket = true;

    final uri = Uri(scheme: 'ws', host: cleanHost, port: serverPort);

    try {
      // Keep the original custom HttpClient.
      // It controls TCP connection timeout.
      final attempt = WebSocket.connect(uri.toString(), customClient: client);

      // ======================================
      // CLEAN UP LATE CONNECTIONS
      // ======================================

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
              // The awaited attempt below
              // handles this error.
            },
          )
          .ignore();

      // ======================================
      // OVERALL HANDSHAKE TIMEOUT
      // ======================================

      final socket = await attempt.timeout(
        connectionTimeout,
        onTimeout: () {
          acceptSocket = false;

          client.close(force: true);

          throw TimeoutException('Windows Hub connection timed out');
        },
      );

      // ======================================
      // CHECK CURRENT ATTEMPT
      // ======================================

      if (!_isCurrent(generation)) {
        acceptSocket = false;

        socket.close().ignore();
        return;
      }

      // ======================================
      // ENABLE PING / PONG
      // ======================================

      socket.pingInterval = pingInterval;

      _socket = socket;
      _host = cleanHost;

      // ======================================
      // LISTEN FOR HUB MESSAGES
      // ======================================

      _subscription = socket.listen(
        (dynamic message) {
          if (_isCurrent(generation)) {
            _handleMessage(generation, message);
          }
        },
        onDone: () {
          _handleConnectionLost(
            generation,
            'Соединение с Windows Hub '
            'закрыто',
          );
        },
        onError: (Object error) {
          _handleConnectionLost(
            generation,
            'Соединение с Windows Hub '
            'потеряно',
          );
        },
        cancelOnError: true,
      );

      _setStatus(
        TelemetryConnectionStatus.waiting,
        'Подключено. Ожидание '
        'телеметрии ETS2 / ATS...',
      );

      // ======================================
      // IDENTIFY MOBILE DEVICE
      // ======================================

      // Do not await this call.
      // Device information must never delay
      // the telemetry connection.
      unawaited(_sendDeviceHello(socket, generation));
    } catch (error) {
      acceptSocket = false;

      if (!_isCurrent(generation)) {
        return;
      }

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
  // SEND DEVICE HELLO
  // ==========================================

  Future<void> _sendDeviceHello(WebSocket socket, int generation) async {
    var platform = Platform.isAndroid
        ? 'Android'
        : Platform.isIOS
        ? 'iOS'
        : Platform.operatingSystem;

    var deviceName = Platform.isAndroid
        ? 'Android-устройство'
        : Platform.isIOS
        ? 'iPhone / iPad'
        : 'TruckLink Device';

    // ========================================
    // READ DEVICE INFORMATION
    // ========================================

    try {
      final plugin = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;

        final manufacturer = _cleanLabel(info.manufacturer, 32);

        final model = _cleanLabel(info.model, 48);

        if (model.isNotEmpty) {
          if (manufacturer.isEmpty ||
              model.toLowerCase().startsWith(manufacturer.toLowerCase())) {
            deviceName = model;
          } else {
            deviceName = '${_capitalize(manufacturer)} $model';
          }
        }

        platform = 'Android';
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;

        final model = _cleanLabel(info.model, 48);

        if (model.isNotEmpty) {
          deviceName = model;
        }

        platform = 'iOS';
      }
    } catch (error) {
      debugPrint('TruckLink device information: $error');
    }

    // ========================================
    // CHECK CONNECTION BEFORE SENDING
    // ========================================

    if (!_isCurrent(generation) ||
        !identical(_socket, socket) ||
        socket.readyState != WebSocket.open) {
      return;
    }

    // ========================================
    // SEND IDENTIFICATION
    // ========================================

    try {
      final name = _cleanLabel(deviceName, 64);

      socket.add(
        jsonEncode({
          'type': 'client_hello',
          'version': 1,
          'name': name.isEmpty ? 'TruckLink Device' : name,
          'platform': _cleanLabel(platform, 20),
        }),
      );

      debugPrint(
        'TruckLink: device identification '
        'sent: $name',
      );
    } catch (error) {
      debugPrint(
        'TruckLink device hello error: '
        '$error',
      );
    }
  }

  // ==========================================
  // DEVICE NAME HELPERS
  // ==========================================

  String _cleanLabel(String value, int maxLength) {
    final cleaned = value
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return cleaned.length > maxLength
        ? cleaned.substring(0, maxLength)
        : cleaned;
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;

    return value[0].toUpperCase() + value.substring(1);
  }

  // ==========================================
  // CONNECTION ERRORS
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
  // RECEIVE HUB MESSAGES
  // ==========================================

  void _handleMessage(int generation, dynamic message) {
    try {
      if (message is! String) {
        throw const FormatException('Expected text WebSocket message');
      }

      // ======================================
      // 1. JOB LIFECYCLE EVENT
      // ======================================

      if (isJobEventMessage(message)) {
        final event = decodeJobEvent(message);

        if (event == JobLifecycleEventKind.started) {
          // A new job replaces the result
          // of any earlier delivery.
          final hadResult = _lastJobEvent != null;

          _lastJobEvent = null;

          if (hadResult) {
            _notify();
          }

          debugPrint('TruckLink: job accepted');
        } else {
          // Confirmed delivery or cancellation.
          _lastJobEvent = event;

          // Clear any old job immediately,
          // even if job_update(null) was delayed.
          _activeJob = null;

          debugPrint('TruckLink: job ${event.name}');

          _notify();
        }

        return;
      }

      // ======================================
      // 2. ACTIVE JOB UPDATE
      // ======================================

      if (isJobUpdateMessage(message)) {
        final nextJob = decodeJobUpdate(message);

        final previousJob = _activeJob;

        // Compare the actual fields, not
        // the model object identities.
        final changed = !mapEquals(previousJob?.toJson(), nextJob?.toJson());

        _activeJob = nextJob;

        var eventChanged = false;

        // New active job clears an old
        // delivered/cancelled notification.
        if (previousJob == null && nextJob != null && _lastJobEvent != null) {
          _lastJobEvent = null;
          eventChanged = true;
        }

        if (previousJob == null && nextJob != null) {
          debugPrint(
            'TruckLink: job started: '
            '${nextJob.displayRoute} · '
            '${nextJob.displayCargo}',
          );
        } else if (previousJob != null && nextJob == null) {
          debugPrint('TruckLink: active job cleared');
        }

        // Avoid unnecessary rebuilds when
        // the repeated job update is identical.
        if (changed || eventChanged) {
          _notify();
        }

        return;
      }

      // ======================================
      // 3. EXISTING TRUCK SNAPSHOT
      // ======================================

      final nextSnapshot = decodeSnapshot(message);

      // Keep only the latest frame.
      _pendingSnapshot = nextSnapshot;
      _lastReceivedAt = DateTime.now();

      // At most 10 truck UI updates/second.
      _updateTimer ??= Timer(uiUpdateInterval, _publishPendingSnapshot);
    } catch (error) {
      _handleConnectionLost(generation, 'Ошибка формата телеметрии: $error');
    }
  }

  // ==========================================
  // PUBLISH TRUCK SNAPSHOT
  // ==========================================

  void _publishPendingSnapshot() {
    _updateTimer = null;

    if (_disposed) return;

    final pending = _pendingSnapshot;

    if (pending == null) return;

    _pendingSnapshot = null;
    _snapshot = pending;

    _status = TelemetryConnectionStatus.connected;

    _statusMessage = 'Телеметрия ETS2 / ATS активна';

    _notify();
  }

  // ==========================================
  // CHECK TELEMETRY FRESHNESS
  // ==========================================

  void _checkFreshness() {
    if (_disposed) return;

    if (_status != TelemetryConnectionStatus.connected) {
      return;
    }

    final lastReceived = _lastReceivedAt;

    if (lastReceived == null) return;

    if (DateTime.now().difference(lastReceived) > telemetryTimeout) {
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

    // Invalidate pending callbacks.
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

  void _stopTransport() {
    final subscription = _subscription;
    final socket = _socket;
    final client = _httpClient;

    _subscription = null;
    _socket = null;
    _httpClient = null;

    // Do not await cleanup here.
    // Navigation and reconnect must stay fast.
    subscription?.cancel().ignore();
    socket?.close().ignore();

    client?.close(force: true);
  }

  // ==========================================
  // CLEAR TELEMETRY AND JOB
  // ==========================================

  void _clearTelemetry() {
    _updateTimer?.cancel();
    _updateTimer = null;

    _snapshot = null;
    _pendingSnapshot = null;

    // Do not show old deliveries
    // after disconnecting.
    _activeJob = null;
    _lastJobEvent = null;

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
