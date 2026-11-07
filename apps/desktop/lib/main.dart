import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_protocol/network_protocol.dart';
import 'package:network_protocol/job_protocol.dart';
import 'package:telemetry_core/telemetry_core.dart';
import 'package:telemetry_core/job_telemetry.dart';

import 'services/scs_job_bridge.dart';
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

  _ConnectedDevice withIdentity(String name, String platformName) {
    return _ConnectedDevice(
      ipAddress: ipAddress,
      connectedAt: connectedAt,
      deviceName: name,
      platform: platformName,
    );
  }

  String get displayName =>
      deviceName?.isNotEmpty == true ? deviceName! : 'Устройство $ipAddress';

  String get timeText {
    final h = connectedAt.hour.toString().padLeft(2, '0');
    final m = connectedAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
  static const Color _accent = Color(0xFF10EF78);
  static const Color _warning = Color(0xFFFFBA63);
  static const Color _muted = Color(0xFF9BAAB9);
  static const Color _surface = Color(0xFF15232F);

  static const int serverPort = 8787;

  // ==========================================
  // TELEMETRY
  // ==========================================

  final ScsTelemetryReader _reader = ScsTelemetryReader();

  Timer? _telemetryTimer;

  TruckSnapshot? _snapshot;
  TruckLinkJobTelemetry? _activeJob;

  int? _lastTimestamp;
  DateTime? _lastFrameAt;

  bool _sharedMemoryAvailable = false;
  bool _telemetryActive = false;

  String? _gameName;
  String _gameStatus = 'Ожидание ETS2 / ATS';

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
  // CLEAR TELEMETRY
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

    // Tell Android to remove the old job.
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
        _telemetryActive ||
        _snapshot != null ||
        _activeJob != null ||
        _gameStatus != 'Нет новых данных от игры';

    final hadJob = _activeJob != null;

    _snapshot = null;
    _activeJob = null;

    _telemetryActive = false;
    _sharedMemoryAvailable = true;

    _gameName = gameName;
    _gameStatus = 'Нет новых данных от игры';

    // Keep _lastTimestamp unchanged.
    // Otherwise the same old frame would
    // repeatedly appear as fresh.
    if (hadJob) {
      _broadcastJob(null);
    }

    if (changed && mounted) {
      setState(() {});
    }
  }

  // ==========================================
  // READ GAME TELEMETRY
  // ==========================================

  void _readTelemetry() {
    if (!mounted) return;

    try {
      final frame = _reader.read();

      if (frame == null) {
        _setTelemetryUnavailable('Ожидание запуска игры');
        return;
      }

      final gameName = switch (frame.gameId) {
        1 => 'Euro Truck Simulator 2',
        2 => 'American Truck Simulator',
        _ => null,
      };

      if (!frame.sdkActive) {
        _setTelemetryUnavailable(
          'SDK обнаружен, но не активен',
          gameName: gameName,
          mappingAvailable: true,
        );
        return;
      }

      if (frame.paused) {
        _setTelemetryUnavailable(
          'Игра на паузе',
          gameName: gameName,
          mappingAvailable: true,
        );
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

      if (_lastTimestamp != frame.timestamp) {
        _lastTimestamp = frame.timestamp;
        _lastFrameAt = now;

        // Existing truck data.
        _snapshot = frame.toTruckSnapshot();

        // NEW: actual job data.
        _activeJob = jobTelemetryFromScs(frame);

        final updateUi =
            !_telemetryActive ||
            !_sharedMemoryAvailable ||
            _gameName != gameName ||
            _gameStatus != 'Телеметрия активна';

        _telemetryActive = true;
        _sharedMemoryAvailable = true;
        _gameName = gameName;
        _gameStatus = 'Телеметрия активна';

        // Existing snapshot protocol.
        _broadcastSnapshot();

        // New optional job message.
        _broadcastJob(_activeJob);

        if (updateUi && mounted) {
          setState(() {});
        }

        return;
      }

      final lastFrame = _lastFrameAt;

      if (lastFrame != null &&
          now.difference(lastFrame) > const Duration(seconds: 4)) {
        _markTelemetryStale(gameName);
      }
    } catch (error) {
      _setTelemetryUnavailable('Ошибка чтения: $error');
    }
  }

  // ==========================================
  // SCAN PLUGIN
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
  // LOCAL IP
  // ==========================================

  Future<void> _detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      final addresses = [
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
    if (_localIp == null) {
      return 'IP компьютера · порт $serverPort';
    }

    return 'ws://$_localIp:$serverPort';
  }

  // ==========================================
  // START SERVER
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
      _serverStatus = 'Сервер запущен';

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

            // Snapshot on initial connection.
            final snapshot = _snapshot;

            if (snapshot != null) {
              socket.add(encodeSnapshot(snapshot));
            }

            // NEW: initial job state, even if
            // the game currently has no job.
            socket.add(encodeJobUpdate(_activeJob));

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
            debugPrint('TruckLink WebSocket handshake: $error');
          }
        },
        onError: (Object error) {
          debugPrint('TruckLink WebSocket server: $error');
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
      _serverStatus = 'Ошибка запуска: $error';
    } catch (error) {
      _serverStatus = 'Ошибка запуска: $error';
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

      final existing = _clients[socket];

      if (existing == null) return;

      _clients[socket] = existing.withIdentity(name, platform);

      if (mounted) {
        setState(() {});
      }
    } on FormatException {
      // Ignore invalid JSON.
    } catch (error) {
      debugPrint('TruckLink client hello: $error');
    }
  }

  String _cleanLabel(String value, int limit) {
    final cleaned = value
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.length <= limit) {
      return cleaned;
    }

    return cleaned.substring(0, limit);
  }

  // ==========================================
  // BROADCAST TRUCK SNAPSHOT
  // ==========================================

  void _broadcastSnapshot() {
    final snapshot = _snapshot;

    if (snapshot == null || _server == null) {
      return;
    }

    final message = encodeSnapshot(snapshot);

    for (final socket in _clients.keys.toList()) {
      try {
        socket.add(message);
      } catch (_) {
        _removeClient(socket);
      }
    }
  }

  // ==========================================
  // NEW: BROADCAST JOB UPDATE
  // ==========================================

  void _broadcastJob(TruckLinkJobTelemetry? job) {
    if (_server == null) return;

    final message = encodeJobUpdate(job);

    for (final socket in _clients.keys.toList()) {
      try {
        socket.add(message);
      } catch (_) {
        _removeClient(socket);
      }
    }
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

    _server = null;

    try {
      for (final socket in _clients.keys.toList()) {
        try {
          await socket.close().timeout(const Duration(seconds: 2));
        } catch (_) {
          // Ignore already closed sockets.
        }
      }

      _clients.clear();

      await server.close(force: true);
    } catch (error) {
      debugPrint('TruckLink server stop: $error');
    } finally {
      if (mounted) {
        setState(() {
          _stopping = false;
          _serverStatus = 'Сервер остановлен';
        });
      }
    }
  }

  // ==========================================
  // PLUGIN DOWNLOAD
  // ==========================================

  Future<void> _openPluginDownload() async {
    try {
      await Process.start('explorer.exe', [
        ScsPluginDetector.downloadUrl,
      ], mode: ProcessStartMode.detached);
    } catch (error) {
      debugPrint('Plugin page: $error');

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
    if (_telemetryActive) return 'Работает';

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
      return 'Установлен не для всех игр';
    }

    return 'Плагин не найден';
  }

  String get _pluginDetails {
    final report = _pluginReport;

    if (report == null) {
      return 'Проверка каталогов ETS2 / ATS';
    }

    if (!report.hasGames) {
      return 'Проверь расположение игр в Steam';
    }

    return report.games
        .map((game) {
          return '${game.name}: '
              '${game.pluginInstalled ? "найден" : "отсутствует"}';
        })
        .join(' · ');
  }

  // ==========================================
  // UI COMPONENTS
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
                const SizedBox(height: 3),
                Text(
                  _gameStatus,
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

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _statusIcon(
                Icons.extension_outlined,
                _telemetryActive ||
                        _sharedMemoryAvailable ||
                        report?.allInstalled == true
                    ? _accent
                    : _warning,
              ),
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
                        width: 18,
                        height: 18,
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
              icon: const Icon(Icons.open_in_new_rounded),
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
                    : () {
                        unawaited(
                          Clipboard.setData(
                            ClipboardData(text: _serverAddress),
                          ),
                        );
                      },
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: busy
                ? null
                : running
                ? () => unawaited(_stopServer())
                : () => unawaited(_startServer()),
            icon: Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded),
            label: Text(
              busy
                  ? 'Подождите...'
                  : running
                  ? 'Остановить сервер'
                  : 'Запустить сервер',
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DEVICE CARD
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
          else
            for (final device in devices)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    const Icon(
                      Icons.smartphone_outlined,
                      color: _accent,
                      size: 21,
                    ),
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
                            [
                              if (device.platform != null &&
                                  device.platform!.isNotEmpty)
                                device.platform!,
                              device.ipAddress,
                              'с ${device.timeText}',
                            ].join(' · '),
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.circle, color: _accent, size: 8),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // ==========================================
  // BUILD
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
