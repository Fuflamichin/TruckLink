import 'dart:async';
import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_protocol/network_protocol.dart';
import 'package:telemetry_core/telemetry_core.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const ProviderScope(child: MobileApp()));
}

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TruckLink',
      debugShowCheckedModeBanner: false,
      theme: TruckLinkTheme.dark,
      home: const MobileHome(),
    );
  }
}

enum ConnectionPhase { disconnected, connecting, waiting, live, stale, error }

class MobileHome extends StatefulWidget {
  const MobileHome({super.key});

  @override
  State<MobileHome> createState() => _MobileHomeState();
}

class _MobileHomeState extends State<MobileHome> {
  static const int serverPort = 8787;

  static const Duration connectionTimeout = Duration(seconds: 5);

  static const Duration telemetryTimeout = Duration(seconds: 4);

  final TextEditingController _hostController = TextEditingController();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  Timer? _watchdog;

  TruckSnapshot? _snapshot;

  DateTime? _lastFrameReceivedAt;

  ConnectionPhase _phase = ConnectionPhase.disconnected;

  String _statusMessage = 'Нет подключения к ПК';

  // ==========================================
  // INITIALIZATION
  // ==========================================

  @override
  void initState() {
    super.initState();

    _watchdog = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkTelemetryFreshness(),
    );
  }

  // ==========================================
  // CONNECTION
  // ==========================================

  Future<void> _connect() async {
    final host = _hostController.text.trim();

    final address = InternetAddress.tryParse(host);

    if (address == null || address.type != InternetAddressType.IPv4) {
      if (!mounted) return;

      setState(() {
        _phase = ConnectionPhase.error;
        _statusMessage = 'Введите правильный IPv4-адрес компьютера';
      });

      return;
    }

    await _closeConnection();

    if (!mounted) return;

    setState(() {
      _phase = ConnectionPhase.connecting;
      _statusMessage = 'Подключение к Windows Hub...';

      _snapshot = null;
      _lastFrameReceivedAt = null;
    });

    WebSocketChannel? channel;

    try {
      channel = WebSocketChannel.connect(
        Uri(scheme: 'ws', host: host, port: serverPort),
      );

      _channel = channel;

      await channel.ready.timeout(connectionTimeout);

      if (!mounted || !identical(_channel, channel)) {
        await channel.sink.close();
        return;
      }

      _subscription = channel.stream.listen(
        (message) {
          _handleMessage(channel!, message);
        },
        onDone: () {
          _handleConnectionLost(channel!, 'Соединение с компьютером закрыто');
        },
        onError: (Object error) {
          _handleConnectionLost(channel!, 'Ошибка соединения: $error');
        },
        cancelOnError: true,
      );

      setState(() {
        _phase = ConnectionPhase.waiting;
        _statusMessage = 'Подключено к ПК. Ожидание телеметрии ETS2...';
      });
    } catch (error) {
      await _closeConnection();

      if (!mounted) return;

      setState(() {
        _phase = ConnectionPhase.error;
        _statusMessage = 'Не удалось подключиться: $error';

        _snapshot = null;
      });
    }
  }

  // ==========================================
  // INCOMING TELEMETRY
  // ==========================================

  void _handleMessage(WebSocketChannel channel, dynamic message) {
    if (!mounted || !identical(_channel, channel)) {
      return;
    }

    try {
      if (message is! String) {
        throw const FormatException('Expected a JSON text message');
      }

      final snapshot = decodeSnapshot(message);

      setState(() {
        _snapshot = snapshot;
        _lastFrameReceivedAt = DateTime.now();

        _phase = ConnectionPhase.live;
        _statusMessage = 'Телеметрия ETS2 активна';
      });
    } catch (error) {
      setState(() {
        _phase = ConnectionPhase.error;
        _snapshot = null;

        _statusMessage = 'Ошибка формата телеметрии: $error';
      });
    }
  }

  // ==========================================
  // TELEMETRY WATCHDOG
  // ==========================================

  void _checkTelemetryFreshness() {
    if (!mounted) return;

    if (_phase != ConnectionPhase.live) {
      return;
    }

    final lastUpdate = _lastFrameReceivedAt;

    if (lastUpdate == null) {
      return;
    }

    final elapsed = DateTime.now().difference(lastUpdate);

    if (elapsed > telemetryTimeout) {
      setState(() {
        _phase = ConnectionPhase.stale;

        // Never show old readings as live data.
        _snapshot = null;

        _statusMessage = 'Нет новых данных. Проверь ETS2 и соединение.';
      });
    }
  }

  // ==========================================
  // CONNECTION LOST
  // ==========================================

  void _handleConnectionLost(WebSocketChannel channel, String message) {
    if (!mounted || !identical(_channel, channel)) {
      return;
    }

    _channel = null;
    _subscription = null;
    _lastFrameReceivedAt = null;

    setState(() {
      _phase = ConnectionPhase.error;
      _statusMessage = message;
      _snapshot = null;
    });
  }

  // ==========================================
  // DISCONNECT
  // ==========================================

  Future<void> _closeConnection() async {
    final subscription = _subscription;
    final channel = _channel;

    _subscription = null;
    _channel = null;
    _lastFrameReceivedAt = null;

    try {
      await subscription?.cancel();
    } catch (_) {
      // Ignore already closed subscriptions.
    }

    try {
      await channel?.sink.close();
    } catch (_) {
      // Ignore already closed sockets.
    }
  }

  Future<void> _disconnect() async {
    await _closeConnection();

    if (!mounted) return;

    setState(() {
      _snapshot = null;
      _phase = ConnectionPhase.disconnected;
      _statusMessage = 'Отключено от Windows Hub';
    });
  }

  // ==========================================
  // UI HELPERS
  // ==========================================

  bool get _isConnected {
    return _phase == ConnectionPhase.waiting ||
        _phase == ConnectionPhase.live ||
        _phase == ConnectionPhase.stale;
  }

  Color get _statusColor {
    switch (_phase) {
      case ConnectionPhase.live:
        return Colors.tealAccent;

      case ConnectionPhase.connecting:
      case ConnectionPhase.waiting:
        return Colors.lightBlueAccent;

      case ConnectionPhase.disconnected:
      case ConnectionPhase.stale:
      case ConnectionPhase.error:
        return Colors.orangeAccent;
    }
  }

  IconData get _statusIcon {
    switch (_phase) {
      case ConnectionPhase.live:
        return Icons.check_circle;

      case ConnectionPhase.connecting:
        return Icons.sync;

      case ConnectionPhase.waiting:
        return Icons.hourglass_top;

      case ConnectionPhase.stale:
        return Icons.warning_amber;

      case ConnectionPhase.error:
        return Icons.error_outline;

      case ConnectionPhase.disconnected:
        return Icons.wifi_off;
    }
  }

  String _formatGear(int? gear) {
    if (gear == null) return '—';
    if (gear == 0) return 'N';
    if (gear < 0) return 'R${gear.abs()}';

    return gear.toString();
  }

  String _formatFuel(TruckSnapshot? snapshot) {
    if (snapshot == null) return '—';

    return '${(snapshot.fuelFraction * 100).toStringAsFixed(0)}%';
  }

  // ==========================================
  // DISPOSE
  // ==========================================

  @override
  void dispose() {
    _watchdog?.cancel();

    _subscription?.cancel();
    _channel?.sink.close();

    _hostController.dispose();

    super.dispose();
  }

  // ==========================================
  // INTERFACE
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return Scaffold(
      appBar: AppBar(title: const Text('TruckLink')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Мой грузовик',
            style: Theme.of(context).textTheme.headlineLarge,
          ),

          const SizedBox(height: 16),

          // ==================================
          // CONNECTION STATUS
          // ==================================
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(_statusIcon, color: _statusColor),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(color: _statusColor),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ==================================
          // CONNECTION FORM
          // ==================================
          TextField(
            controller: _hostController,
            enabled: _phase != ConnectionPhase.connecting,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'IP компьютера',
              hintText: '192.168.1.20',
              prefixIcon: Icon(Icons.computer),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: _phase == ConnectionPhase.connecting ? null : _connect,
            icon: const Icon(Icons.wifi),
            label: Text(
              _isConnected ? 'Переподключиться' : 'Подключиться к Windows',
            ),
          ),

          if (_channel != null) ...[
            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: _disconnect,
              icon: const Icon(Icons.link_off),
              label: const Text('Отключиться'),
            ),
          ],

          const SizedBox(height: 12),

          const Text(
            'Локальное подключение через WebSocket. '
            'Используйте только доверенную Wi-Fi сеть.',
          ),

          const SizedBox(height: 24),

          // ==================================
          // TRUCK DASHBOARD
          // ==================================
          Text(
            'Приборная панель',
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: 12),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,

            // Taller cards prevent bottom overflow
            // on smaller smartphone displays.
            childAspectRatio: 0.9,

            children: [
              MetricTile(
                title: 'Скорость (км/ч)',
                value: snapshot == null
                    ? '—'
                    : snapshot.speedKmh.abs().toStringAsFixed(1),
                icon: Icons.speed,
              ),

              MetricTile(
                title: 'Обороты (RPM)',
                value: snapshot == null ? '—' : snapshot.rpm.toStringAsFixed(0),
                icon: Icons.autorenew,
              ),

              MetricTile(
                title: 'Передача',
                value: _formatGear(snapshot?.gear),
                icon: Icons.settings,
              ),

              MetricTile(
                title: 'Топливо',
                value: _formatFuel(snapshot),
                icon: Icons.local_gas_station,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ==================================
          // TRUCK INFORMATION
          // ==================================
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Состояние грузовика',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),

                  const SizedBox(height: 16),

                  _infoRow(
                    'Двигатель',
                    snapshot == null
                        ? 'Нет данных'
                        : snapshot.engineOn
                        ? 'Включён'
                        : 'Выключен',
                  ),

                  const Divider(),

                  _infoRow(
                    'Топливо',
                    snapshot == null
                        ? '—'
                        : '${snapshot.fuelLiters.toStringAsFixed(1)} '
                              '/ ${snapshot.fuelCapacityLiters.toStringAsFixed(1)} л',
                  ),

                  const Divider(),

                  _infoRow(
                    'Обновлено',
                    snapshot == null
                        ? '—'
                        : _formatTime(snapshot.timestamp.toLocal()),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ==================================
          // FUTURE MODULES
          // ==================================
          const Card(
            child: ListTile(
              leading: Icon(Icons.route),
              title: Text('Заказы / GPS / Финансы'),
              subtitle: Text('Разделы появятся в следующих версиях.'),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 8),
        Flexible(child: Text(value, textAlign: TextAlign.right)),
      ],
    );
  }

  String _formatTime(DateTime time) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${twoDigits(time.hour)}:'
        '${twoDigits(time.minute)}:'
        '${twoDigits(time.second)}';
  }
}
