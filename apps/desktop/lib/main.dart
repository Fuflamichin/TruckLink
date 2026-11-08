import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_protocol/finance_protocol.dart';
import 'package:network_protocol/job_lifecycle_protocol.dart';
import 'package:network_protocol/job_protocol.dart';
import 'package:network_protocol/network_protocol.dart';
import 'package:telemetry_core/job_telemetry.dart';
import 'package:telemetry_core/telemetry_core.dart';

import 'services/scs_finance_reader.dart';
import 'services/scs_job_bridge.dart';
import 'services/scs_job_lifecycle_tracker.dart';
import 'services/scs_plugin_detector.dart';
import 'services/scs_telemetry_reader.dart';

// ============================================
// APPLICATION
// ============================================

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

// ============================================
// CONNECTED DEVICE MODEL
// ============================================

class _ConnectedDevice {
  const _ConnectedDevice({
    required this.ipAddress,
    required this.connectedAt,
    this.name,
    this.platform,
  });

  final String ipAddress;
  final DateTime connectedAt;
  final String? name;
  final String? platform;

  _ConnectedDevice identified({
    required String name,
    required String platform,
  }) {
    return _ConnectedDevice(
      ipAddress: ipAddress,
      connectedAt: connectedAt,
      name: name,
      platform: platform,
    );
  }

  String get displayName {
    final value = name;

    return value == null || value.isEmpty ? 'Устройство $ipAddress' : value;
  }

  String get connectedTime {
    final hours = connectedAt.hour.toString().padLeft(2, '0');

    final minutes = connectedAt.minute.toString().padLeft(2, '0');

    return '$hours:$minutes';
  }
}

// ============================================
// DESKTOP HOME
// ============================================

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

  static const Duration _jobSendInterval = Duration(seconds: 1);

  static const Duration _historyCandidateLifetime = Duration(seconds: 30);

  // ==========================================
  // SCS SERVICES
  // ==========================================

  final ScsTelemetryReader _reader = ScsTelemetryReader();

  final ScsJobLifecycleTracker _lifecycle = ScsJobLifecycleTracker();

  final ScsFinanceReader _financeReader = ScsFinanceReader();

  final ScsPluginDetector _pluginDetector = const ScsPluginDetector();

  Timer? _telemetryTimer;
  Timer? _pluginTimer;

  // ==========================================
  // LIVE TELEMETRY
  // ==========================================

  TruckSnapshot? _snapshot;

  TruckLinkJobTelemetry? _activeJob;

  int? _lastTimestamp;

  DateTime? _lastFrameAt;

  bool _telemetryActive = false;
  bool _sharedMemoryAvailable = false;

  String? _gameName;

  String _gameStatus = 'Ожидание ETS2 / ATS';

  // ==========================================
  // JOB HISTORY
  // ==========================================

  TruckLinkJobTelemetry? _historyCandidate;

  DateTime? _historyCandidateSeenAt;

  DateTime? _lastJobBroadcastAt;

  String? _lastJobBroadcastKey;

  int _historyEventSequence = 0;

  // ==========================================
  // FINANCE HISTORY
  // ==========================================

  int _financeEventSequence = 0;

  // ==========================================
  // PLUGIN STATUS
  // ==========================================

  ScsPluginScanResult? _pluginReport;

  bool _pluginChecking = false;

  // ==========================================
  // WEBSOCKET SERVER
  // ==========================================

  HttpServer? _server;

  final Map<WebSocket, _ConnectedDevice> _clients = {};

  bool _starting = false;
  bool _stopping = false;

  String _serverStatus = 'Сервер остановлен';

  String? _localIp;

  // ==========================================
  // INITIALIZATION
  // ==========================================

  @override
  void initState() {
    super.initState();

    _telemetryTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _readTelemetry(),
    );

    _pluginTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_checkPlugin()),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _readTelemetry();

      unawaited(_checkPlugin());
      unawaited(_detectLocalIp());
    });
  }

  // ==========================================
  // JOB IDENTITY
  // ==========================================

  String _jobKey(TruckLinkJobTelemetry? job) {
    if (job == null) {
      return '<no-job>';
    }

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
  // CLEAR HISTORY CANDIDATE
  // ==========================================

  void _clearHistoryCandidate() {
    _historyCandidate = null;
    _historyCandidateSeenAt = null;
  }

  // ==========================================
  // TELEMETRY UNAVAILABLE
  // ==========================================

  void _setTelemetryUnavailable(
    String message, {
    String? gameName,
    bool mappingAvailable = false,
  }) {
    final changed =
        _snapshot != null ||
        _activeJob != null ||
        _telemetryActive ||
        _sharedMemoryAvailable != mappingAvailable ||
        _gameName != gameName ||
        _gameStatus != message;

    final hadJob = _activeJob != null;

    _snapshot = null;
    _activeJob = null;

    _lastTimestamp = null;
    _lastFrameAt = null;

    _telemetryActive = false;
    _sharedMemoryAvailable = mappingAvailable;

    _gameName = gameName;
    _gameStatus = message;

    if (hadJob) {
      _broadcastJob(null);
    }

    if (changed && mounted) {
      setState(() {});
    }
  }

  // ==========================================
  // STALE TELEMETRY
  // ==========================================

  void _markTelemetryStale(String? gameName) {
    final changed =
        _snapshot != null ||
        _activeJob != null ||
        _telemetryActive ||
        _gameStatus != 'Нет новых данных от игры';

    final hadJob = _activeJob != null;

    _snapshot = null;
    _activeJob = null;

    // Keep _lastTimestamp unchanged.
    // Otherwise a frozen frame may repeatedly
    // appear to be fresh.
    _telemetryActive = false;
    _sharedMemoryAvailable = true;

    _gameName = gameName;
    _gameStatus = 'Нет новых данных от игры';

    if (hadJob) {
      _broadcastJob(null);
    }

    if (changed && mounted) {
      setState(() {});
    }
  }

  // ==========================================
  // FINANCE READER
  // ==========================================

  void _readFinanceEvents() {
    try {
      final occurrences = _financeReader.poll();

      for (final occurrence in occurrences) {
        _broadcastFinanceEvent(occurrence);
      }
    } catch (error) {
      debugPrint('TruckLink finance reader: $error');

      _financeReader.reset();
    }
  }

  // ==========================================
  // FINANCE EVENT BROADCAST
  // ==========================================

  void _broadcastFinanceEvent(ScsFinanceOccurrence occurrence) {
    if (_server == null) return;

    final now = DateTime.now().toUtc();

    _financeEventSequence++;

    final event = FinanceEvent(
      id:
          'fin-$pid-${now.microsecondsSinceEpoch}'
          '-$_financeEventSequence',
      gameId: occurrence.gameId,
      kind: occurrence.kind,
      amount: occurrence.signedAmount,
      occurredAtUtc: now,
    );

    _sendToAll(encodeFinanceEvent(event));

    debugPrint(
      'TruckLink finance: '
      '${event.kind.name} ${event.amount}',
    );
  }

  // ==========================================
  // READ GAME TELEMETRY
  // ==========================================

  void _readTelemetry() {
    if (!mounted) return;

    // Financial events are processed separately
    // because their flags can change without
    // a new ordinary telemetry timestamp.
    _readFinanceEvents();

    try {
      final frame = _reader.read();

      // ======================================
      // NO GAME
      // ======================================

      if (frame == null) {
        _lifecycle.reset();
        _clearHistoryCandidate();

        _setTelemetryUnavailable('Ожидание запуска игры');

        return;
      }

      final gameName = switch (frame.gameId) {
        1 => 'Euro Truck Simulator 2',
        2 => 'American Truck Simulator',
        _ => null,
      };

      // ======================================
      // SDK INACTIVE
      // ======================================

      if (!frame.sdkActive) {
        _lifecycle.reset();
        _clearHistoryCandidate();

        _setTelemetryUnavailable(
          'SDK обнаружен, но не активен',
          gameName: gameName,
          mappingAvailable: true,
        );

        return;
      }

      // ======================================
      // JOB LIFECYCLE EVENTS
      // ======================================

      final event = _lifecycle.observe(
        gameId: frame.gameId,
        onJob: frame.hasActiveJob,
        deliveredFlag: frame.jobDeliveredEventFlag,
        cancelledFlag: frame.jobCancelledEventFlag,
      );

      final observedJob = jobTelemetryFromScs(frame);

      final terminal =
          event == JobLifecycleEventKind.delivered ||
          event == JobLifecycleEventKind.cancelled;

      if (!terminal && observedJob != null) {
        _historyCandidate = observedJob;
        _historyCandidateSeenAt = DateTime.now();
      }

      // ======================================
      // GAME PAUSED
      // ======================================

      if (frame.paused) {
        _setTelemetryUnavailable(
          'Игра на паузе',
          gameName: gameName,
          mappingAvailable: true,
        );

        if (event != null) {
          _broadcastJobEvent(event, gameId: frame.gameId);
        }

        return;
      }

      // ======================================
      // NOT LIVE
      // ======================================

      if (!frame.isLive) {
        _setTelemetryUnavailable(
          'Ожидание игровых данных',
          gameName: gameName,
          mappingAvailable: true,
        );

        if (event != null) {
          _broadcastJobEvent(event, gameId: frame.gameId);
        }

        return;
      }

      final now = DateTime.now();

      final hasNewTimestamp = _lastTimestamp != frame.timestamp;

      final lastFrame = _lastFrameAt;

      // ======================================
      // FROZEN FRAME
      // ======================================

      if (!hasNewTimestamp &&
          lastFrame != null &&
          now.difference(lastFrame) > const Duration(seconds: 4)) {
        _markTelemetryStale(gameName);

        if (event != null) {
          _broadcastJobEvent(event, gameId: frame.gameId);
        }

        return;
      }

      // ======================================
      // TRUCK SNAPSHOT
      // ======================================

      if (hasNewTimestamp) {
        _lastTimestamp = frame.timestamp;
        _lastFrameAt = now;

        _snapshot = frame.toTruckSnapshot();
      }

      // ======================================
      // ACTIVE JOB
      // ======================================

      final oldJobKey = _jobKey(_activeJob);
      final newJobKey = _jobKey(observedJob);

      _activeJob = observedJob;

      final updateUi =
          !_telemetryActive ||
          !_sharedMemoryAvailable ||
          _gameName != gameName ||
          _gameStatus != 'Телеметрия активна';

      _telemetryActive = true;
      _sharedMemoryAvailable = true;

      _gameName = gameName;
      _gameStatus = 'Телеметрия активна';

      // ======================================
      // TRUCK BROADCAST
      // ======================================

      if (hasNewTimestamp) {
        _broadcastSnapshot();
      }

      // ======================================
      // JOB BROADCAST
      // ======================================

      if (hasNewTimestamp || oldJobKey != newJobKey || event != null) {
        _broadcastJob(observedJob);
      }

      // ======================================
      // LIFECYCLE BROADCAST
      // ======================================

      if (event != null) {
        _broadcastJobEvent(event, gameId: frame.gameId);
      }

      if (updateUi && mounted) {
        setState(() {});
      }
    } catch (error) {
      _lifecycle.reset();
      _clearHistoryCandidate();

      _setTelemetryUnavailable('Ошибка чтения: $error');
    }
  }

  // ==========================================
  // BROADCAST TRUCK SNAPSHOT
  // ==========================================

  void _broadcastSnapshot() {
    final snapshot = _snapshot;

    if (_server == null || snapshot == null) {
      return;
    }

    _sendToAll(encodeSnapshot(snapshot));
  }

  // ==========================================
  // BROADCAST CURRENT JOB
  // ==========================================

  void _broadcastJob(TruckLinkJobTelemetry? job) {
    if (_server == null) return;

    final key = _jobKey(job);
    final now = DateTime.now();

    final changed = key != _lastJobBroadcastKey;

    final previous = _lastJobBroadcastAt;

    final intervalElapsed =
        previous == null || now.difference(previous) >= _jobSendInterval;

    if (!changed && (job == null || !intervalElapsed)) {
      return;
    }

    _lastJobBroadcastKey = key;
    _lastJobBroadcastAt = now;

    _sendToAll(encodeJobUpdate(job));
  }

  // ==========================================
  // JOB RESULT AND HISTORY
  // ==========================================

  void _broadcastJobEvent(JobLifecycleEventKind event, {required int gameId}) {
    final terminal =
        event == JobLifecycleEventKind.delivered ||
        event == JobLifecycleEventKind.cancelled;

    final now = DateTime.now();

    TruckLinkJobTelemetry? completedJob;
    String? eventId;

    if (terminal) {
      final candidate = _historyCandidate;
      final seenAt = _historyCandidateSeenAt;

      if (candidate != null && candidate.gameId == gameId && seenAt != null) {
        final age = now.difference(seenAt);

        if (!age.isNegative && age <= _historyCandidateLifetime) {
          completedJob = candidate;
        }
      }

      if (completedJob != null) {
        _historyEventSequence++;

        eventId =
            'job-$pid-${now.microsecondsSinceEpoch}'
            '-$_historyEventSequence';
      }
    }

    _sendToAll(
      encodeJobEvent(
        event,
        eventId: eventId,
        occurredAtUtc: eventId == null ? null : now.toUtc(),
        finalJob: completedJob,
      ),
    );

    debugPrint('TruckLink job event: ${event.name}');

    if (terminal) {
      _clearHistoryCandidate();
    }
  }

  // ==========================================
  // SEND TO ALL PHONES
  // ==========================================

  void _sendToAll(String message) {
    if (_server == null) return;

    for (final socket in _clients.keys.toList()) {
      try {
        socket.add(message);
      } catch (error) {
        debugPrint('TruckLink WebSocket send: $error');

        _removeClient(socket);
      }
    }
  }

  // ==========================================
  // PLUGIN DETECTION
  // ==========================================

  Future<void> _checkPlugin() async {
    if (!mounted || _pluginChecking) return;

    setState(() {
      _pluginChecking = true;
    });

    try {
      final result = await _pluginDetector.scan();

      if (!mounted) return;

      setState(() {
        _pluginReport = result;
      });
    } catch (error) {
      debugPrint('TruckLink plugin scan: $error');

      if (!mounted) return;

      setState(() {
        _pluginReport = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _pluginChecking = false;
        });
      }
    }
  }

  // ==========================================
  // DETECT LOCAL IP
  // ==========================================

  Future<void> _detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      final addresses = <String>[
        for (final interface in interfaces)
          for (final address in interface.addresses) address.address,
      ];

      bool isPrivate(String address) {
        if (address.startsWith('192.168.') || address.startsWith('10.')) {
          return true;
        }

        final parts = address.split('.');

        if (parts.length != 4 || parts[0] != '172') {
          return false;
        }

        final second = int.tryParse(parts[1]);

        return second != null && second >= 16 && second <= 31;
      }

      final privateAddresses = addresses.where(isPrivate).toList();

      final ip = privateAddresses.isNotEmpty
          ? privateAddresses.first
          : addresses.isEmpty
          ? null
          : addresses.first;

      if (mounted) {
        setState(() {
          _localIp = ip;
        });
      }
    } catch (error) {
      debugPrint('TruckLink IP detection: $error');
    }
  }

  String get _serverAddress {
    final ip = _localIp;

    if (ip == null) {
      return 'IP компьютера · порт $serverPort';
    }

    return 'ws://$ip:$serverPort';
  }

  // ==========================================
  // START WEBSOCKET SERVER
  // ==========================================

  Future<void> _startServer() async {
    if (_server != null || _starting || _stopping) {
      return;
    }

    setState(() {
      _starting = true;
      _serverStatus = 'Запуск сервера...';
    });

    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, serverPort);

      if (!mounted) {
        await server.close(force: true);
        return;
      }

      _server = server;

      _lastJobBroadcastAt = null;
      _lastJobBroadcastKey = null;

      setState(() {
        _serverStatus = 'Сервер запущен';
      });

      server.listen(
        (request) async {
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
              ipAddress: remoteIp,
              connectedAt: DateTime.now(),
            );

            // Immediately send current state.
            // Historical events are not replayed.
            final snapshot = _snapshot;

            if (snapshot != null) {
              socket.add(encodeSnapshot(snapshot));
            }

            socket.add(encodeJobUpdate(_activeJob));

            socket.listen(
              (message) {
                _handleClientMessage(socket, message);
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
              'TruckLink WebSocket handshake: '
              '$error',
            );
          }
        },
        onError: (Object error) {
          debugPrint('TruckLink server: $error');
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

      unawaited(_detectLocalIp());
    } catch (error) {
      if (mounted) {
        setState(() {
          _serverStatus = 'Ошибка запуска: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
        });
      }
    }
  }

  // ==========================================
  // CLIENT HELLO
  // ==========================================

  void _handleClientMessage(WebSocket socket, dynamic message) {
    if (message is! String || message.length > 1024) {
      return;
    }

    try {
      final data = jsonDecode(message);

      if (data is! Map<String, dynamic> || data['type'] != 'client_hello') {
        return;
      }

      final rawName = data['name'];

      if (rawName is! String) return;

      final name = _cleanLabel(rawName, 64);

      if (name.isEmpty) return;

      final rawPlatform = data['platform'];

      final platform = rawPlatform is String
          ? _cleanLabel(rawPlatform, 20)
          : '';

      final previous = _clients[socket];

      if (previous == null) return;

      if (previous.name == name && previous.platform == platform) {
        return;
      }

      _clients[socket] = previous.identified(name: name, platform: platform);

      if (mounted) {
        setState(() {});
      }
    } on FormatException {
      // Ignore malformed identification data.
    } catch (error) {
      debugPrint('TruckLink client identification: $error');
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

  // ==========================================
  // REMOVE DEVICE
  // ==========================================

  void _removeClient(WebSocket socket) {
    final removed = _clients.remove(socket) != null;

    if (removed && mounted) {
      setState(() {});
    }
  }

  // ==========================================
  // STOP SERVER
  // ==========================================

  Future<void> _stopServer() async {
    final server = _server;

    if (server == null || _stopping) {
      return;
    }

    setState(() {
      _stopping = true;
      _serverStatus = 'Остановка сервера...';
    });

    _server = null;

    try {
      for (final socket in _clients.keys.toList()) {
        try {
          await socket.close().timeout(const Duration(seconds: 2));
        } catch (_) {
          // The socket may already be closed.
        }
      }

      _clients.clear();

      await server.close(force: true);
    } catch (error) {
      debugPrint('TruckLink server stop: $error');
    } finally {
      _lastJobBroadcastAt = null;
      _lastJobBroadcastKey = null;

      if (mounted) {
        setState(() {
          _stopping = false;
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
      await Process.start('explorer.exe', [
        ScsPluginDetector.downloadUrl,
      ], mode: ProcessStartMode.detached);
    } catch (error) {
      debugPrint('TruckLink plugin download: $error');

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

    return report.games
        .map((game) {
          final status = game.pluginInstalled ? 'найден' : 'отсутствует';

          return '${game.name}: $status';
        })
        .join(' · ');
  }

  // ==========================================
  // CARD HELPERS
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

  Widget _buildGameCard() {
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
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
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

  Widget _buildPluginCard() {
    final report = _pluginReport;

    final ready =
        _telemetryActive ||
        _sharedMemoryAvailable ||
        report?.allInstalled == true;

    final offerDownload =
        !_telemetryActive &&
        !_sharedMemoryAvailable &&
        (report == null || !report.hasGames || report.hasMissingPlugin);

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                onPressed: _pluginChecking
                    ? null
                    : () => unawaited(_checkPlugin()),
                icon: _pluginChecking
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 19),
              ),
            ],
          ),

          if (offerDownload) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => unawaited(_openPluginDownload()),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Скачать / установить плагин'),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // SERVER CARD
  // ==========================================

  Widget _buildServerCard() {
    final running = _server != null;
    final busy = _starting || _stopping;

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
              onPressed: busy
                  ? null
                  : running
                  ? () => unawaited(_stopServer())
                  : () => unawaited(_startServer()),
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
  // CONNECTED DEVICES CARD
  // ==========================================

  Widget _buildDevicesCard() {
    final devices = _clients.values.toList()
      ..sort((a, b) => b.connectedAt.compareTo(a.connectedAt));

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          if (devices.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Нет активных подключений',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            )
          else
            for (final device in devices) _deviceRow(device),
        ],
      ),
    );
  }

  // ==========================================
  // CONNECTED DEVICE ROW
  // ==========================================

  Widget _deviceRow(_ConnectedDevice device) {
    // Build the subtitle separately to keep
    // the widget tree simple and valid.
    final subtitleParts = <String>[];

    final platform = device.platform;

    if (platform != null && platform.isNotEmpty) {
      subtitleParts.add(platform);
    }

    subtitleParts.add(device.ipAddress);
    subtitleParts.add('с ${device.connectedTime}');

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
                  subtitleParts.join(' · '),
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
                'Связь между ETS2 / ATS '
                'и телефоном',
                style: TextStyle(color: _muted, fontSize: 12),
              ),

              const SizedBox(height: 17),

              _buildGameCard(),

              const SizedBox(height: 10),

              _buildPluginCard(),

              const SizedBox(height: 10),

              _buildServerCard(),

              const SizedBox(height: 10),

              _buildDevicesCard(),

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
  // DISPOSE
  // ==========================================

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _pluginTimer?.cancel();

    for (final socket in _clients.keys.toList()) {
      unawaited(socket.close());
    }

    _clients.clear();

    final server = _server;
    _server = null;

    if (server != null) {
      unawaited(server.close(force: true));
    }

    super.dispose();
  }
}
