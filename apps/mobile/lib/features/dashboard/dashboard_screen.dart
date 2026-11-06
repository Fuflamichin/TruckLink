import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:telemetry_core/telemetry_core.dart';

import '../../core/network/telemetry_connection.dart';

// ============================================
// DASHBOARD SCREEN
// ============================================

/// TruckLink instrument dashboard.
///
/// This screen displays telemetry only.
///
/// Connection management is available in:
/// Settings -> Connection.
///
/// AppShell provides the shared AppBar and
/// bottom navigation.
///
/// TelemetryConnection is owned by the app,
/// not by this screen.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.connection});

  final TelemetryConnection connection;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const PageStorageKey<String>('trucklink-dashboard-scroll'),
      physics: const ClampingScrollPhysics(),
      slivers: [
        // ==================================
        // SCREEN HEADER
        // ==================================
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                  'Телеметрия грузовика '
                  'в реальном времени',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),

        // ==================================
        // MAIN METRICS HEADER
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
        // TELEMETRY GRID
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
                  final metric = _MetricKind.values[index];

                  return _MetricCard(
                    key: ValueKey(metric),
                    connection: connection,
                    metric: metric,
                  );
                }, childCount: _MetricKind.values.length),
              );
            },
          ),
        ),

        // ==================================
        // ADDITIONAL METRICS HEADER
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

        // ==================================
        // ADDITIONAL METRICS CARD
        // ==================================
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverToBoxAdapter(
            child: _AdditionalMetricsCard(connection: connection),
          ),
        ),
      ],
    );
  }
}

// ============================================
// METRIC TYPES
// ============================================

enum _MetricKind { speed, rpm, gear, fuel, temperature, engineWear }

// ============================================
// METRIC METADATA
// ============================================

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

// ============================================
// METRIC FORMATTING
// ============================================

String _metricValue(_MetricKind metric, TruckSnapshot? snapshot) {
  if (snapshot == null) {
    return '—';
  }

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

/// Each metric card listens to the shared
/// telemetry controller independently.
///
/// It rebuilds only when its displayed
/// formatted value changes.
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

    _value = _readValue();

    widget.connection.addListener(_onTelemetryChanged);
  }

  String _readValue() {
    return _metricValue(widget.metric, widget.connection.snapshot);
  }

  @override
  void didUpdateWidget(covariant _MetricCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onTelemetryChanged);

      widget.connection.addListener(_onTelemetryChanged);
    }

    _value = _readValue();
  }

  void _onTelemetryChanged() {
    if (!mounted) return;

    final nextValue = _readValue();

    if (nextValue == _value) {
      return;
    }

    setState(() {
      _value = nextValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                color: theme.colorScheme.primary,
              ),

              const SizedBox(height: 10),

              Text(
                _metricTitle(widget.metric),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium,
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
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                  ),

                  if (_metricUnit(widget.metric).isNotEmpty) ...[
                    const SizedBox(width: 5),

                    Text(
                      _metricUnit(widget.metric),
                      style: theme.textTheme.labelSmall,
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
// ADDITIONAL METRICS CARD
// ============================================

class _AdditionalMetricsCard extends StatefulWidget {
  const _AdditionalMetricsCard({required this.connection});

  final TelemetryConnection connection;

  @override
  State<_AdditionalMetricsCard> createState() => _AdditionalMetricsCardState();
}

class _AdditionalMetricsCardState extends State<_AdditionalMetricsCard> {
  static const List<String> _labels = [
    'Двигатель',
    'Пробег',
    'Максимальные обороты',
    'Топливо в баке',
    'Круиз-контроль',
    'Ограничение скорости',
    'Стояночный тормоз',
  ];

  late List<String> _values;

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

  // ==========================================
  // FORMAT VALUES
  // ==========================================

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

  // ==========================================
  // UPDATE ONLY WHEN NEEDED
  // ==========================================

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

  // ==========================================
  // BUILD
  // ==========================================

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
// REUSABLE INFORMATION ROW
// ============================================

class _MetricInfoRow extends StatelessWidget {
  const _MetricInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),

        const SizedBox(width: 12),

        Flexible(
          child: Text(value, textAlign: TextAlign.right, style: style),
        ),
      ],
    );
  }
}
