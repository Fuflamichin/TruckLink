import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telemetry_core/telemetry_core.dart';

import 'core/network/telemetry_connection.dart';

// ============================================
// APP INITIALIZATION
// ============================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: TruckLinkApp()));
}

// ============================================
// DEPENDENCY INJECTION
// ============================================

final telemetryConnectionProvider = Provider<TelemetryConnection>((ref) {
  final connection = TelemetryConnection();

  ref.onDispose(connection.dispose);

  return connection;
});

// ============================================
// APPLICATION
// ============================================

class TruckLinkApp extends StatelessWidget {
  const TruckLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TruckLink',
      debugShowCheckedModeBanner: false,
      theme: TruckLinkTheme.dark,
      home: const MobileDashboard(),
    );
  }
}

// ============================================
// DASHBOARD
// ============================================

class MobileDashboard extends ConsumerWidget {
  const MobileDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(telemetryConnectionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('TruckLink'), centerTitle: false),
      body: CustomScrollView(
        key: const PageStorageKey('dashboard-scroll'),
        physics: const ClampingScrollPhysics(),
        slivers: [
          // ==================================
          // HEADER AND CONNECTION
          // ==================================
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Мой грузовик',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Мониторинг в реальном времени',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _ConnectionCard(connection: connection),
                ],
              ),
            ),
          ),

          // ==================================
          // TELEMETRY HEADER
          // ==================================
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Приборная панель',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),

          // ==================================
          // OPTIMIZED TELEMETRY GRID
          // ==================================
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.crossAxisExtent < 270 ? 1 : 2;

                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 152,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return _MetricCard(connection: connection, index: index);
                  }, childCount: 6),
                );
              },
            ),
          ),

          // ==================================
          // TRUCK INFORMATION
          // ==================================
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Состояние грузовика',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _TruckStateCard(connection: connection),
                ],
              ),
            ),
          ),

          // ==================================
          // FUTURE MODULES
          // ==================================
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverToBoxAdapter(
              child: Card(
                child: ListTile(
                  leading: Icon(Icons.dashboard_customize),
                  title: Text('TruckLink Dashboard'),
                  subtitle: Text(
                    'Навигация, GPS, заказы и финансы '
                    'будут добавлены в следующих версиях.',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// CONNECTION CARD
// ============================================

class _ConnectionCard extends StatefulWidget {
  const _ConnectionCard({required this.connection});

  final TelemetryConnection connection;

  @override
  State<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<_ConnectionCard> {
  final TextEditingController _hostController = TextEditingController();

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  Color _statusColor(TelemetryConnectionStatus status) {
    return switch (status) {
      TelemetryConnectionStatus.connected => Colors.tealAccent,
      TelemetryConnectionStatus.connecting ||
      TelemetryConnectionStatus.waiting => Colors.lightBlueAccent,
      _ => Colors.orangeAccent,
    };
  }

  IconData _statusIcon(TelemetryConnectionStatus status) {
    return switch (status) {
      TelemetryConnectionStatus.connected => Icons.check_circle,
      TelemetryConnectionStatus.connecting => Icons.sync,
      TelemetryConnectionStatus.waiting => Icons.hourglass_top,
      TelemetryConnectionStatus.stale => Icons.warning_amber,
      TelemetryConnectionStatus.error => Icons.error_outline,
      TelemetryConnectionStatus.disconnected => Icons.wifi_off,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection status only.
            ListenableBuilder(
              listenable: widget.connection,
              builder: (context, child) {
                final status = widget.connection.status;

                return Row(
                  children: [
                    Icon(_statusIcon(status), color: _statusColor(status)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.connection.statusMessage,
                        style: TextStyle(color: _statusColor(status)),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _hostController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'IP компьютера',
                hintText: '192.168.1.20',
                prefixIcon: Icon(Icons.computer),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            // Connection actions are rebuilt
            // independently of the text field.
            ListenableBuilder(
              listenable: widget.connection,
              builder: (context, child) {
                final isConnecting =
                    widget.connection.status ==
                    TelemetryConnectionStatus.connecting;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: isConnecting
                          ? null
                          : () {
                              widget.connection.connect(_hostController.text);
                            },
                      icon: const Icon(Icons.wifi),
                      label: Text(
                        widget.connection.isConnected
                            ? 'Переподключиться'
                            : 'Подключиться к Windows',
                      ),
                    ),
                    if (widget.connection.isConnected) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          widget.connection.disconnect();
                        },
                        icon: const Icon(Icons.link_off),
                        label: const Text('Отключиться'),
                      ),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 10),

            Text(
              'Локальная сеть · WebSocket · порт 8787',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// METRIC CONFIGURATION
// ============================================

const _metricTitles = <String>[
  'Скорость',
  'Обороты',
  'Передача',
  'Топливо',
  'Температура',
  'Износ двигателя',
];

const _metricUnits = <String>['км/ч', 'RPM', '', '%', '°C', '%'];

const _metricIcons = <IconData>[
  Icons.speed,
  Icons.autorenew,
  Icons.settings,
  Icons.local_gas_station,
  Icons.thermostat,
  Icons.build_circle_outlined,
];

String _metricValue(int index, TruckSnapshot? snapshot) {
  if (snapshot == null) return '—';

  return switch (index) {
    0 => snapshot.speedKmh.abs().toStringAsFixed(1),
    1 => snapshot.rpm.toStringAsFixed(0),
    2 => _formatGear(snapshot.gear),
    3 => snapshot.fuelPercent.toStringAsFixed(0),
    4 => snapshot.waterTemperatureC?.toStringAsFixed(0) ?? '—',
    5 => snapshot.engineWearPercent?.toStringAsFixed(1) ?? '—',
    _ => '—',
  };
}

String _formatGear(int gear) {
  if (gear == 0) return 'N';
  if (gear < 0) return 'R${gear.abs()}';
  return gear.toString();
}

// ============================================
// OPTIMIZED METRIC CARD
// ============================================

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.connection, required this.index});

  final TelemetryConnection connection;
  final int index;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: connection,
      builder: (context, child) {
        final snapshot = connection.snapshot;
        final value = _metricValue(index, snapshot);

        return RepaintBoundary(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _metricIcons[index],
                    size: 22,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _metricTitles[index],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            value,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                      ),
                      if (_metricUnits[index].isNotEmpty) ...[
                        const SizedBox(width: 5),
                        Text(
                          _metricUnits[index],
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================
// TRUCK STATE CARD
// ============================================

class _TruckStateCard extends StatelessWidget {
  const _TruckStateCard({required this.connection});

  final TelemetryConnection connection;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: connection,
      builder: (context, child) {
        final snapshot = connection.snapshot;

        return RepaintBoundary(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _InfoRow(
                    label: 'Двигатель',
                    value: snapshot == null
                        ? '—'
                        : snapshot.engineOn
                        ? 'Включён'
                        : 'Выключен',
                  ),
                  const Divider(),
                  _InfoRow(
                    label: 'Пробег',
                    value: snapshot?.odometerKm == null
                        ? '—'
                        : '${snapshot!.odometerKm!.toStringAsFixed(1)} км',
                  ),
                  const Divider(),
                  _InfoRow(
                    label: 'Топливо',
                    value: snapshot == null
                        ? '—'
                        : '${snapshot.fuelLiters.toStringAsFixed(1)} / '
                              '${snapshot.fuelCapacityLiters.toStringAsFixed(0)} л',
                  ),
                  const Divider(),
                  _InfoRow(
                    label: 'Круиз-контроль',
                    value: snapshot?.cruiseControlKmh == null
                        ? '—'
                        : '${snapshot!.cruiseControlKmh!.toStringAsFixed(0)} км/ч',
                  ),
                  const Divider(),
                  _InfoRow(
                    label: 'Ограничение',
                    value: snapshot?.speedLimitKmh == null
                        ? '—'
                        : '${snapshot!.speedLimitKmh!.toStringAsFixed(0)} км/ч',
                  ),
                  const Divider(),
                  _InfoRow(
                    label: 'Стояночный тормоз',
                    value: snapshot?.parkBrake == null
                        ? '—'
                        : snapshot!.parkBrake!
                        ? 'Активен'
                        : 'Выключен',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================
// REUSABLE INFORMATION ROW
// ============================================

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
