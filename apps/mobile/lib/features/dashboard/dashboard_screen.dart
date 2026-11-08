import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:telemetry_core/telemetry_core.dart';

import '../../core/formatting/telemetry_format.dart';
import '../../core/network/telemetry_connection.dart';

// ============================================
// INSTRUMENTS DASHBOARD
// ============================================

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.connection});

  final TelemetryConnection connection;

  @override
  Widget build(BuildContext context) {
    // Scaffold.extendBody makes the scroll view extend
    // behind the floating navigation.
    // MediaQuery.padding.bottom includes its actual height.
    final navigationInset = MediaQuery.paddingOf(context).bottom;

    return CustomScrollView(
      key: const PageStorageKey<String>('trucklink-dashboard-scroll'),
      physics: const ClampingScrollPhysics(),
      slivers: [
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

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Основные показатели',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),

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
          padding: EdgeInsets.fromLTRB(16, 0, 16, navigationInset + 32),
          sliver: SliverToBoxAdapter(
            child: _AdditionalMetricsCard(connection: connection),
          ),
        ),
      ],
    );
  }
}

// ============================================
// MAIN METRICS
// ============================================

enum _MetricKind { speed, rpm, gear, fuel, temperature, engineWear }

extension _MetricInfo on _MetricKind {
  String get title => switch (this) {
    _MetricKind.speed => 'Скорость',
    _MetricKind.rpm => 'Обороты',
    _MetricKind.gear => 'Передача',
    _MetricKind.fuel => 'Топливо',
    _MetricKind.temperature => 'Температура',
    _MetricKind.engineWear => 'Износ двигателя',
  };

  String get unit => switch (this) {
    _MetricKind.speed => 'км/ч',
    _MetricKind.rpm => 'RPM',
    _MetricKind.gear => '',
    _MetricKind.fuel => '%',
    _MetricKind.temperature => '°C',
    _MetricKind.engineWear => '%',
  };

  IconData get icon => switch (this) {
    _MetricKind.speed => Icons.speed,
    _MetricKind.rpm => Icons.autorenew,
    _MetricKind.gear => Icons.settings,
    _MetricKind.fuel => Icons.local_gas_station,
    _MetricKind.temperature => Icons.thermostat,
    _MetricKind.engineWear => Icons.build_circle_outlined,
  };

  String formatValue(TruckSnapshot? snapshot) {
    if (snapshot == null) {
      return TelemetryFormat.unavailable;
    }

    return switch (this) {
      _MetricKind.speed => TelemetryFormat.integer(
        snapshot.speedKmh,
        absolute: true,
      ),

      _MetricKind.rpm => TelemetryFormat.integer(snapshot.rpm),

      _MetricKind.gear => TelemetryFormat.gear(snapshot.gear),

      _MetricKind.fuel =>
        snapshot.fuelCapacityLiters <= 0
            ? TelemetryFormat.unavailable
            : TelemetryFormat.integer(snapshot.fuelPercent),

      _MetricKind.temperature => TelemetryFormat.integer(
        snapshot.waterTemperatureC,
      ),

      _MetricKind.engineWear => TelemetryFormat.integer(
        snapshot.engineWearPercent,
      ),
    };
  }
}

// ============================================
// OPTIMIZED MAIN METRIC CARD
// ============================================

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
    return widget.metric.formatValue(widget.connection.snapshot);
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

    if (nextValue == _value) return;

    setState(() {
      _value = nextValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = _value;

    return RepaintBoundary(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                widget.metric.icon,
                size: 22,
                color: theme.colorScheme.primary,
              ),

              const SizedBox(height: 10),

              Text(
                widget.metric.title,
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
                        value,
                        maxLines: 1,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                  ),

                  if (value != TelemetryFormat.unavailable &&
                      widget.metric.unit.isNotEmpty) ...[
                    const SizedBox(width: 5),

                    Text(widget.metric.unit, style: theme.textTheme.labelSmall),
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

    _values = _readValues();

    widget.connection.addListener(_onTelemetryChanged);
  }

  List<String> _readValues() {
    final snapshot = widget.connection.snapshot;

    if (snapshot == null) {
      return List<String>.filled(_labels.length, TelemetryFormat.unavailable);
    }

    return [
      TelemetryFormat.onOff(snapshot.engineOn),

      TelemetryFormat.distance(snapshot.odometerKm),

      TelemetryFormat.rpm(snapshot.maxRpm),

      TelemetryFormat.fuelTank(
        snapshot.fuelLiters,
        snapshot.fuelCapacityLiters,
      ),

      TelemetryFormat.cruiseControl(snapshot.cruiseControlKmh),

      TelemetryFormat.speedLimit(snapshot.speedLimitKmh),

      TelemetryFormat.onOff(snapshot.parkBrake, enabled: 'Активен'),
    ];
  }

  @override
  void didUpdateWidget(covariant _AdditionalMetricsCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onTelemetryChanged);

      widget.connection.addListener(_onTelemetryChanged);
    }

    _values = _readValues();
  }

  void _onTelemetryChanged() {
    if (!mounted) return;

    final nextValues = _readValues();

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
// REUSABLE DETAIL ROW
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
