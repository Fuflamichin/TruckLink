import 'package:flutter/material.dart';
import 'package:telemetry_core/telemetry_core.dart';

import '../../core/formatting/telemetry_format.dart';
import '../../core/network/telemetry_connection.dart';

// ============================================
// TRUCK SCREEN
// ============================================

class TruckScreen extends StatelessWidget {
  const TruckScreen({super.key, required this.connection});

  final TelemetryConnection connection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // With Scaffold.extendBody, MediaQuery.padding.bottom
    // includes the floating bottom navigation height.
    // It also reacts to user appearance settings.
    final navigationInset = MediaQuery.paddingOf(context).bottom;

    return ListView(
      key: const PageStorageKey<String>('trucklink-truck-scroll'),
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 20, 16, navigationInset + 32),
      children: [
        // ====================================
        // HEADER
        // ====================================
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Грузовик', style: theme.textTheme.headlineMedium),

              const SizedBox(height: 6),

              Text(
                'Состояние и характеристики '
                'текущего грузовика',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ====================================
        // MOVEMENT
        // ====================================
        _TruckMetricSection(
          title: 'Движение',
          icon: Icons.local_shipping_outlined,
          children: [
            _TruckMetricRow(
              key: const ValueKey('truck-speed'),
              connection: connection,
              label: 'Скорость',
              formatter: (snapshot) {
                if (snapshot == null) {
                  return TelemetryFormat.unavailable;
                }

                return TelemetryFormat.speed(snapshot.speedKmh);
              },
            ),

            _TruckMetricRow(
              key: const ValueKey('truck-gear'),
              connection: connection,
              label: 'Передача',
              formatter: (snapshot) {
                if (snapshot == null) {
                  return TelemetryFormat.unavailable;
                }

                return TelemetryFormat.gear(snapshot.gear);
              },
            ),

            _TruckMetricRow(
              key: const ValueKey('truck-odometer'),
              connection: connection,
              label: 'Пробег',
              formatter: (snapshot) {
                return TelemetryFormat.distance(snapshot?.odometerKm);
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ====================================
        // ENGINE
        // ====================================
        _TruckMetricSection(
          title: 'Двигатель',
          icon: Icons.settings_outlined,
          children: [
            _TruckMetricRow(
              key: const ValueKey('truck-engine-state'),
              connection: connection,
              label: 'Состояние двигателя',
              formatter: (snapshot) {
                if (snapshot == null) {
                  return TelemetryFormat.unavailable;
                }

                return TelemetryFormat.onOff(snapshot.engineOn);
              },
            ),

            _TruckMetricRow(
              key: const ValueKey('truck-rpm'),
              connection: connection,
              label: 'Обороты двигателя',
              formatter: (snapshot) {
                return TelemetryFormat.rpm(snapshot?.rpm);
              },
            ),

            _TruckMetricRow(
              key: const ValueKey('truck-max-rpm'),
              connection: connection,
              label: 'Максимальные обороты',
              formatter: (snapshot) {
                return TelemetryFormat.rpm(snapshot?.maxRpm);
              },
            ),

            _TruckMetricRow(
              key: const ValueKey('truck-temperature'),
              connection: connection,
              label: 'Температура воды',
              formatter: (snapshot) {
                return TelemetryFormat.temperature(snapshot?.waterTemperatureC);
              },
            ),

            _TruckMetricRow(
              key: const ValueKey('truck-engine-wear'),
              connection: connection,
              label: 'Износ двигателя',
              formatter: (snapshot) {
                return TelemetryFormat.percent(snapshot?.engineWearPercent);
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ====================================
        // FUEL
        // ====================================
        _TruckMetricSection(
          title: 'Топливо',
          icon: Icons.local_gas_station_outlined,
          children: [
            _TruckMetricRow(
              key: const ValueKey('truck-fuel-percent'),
              connection: connection,
              label: 'Уровень топлива',
              formatter: (snapshot) {
                if (snapshot == null || snapshot.fuelCapacityLiters <= 0) {
                  return TelemetryFormat.unavailable;
                }

                return TelemetryFormat.percent(snapshot.fuelPercent);
              },
            ),

            _TruckMetricRow(
              key: const ValueKey('truck-fuel-liters'),
              connection: connection,
              label: 'Остаток топлива',
              formatter: (snapshot) {
                return TelemetryFormat.liters(snapshot?.fuelLiters);
              },
            ),

            _TruckMetricRow(
              key: const ValueKey('truck-fuel-capacity'),
              connection: connection,
              label: 'Ёмкость бака',
              formatter: (snapshot) {
                if (snapshot == null || snapshot.fuelCapacityLiters <= 0) {
                  return TelemetryFormat.unavailable;
                }

                return TelemetryFormat.liters(snapshot.fuelCapacityLiters);
              },
            ),

            _TruckMetricRow(
              key: const ValueKey('truck-fuel-tank'),
              connection: connection,
              label: 'Заполнение бака',
              formatter: (snapshot) {
                return TelemetryFormat.fuelTank(
                  snapshot?.fuelLiters,
                  snapshot?.fuelCapacityLiters,
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ====================================
        // ADDITIONAL SYSTEMS
        // ====================================
        _TruckMetricSection(
          title: 'Дополнительные системы',
          icon: Icons.tune_rounded,
          children: [
            _TruckMetricRow(
              key: const ValueKey('truck-cruise'),
              connection: connection,
              label: 'Круиз-контроль',
              formatter: (snapshot) {
                return TelemetryFormat.cruiseControl(
                  snapshot?.cruiseControlKmh,
                );
              },
            ),

            _TruckMetricRow(
              key: const ValueKey('truck-speed-limit'),
              connection: connection,
              label: 'Ограничение скорости',
              formatter: (snapshot) {
                return TelemetryFormat.speedLimit(snapshot?.speedLimitKmh);
              },
            ),

            _TruckMetricRow(
              key: const ValueKey('truck-park-brake'),
              connection: connection,
              label: 'Стояночный тормоз',
              formatter: (snapshot) {
                return TelemetryFormat.onOff(
                  snapshot?.parkBrake,
                  enabled: 'Активен',
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================
// METRIC SECTION
// ============================================

class _TruckMetricSection extends StatelessWidget {
  const _TruckMetricSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: scheme.primary),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),

            const SizedBox(height: 12),

            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const Divider(height: 1),

              children[index],
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================
// LIVE TELEMETRY ROW
// ============================================

typedef _TruckValueFormatter = String Function(TruckSnapshot? snapshot);

class _TruckMetricRow extends StatefulWidget {
  const _TruckMetricRow({
    super.key,
    required this.connection,
    required this.label,
    required this.formatter,
  });

  final TelemetryConnection connection;
  final String label;
  final _TruckValueFormatter formatter;

  @override
  State<_TruckMetricRow> createState() => _TruckMetricRowState();
}

class _TruckMetricRowState extends State<_TruckMetricRow> {
  late String _value;

  // ==========================================
  // INITIALIZATION
  // ==========================================

  @override
  void initState() {
    super.initState();

    _value = _readValue();

    widget.connection.addListener(_onTelemetryChanged);
  }

  // ==========================================
  // READ VALUE
  // ==========================================

  String _readValue() {
    return widget.formatter(widget.connection.snapshot);
  }

  // ==========================================
  // UPDATE CONNECTION
  // ==========================================

  @override
  void didUpdateWidget(covariant _TruckMetricRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onTelemetryChanged);

      widget.connection.addListener(_onTelemetryChanged);
    }

    _value = _readValue();
  }

  // ==========================================
  // TELEMETRY LISTENER
  // ==========================================

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

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(widget.label, style: theme.textTheme.bodyMedium),
            ),

            const SizedBox(width: 12),

            Flexible(
              child: Text(
                _value,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // CLEANUP
  // ==========================================

  @override
  void dispose() {
    widget.connection.removeListener(_onTelemetryChanged);

    super.dispose();
  }
}
