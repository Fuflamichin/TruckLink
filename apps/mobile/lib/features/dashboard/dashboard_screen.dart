import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:telemetry_core/telemetry_core.dart';

import '../../core/network/telemetry_connection.dart';

// ============================================
// DASHBOARD SCREEN
// ============================================

/// Instrument dashboard for ETS2 / ATS.
///
/// The screen does not manage WebSocket connections
/// and does not create its own Scaffold or AppBar.
///
/// AppShell owns the application navigation.
/// TelemetryConnection owns the network connection.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.connection});

  final TelemetryConnection connection;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: const PageStorageKey<String>('trucklink-dashboard-scroll'),
        physics: const ClampingScrollPhysics(),
        slivers: [
          // ==================================
          // SCREEN HEADER
          // ==================================
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 76, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Приборы',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Телеметрия грузовика в реальном времени',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          // ==================================
          // WINDOWS HUB STATUS
          // ==================================
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _HubStatusCard(connection: connection),
            ),
          ),

          // ==================================
          // INSTRUMENT SECTION HEADER
          // ==================================
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Основные показатели',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),

          // ==================================
          // OPTIMIZED INSTRUMENT GRID
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
                    return _MetricCard(
                      key: ValueKey(index),
                      connection: connection,
                      metric: _MetricKind.values[index],
                    );
                  }, childCount: _MetricKind.values.length),
                );
              },
            ),
          ),

          // ==================================
          // ADDITIONAL INSTRUMENTS
          // ==================================
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Дополнительные показатели',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverToBoxAdapter(
              child: _AdditionalMetricsCard(connection: connection),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// WINDOWS HUB STATUS CARD
// ============================================

/// Rebuilds only when the connection status changes,
/// not on every new telemetry packet.
class _HubStatusCard extends StatefulWidget {
  const _HubStatusCard({required this.connection});

  final TelemetryConnection connection;

  @override
  State<_HubStatusCard> createState() => _HubStatusCardState();
}

class _HubStatusCardState extends State<_HubStatusCard> {
  late TelemetryConnectionStatus _status;
  late String _message;

  @override
  void initState() {
    super.initState();

    _readStatus();

    widget.connection.addListener(_onConnectionChanged);
  }

  void _readStatus() {
    _status = widget.connection.status;
    _message = widget.connection.statusMessage;
  }

  @override
  void didUpdateWidget(covariant _HubStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onConnectionChanged);

      widget.connection.addListener(_onConnectionChanged);
    }

    _readStatus();
  }

  void _onConnectionChanged() {
    if (!mounted) return;

    final nextStatus = widget.connection.status;
    final nextMessage = widget.connection.statusMessage;

    if (_status == nextStatus && _message == nextMessage) {
      return;
    }

    setState(() {
      _status = nextStatus;
      _message = nextMessage;
    });
  }

  IconData get _statusIcon {
    return switch (_status) {
      TelemetryConnectionStatus.connected => Icons.check_circle_rounded,

      TelemetryConnectionStatus.waiting => Icons.hourglass_top_rounded,

      TelemetryConnectionStatus.connecting => Icons.sync_rounded,

      TelemetryConnectionStatus.stale => Icons.warning_amber_rounded,

      TelemetryConnectionStatus.error => Icons.error_outline_rounded,

      TelemetryConnectionStatus.disconnected => Icons.wifi_off_rounded,
    };
  }

  Color _statusColor(ColorScheme scheme) {
    return switch (_status) {
      TelemetryConnectionStatus.connected => scheme.primary,

      TelemetryConnectionStatus.waiting => scheme.tertiary,

      TelemetryConnectionStatus.connecting => scheme.tertiary,

      TelemetryConnectionStatus.stale => scheme.tertiary,

      TelemetryConnectionStatus.error => scheme.error,

      TelemetryConnectionStatus.disconnected => scheme.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(_statusIcon, color: _statusColor(scheme)),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Windows Hub',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),

                  const SizedBox(height: 4),

                  Text(
                    _message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _statusColor(scheme),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            IconButton(
              tooltip: 'Отключиться от компьютера',
              onPressed: widget.connection.isConnected
                  ? () {
                      unawaited(widget.connection.disconnect());
                    }
                  : null,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.connection.removeListener(_onConnectionChanged);

    super.dispose();
  }
}

// ============================================
// INSTRUMENT DEFINITIONS
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

  if (gear < 0) {
    return 'R${gear.abs()}';
  }

  return gear.toString();
}

// ============================================
// OPTIMIZED METRIC CARD
// ============================================

/// A card only rebuilds when its displayed
/// formatted value actually changes.
class _MetricCard extends StatefulWidget {
  const _MetricCard({
    super.key,
    required this.connection,
    required this.metric,
  });

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
    if (!mounted) return;

    final nextValue = _metricValue(widget.metric, widget.connection.snapshot);

    if (_value == nextValue) return;

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
// ADDITIONAL METRICS
// ============================================

class _AdditionalMetricsCard extends StatefulWidget {
  const _AdditionalMetricsCard({required this.connection});

  final TelemetryConnection connection;

  @override
  State<_AdditionalMetricsCard> createState() => _AdditionalMetricsCardState();
}

class _AdditionalMetricsCardState extends State<_AdditionalMetricsCard> {
  late List<String> _values;

  static const _labels = <String>[
    'Двигатель',
    'Пробег',
    'Максимальные обороты',
    'Топливо в баке',
    'Круиз-контроль',
    'Ограничение скорости',
    'Стояночный тормоз',
  ];

  @override
  void initState() {
    super.initState();

    _values = _buildValues(widget.connection.snapshot);

    widget.connection.addListener(_onTelemetryChanged);
  }

  @override
  void didUpdateWidget(covariant _AdditionalMetricsCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onTelemetryChanged);

      widget.connection.addListener(_onTelemetryChanged);
    }

    _values = _buildValues(widget.connection.snapshot);
  }

  List<String> _buildValues(TruckSnapshot? snapshot) {
    if (snapshot == null) {
      return List<String>.filled(_labels.length, '—');
    }

    return [
      snapshot.engineOn ? 'Включён' : 'Выключен',

      snapshot.odometerKm == null
          ? '—'
          : '${snapshot.odometerKm!.toStringAsFixed(1)} км',

      snapshot.maxRpm == null
          ? '—'
          : '${snapshot.maxRpm!.toStringAsFixed(0)} RPM',

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
    if (!mounted) return;

    final nextValues = _buildValues(widget.connection.snapshot);

    if (listEquals(_values, nextValues)) {
      return;
    }

    setState(() {
      _values = nextValues;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              for (var index = 0; index < _labels.length; index++) ...[
                if (index != 0) const Divider(),

                _MetricInfoRow(label: _labels[index], value: _values[index]),
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

class _MetricInfoRow extends StatelessWidget {
  const _MetricInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),

        const SizedBox(width: 12),

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
