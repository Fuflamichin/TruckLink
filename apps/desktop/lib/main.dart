import 'dart:async';
import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_protocol/network_protocol.dart';
import 'package:telemetry_core/telemetry_core.dart';

import 'services/scs_plugin_detector.dart';
import 'services/scs_telemetry_reader.dart';

// ============================================
// MAIN
// ============================================

void main() {
  runApp(const ProviderScope(child: DesktopApp()));
}

// ============================================
// WINDOWS APPLICATION
// ============================================

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
  const _ConnectedDevice({required this.ipAddress, required this.connectedAt});

  final String ipAddress;
  final DateTime connectedAt;

  String get timeText {
    final h = connectedAt.hour.toString().padLeft(2, '0');
    final m = connectedAt.minute.toString().padLeft(2, '0');

    return '$h:$m';
  }
}

// ============================================
// HUB HOME
// ============================================

class DesktopHome extends StatefulWidget {
  const DesktopHome({super.key});

  @override
  State<DesktopHome> createState() => _DesktopHomeState();
}

class _DesktopHomeState extends State<DesktopHome> {
  // ==========================================
  // COLORS
  // ==========================================

  static const Color _accent = Color(0xFF10EF78);
  static const Color _muted = Color(0xFF9BAAB9);
  static const Color _warning = Color(0xFFFFBA63);
  static const Color _surface = Color(0xFF15232F);

  // ==========================================
  // SCS TELEMETRY
  // ==========================================

  final ScsTelemetryReader _reader = ScsTelemetryReader();

  Timer? _telemetryTimer;

  TruckSnapshot? _snapshot;

  int? _lastTimestamp;
  DateTime? _lastFrameAt;

  bool _sharedMemoryAvailable = false;
  bool _telemetryActive = false;

  String? _gameName;
  String _gameStatus = 'Ожидание ETS2 / ATS';

  // ==========================================
  // PLUGIN CHECK
  // ==========================================

  final ScsPluginDetector _pluginDetector = const ScsPluginDetector();

  ScsPluginScanResult? _pluginReport;

  Timer? _pluginTimer;

  bool _pluginChecking = false;

  // ==========================================
  // NETWORK
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
  // TELEMETRY STATE
  // ==========================================

  void _setTelemetryUnavailable(
    String status, {
    String? gameName,
    bool hasMapping = false,
  }) {
    final changed =
        _telemetryActive ||
        _gameStatus != status ||
        _gameName != gameName ||
        _sharedMemoryAvailable != hasMapping;

    _snapshot = null;
    _lastTimestamp = null;
    _lastFrameAt = null;

    _telemetryActive = false;
    _sharedMemoryAvailable = hasMapping;

    _gameName = gameName;
    _gameStatus = status;

    if (changed && mounted) {
      setState(() {});
    }
  }

  // ==========================================
  // READ REAL GAME TELEMETRY
  // ==========================================

  void _readTelemetry() {
    if (!mounted) return;

    try {
      final frame = _reader.read();

      // Mapping not found: game may be closed,
      // or its telemetry plugin is not loaded.
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
          hasMapping: true,
        );
        return;
      }

      if (frame.paused) {
        _setTelemetryUnavailable(
          'Игра на паузе',
          gameName: gameName,
          hasMapping: true,
        );
        return;
      }

      if (!frame.isLive) {
        _setTelemetryUnavailable(
          'Ожидание игровых данных',
          gameName: gameName,
          hasMapping: true,
        );
        return;
      }

      final now = DateTime.now();

      // The plugin timestamp is NOT a Unix timestamp.
      // We only compare it with the previous value.
      final hasNewFrame = frame.timestamp != _lastTimestamp;

      if (hasNewFrame) {
        _lastTimestamp = frame.timestamp;
        _lastFrameAt = now;

        _snapshot = frame.toTruckSnapshot();

        final needsUiUpdate =
            !_telemetryActive ||
            _gameName != gameName ||
            !_sharedMemoryAvailable ||
            _gameStatus != 'Телеметрия активна';

        _telemetryActive = true;
        _sharedMemoryAvailable = true;

        _gameName = gameName;
        _gameStatus = 'Телеметрия активна';

        // Important: preserve the original
        // TruckLink mobile protocol.
        _broadcastSnapshot();

        if (needsUiUpdate && mounted) {
          setState(() {});
        }

        return;
      }

      // The mapping still exists, but the
      // telemetry timestamp stopped changing.
      final lastUpdate = _lastFrameAt;

      if (lastUpdate != null &&
          now.difference(lastUpdate) > const Duration(seconds: 4)) {
        final wasActive = _telemetryActive;

        _snapshot = null;
        _telemetryActive = false;
        _sharedMemoryAvailable = true;

        _gameName = gameName;
        _gameStatus = 'Нет новых данных от игры';

        if (wasActive && mounted) {
          setState(() {});
        }
      }
    } catch (error) {
      _setTelemetryUnavailable('Ошибка чтения: $error');
    }
  }

  // ==========================================
  // CHECK INSTALLED PLUGIN
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
      debugPrint('Plugin scan failed: $error');

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
  // DETECT COMPUTER IP
  // ==========================================

  Future<void> _detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      final addresses = <String>[];

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          addresses.add(address.address);
        }
      }

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
      debugPrint('IP detection failed: $error');
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
      // Local-network development server.
      // There is no authentication or TLS yet.
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

          // Record remote IP before upgrade.
          final remoteIp =
              request.connectionInfo?.remoteAddress.address ?? 'Неизвестный IP';

          try {
            final socket = await WebSocketTransformer.upgrade(request);

            // Server could have been stopped
            // while the handshake was pending.
            if (!mounted || !identical(_server, server)) {
              await socket.close();
              return;
            }

            _clients[socket] = _ConnectedDevice(
              ipAddress: remoteIp,
              connectedAt: DateTime.now(),
            );

            // Send current snapshot immediately.
            final snapshot = _snapshot;

            if (snapshot != null) {
              socket.add(encodeSnapshot(snapshot));
            }

            socket.listen(
              (_) {
                // Client identification messages
                // will be added in a later stage.
              },
              onDone: () => _removeClient(socket),
              onError: (Object error) {
                _removeClient(socket);
              },
              cancelOnError: true,
            );

            if (mounted) {
              setState(() {});
            }
          } catch (error) {
            debugPrint('WebSocket handshake error: $error');
          }
        },
        onError: (Object error) {
          debugPrint('WebSocket server error: $error');
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
  // BROADCAST TELEMETRY
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
  // REMOVE DISCONNECTED CLIENT
  // ==========================================

  void _removeClient(WebSocket socket) {
    final removed = _clients.remove(socket) != null;

    if (removed && mounted) {
      setState(() {});
    }
  }

  // ==========================================
  // STOP WEBSOCKET SERVER
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

    // Prevent new handshakes from being
    // registered while stopping.
    _server = null;

    try {
      for (final socket in _clients.keys.toList()) {
        try {
          await socket.close().timeout(const Duration(seconds: 2));
        } catch (_) {
          // Ignore already closed connections.
        }
      }

      _clients.clear();

      await server.close(force: true);
    } catch (error) {
      debugPrint('Server stop error: $error');
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
  // OPEN PLUGIN DOWNLOAD PAGE
  // ==========================================

  Future<void> _openPluginDownload() async {
    try {
      await Process.start('explorer.exe', [
        ScsPluginDetector.downloadUrl,
      ], mode: ProcessStartMode.detached);
    } catch (error) {
      debugPrint('Cannot open plugin page: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть страницу плагина')),
      );
    }
  }

  // ==========================================
  // PLUGIN STATUS LABELS
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
  // UI CARD
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

  // ==========================================
  // STATUS ICON
  // ==========================================

  Widget _statusIcon(IconData icon, Color color) {
    return Container(
      height: 38,
      width: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  // ==========================================
  // GAME STATUS CARD
  // ==========================================

  Widget _buildGameCard() {
    final name = _gameName ?? 'ETS2 / ATS';

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
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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
  // PLUGIN STATUS CARD
  // ==========================================

  Widget _buildPluginCard() {
    final missing = _pluginReport?.hasMissingPlugin == true;

    final unknown =
        !_sharedMemoryAvailable &&
        (_pluginReport == null || _pluginReport?.hasGames == false);

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
                        _pluginReport?.allInstalled == true
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
              icon: const Icon(Icons.open_in_new, size: 17),
              label: Text(
                missing ? 'Скачать плагин' : 'Инструкция по установке',
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // WEBSOCKET SERVER CARD
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
                  style: const TextStyle(fontSize: 12, color: _muted),
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
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${devices.length}',
                style: const TextStyle(
                  color: _accent,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (devices.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Нет активных подключений',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ] else ...[
            const SizedBox(height: 10),
            for (final device in devices)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    const Icon(
                      Icons.smartphone_outlined,
                      color: _accent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        device.ipAddress,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      'с ${device.timeText}',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.circle, color: _accent, size: 8),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // COMPACT INTERFACE
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
              // ==============================
              // HEADER
              // ==============================
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
                'Подключай устройства только '
                'в доверенной локальной сети.',
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
