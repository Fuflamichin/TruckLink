import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_protocol/network_protocol.dart';
import 'package:telemetry_core/telemetry_core.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() => runApp(const ProviderScope(child: MobileApp()));

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TruckLink',
    theme: TruckLinkTheme.dark,
    debugShowCheckedModeBanner: false,
    home: const MobileHome(),
  );
}

class MobileHome extends StatefulWidget {
  const MobileHome({super.key});
  @override
  State<MobileHome> createState() => _MobileHomeState();
}

class _MobileHomeState extends State<MobileHome> {
  final _host = TextEditingController();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  TruckSnapshot _snapshot = TruckSnapshot.demo();
  String _status = 'Демо: нет подключения';
  bool _connected = false;

  Future<void> _connect() async {
    await _disconnect();
    final host = _host.text.trim();
    if (host.isEmpty || host.contains('/') || host.contains(':')) {
      setState(() => _status = 'Введите IPv4-адрес ПК, например 192.168.1.20');
      return;
    }
    setState(() => _status = 'Подключаемся...');
    final channel = WebSocketChannel.connect(Uri.parse('ws://$host:8787'));
    _channel = channel;
    try {
      await channel.ready.timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _connected = true;
        _status = 'Подключено (демо)';
      });
      _subscription = channel.stream.listen(
        (message) {
          try {
            final next = decodeSnapshot(message as String);
            if (mounted) setState(() => _snapshot = next);
          } catch (_) {
            if (mounted) setState(() => _status = 'Ошибка формата данных');
          }
        },
        onDone: () {
          if (mounted)
            setState(() {
              _connected = false;
              _status = 'Соединение закрыто';
            });
        },
        onError: (Object error) {
          if (mounted)
            setState(() {
              _connected = false;
              _status = 'Ошибка соединения: $error';
            });
        },
      );
    } catch (e) {
      await channel.sink.close();
      if (mounted)
        setState(() {
          _connected = false;
          _status = 'Не удалось подключиться: $e';
        });
    }
  }

  Future<void> _disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _connected = false;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('TruckLink')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Мой грузовик', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
          _status,
          style: TextStyle(
            color: _connected ? Colors.tealAccent : Colors.orangeAccent,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _host,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'IP компьютера',
            hintText: '192.168.1.20',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _connect,
          icon: const Icon(Icons.wifi),
          label: const Text('Подключиться к Windows (LAN)'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Без подключения показаны примерные данные. Используется ws:// без шифрования — только доверенная локальная сеть.',
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1,
          children: [
            MetricTile(
              title: 'Скорость',
              value: '${_snapshot.speedKmh.toStringAsFixed(1)} км/ч',
            ),
            MetricTile(
              title: 'RPM',
              value: '${_snapshot.rpm.toInt()}',
              icon: Icons.autorenew,
            ),
            MetricTile(
              title: 'Передача',
              value: '${_snapshot.gear}',
              icon: Icons.settings,
            ),
            MetricTile(
              title: 'Топливо',
              value: '${(_snapshot.fuelFraction * 100).round()}%',
              icon: Icons.local_gas_station,
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.route),
            title: Text('Заказы / GPS / Финансы'),
            subtitle: Text('Разделы запланированы на следующие этапы.'),
          ),
        ),
      ],
    ),
  );
}
