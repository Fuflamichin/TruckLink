import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_protocol/network_protocol.dart';
import 'package:network_protocol/job_protocol.dart';
import 'package:network_protocol/job_lifecycle_protocol.dart';
import 'package:telemetry_core/telemetry_core.dart';
import 'package:telemetry_core/job_telemetry.dart';

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
// CONNECTED DEVICE
// ============================================

class _ConnectedDevice {
  const _ConnectedDevice({
    required this.ipAddress,
    required this.connectedAt,
    this.deviceName,
    this.platform,
  });

  final String ipAddress;
  final DateTime connectedAt;
  final String? deviceName;
  final String? platform;

  _ConnectedDevice withIdentity({
    required String name,
    required String platformName,
  }) {
    return _ConnectedDevice(
      ipAddress: ipAddress,
      connectedAt: connectedAt,
      deviceName: name,
      platform: platformName,
    );
  }

  String get displayName {
    final name = deviceName;
    return name == null || name.isEmpty ? 'Устройство $ipAddress' : name;
  }

  String get timeText {
    final h = connectedAt.hour.toString().padLeft(2, '0');

    final m = connectedAt.minute.toString().padLeft(2, '0');

    return '$h:$m';
  }
}

// ============================================
// WINDOWS HUB HOME
// ============================================

class DesktopHome extends StatefulWidget {
  const DesktopHome({super.key});

  @override
  State<DesktopHome> createState() => _DesktopHomeState();
}

class _DesktopHomeState extends State<DesktopHome> {
  // ==========================================
  // THEME
  // ==========================================

  static const Color _accent = Color(0xFF10EF78);

  static const Color _warning = Color(0xFFFFBA63);

  static const Color _muted = Color(0xFF9BAAB9);

  static const Color _surface = Color(0xFF15232F);

  // ==========================================
  // TELEMETRY
  // ==========================================

  final ScsTelemetryReader _reader = ScsTelemetryReader();

  Timer? _telemetryTimer;

  TruckSnapshot? _snapshot;
  TruckLinkJobTelemetry? _activeJob;

  int? _lastTimestamp;
  DateTime? _lastFrameAt;

  bool _telemetryActive = false;
  bool _sharedMemoryAvailable = false;

  String? _gameName;
  String _gameStatus = 'Ожидание ETS2 / ATS';

  // ==========================================
  // JOB LIFECYCLE
  // ==========================================

  final ScsJobLifecycleTracker _jobLifecycle = ScsJobLifecycleTracker();

  DateTime? _lastJobBroadcastAt;
  String? _lastJobBroadcastKey;

  static const Duration _jobBroadcastInterval = Duration(seconds: 1);

  // ==========================================
  // PLUGIN DETECTOR
  // ==========================================

  final ScsPluginDetector _pluginDetector = const ScsPluginDetector();

  ScsPluginScanResult? _pluginReport;

  Timer? _pluginTimer;
  bool _pluginChecking = false;

  // ==========================================
  // WEBSOCKET
  // ==========================================

  static const int serverPort = 8787;

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

  // Fields that identify the delivery.
  // Changing GPS distance does not make
  // it a different job.
  String _jobKey(TruckLinkJobTelemetry? job) {
    if (job == null) {
      return '<no-job>';
    }

    return [
      job.gameId,
      job.cargoId,
      job.sourceCity,
      job.destinationCity,
      job.sourceCompany,
      job.destinationCompany,
      job.income,
    ].join('|');
  }

  // ==========================================
  // TELEMETRY UNAVAILABLE
  // ==========================================

  void _setTelemetryUnavailable(
    String status, {
    String? gameName,
    bool mappingAvailable = false,
  }) {
    final changed =
        _snapshot != null ||
        _activeJob != null ||
        _telemetryActive ||
        _sharedMemoryAvailable != mappingAvailable ||
        _gameName != gameName ||
        _gameStatus != status;

    final hadJob = _activeJob != null;

    _snapshot = null;
    _activeJob = null;

    _lastTimestamp = null;
    _lastFrameAt = null;

    _telemetryActive = false;
    _sharedMemoryAvailable = mappingAvailable;

    _gameName = gameName;
    _gameStatus = status;

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

    _telemetryActive = false;
    _sharedMemoryAvailable = true;

    _gameName = gameName;
    _gameStatus = 'Нет новых данных от игры';

    // Do not reset _lastTimestamp.
    // Otherwise a frozen frame would
    // repeatedly look fresh.
    if (hadJob) {
      _broadcastJob(null);
    }

    if (changed && mounted) {
      setState(() {});
    }
  }

  // ==========================================
  // READ SCS TELEMETRY
  // ==========================================

  void _readTelemetry() {
    if (!mounted) return;

    try {
      final frame = _reader.read();

      if (frame == null) {
        _jobLifecycle.reset();

        _setTelemetryUnavailable('Ожидание запуска игры');
        return;
      }

      final gameName = switch (frame.gameId) {
        1 => 'Euro Truck Simulator 2',
        2 => 'American Truck Simulator',
        _ => null,
      };

      if (!frame.sdkActive) {
        _jobLifecycle.reset();

        _setTelemetryUnavailable(
          'SDK обнаружен, но не активен',
          gameName: gameName,
          mappingAvailable: true,
        );
        return;
      }

      // ======================================
      // TRACK SDK JOB EVENTS
      // ======================================

      // Observe on every poll, even when
      // the regular timestamp is unchanged.
      final event = _jobLifecycle.observe(
        gameId: frame.gameId,
        onJob: frame.hasActiveJob,
        deliveredFlag: frame.jobDeliveredEventFlag,
        cancelledFlag: frame.jobCancelledEventFlag,
      );

      // ======================================
      // PAUSE / WAITING
      // ======================================

      if (frame.paused) {
        _setTelemetryUnavailable(
          'Игра на паузе',
          gameName: gameName,
          mappingAvailable: true,
        );

        if (event != null) {
          _broadcastJobEvent(event);
        }

        return;
      }

      if (!frame.isLive) {
        _setTelemetryUnavailable(
          'Ожидание игровых данных',
          gameName: gameName,
          mappingAvailable: true,
        );
        return;
      }

      final now = DateTime.now();

      final hasNewTimestamp = _lastTimestamp != frame.timestamp;

      // ======================================
      // CURRENT JOB
      // ======================================

      final nextJob = jobTelemetryFromScs(frame);

      final jobChanged = _jobKey(nextJob) != _jobKey(_activeJob);

      // ======================================
      // UPDATE TRUCK SNAPSHOT
      // ======================================

      if (hasNewTimestamp) {
        _lastTimestamp = frame.timestamp;
        _lastFrameAt = now;

        _snapshot = frame.toTruckSnapshot();
      }

      // Always keep the newest job reference.
      _activeJob = nextJob;

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
      // EXISTING SNAPSHOT PROTOCOL
      // ======================================

      if (hasNewTimestamp) {
        _broadcastSnapshot();
      }

      // ======================================
      // JOB UPDATE PROTOCOL
      // ======================================

      if (hasNewTimestamp || jobChanged || event != null) {
        _broadcastJob(nextJob);
      }

      // ======================================
      // JOB LIFECYCLE EVENT
      // ======================================

      // Send after job_update, so the
      // phone has the latest job state.
      if (event != null) {
        _broadcastJobEvent(event);
      }

      if (updateUi && mounted) {
        setState(() {});
      }

      // ======================================
      // STALE TELEMETRY CHECK
      // ======================================

      final lastFrame = _lastFrameAt;

      if (lastFrame != null &&
          now.difference(lastFrame) > const Duration(seconds: 4)) {
        _markTelemetryStale(gameName);
      }
    } catch (error) {
      _jobLifecycle.reset();

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

    final message = encodeSnapshot(snapshot);

    _sendToAll(message);
  }

  // ==========================================
  // BROADCAST JOB UPDATE
  // ==========================================

  void _broadcastJob(TruckLinkJobTelemetry? job) {
    if (_server == null) return;

    final now = DateTime.now();
    final key = _jobKey(job);

    final isDifferentJob = key != _lastJobBroadcastKey;

    final lastSent = _lastJobBroadcastAt;

    final intervalElapsed =
        lastSent == null || now.difference(lastSent) >= _jobBroadcastInterval;

    // No need to resend an unchanged null job.
    if (!isDifferentJob && job == null) {
      return;
    }

    // Active jobs update at most once
    // per second, unless the job changed.
    if (!isDifferentJob && !intervalElapsed) {
      return;
    }

    _lastJobBroadcastKey = key;
    _lastJobBroadcastAt = now;

    _sendToAll(encodeJobUpdate(job));
  }

  // ==========================================
  // BROADCAST JOB EVENT
  // ==========================================

  void _broadcastJobEvent(JobLifecycleEventKind event) {
    if (_server == null) return;

    debugPrint('TruckLink: job event ${event.name}');

    _sendToAll(encodeJobEvent(event));
  }

  // ==========================================
  // SEND TEXT TO ALL CLIENTS
  // ==========================================

  void _sendToAll(String message) {
    if (_server == null) return;

    for (final socket in _clients.keys.toList()) {
      try {
        socket.add(message);
      } catch (error) {
        debugPrint('TruckLink send error: $error');
        _removeClient(socket);
      }
    }
  }

  // ==========================================
  // CHECK PLUGIN INSTALLATION
  // ==========================================

  Future<void> _checkPlugin() async {
    if (!mounted || _pluginChecking) return;

    setState(() {
      _pluginChecking = true;
    });

    try {
      final report = await _pluginDetector.scan();

      if (!mounted) return;

      setState(() {
        _pluginReport = report;
      });
    } catch (error) {
      debugPrint('TruckLink plugin scan error: $error');

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

      bool isPrivate(String value) {
        if (value.startsWith('192.168.') || value.startsWith('10.')) {
          return true;
        }

        final parts = value.split('.');

        if (parts.length != 4 || parts[0] != '172') {
          return false;
        }

        final second = int.tryParse(parts[1]);

        return second != null && second >= 16 && second <= 31;
      }

      final privateAddresses = addresses.where(isPrivate).toList();

      final selected = privateAddresses.isNotEmpty
          ? privateAddresses.first
          : addresses.isNotEmpty
          ? addresses.first
          : null;

      if (!mounted) return;

      setState(() {
        _localIp = selected;
      });
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

            // ==================================
            // SEND CURRENT STATE TO NEW PHONE
            // ==================================

            final snapshot = _snapshot;

            if (snapshot != null) {
              socket.add(encodeSnapshot(snapshot));
            }

            // The job message is sent even
            // when there is no active job.
            socket.add(encodeJobUpdate(_activeJob));

            // Lifecycle events are NOT replayed
            // to newly connected clients.
            // Otherwise an old delivery could
            // look like a new one.

            // ==================================
            // LISTEN FOR CLIENT HELLO
            // ==================================

            socket.listen(
              (dynamic message) {
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
          debugPrint('TruckLink server error: $error');
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
    } on SocketException catch (error) {
      if (mounted) {
        setState(() {
          _serverStatus = 'Ошибка запуска: $error';
        });
      }
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
  // CLIENT IDENTIFICATION
  // ==========================================

  void _handleClientMessage(WebSocket socket, dynamic message) {
    if (message is! String || message.length > 1024) {
      return;
    }

    try {
      final decoded = jsonDecode(message);

      if (decoded is! Map<String, dynamic> ||
          decoded['type'] != 'client_hello') {
        return;
      }

      final rawName = decoded['name'];
      final rawPlatform = decoded['platform'];

      if (rawName is! String) return;

      final name = _cleanLabel(rawName, 64);

      if (name.isEmpty) return;

      final platform = rawPlatform is String
          ? _cleanLabel(rawPlatform, 20)
          : '';

      final previous = _clients[socket];

      if (previous == null) return;

      if (previous.deviceName == name && previous.platform == platform) {
        return;
      }

      _clients[socket] = previous.withIdentity(
        name: name,
        platformName: platform,
      );

      debugPrint(
        'TruckLink: identified '
        '$name (${previous.ipAddress})',
      );

      if (mounted) {
        setState(() {});
      }
    } on FormatException {
      // Ignore malformed client JSON.
    } catch (error) {
      debugPrint(
        'TruckLink client message error: '
        '$error',
      );
    }
  }

  String _cleanLabel(String value, int maxLength) {
    final result = value
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return result.length > maxLength ? result.substring(0, maxLength) : result;
  }

  // ==========================================
  // REMOVE CLIENT
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

    // Reject handshakes completing
    // after the stop was requested.
    _server = null;

    try {
      for (final socket in _clients.keys.toList()) {
        try {
          await socket.close().timeout(const Duration(seconds: 2));
        } catch (_) {
          // Ignore already closed clients.
        }
      }

      _clients.clear();

      await server.close(force: true);
    } catch (error) {
      debugPrint('TruckLink server stop: $error');
    } finally {
      // A fresh server session must not
      // inherit the previous send throttle.
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
  // OPEN PLUGIN DOWNLOAD
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
        const SnackBar(
          content: Text(
            'Не удалось открыть '
            'страницу плагина',
          ),
        ),
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
          return '${game.name}: '
              '${game.pluginInstalled ? "найден" : "отсутствует"}';
        })
        .join(' · ');
  }

  // ==========================================
  // REUSABLE CARD
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
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _gameName ?? 'ETS2 / ATS',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
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

    final missing = report?.hasMissingPlugin == true;

    final unknown =
        !_sharedMemoryAvailable && (report == null || !report.hasGames);

    final pluginReady =
        _telemetryActive ||
        _sharedMemoryAvailable ||
        report?.allInstalled == true;

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _statusIcon(
                Icons.extension_outlined,
                pluginReady ? _accent : _warning,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ПЛАГИН ТЕЛЕМЕТРИИ',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _pluginStatus,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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
          if ((missing || unknown) &&
              !_telemetryActive &&
              !_sharedMemoryAvailable) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                unawaited(_openPluginDownload());
              },
              icon: const Icon(Icons.open_in_new, size: 17),
              label: const Text('Скачать / установить плагин'),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // WEBSOCKET CARD
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
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
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
          const SizedBox(height: 12),
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
  // CONNECTED DEVICE ROW
  // ==========================================

  Widget _buildDeviceRow(_ConnectedDevice device) {
    final details = <String>[
      if (device.platform != null && device.platform!.isNotEmpty)
        device.platform!,
      device.ipAddress,
      'с ${device.timeText}',
    ];

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
                  details.join(' · '),
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
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Нет активных подключений',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            )
          else ...[
            const SizedBox(height: 7),
            for (final device in devices) _buildDeviceRow(device),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // COMPACT HUB UI
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

    final server = _server;
    _server = null;

    if (server != null) {
      unawaited(server.close(force: true));
    }

    super.dispose();
  }
}
