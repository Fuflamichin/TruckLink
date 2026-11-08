import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:network_protocol/event_sync_protocol.dart';
import 'package:network_protocol/finance_protocol.dart';
import 'package:network_protocol/job_lifecycle_protocol.dart';
import 'package:network_protocol/job_protocol.dart';
import 'package:network_protocol/network_protocol.dart';
import 'package:telemetry_core/job_telemetry.dart';
import 'package:telemetry_core/telemetry_core.dart';

import '../../features/finance/finance_store.dart';
import '../../features/jobs/history/job_history_entry.dart';
import '../../features/jobs/history/job_history_store.dart';

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
// TRUCKLINK CONNECTION v0.8.4
// ============================================

class TelemetryConnection extends ChangeNotifier {
  TelemetryConnection() {
    final initialState = WidgetsBinding.instance.lifecycleState;

    _isForeground =
        initialState == null || initialState == AppLifecycleState.resumed;

    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onLifecycleChanged,
    );

    _watchdog = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkConnection(),
    );
  }

  // ==========================================
  // CONNECTION CONFIGURATION
  // ==========================================

  static const int serverPort = 8787;

  static const Duration tcpTimeout = Duration(seconds: 4);

  static const Duration connectionTimeout = Duration(seconds: 5);

  static const Duration telemetryTimeout = Duration(seconds: 4);

  static const Duration pingInterval = Duration(seconds: 10);

  static const Duration uiUpdateInterval = Duration(milliseconds: 100);

  static const Duration resumeMessageTimeout = Duration(seconds: 20);

  static const List<int> _reconnectDelays = [1, 2, 4, 8, 16, 30];

  // ==========================================
  // NETWORK TRANSPORT
  // ==========================================

  HttpClient? _httpClient;
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;

  Timer? _watchdog;
  Timer? _updateTimer;
  Timer? _reconnectTimer;

  late final AppLifecycleListener _lifecycleListener;

  int _generation = 0;

  bool _disposed = false;
  bool _connecting = false;
  bool _isForeground = true;

  // ==========================================
  // AUTO RECONNECT
  // ==========================================

  String? _desiredHost;
  bool _autoReconnectEnabled = false;

  int _reconnectAttempt = 0;

  DateTime? _connectedAt;
  DateTime? _lastMessageAt;

  // ==========================================
  // LIVE TRUCK DATA
  // ==========================================

  TruckSnapshot? _snapshot;
  TruckSnapshot? _pendingSnapshot;

  DateTime? _lastReceivedAt;

  // ==========================================
  // JOB DATA
  // ==========================================

  TruckLinkJobTelemetry? _activeJob;

  JobLifecycleEventKind? _lastJobEvent;

  String? _endedJobIdentity;

  // ==========================================
  // EVENT SYNC
  // ==========================================

  bool _syncInProgress = false;
  int _expectedSyncCount = 0;
  int _receivedSyncCount = 0;
  int _lastSyncCount = 0;

  // ==========================================
  // CONNECTION STATUS
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

  bool get isConnecting => _connecting;

  bool get autoReconnectEnabled => _autoReconnectEnabled;

  String? get rememberedHost => _desiredHost;

  bool get isSyncingHistory => _syncInProgress;

  int get lastSyncCount => _lastSyncCount;

  bool get isConnected {
    return _status == TelemetryConnectionStatus.waiting ||
        _status == TelemetryConnectionStatus.connected ||
        _status == TelemetryConnectionStatus.stale;
  }

  bool get hasLiveData {
    return _status == TelemetryConnectionStatus.connected && _snapshot != null;
  }

  // ==========================================
  // MANUAL CONNECTION
  // ==========================================

  Future<void> connect(String host) async {
    if (_disposed) return;

    final cleanHost = host.trim();

    final address = InternetAddress.tryParse(cleanHost);

    if (address == null || address.type != InternetAddressType.IPv4) {
      _cancelReconnect();

      _autoReconnectEnabled = false;
      _desiredHost = null;

      ++_generation;
      _connecting = false;

      _stopTransport();
      _clearTelemetry();

      _setStatus(
        TelemetryConnectionStatus.error,
        'Введите корректный IPv4-адрес компьютера',
      );

      return;
    }

    _desiredHost = address.address;
    _autoReconnectEnabled = true;
    _reconnectAttempt = 0;

    _cancelReconnect();

    await _openConnection(address.address, automatic: false);
  }

  // ==========================================
  // OPEN CONNECTION
  // ==========================================

  Future<void> _openConnection(String host, {required bool automatic}) async {
    if (_disposed || !_autoReconnectEnabled) {
      return;
    }

    final generation = ++_generation;

    _cancelReconnect();
    _stopTransport();
    _clearTelemetry();

    _host = null;
    _connectedAt = null;
    _lastMessageAt = null;

    _connecting = true;

    _setStatus(
      TelemetryConnectionStatus.connecting,
      automatic
          ? 'Восстановление подключения '
                'к $host:$serverPort...'
          : 'Подключение к $host:$serverPort...',
    );

    final client = HttpClient()..connectionTimeout = tcpTimeout;

    _httpClient = client;

    var acceptSocket = true;

    final uri = Uri(scheme: 'ws', host: host, port: serverPort);

    try {
      final attempt = WebSocket.connect(uri.toString(), customClient: client);

      // Dispose of any connection that
      // finishes after it has been superseded.
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
              // Await below handles the error.
            },
          )
          .ignore();

      final socket = await attempt.timeout(
        connectionTimeout,
        onTimeout: () {
          acceptSocket = false;
          client.close(force: true);

          throw TimeoutException('TruckLink connection timed out');
        },
      );

      if (!_isCurrent(generation)) {
        acceptSocket = false;
        socket.close().ignore();
        return;
      }

      socket.pingInterval = pingInterval;

      _socket = socket;
      _host = host;

      _connectedAt = DateTime.now();
      _lastMessageAt = _connectedAt;

      _reconnectAttempt = 0;

      _subscription = socket.listen(
        (dynamic message) {
          if (_isCurrent(generation)) {
            _handleMessage(generation, message);
          }
        },
        onDone: () {
          _handleConnectionLost(generation, 'Windows Hub закрыл соединение');
        },
        onError: (Object error) {
          _handleConnectionLost(
            generation,
            'Соединение с Windows Hub потеряно',
          );
        },
        cancelOnError: true,
      );

      _setStatus(
        TelemetryConnectionStatus.waiting,
        'Подключено. Ожидание телеметрии ETS2 / ATS...',
      );

      // ======================================
      // REQUEST MISSED EVENTS
      // ======================================

      // The Hub will send:
      // event_sync_begin
      // job_event / finance_event (archived)
      // event_sync_end
      try {
        socket.add(encodeEventSyncRequest());

        debugPrint('TruckLink: requested event sync');
      } catch (error) {
        debugPrint('TruckLink: sync request failed: $error');
      }

      // ======================================
      // IDENTIFY PHONE
      // ======================================

      unawaited(_sendDeviceHello(socket, generation));
    } catch (error) {
      acceptSocket = false;

      if (!_isCurrent(generation)) return;

      _stopTransport();
      _clearTelemetry();

      _host = null;
      _connectedAt = null;
      _lastMessageAt = null;

      _setStatus(
        TelemetryConnectionStatus.error,
        _connectionErrorMessage(error, host),
      );

      _scheduleReconnect();
    } finally {
      if (_isCurrent(generation)) {
        _connecting = false;
      }
    }
  }

  // ==========================================
  // FLUTTER APP LIFECYCLE
  // ==========================================

  void _onLifecycleChanged(AppLifecycleState state) {
    if (_disposed) return;

    if (state == AppLifecycleState.resumed) {
      _isForeground = true;
      _onAppResumed();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _isForeground = false;
      _cancelReconnect();
    }
  }

  // ==========================================
  // RESUME / UNLOCK
  // ==========================================

  void _onAppResumed() {
    if (_disposed ||
        !_autoReconnectEnabled ||
        _desiredHost == null ||
        _connecting) {
      return;
    }

    final socket = _socket;

    if (socket == null || socket.readyState != WebSocket.open) {
      _scheduleReconnect(immediate: true);
      return;
    }

    final lastActivity = _lastMessageAt ?? _connectedAt;

    if (lastActivity == null ||
        DateTime.now().difference(lastActivity) > resumeMessageTimeout) {
      unawaited(_openConnection(_desiredHost!, automatic: true));
    }
  }

  // ==========================================
  // RECONNECTION BACKOFF
  // ==========================================

  void _scheduleReconnect({bool immediate = false}) {
    if (_disposed ||
        !_autoReconnectEnabled ||
        !_isForeground ||
        _desiredHost == null) {
      return;
    }

    if (_reconnectTimer != null && !immediate) {
      return;
    }

    if (immediate) {
      _cancelReconnect();
    }

    final index = _reconnectAttempt < _reconnectDelays.length
        ? _reconnectAttempt
        : _reconnectDelays.length - 1;

    final delaySeconds = immediate ? 0 : _reconnectDelays[index];

    if (!immediate && _reconnectAttempt < _reconnectDelays.length - 1) {
      _reconnectAttempt++;
    }

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectTimer = null;

      if (_disposed ||
          !_autoReconnectEnabled ||
          !_isForeground ||
          _connecting) {
        return;
      }

      final socket = _socket;

      if (socket != null && socket.readyState == WebSocket.open) {
        return;
      }

      final host = _desiredHost;
      if (host == null) return;

      unawaited(_openConnection(host, automatic: true));
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  // ==========================================
  // WATCHDOG
  // ==========================================

  void _checkConnection() {
    if (_disposed) return;

    final socket = _socket;

    if (!_connecting && socket != null && socket.readyState != WebSocket.open) {
      _handleConnectionLost(_generation, 'Соединение с Windows Hub закрыто');
      return;
    }

    if (_status == TelemetryConnectionStatus.connected) {
      final lastReceived = _lastReceivedAt;

      if (lastReceived != null &&
          DateTime.now().difference(lastReceived) > telemetryTimeout) {
        _clearTelemetry(preserveLastJobEvent: true);

        _setStatus(
          TelemetryConnectionStatus.stale,
          'Нет новых данных от ETS2 / ATS',
        );
      }
    }

    if (_autoReconnectEnabled &&
        _isForeground &&
        !_connecting &&
        _socket == null &&
        _reconnectTimer == null) {
      _scheduleReconnect();
    }
  }

  // ==========================================
  // DEVICE IDENTIFICATION
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
      debugPrint('TruckLink device info: $error');
    }

    if (!_isCurrent(generation) ||
        !identical(_socket, socket) ||
        socket.readyState != WebSocket.open) {
      return;
    }

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
    } catch (error) {
      debugPrint('TruckLink device hello: $error');
    }
  }

  String _cleanLabel(String value, int maxLength) {
    final cleaned = value
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return cleaned.length <= maxLength
        ? cleaned
        : cleaned.substring(0, maxLength);
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;

    return value[0].toUpperCase() + value.substring(1);
  }

  // ==========================================
  // CONNECTION ERROR DESCRIPTION
  // ==========================================

  String _connectionErrorMessage(Object error, String host) {
    if (error is TimeoutException) {
      return 'ПК не ответил за '
          '${connectionTimeout.inSeconds} секунд. '
          'Повторим попытку автоматически.';
    }

    if (error is SocketException) {
      return 'Windows Hub по адресу '
          '$host:$serverPort недоступен.';
    }

    if (error is WebSocketException || error is HttpException) {
      return 'Сервер $host:$serverPort '
          'не принял WebSocket-подключение.';
    }

    return 'Ошибка подключения: $error';
  }

  // ==========================================
  // JOB IDENTITY
  // ==========================================

  String _jobIdentity(TruckLinkJobTelemetry job) {
    return jsonEncode([
      job.gameId,
      job.cargoId,
      job.cargoName,
      job.sourceCity,
      job.destinationCity,
      job.sourceCompany,
      job.destinationCompany,
      job.income,
      job.plannedDistanceKm,
    ]);
  }

  // ==========================================
  // SAVE JOB HISTORY
  // ==========================================

  Future<void> _saveHistory(JobLifecycleMessage details) async {
    final event = details.event;

    if (event != JobLifecycleEventKind.delivered &&
        event != JobLifecycleEventKind.cancelled) {
      return;
    }

    final id = details.eventId;
    final time = details.occurredAtUtc;
    final job = details.finalJob;

    if (id == null || time == null || job == null) {
      return;
    }

    try {
      await JobHistoryStore.instance.addEntry(
        JobHistoryEntry(id: id, result: event, completedAtUtc: time, job: job),
      );
    } catch (error) {
      debugPrint('TruckLink history save: $error');
    }
  }

  // ==========================================
  // SAVE FINANCIAL EVENT
  // ==========================================

  Future<void> _saveFinance(FinanceEvent event) async {
    try {
      await FinanceStore.instance.addEvent(event);
    } catch (error) {
      debugPrint('TruckLink finance save: $error');
    }
  }

  // ==========================================
  // RECEIVE WEBSOCKET MESSAGE
  // ==========================================

  void _handleMessage(int generation, dynamic message) {
    try {
      if (message is! String) {
        throw const FormatException('Expected WebSocket text message');
      }

      _lastMessageAt = DateTime.now();

      // ======================================
      // BEGIN ARCHIVE REPLAY
      // ======================================

      if (isEventSyncBeginMessage(message)) {
        _expectedSyncCount = decodeEventSyncBegin(message);

        _receivedSyncCount = 0;
        _syncInProgress = true;

        debugPrint(
          'TruckLink: receiving '
          '$_expectedSyncCount archived events',
        );

        _notify();
        return;
      }

      // ======================================
      // END ARCHIVE REPLAY
      // ======================================

      if (isEventSyncEndMessage(message)) {
        final count = decodeEventSyncEnd(message);

        _syncInProgress = false;
        _lastSyncCount = _receivedSyncCount;

        if (count != _expectedSyncCount || count != _receivedSyncCount) {
          debugPrint(
            'TruckLink: incomplete event sync '
            '($_receivedSyncCount/$count)',
          );
        } else {
          debugPrint(
            'TruckLink: synced '
            '$_lastSyncCount archived events',
          );
        }

        _notify();
        return;
      }

      // ======================================
      // FINANCIAL EVENT
      // ======================================

      if (isFinanceEventMessage(message)) {
        final event = decodeFinanceEvent(message);

        if (_syncInProgress) {
          _receivedSyncCount++;
        }

        // Store deduplicates by event.id.
        unawaited(_saveFinance(event));

        return;
      }

      // ======================================
      // JOB LIFECYCLE EVENT
      // ======================================

      if (isJobEventMessage(message)) {
        final details = decodeJobEventDetails(message);

        // ====================================
        // ARCHIVED JOB RESULT
        // ====================================

        if (_syncInProgress) {
          _receivedSyncCount++;

          // Archived results must never
          // clear a currently active delivery
          // or show an old completion banner.
          unawaited(_saveHistory(details));

          return;
        }

        // ====================================
        // NEW LIVE JOB
        // ====================================

        final event = details.event;

        if (event == JobLifecycleEventKind.started) {
          final hadResult = _lastJobEvent != null;

          _lastJobEvent = null;
          _endedJobIdentity = null;

          if (hadResult) {
            _notify();
          }

          return;
        }

        // ====================================
        // LIVE DELIVERY / CANCELLATION
        // ====================================

        final finishedJob = details.finalJob ?? _activeJob;

        if (finishedJob != null) {
          _endedJobIdentity = _jobIdentity(finishedJob);
        }

        _activeJob = null;
        _lastJobEvent = event;

        _notify();

        unawaited(_saveHistory(details));

        return;
      }

      // ======================================
      // ACTIVE JOB UPDATE
      // ======================================

      if (isJobUpdateMessage(message)) {
        final nextJob = decodeJobUpdate(message);

        // Ignore delayed data for a job
        // that was already completed.
        if (nextJob != null &&
            _endedJobIdentity != null &&
            _jobIdentity(nextJob) == _endedJobIdentity) {
          return;
        }

        if (nextJob == null) {
          _endedJobIdentity = null;
        }

        final previousJob = _activeJob;

        final changed = !mapEquals(previousJob?.toJson(), nextJob?.toJson());

        _activeJob = nextJob;

        var resultChanged = false;

        if (nextJob != null && _lastJobEvent != null) {
          _lastJobEvent = null;
          _endedJobIdentity = null;
          resultChanged = true;
        }

        if (changed || resultChanged) {
          _notify();
        }

        return;
      }

      // ======================================
      // ORDINARY TRUCK SNAPSHOT
      // ======================================

      final nextSnapshot = decodeSnapshot(message);

      _pendingSnapshot = nextSnapshot;
      _lastReceivedAt = DateTime.now();

      _updateTimer ??= Timer(uiUpdateInterval, _publishPendingSnapshot);
    } catch (error) {
      _handleConnectionLost(generation, 'Ошибка формата телеметрии: $error');
    }
  }

  // ==========================================
  // PUBLISH SNAPSHOT
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
  // CONNECTION WATCHDOG
  // ==========================================

  void _handleConnectionLost(int generation, String message) {
    if (!_isCurrent(generation)) return;

    ++_generation;
    _connecting = false;

    _stopTransport();
    _clearTelemetry();

    _host = null;
    _connectedAt = null;
    _lastMessageAt = null;

    _setStatus(TelemetryConnectionStatus.error, message);

    _scheduleReconnect();
  }

  // ==========================================
  // MANUAL DISCONNECT
  // ==========================================

  Future<void> disconnect() async {
    if (_disposed) return;

    _autoReconnectEnabled = false;
    _desiredHost = null;
    _reconnectAttempt = 0;

    _cancelReconnect();

    ++_generation;
    _connecting = false;

    _stopTransport();
    _clearTelemetry();

    _host = null;
    _connectedAt = null;
    _lastMessageAt = null;

    _setStatus(
      TelemetryConnectionStatus.disconnected,
      'Отключено от Windows Hub',
    );
  }

  // ==========================================
  // STOP TRANSPORT
  // ==========================================

  void _stopTransport() {
    final subscription = _subscription;
    final socket = _socket;
    final client = _httpClient;

    _subscription = null;
    _socket = null;
    _httpClient = null;

    subscription?.cancel().ignore();
    socket?.close().ignore();

    client?.close(force: true);
  }

  // ==========================================
  // CLEAR LIVE STATE
  // ==========================================

  void _clearTelemetry({bool preserveLastJobEvent = false}) {
    _updateTimer?.cancel();
    _updateTimer = null;

    _snapshot = null;
    _pendingSnapshot = null;

    _activeJob = null;
    _lastReceivedAt = null;

    _syncInProgress = false;
    _expectedSyncCount = 0;
    _receivedSyncCount = 0;

    if (!preserveLastJobEvent) {
      _lastJobEvent = null;
      _endedJobIdentity = null;
    }
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
  // CLEANUP
  // ==========================================

  @override
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    ++_generation;

    _autoReconnectEnabled = false;

    _cancelReconnect();
    _lifecycleListener.dispose();

    _watchdog?.cancel();
    _watchdog = null;

    _updateTimer?.cancel();
    _updateTimer = null;

    _stopTransport();
    _clearTelemetry();

    super.dispose();
  }
}
