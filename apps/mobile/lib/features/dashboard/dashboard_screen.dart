import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:telemetry_core/telemetry_core.dart';

import '../../core/network/telemetry_connection.dart';

// ============================================
// DASHBOARD SCREEN
// ============================================

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.connection});

  final TelemetryConnection connection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TruckLink')),
      body: CustomScrollView(
        key: const PageStorageKey('trucklink-dashboard-scroll'),
        physics: const ClampingScrollPhysics(),
        slivers: [
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

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Приборная панель',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),

          // One scrollable viewport.
          // No nested shrinkWrap GridView.
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
                    return _MetricCard(
                      connection: connection,
                      metric: _MetricKind.values[index],
                    );
                  }, childCount: _MetricKind.values.length),
                );
              },
            ),
          ),

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

          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverToBoxAdapter(
              child: Card(
                child: ListTile(
                  leading: Icon(Icons.dashboard_customize),
                  title: Text('TruckLink Dashboard'),
                  subtitle: Text(
                    'Заказы, GPS, финансы и статистика '
                    'появятся в следующих версиях.',
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

  late TelemetryConnectionStatus _status;
  late String _message;

  @override
  void initState() {
    super.initState();

    _status = widget.connection.status;
    _message = widget.connection.statusMessage;

    widget.connection.addListener(_onConnectionChanged);
  }

  @override
  void didUpdateWidget(covariant _ConnectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onConnectionChanged);

      widget.connection.addListener(_onConnectionChanged);

      _status = widget.connection.status;
      _message = widget.connection.statusMessage;
    }
  }

  void _onConnectionChanged() {
    final nextStatus = widget.connection.status;
    final nextMessage = widget.connection.statusMessage;

    // Avoid rebuilding the connection form
    // on every telemetry frame.
    if (_status == nextStatus && _message == nextMessage) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _status = nextStatus;
      _message = nextMessage;
    });
  }

  Color get _statusColor {
    return switch (_status) {
      TelemetryConnectionStatus.connected => Colors.tealAccent,
      TelemetryConnectionStatus.connecting ||
      TelemetryConnectionStatus.waiting => Colors.lightBlueAccent,
      _ => Colors.orangeAccent,
    };
  }

  IconData get _statusIcon {
    return switch (_status) {
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
    final isConnecting = _status == TelemetryConnectionStatus.connecting;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(_statusIcon, color: _statusColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_message, style: TextStyle(color: _statusColor)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _hostController,
              enabled: !isConnecting,
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

            FilledButton.icon(
              onPressed: isConnecting
                  ? null
                  : () {
                      unawaited(
                        widget.connection.connect(_hostController.text),
                      );
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
                  unawaited(widget.connection.disconnect());
                },
                icon: const Icon(Icons.link_off),
                label: const Text('Отключиться'),
              ),
            ],

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

  @override
  void dispose() {
    widget.connection.removeListener(_onConnectionChanged);

    _hostController.dispose();
    super.dispose();
  }
}

// ============================================
// METRIC DEFINITIONS
// ============================================

enum _MetricKind { speed, rpm, gear, fuel, temperature, engineWear }

String _metricTitle(_MetricKind metric) {
  return switch (metric) {
    _MetricKind.speed => 'Скорость',
    _MetricKind.rpm => 'Обороты',
    _MetricKind.gear => 'Передача',
    _MetricKind.fuel => 'Топливо',
    _MetricKind.temperature => 'Температура',
    _MetricKind.engineWear => 'Износ двигателя',
  };
}

String _metricUnit(_MetricKind metric) {
  return switch (metric) {
    _MetricKind.speed => 'км/ч',
    _MetricKind.rpm => 'RPM',
    _MetricKind.gear => '',
    _MetricKind.fuel => '%',
    _MetricKind.temperature => '°C',
    _MetricKind.engineWear => '%',
  };
}

IconData _metricIcon(_MetricKind metric) {
  return switch (metric) {
    _MetricKind.speed => Icons.speed,
    _MetricKind.rpm => Icons.autorenew,
    _MetricKind.gear => Icons.settings,
    _MetricKind.fuel => Icons.local_gas_station,
    _MetricKind.temperature => Icons.thermostat,
    _MetricKind.engineWear => Icons.build_circle_outlined,
  };
}

String _metricValue(_MetricKind metric, TruckSnapshot? snapshot) {
  if (snapshot == null) return '—';

  return switch (metric) {
    _MetricKind.speed => snapshot.speedKmh.abs().toStringAsFixed(1),
    _MetricKind.rpm => snapshot.rpm.toStringAsFixed(0),
    _MetricKind.gear => _formatGear(snapshot.gear),
    _MetricKind.fuel => snapshot.fuelPercent.toStringAsFixed(0),
    _MetricKind.temperature =>
      snapshot.waterTemperatureC?.toStringAsFixed(0) ?? '—',
    _MetricKind.engineWear =>
      snapshot.engineWearPercent?.toStringAsFixed(1) ?? '—',
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

class _MetricCard extends StatefulWidget {
  const _MetricCard({required this.connection, required this.metric});

  final TelemetryConnection connection;
  final _MetricKind metric;

  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard> {
  late String _value;

  @override
  void initState() {
    super.initState();

    _value = _metricValue(widget.metric, widget.connection.snapshot);

    widget.connection.addListener(_onTelemetryChanged);
  }

  @override
  void didUpdateWidget(covariant _MetricCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onTelemetryChanged);

      widget.connection.addListener(_onTelemetryChanged);
    }

    _value = _metricValue(widget.metric, widget.connection.snapshot);
  }

  void _onTelemetryChanged() {
    final nextValue = _metricValue(widget.metric, widget.connection.snapshot);

    // Rebuild only when the displayed metric changes.
    if (nextValue == _value || !mounted) {
      return;
    }

    setState(() {
      _value = nextValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _metricIcon(widget.metric),
                size: 22,
                color: Theme.of(context).colorScheme.primary,
              ),

              const SizedBox(height: 10),

              Text(
                _metricTitle(widget.metric),
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
                        _value,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),

                  if (_metricUnit(widget.metric).isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Text(
                      _metricUnit(widget.metric),
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
  }

  @override
  void dispose() {
    widget.connection.removeListener(_onTelemetryChanged);

    super.dispose();
  }
}

// ============================================
// TRUCK STATE CARD
// ============================================

class _TruckStateCard extends StatefulWidget {
  const _TruckStateCard({required this.connection});

  final TelemetryConnection connection;

  @override
  State<_TruckStateCard> createState() => _TruckStateCardState();
}

class _TruckStateCardState extends State<_TruckStateCard> {
  late List<String> _values;

  @override
  void initState() {
    super.initState();

    _values = _buildValues(widget.connection.snapshot);

    widget.connection.addListener(_onTelemetryChanged);
  }

  @override
  void didUpdateWidget(covariant _TruckStateCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onTelemetryChanged);

      widget.connection.addListener(_onTelemetryChanged);
    }

    _values = _buildValues(widget.connection.snapshot);
  }

  List<String> _buildValues(TruckSnapshot? snapshot) {
    if (snapshot == null) {
      return List<String>.filled(6, '—');
    }

    return [
      snapshot.engineOn ? 'Включён' : 'Выключен',

      snapshot.odometerKm == null
          ? '—'
          : '${snapshot.odometerKm!.toStringAsFixed(1)} км',

      '${snapshot.fuelLiters.toStringAsFixed(1)} / '
          '${snapshot.fuelCapacityLiters.toStringAsFixed(0)} л',

      snapshot.cruiseControlKmh == null
          ? '—'
          : '${snapshot.cruiseControlKmh!.toStringAsFixed(0)} км/ч',

      snapshot.speedLimitKmh == null
          ? '—'
          : '${snapshot.speedLimitKmh!.toStringAsFixed(0)} км/ч',

      snapshot.parkBrake == null
          ? '—'
          : snapshot.parkBrake!
          ? 'Активен'
          : 'Выключен',
    ];
  }

  void _onTelemetryChanged() {
    final nextValues = _buildValues(widget.connection.snapshot);

    // Avoid rebuilding when formatted values
    // have not changed.
    if (listEquals(_values, nextValues) || !mounted) {
      return;
    }

    setState(() {
      _values = nextValues;
    });
  }

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Двигатель',
      'Пробег',
      'Топливо',
      'Круиз-контроль',
      'Ограничение',
      'Стояночный тормоз',
    ];

    return RepaintBoundary(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              for (var index = 0; index < labels.length; index++) ...[
                if (index != 0) const Divider(),
                _InfoRow(label: labels[index], value: _values[index]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.connection.removeListener(_onTelemetryChanged);

    super.dispose();
  }
}

// ============================================
// INFORMATION ROW
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
