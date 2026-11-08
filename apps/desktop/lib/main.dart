import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_protocol/event_sync_protocol.dart';
import 'package:network_protocol/finance_protocol.dart';
import 'package:network_protocol/job_lifecycle_protocol.dart';
import 'package:network_protocol/job_protocol.dart';
import 'package:network_protocol/network_protocol.dart';
import 'package:telemetry_core/job_telemetry.dart';
import 'package:telemetry_core/telemetry_core.dart';

import 'services/hub_event_journal.dart';
import 'services/scs_finance_reader.dart';
import 'services/scs_job_bridge.dart';
import 'services/scs_job_lifecycle_tracker.dart';
import 'services/scs_plugin_detector.dart';
import 'services/scs_telemetry_reader.dart';

void main() {
  runApp(const ProviderScope(child: DesktopApp()));
}

class DesktopApp extends StatelessWidget {
  const DesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TruckLink Hub',
      debugShowCheckedModeBanner: false,
      theme: TruckLinkTheme.dark,
      home: const DesktopHome(),
    );
  }
}

class _ConnectedDevice {
  const _ConnectedDevice({
    required this.ip,
    required this.connectedAt,
    this.name,
    this.platform,
  });

  final String ip;
  final DateTime connectedAt;
  final String? name;
  final String? platform;

  String get displayName {
    final candidate = name;
    return candidate == null || candidate.isEmpty
        ? 'Устройство $ip'
        : candidate;
  }

  String get connectedTime {
    final hours = connectedAt.hour.toString().padLeft(2, '0');
    final minutes = connectedAt.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  _ConnectedDevice withIdentity(String newName, String newPlatform) {
    return _ConnectedDevice(
      ip: ip,
      connectedAt: connectedAt,
      name: newName,
      platform: newPlatform,
    );
  }
}

class DesktopHome extends StatefulWidget {
  const DesktopHome({super.key});

  @override
  State<DesktopHome> createState() => _DesktopHomeState();
}

class _DesktopHomeState extends State<DesktopHome> {
  // ==========================================
  // CONSTANTS
  // ==========================================

  static const int serverPort = 8787;

  static const Color _accent = Color(0xFF10EF78);
  static const Color _warning = Color(0xFFFFBA63);
  static const Color _muted = Color(0xFF9BAAB9);
  static const Color _surface = Color(0xFF15232F);

  static const Duration _jobUpdateInterval = Duration(seconds: 1);

  static const Duration _jobCandidateLifetime = Duration(hours: 2);

  // ==========================================
  // SERVICES
  // ==========================================

  final ScsTelemetryReader _telemetryReader = ScsTelemetryReader();

  final ScsJobLifecycleTracker _jobTracker = ScsJobLifecycleTracker();

  final ScsFinanceReader _financeReader = ScsFinanceReader();

  final ScsPluginDetector _pluginDetector = const ScsPluginDetector();

  late final Future<HubEventJournal?> _journalFuture;

  // ==========================================
  // TIMERS AND SERVER
  // ==========================================

  Timer? _telemetryTimer;
  Timer? _pluginTimer;

  HttpServer? _server;

  final Map<WebSocket, _ConnectedDevice> _clients = {};

  final Set<WebSocket> _syncingClients = {};

  // ==========================================
  // GAME TELEMETRY
  // ==========================================

  TruckSnapshot? _snapshot;
  TruckLinkJobTelemetry? _activeJob;
  TruckLinkJobTelemetry? _historyCandidate;

  int? _lastTimestamp;

  DateTime? _lastFrameAt;
  DateTime? _historyCandidateAt;
  DateTime? _lastJobSentAt;

  String? _lastJobSentKey;

  int _jobEventSerial = 0;
  int _financeEventSerial = 0;

  bool _telemetryActive = false;
  bool _sharedMemoryAvailable = false;

  // ==========================================
  // HUB STATUS
  // ==========================================

  bool _serverStarting = false;
  bool _serverStopping = false;
  bool _pluginChecking = false;

  String? _gameName;
  String? _localIp;

  String _gameStatus = 'Ожидание ETS2 / ATS';
  String _serverStatus = 'Сервер остановлен';

  ScsPluginScanResult? _pluginReport;

  // ==========================================
  // INITIALIZATION
  // ==========================================

  @override
  void initState() {
    super.initState();

    _journalFuture = _openJournal();

    _telemetryTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _pollTelemetry(),
    );

    _pluginTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_scanPlugin()),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _pollTelemetry();
      unawaited(_scanPlugin());
      unawaited(_findLocalIp());
    });
  }

  // ==========================================
  // EVENT JOURNAL
  // ==========================================

  Future<HubEventJournal?> _openJournal() async {
    try {
      final journal = await HubEventJournal.open();

      debugPrint(
        'TruckLink: journal contains '
        '${journal.eventCount} events',
      );

      return journal;
    } catch (error) {
      debugPrint(
        'TruckLink: cannot open event journal: '
        '$error',
      );

      return null;
    }
  }

  // ==========================================
  // JOB IDENTITY
  // ==========================================

  String _jobIdentity(TruckLinkJobTelemetry? job) {
    if (job == null) return '<no-job>';

    return jsonEncode(<Object>[
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

  void _clearHistoryCandidate() {
    _historyCandidate = null;
    _historyCandidateAt = null;
  }

  // ==========================================
  // UNAVAILABLE TELEMETRY
  // ==========================================

  void _setUnavailable(
    String status, {
    String? gameName,
    bool memoryAvailable = false,
    bool keepTimestamp = false,
  }) {
    final changed =
        _snapshot != null ||
        _activeJob != null ||
        _telemetryActive ||
        _sharedMemoryAvailable != memoryAvailable ||
        _gameName != gameName ||
        _gameStatus != status;

    final hadJob = _activeJob != null;

    _snapshot = null;
    _activeJob = null;

    _telemetryActive = false;
    _sharedMemoryAvailable = memoryAvailable;

    _gameName = gameName;
    _gameStatus = status;

    if (!keepTimestamp) {
      _lastTimestamp = null;
      _lastFrameAt = null;
    }

    if (hadJob) {
      _sendJobUpdate(null);
    }

    if (changed && mounted) {
      setState(() {});
    }
  }

  // ==========================================
  // POLL ALL SCS TELEMETRY
  // ==========================================

  void _pollTelemetry() {
    if (!mounted) return;

    // Financial flags are read separately.
    // They can change when the ordinary
    // truck timestamp is unchanged.
    try {
      final financeEvents = _financeReader.poll();

      for (final occurrence in financeEvents) {
        _recordFinanceEvent(occurrence);
      }
    } catch (error) {
      debugPrint('TruckLink: finance poll failed: $error');

      _financeReader.reset();
    }

    try {
      final frame = _telemetryReader.read();

      // ======================================
      // GAME IS NOT RUNNING
      // ======================================

      if (frame == null) {
        _jobTracker.reset();
        _clearHistoryCandidate();

        _setUnavailable('Ожидание запуска игры');

        return;
      }

      final String? gameName;

      if (frame.gameId == 1) {
        gameName = 'Euro Truck Simulator 2';
      } else if (frame.gameId == 2) {
        gameName = 'American Truck Simulator';
      } else {
        gameName = null;
      }

      // ======================================
      // SDK INACTIVE
      // ======================================

      if (!frame.sdkActive) {
        _jobTracker.reset();
        _clearHistoryCandidate();

        _setUnavailable(
          'SDK обнаружен, но не активен',
          gameName: gameName,
          memoryAvailable: true,
        );

        return;
      }

      // ======================================
      // JOB LIFECYCLE
      // ======================================

      final jobEvent = _jobTracker.observe(
        gameId: frame.gameId,
        onJob: frame.hasActiveJob,
        deliveredFlag: frame.jobDeliveredEventFlag,
        cancelledFlag: frame.jobCancelledEventFlag,
      );

      final observedJob = jobTelemetryFromScs(frame);

      final terminal =
          jobEvent == JobLifecycleEventKind.delivered ||
          jobEvent == JobLifecycleEventKind.cancelled;

      if (jobEvent == JobLifecycleEventKind.started) {
        _clearHistoryCandidate();
      }

      if (!terminal && observedJob != null) {
        _historyCandidate = observedJob;
        _historyCandidateAt = DateTime.now();
      }

      // ======================================
      // PAUSED / INACTIVE GAME
      // ======================================

      if (frame.paused || !frame.isLive) {
        _setUnavailable(
          frame.paused ? 'Игра на паузе' : 'Ожидание игровых данных',
          gameName: gameName,
          memoryAvailable: true,
        );

        if (jobEvent != null) {
          _recordJobEvent(jobEvent, frame.gameId);
        }

        return;
      }

      final now = DateTime.now();

      final newTimestamp = _lastTimestamp != frame.timestamp;

      // ======================================
      // STALE FRAME PROTECTION
      // ======================================

      if (!newTimestamp &&
          _lastFrameAt != null &&
          now.difference(_lastFrameAt!) > const Duration(seconds: 4)) {
        _setUnavailable(
          'Нет новых данных от игры',
          gameName: gameName,
          memoryAvailable: true,
          keepTimestamp: true,
        );

        if (jobEvent != null) {
          _recordJobEvent(jobEvent, frame.gameId);
        }

        return;
      }

      // ======================================
      // ORDINARY TRUCK DATA
      // ======================================

      if (newTimestamp) {
        _lastTimestamp = frame.timestamp;
        _lastFrameAt = now;

        _snapshot = frame.toTruckSnapshot();

        _sendSnapshot();
      }

      // ======================================
      // CURRENT JOB
      // ======================================

      final oldKey = _jobIdentity(_activeJob);
      final newKey = _jobIdentity(observedJob);

      _activeJob = observedJob;

      final shouldRefreshUi =
          !_telemetryActive ||
          !_sharedMemoryAvailable ||
          _gameName != gameName ||
          _gameStatus != 'Телеметрия активна';

      _telemetryActive = true;
      _sharedMemoryAvailable = true;

      _gameName = gameName;
      _gameStatus = 'Телеметрия активна';

      if (newTimestamp || oldKey != newKey || jobEvent != null) {
        _sendJobUpdate(observedJob);
      }

      if (jobEvent != null) {
        _recordJobEvent(jobEvent, frame.gameId);
      }

      if (shouldRefreshUi && mounted) {
        setState(() {});
      }
    } catch (error) {
      _jobTracker.reset();
      _clearHistoryCandidate();

      _setUnavailable('Ошибка чтения: $error');
    }
  }

  // ==========================================
  // BROADCAST SNAPSHOT
  // ==========================================

  void _sendSnapshot() {
    if (_server == null || _snapshot == null) {
      return;
    }

    _sendAll(encodeSnapshot(_snapshot!));
  }

  // ==========================================
  // BROADCAST CURRENT JOB
  // ==========================================

  void _sendJobUpdate(TruckLinkJobTelemetry? job) {
    if (_server == null) return;

    final now = DateTime.now();
    final identity = _jobIdentity(job);

    final changed = identity != _lastJobSentKey;

    final allowedByTime =
        _lastJobSentAt == null ||
        now.difference(_lastJobSentAt!) >= _jobUpdateInterval;

    if (!changed && (job == null || !allowedByTime)) {
      return;
    }

    _lastJobSentKey = identity;
    _lastJobSentAt = now;

    _sendAll(encodeJobUpdate(job));
  }

  // ==========================================
  // JOB LIFECYCLE EVENT
  // ==========================================

  void _recordJobEvent(JobLifecycleEventKind kind, int gameId) {
    final terminal =
        kind == JobLifecycleEventKind.delivered ||
        kind == JobLifecycleEventKind.cancelled;

    final now = DateTime.now().toUtc();

    TruckLinkJobTelemetry? finalJob;

    if (terminal &&
        _historyCandidate != null &&
        _historyCandidate!.gameId == gameId &&
        _historyCandidateAt != null) {
      final age = DateTime.now().difference(_historyCandidateAt!);

      if (!age.isNegative && age <= _jobCandidateLifetime) {
        finalJob = _historyCandidate;
      }
    }

    String? id;

    if (terminal && finalJob != null) {
      _jobEventSerial++;

      id =
          'job-$pid-${now.microsecondsSinceEpoch}'
          '-$_jobEventSerial';
    }

    final message = encodeJobEvent(
      kind,
      eventId: id,
      occurredAtUtc: id == null ? null : now,
      finalJob: finalJob,
    );

    if (id != null) {
      unawaited(_saveAndSend(id, message));
    } else {
      _sendAll(message);
    }

    if (terminal) {
      _clearHistoryCandidate();
    }

    debugPrint('TruckLink: job event ${kind.name}');
  }

  // ==========================================
  // FINANCIAL EVENT
  // ==========================================

  void _recordFinanceEvent(ScsFinanceOccurrence occurrence) {
    final now = DateTime.now().toUtc();

    _financeEventSerial++;

    final event = FinanceEvent(
      id:
          'fin-$pid-${now.microsecondsSinceEpoch}'
          '-$_financeEventSerial',
      gameId: occurrence.gameId,
      kind: occurrence.kind,
      amount: occurrence.signedAmount,
      occurredAtUtc: now,
    );

    unawaited(_saveAndSend(event.id, encodeFinanceEvent(event)));

    debugPrint(
      'TruckLink: finance '
      '${event.kind.name} ${event.amount}',
    );
  }

  // ==========================================
  // SAVE TO JOURNAL THEN BROADCAST
  // ==========================================

  Future<void> _saveAndSend(String id, String message) async {
    try {
      final journal = await _journalFuture;

      if (journal != null) {
        await journal.add(id: id, message: message);
      } else {
        debugPrint(
          'TruckLink: journal unavailable, '
          'event is live-only',
        );
      }
    } catch (error) {
      debugPrint('TruckLink: cannot archive $id: $error');
    }

    if (mounted) {
      _sendAll(message);
    }
  }

  // ==========================================
  // SEND MESSAGE TO ALL CONNECTED CLIENTS
  // ==========================================

  void _sendAll(String message) {
    if (_server == null) return;

    for (final socket in _clients.keys.toList()) {
      try {
        socket.add(message);
      } catch (error) {
        debugPrint(
          'TruckLink: WebSocket send error: '
          '$error',
        );

        _removeClient(socket);
      }
    }
  }

  // ==========================================
  // REPLAY EVENT JOURNAL TO ONE CLIENT
  // ==========================================

  Future<void> _replayEvents(WebSocket socket) async {
    if (!_syncingClients.add(socket)) {
      return;
    }

    try {
      final journal = await _journalFuture;

      if (journal == null) {
        return;
      }

      final messages = await journal.replayMessages();

      if (!mounted || _server == null || !_clients.containsKey(socket)) {
        return;
      }

      // All three steps are performed without
      // awaiting between them to preserve
      // the ordering of the replay batch.
      socket.add(encodeEventSyncBegin(eventCount: messages.length));

      for (final message in messages) {
        socket.add(message);
      }

      socket.add(encodeEventSyncEnd(eventCount: messages.length));

      debugPrint(
        'TruckLink: replayed '
        '${messages.length} events',
      );
    } catch (error) {
      debugPrint('TruckLink: event sync failed: $error');

      _removeClient(socket);

      unawaited(socket.close());
    } finally {
      _syncingClients.remove(socket);
    }
  }

  // ==========================================
  // PLUGIN DETECTION
  // ==========================================

  Future<void> _scanPlugin() async {
    if (!mounted || _pluginChecking) return;

    setState(() {
      _pluginChecking = true;
    });

    try {
      final report = await _pluginDetector.scan();

      if (mounted) {
        setState(() {
          _pluginReport = report;
        });
      }
    } catch (error) {
      debugPrint(
        'TruckLink: plugin detection error: '
        '$error',
      );

      if (mounted) {
        setState(() {
          _pluginReport = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _pluginChecking = false;
        });
      }
    }
  }

  // ==========================================
  // LOCAL IP DETECTION
  // ==========================================

  Future<void> _findLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      final addresses = <String>[];

      for (final networkInterface in interfaces) {
        for (final address in networkInterface.addresses) {
          addresses.add(address.address);
        }
      }

      String? selected;

      for (final address in addresses) {
        if (address.startsWith('192.168.') || address.startsWith('10.')) {
          selected = address;
          break;
        }

        final octets = address.split('.');

        if (octets.length == 4 && octets.first == '172') {
          final second = int.tryParse(octets[1]);

          if (second != null && second >= 16 && second <= 31) {
            selected = address;
            break;
          }
        }
      }

      if (selected == null && addresses.isNotEmpty) {
        selected = addresses.first;
      }

      if (mounted) {
        setState(() {
          _localIp = selected;
        });
      }
    } catch (error) {
      debugPrint('TruckLink: IP detection error: $error');
    }
  }

  String get _serverAddress {
    if (_localIp == null) {
      return 'IP компьютера · порт $serverPort';
    }

    return 'ws://$_localIp:$serverPort';
  }

  // ==========================================
  // START WEBSOCKET SERVER
  // ==========================================

  Future<void> _startServer() async {
    if (_server != null || _serverStarting || _serverStopping) {
      return;
    }

    setState(() {
      _serverStarting = true;
      _serverStatus = 'Запуск сервера...';
    });

    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, serverPort);

      if (!mounted) {
        await server.close(force: true);
        return;
      }

      _server = server;

      _lastJobSentAt = null;
      _lastJobSentKey = null;

      setState(() {
        _serverStatus = 'Сервер запущен';
      });

      server.listen(
        (request) async {
          // ==================================
          // WEBSOCKET HANDSHAKE
          // ==================================

          if (!WebSocketTransformer.isUpgradeRequest(request)) {
            request.response.statusCode = HttpStatus.badRequest;

            await request.response.close();
            return;
          }

          final remoteIp =
              request.connectionInfo?.remoteAddress.address ?? 'Неизвестный IP';

          try {
            final socket = await WebSocketTransformer.upgrade(request);

            if (!mounted || !identical(_server, server)) {
              await socket.close();
              return;
            }

            _clients[socket] = _ConnectedDevice(
              ip: remoteIp,
              connectedAt: DateTime.now(),
            );

            // Send the current game state to
            // the newly connected phone.
            if (_snapshot != null) {
              socket.add(encodeSnapshot(_snapshot!));
            }

            socket.add(encodeJobUpdate(_activeJob));

            socket.listen(
              (data) {
                _handleClientMessage(socket, data);
              },
              onDone: () {
                _removeClient(socket);
              },
              onError: (Object error) {
                _removeClient(socket);
              },
              cancelOnError: true,
            );

            if (mounted) {
              setState(() {});
            }
          } catch (error) {
            debugPrint(
              'TruckLink: WebSocket upgrade '
              'error: $error',
            );
          }
        },
        onError: (Object error) {
          debugPrint('TruckLink: server error: $error');
        },
        onDone: () {
          if (!mounted || !identical(_server, server)) {
            return;
          }

          setState(() {
            _server = null;
            _serverStatus = 'Сервер остановлен';
          });
        },
      );

      unawaited(_findLocalIp());
    } catch (error) {
      if (mounted) {
        setState(() {
          _serverStatus = 'Ошибка запуска: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _serverStarting = false;
        });
      }
    }
  }

  // ==========================================
  // HANDLE PHONE MESSAGES
  // ==========================================

  void _handleClientMessage(WebSocket socket, dynamic data) {
    if (data is! String || data.length > 1024) {
      return;
    }

    try {
      // ======================================
      // EVENT SYNCHRONIZATION REQUEST
      // ======================================

      if (isEventSyncRequestMessage(data)) {
        decodeEventSyncRequest(data);

        unawaited(_replayEvents(socket));

        return;
      }

      // ======================================
      // CLIENT IDENTIFICATION
      // ======================================

      final decoded = jsonDecode(data);

      if (decoded is! Map<String, dynamic> ||
          decoded['type'] != 'client_hello') {
        return;
      }

      final rawName = decoded['name'];

      if (rawName is! String) {
        return;
      }

      final name = _safeLabel(rawName, 64);

      if (name.isEmpty) return;

      final rawPlatform = decoded['platform'];

      final platform = rawPlatform is String ? _safeLabel(rawPlatform, 20) : '';

      final oldDevice = _clients[socket];

      if (oldDevice == null) return;

      if (oldDevice.name == name && oldDevice.platform == platform) {
        return;
      }

      _clients[socket] = oldDevice.withIdentity(name, platform);

      if (mounted) {
        setState(() {});
      }
    } on FormatException {
      // Ignore malformed client input.
    } catch (error) {
      debugPrint('TruckLink: bad client message: $error');
    }
  }

  // ==========================================
  // SAFE DEVICE NAME
  // ==========================================

  String _safeLabel(String text, int maximumLength) {
    final cleaned = text
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.length <= maximumLength) {
      return cleaned;
    }

    return cleaned.substring(0, maximumLength);
  }

  // ==========================================
  // REMOVE CLIENT
  // ==========================================

  void _removeClient(WebSocket socket) {
    final removed = _clients.remove(socket) != null;

    _syncingClients.remove(socket);

    if (removed && mounted) {
      setState(() {});
    }
  }

  // ==========================================
  // STOP WEBSOCKET SERVER
  // ==========================================

  Future<void> _stopServer() async {
    final server = _server;

    if (server == null || _serverStopping) {
      return;
    }

    setState(() {
      _serverStopping = true;
      _serverStatus = 'Остановка сервера...';
    });

    _server = null;

    try {
      for (final socket in _clients.keys.toList()) {
        try {
          await socket.close().timeout(const Duration(seconds: 2));
        } catch (_) {
          // Client is already disconnected.
        }
      }

      _clients.clear();
      _syncingClients.clear();

      await server.close(force: true);
    } catch (error) {
      debugPrint('TruckLink: server stop error: $error');
    } finally {
      _lastJobSentAt = null;
      _lastJobSentKey = null;

      if (mounted) {
        setState(() {
          _serverStopping = false;
          _serverStatus = 'Сервер остановлен';
        });
      }
    }
  }

  // ==========================================
  // OPEN PLUGIN DOWNLOAD PAGE
  // ==========================================

  Future<void> _openPluginDownload() async {
    try {
      await Process.start('explorer.exe', <String>[
        ScsPluginDetector.downloadUrl,
      ], mode: ProcessStartMode.detached);
    } catch (error) {
      debugPrint(
        'TruckLink: cannot open plugin page: '
        '$error',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть страницу плагина')),
      );
    }
  }

  // ==========================================
  // PLUGIN STATUS
  // ==========================================

  String get _pluginStatus {
    if (_telemetryActive) {
      return 'Работает';
    }

    if (_sharedMemoryAvailable) {
      return 'Обнаружен в памяти';
    }

    final report = _pluginReport;

    if (report == null) {
      return _pluginChecking ? 'Проверка...' : 'Не удалось проверить';
    }

    if (!report.hasGames) {
      return 'Путь игры не найден';
    }

    if (report.allInstalled) {
      return 'DLL установлена';
    }

    if (report.hasPlugin) {
      return 'Не для всех игр';
    }

    return 'Плагин не найден';
  }

  String get _pluginDetails {
    final report = _pluginReport;

    if (report == null) {
      return 'Проверка каталогов ETS2 / ATS';
    }

    if (!report.hasGames) {
      return 'Проверь библиотеки Steam';
    }

    final parts = <String>[];

    for (final game in report.games) {
      final label = game.pluginInstalled ? 'найден' : 'отсутствует';

      parts.add('${game.name}: $label');
    }

    return parts.join(' · ');
  }

  // ==========================================
  // UI CARD HELPERS
  // ==========================================

  Widget _card(Widget child) {
    return Card(
      margin: EdgeInsets.zero,
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFF2D4050)),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }

  Widget _statusIcon(IconData icon, Color color) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  // ==========================================
  // GAME CARD
  // ==========================================

  Widget _gameCard() {
    return _card(
      Row(
        children: [
          _statusIcon(
            Icons.sports_esports_outlined,
            _telemetryActive ? _accent : _warning,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ИГРА',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),

                const SizedBox(height: 4),

                Text(
                  _gameName ?? 'ETS2 / ATS',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  _gameStatus,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PLUGIN CARD
  // ==========================================

  Widget _pluginCard() {
    final report = _pluginReport;

    final ready =
        _telemetryActive ||
        _sharedMemoryAvailable ||
        report?.allInstalled == true;

    final needsDownload =
        !_telemetryActive &&
        !_sharedMemoryAvailable &&
        (report == null || !report.hasGames || report.hasMissingPlugin);

    final children = <Widget>[
      Row(
        children: [
          _statusIcon(Icons.extension_outlined, ready ? _accent : _warning),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ПЛАГИН ТЕЛЕМЕТРИИ',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),

                const SizedBox(height: 4),

                Text(
                  _pluginStatus,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  _pluginDetails,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),

          IconButton(
            tooltip: 'Проверить снова',
            onPressed: _pluginChecking ? null : () => unawaited(_scanPlugin()),
            icon: _pluginChecking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 19),
          ),
        ],
      ),
    ];

    if (needsDownload) {
      children.add(const SizedBox(height: 10));

      children.add(
        OutlinedButton.icon(
          onPressed: () => unawaited(_openPluginDownload()),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('Скачать / установить плагин'),
        ),
      );
    }

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  // ==========================================
  // SERVER CARD
  // ==========================================

  Widget _serverCard() {
    final running = _server != null;

    final busy = _serverStarting || _serverStopping;

    // Explicit button action instead of
    // deeply nested ternary expressions.
    final VoidCallback? action;

    if (busy) {
      action = null;
    } else if (running) {
      action = () => unawaited(_stopServer());
    } else {
      action = () => unawaited(_startServer());
    }

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _statusIcon(Icons.wifi_tethering, running ? _accent : _warning),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WEBSOCKET HUB',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _serverStatus,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                ':$serverPort',
                style: const TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Text(
                  _serverAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ),

              IconButton(
                tooltip: 'Скопировать адрес',
                onPressed: _localIp == null
                    ? null
                    : () => unawaited(
                        Clipboard.setData(ClipboardData(text: _serverAddress)),
                      ),
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),

          const SizedBox(height: 6),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: action,
              icon: Icon(
                running ? Icons.stop_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(
                busy
                    ? 'Подождите...'
                    : running
                    ? 'Остановить сервер'
                    : 'Запустить сервер',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CONNECTED DEVICE ROW
  // ==========================================

  Widget _deviceRow(_ConnectedDevice device) {
    final subtitles = <String>[];

    final platform = device.platform;

    if (platform != null && platform.isNotEmpty) {
      subtitles.add(platform);
    }

    subtitles.add(device.ip);
    subtitles.add('с ${device.connectedTime}');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          const Icon(Icons.smartphone_outlined, color: _accent, size: 21),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  subtitles.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          const Icon(Icons.circle, color: _accent, size: 8),
        ],
      ),
    );
  }

  // ==========================================
  // CONNECTED DEVICES CARD
  // ==========================================

  Widget _devicesCard() {
    final devices = _clients.values.toList();

    devices.sort((a, b) => b.connectedAt.compareTo(a.connectedAt));

    // Build the list explicitly to avoid
    // nested if/else/for collection syntax.
    final children = <Widget>[
      Row(
        children: [
          const Icon(Icons.devices_outlined, color: _accent, size: 21),

          const SizedBox(width: 10),

          const Expanded(
            child: Text(
              'Подключённые устройства',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),

          Text(
            '${devices.length}',
            style: const TextStyle(
              color: _accent,
              fontWeight: FontWeight.w800,
              fontSize: 23,
            ),
          ),
        ],
      ),
    ];

    if (devices.isEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Нет активных подключений',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ),
      );
    } else {
      for (final device in devices) {
        children.add(_deviceRow(device));
      }
    }

    return _card(
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  // ==========================================
  // BUILD HUB
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_shipping_rounded,
                    color: _accent,
                    size: 27,
                  ),

                  const SizedBox(width: 10),

                  Text(
                    'TruckLink Hub',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 5),

              const Text(
                'Связь между ETS2 / ATS и телефоном',
                style: TextStyle(color: _muted, fontSize: 12),
              ),

              const SizedBox(height: 17),

              _gameCard(),

              const SizedBox(height: 10),

              _pluginCard(),

              const SizedBox(height: 10),

              _serverCard(),

              const SizedBox(height: 10),

              _devicesCard(),

              const SizedBox(height: 12),

              const Text(
                'Используй только доверенную '
                'локальную сеть.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // CLEANUP
  // ==========================================

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _pluginTimer?.cancel();

    for (final socket in _clients.keys.toList()) {
      unawaited(socket.close());
    }

    _clients.clear();
    _syncingClients.clear();

    final server = _server;
    _server = null;

    if (server != null) {
      unawaited(server.close(force: true));
    }

    super.dispose();
  }
}
