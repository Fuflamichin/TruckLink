import 'dart:async';
import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_protocol/network_protocol.dart';
import 'package:telemetry_core/telemetry_core.dart';

void main() => runApp(const ProviderScope(child: DesktopApp()));

class DesktopApp extends StatelessWidget {
  const DesktopApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TruckLink Desktop',
    debugShowCheckedModeBanner: false,
    theme: TruckLinkTheme.dark,
    home: const DesktopHome(),
  );
}

class DesktopHome extends StatefulWidget {
  const DesktopHome({super.key});
  @override
  State<DesktopHome> createState() => _DesktopHomeState();
}

class _DesktopHomeState extends State<DesktopHome> {
  HttpServer? _server;
  Timer? _timer;
  final _clients = <WebSocket>{};
  String _status = 'Сервер остановлен';
  final TruckSnapshot _snapshot = TruckSnapshot.demo();

  Future<void> _start() async {
    if (_server != null) return;
    try {
      // Stage 1 demo only. Binds all adapters for LAN testing; no auth/TLS yet.
      final server = await HttpServer.bind(InternetAddress.anyIPv4, 8787);
      _server = server;
      _status = 'Демо-сервер: порт 8787 (только доверенная Wi-Fi сеть)';
      server.listen((request) async {
        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
          return;
        }
        try {
          final socket = await WebSocketTransformer.upgrade(request);
          _clients.add(socket);
          socket.add(encodeSnapshot(TruckSnapshot.demo()));
          socket.listen((_) {}, onDone: () => _clients.remove(socket),
            onError: (_) => _clients.remove(socket), cancelOnError: true);
          if (mounted) setState(() {});
        } catch (_) {
          // A disconnected demo client is not fatal to the hub.
        }
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final data = encodeSnapshot(TruckSnapshot.demo());
        for (final client in _clients.toList()) {
          try { client.add(data); } catch (_) { _clients.remove(client); }
        }
        if (mounted) setState(() {});
      });
    } on SocketException catch (e) {
      _status = 'Не удалось открыть порт 8787: $e';
    }
    if (mounted) setState(() {});
  }

  Future<void> _stop() async {
    _timer?.cancel();
    _timer = null;
    for (final client in _clients.toList()) { await client.close(); }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
    _status = 'Сервер остановлен';
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final socket in _clients) { socket.close(); }
    _server?.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('TruckLink · Windows Hub')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000),
      child: ListView(padding: const EdgeInsets.all(24), children: [
        Text('Центр телеметрии', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        const Text('Этап 1 · Демо-данные. Подключения к ETS2 пока нет.'),
        const SizedBox(height: 20),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_status),
            const SizedBox(height: 8),
            Text('Клиентов: ${_clients.length}'),
            const SizedBox(height: 8),
            const SelectableText('Адрес на телефоне: ws://IP_ВАШЕГО_ПК:8787'),
            const SizedBox(height: 12),
            Wrap(spacing: 12, children: [
              FilledButton.icon(onPressed: _server == null ? _start : null,
                icon: const Icon(Icons.play_arrow), label: const Text('Запустить демо')),
              OutlinedButton(onPressed: _server == null ? null : _stop,
                child: const Text('Остановить')),
            ]),
          ],
        ))),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, size) => GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: size.maxWidth > 620 ? 3 : 2,
          childAspectRatio: 1.55,
          children: [
            MetricTile(title: 'Скорость', value: '${_snapshot.speedKmh} км/ч'),
            MetricTile(title: 'Обороты', value: '${_snapshot.rpm.toInt()} RPM', icon: Icons.autorenew),
            MetricTile(title: 'Передача', value: '${_snapshot.gear}', icon: Icons.settings),
            MetricTile(title: 'Топливо', value: '${_snapshot.fuelLiters.toInt()} л', icon: Icons.local_gas_station),
            const MetricTile(title: 'Игра', value: 'DEMO', icon: Icons.sports_esports),
            const MetricTile(title: 'Протокол', value: 'v1', icon: Icons.hub),
          ],
        )),
      ]))),
  );
}
