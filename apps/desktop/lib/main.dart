import 'dart:async';
import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_protocol/network_protocol.dart';
import 'package:telemetry_core/telemetry_core.dart';

import 'services/scs_telemetry_reader.dart';

void main() {
  runApp(const ProviderScope(child: DesktopApp()));
}

class DesktopApp extends StatelessWidget {
  const DesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TruckLink Desktop',
      debugShowCheckedModeBanner: false,
      theme: TruckLinkTheme.dark,
      home: const DesktopHome(),
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
  // SCS TELEMETRY
  // ==========================================

  final ScsTelemetryReader _telemetryReader = ScsTelemetryReader();

  Timer? _telemetryTimer;

  ScsTelemetryFrame? _frame;
  TruckSnapshot? _snapshot;

  int? _lastTimestamp;
  DateTime? _lastUpdateTime;

  String _telemetryStatus = 'Ожидание подключения к ETS2...';

  // ==========================================
  // WEBSOCKET SERVER
  // ==========================================

  static const int serverPort = 8787;

  HttpServer? _server;

  final Set<WebSocket> _clients = {};

  bool _serverStarting = false;

  String _serverStatus = 'Сервер остановлен';

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _readTelemetry();
      }
    });
  }

  // ==========================================
  // TELEMETRY READER
  // ==========================================

  void _readTelemetry() {
    if (!mounted) return;

    try {
      final frame = _telemetryReader.read();

      if (frame == null) {
        _clearTelemetry('Ожидание ETS2 / SCS Telemetry Plugin...');
        return;
      }

      if (!frame.sdkActive) {
        _clearTelemetry('SDK обнаружен, но не активен');
        return;
      }

      if (frame.paused) {
        _clearTelemetry('Телеметрия на паузе');
        return;
      }

      if (!frame.isLive) {
        _clearTelemetry('Ожидание игровых данных...');
        return;
      }

      final now = DateTime.now();

      final hasNewData = _lastTimestamp != frame.timestamp;

      if (hasNewData) {
        _lastTimestamp = frame.timestamp;
        _lastUpdateTime = now;

        _frame = frame;
        _snapshot = frame.toTruckSnapshot();

        _telemetryStatus = '${frame.gameName} — телеметрия активна';

        // Send only valid, fresh game snapshots.
        _broadcastSnapshot();
      } else {
        // Detect telemetry that stopped updating
        // while the shared memory still exists.
        final lastUpdate = _lastUpdateTime;

        if (lastUpdate != null &&
            now.difference(lastUpdate) > const Duration(seconds: 4)) {
          _frame = null;
          _snapshot = null;

          _telemetryStatus = 'Нет новых данных от игры';
        }
      }

      setState(() {});
    } catch (error) {
      _clearTelemetry('Ошибка телеметрии: $error');
    }
  }

  void _clearTelemetry(String status) {
    _frame = null;
    _snapshot = null;

    _lastTimestamp = null;
    _lastUpdateTime = null;

    _telemetryStatus = status;

    if (mounted) {
      setState(() {});
    }
  }

  // ==========================================
  // WEBSOCKET SERVER
  // ==========================================

  Future<void> _startServer() async {
    if (_server != null || _serverStarting) {
      return;
    }

    setState(() {
      _serverStarting = true;
      _serverStatus = 'Запуск сервера...';
    });

    try {
      // LAN development mode only.
      // Authentication and TLS are not implemented yet.
      final server = await HttpServer.bind(InternetAddress.anyIPv4, serverPort);

      _server = server;

      _serverStatus = 'Сервер запущен на порту $serverPort';

      server.listen((request) async {
        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          request.response.statusCode = HttpStatus.badRequest;

          await request.response.close();
          return;
        }

        try {
          final socket = await WebSocketTransformer.upgrade(request);

          _clients.add(socket);

          // Send current data immediately
          // when a new client connects.
          final snapshot = _snapshot;

          if (snapshot != null) {
            socket.add(encodeSnapshot(snapshot));
          }

          socket.listen(
            (_) {
              // Incoming commands will be added
              // in a future protocol version.
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
        } catch (_) {
          // A failed client handshake must not
          // stop the telemetry server.
        }
      });
    } on SocketException catch (error) {
      _serverStatus = 'Ошибка запуска сервера: $error';
    } catch (error) {
      _serverStatus = 'Не удалось запустить сервер: $error';
    } finally {
      _serverStarting = false;

      if (mounted) {
        setState(() {});
      }
    }
  }

  void _broadcastSnapshot() {
    final snapshot = _snapshot;

    if (snapshot == null || _server == null) {
      return;
    }

    final message = encodeSnapshot(snapshot);

    for (final client in _clients.toList()) {
      try {
        client.add(message);
      } catch (_) {
        _removeClient(client);
      }
    }
  }

  void _removeClient(WebSocket socket) {
    _clients.remove(socket);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _stopServer() async {
    final server = _server;

    _server = null;

    for (final client in _clients.toList()) {
      try {
        await client.close();
      } catch (_) {
        // Ignore sockets already disconnected.
      }
    }

    _clients.clear();

    await server?.close(force: true);

    _serverStatus = 'Сервер остановлен';

    if (mounted) {
      setState(() {});
    }
  }

  // ==========================================
  // LIFECYCLE
  // ==========================================

  @override
  void dispose() {
    _telemetryTimer?.cancel();

    for (final client in _clients) {
      client.close();
    }

    _clients.clear();

    _server?.close(force: true);

    super.dispose();
  }

  // ==========================================
  // HELPERS
  // ==========================================

  String _formatGear(int gear) {
    if (gear == 0) return 'N';
    if (gear < 0) return 'R${gear.abs()}';
    return gear.toString();
  }

  String get _speedText {
    final snapshot = _snapshot;

    if (snapshot == null) return '—';

    return '${snapshot.speedKmh.abs().toStringAsFixed(1)} км/ч';
  }

  String get _rpmText {
    final snapshot = _snapshot;

    if (snapshot == null) return '—';

    return '${snapshot.rpm.toStringAsFixed(0)} RPM';
  }

  String get _gearText {
    final snapshot = _snapshot;

    if (snapshot == null) return '—';

    return _formatGear(snapshot.gear);
  }

  String get _fuelText {
    final snapshot = _snapshot;

    if (snapshot == null) return '—';

    return '${snapshot.fuelLiters.toStringAsFixed(0)} л';
  }

  String get _engineText {
    final snapshot = _snapshot;

    if (snapshot == null) return '—';

    return snapshot.engineOn ? 'Включён' : 'Выключен';
  }

  String get _gameText {
    final frame = _frame;

    if (frame == null) return 'Нет данных';

    return switch (frame.gameId) {
      1 => 'ETS2',
      2 => 'ATS',
      _ => 'UNKNOWN',
    };
  }

  // ==========================================
  // USER INTERFACE
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final frame = _frame;

    final telemetryAvailable = snapshot != null;
    final serverRunning = _server != null;

    return Scaffold(
      appBar: AppBar(title: const Text('TruckLink · Windows Hub')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Центр телеметрии',
                style: Theme.of(context).textTheme.headlineLarge,
              ),

              const SizedBox(height: 8),

              const Text('TruckLink v0.2 · SCS Telemetry SDK'),

              const SizedBox(height: 20),

              // ==================================
              // GAME CONNECTION
              // ==================================
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            telemetryAvailable
                                ? Icons.check_circle
                                : Icons.sensors_off,
                            color: telemetryAvailable
                                ? Colors.tealAccent
                                : Colors.orangeAccent,
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Text(
                              'Подключение к игре',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Text(_telemetryStatus),

                      if (frame != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'SCS Telemetry Revision: '
                          '${frame.pluginRevision}',
                        ),
                        const SizedBox(height: 8),
                        Text('Двигатель: $_engineText'),
                        const SizedBox(height: 8),
                        Text(
                          'Топливо: '
                          '${frame.fuelLiters.toStringAsFixed(1)} '
                          '/ '
                          '${frame.fuelCapacityLiters.toStringAsFixed(1)} л '
                          '(${frame.fuelPercent.toStringAsFixed(1)}%)',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Пробег: '
                          '${frame.odometerKm.toStringAsFixed(1)} км',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Температура ОЖ: '
                          '${frame.waterTemperatureC.toStringAsFixed(1)} °C',
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==================================
              // SERVER CONTROL
              // ==================================
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            serverRunning ? Icons.wifi : Icons.wifi_off,
                            color: serverRunning
                                ? Colors.tealAccent
                                : Colors.orangeAccent,
                          ),

                          const SizedBox(width: 10),

                          Text(
                            'Мобильное подключение',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Text(_serverStatus),

                      const SizedBox(height: 8),

                      Text(
                        'Подключено устройств: '
                        '${_clients.length}',
                      ),

                      const SizedBox(height: 8),

                      const SelectableText('Адрес: ws://IP_ВАШЕГО_ПК:8787'),

                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: serverRunning || _serverStarting
                                ? null
                                : _startServer,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Запустить сервер'),
                          ),

                          OutlinedButton.icon(
                            onPressed: serverRunning ? _stopServer : null,
                            icon: const Icon(Icons.stop),
                            label: const Text('Остановить'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==================================
              // TELEMETRY DASHBOARD
              // ==================================
              Text(
                'Показатели грузовика',
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: 12),

              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 620 ? 3 : 2;

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: columns,
                    childAspectRatio: columns == 3 ? 1.55 : 1.15,
                    children: [
                      MetricTile(
                        title: 'Скорость',
                        value: _speedText,
                        icon: Icons.speed,
                      ),

                      MetricTile(
                        title: 'Обороты',
                        value: _rpmText,
                        icon: Icons.autorenew,
                      ),

                      MetricTile(
                        title: 'Передача',
                        value: _gearText,
                        icon: Icons.settings,
                      ),

                      MetricTile(
                        title: 'Топливо',
                        value: _fuelText,
                        icon: Icons.local_gas_station,
                      ),

                      MetricTile(
                        title: 'Игра',
                        value: _gameText,
                        icon: Icons.sports_esports,
                      ),

                      const MetricTile(
                        title: 'Протокол',
                        value: 'v1',
                        icon: Icons.hub,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              const Text(
                'Телеметрия обновляется автоматически. '
                'На мобильные устройства передаются только '
                'доступные игровые данные.',
              ),

              const SizedBox(height: 8),

              const Text(
                'Внимание: локальный WebSocket пока работает '
                'без шифрования и авторизации. '
                'Используйте только доверенную сеть.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
