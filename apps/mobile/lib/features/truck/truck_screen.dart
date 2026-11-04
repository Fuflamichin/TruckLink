import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:telemetry_core/telemetry_core.dart';

import '../../core/network/telemetry_connection.dart';
import '../common/detail_row.dart';

// ============================================
// TRUCK TECHNICAL CONDITION SCREEN
// ============================================

class TruckScreen extends StatefulWidget {
  const TruckScreen({super.key, required this.connection});

  final TelemetryConnection connection;

  @override
  State<TruckScreen> createState() => _TruckScreenState();
}

class _TruckScreenState extends State<TruckScreen> {
  late List<String> _values;

  static const _labels = <String>[
    'Двигатель',
    'Пробег',
    'Температура',
    'Износ двигателя',
    'Топливо',
    'Стояночный тормоз',
  ];

  @override
  void initState() {
    super.initState();

    _values = _buildValues(widget.connection.snapshot);

    widget.connection.addListener(_onUpdate);
  }

  @override
  void didUpdateWidget(covariant TruckScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onUpdate);
      widget.connection.addListener(_onUpdate);
    }

    _values = _buildValues(widget.connection.snapshot);
  }

  // ==========================================
  // FORMATTED TELEMETRY
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

      snapshot.waterTemperatureC == null
          ? '—'
          : '${snapshot.waterTemperatureC!.toStringAsFixed(1)} °C',

      snapshot.engineWearPercent == null
          ? '—'
          : '${snapshot.engineWearPercent!.toStringAsFixed(1)}%',

      '${snapshot.fuelLiters.toStringAsFixed(1)} / '
          '${snapshot.fuelCapacityLiters.toStringAsFixed(0)} л',

      snapshot.parkBrake == null
          ? '—'
          : snapshot.parkBrake!
          ? 'Активен'
          : 'Выключен',
    ];
  }

  void _onUpdate() {
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
  // UI
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const PageStorageKey<String>('truck-screen'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Техническое состояние',
          style: Theme.of(context).textTheme.titleLarge,
        ),

        const SizedBox(height: 12),

        RepaintBoundary(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (var index = 0; index < _labels.length; index++) ...[
                    if (index != 0) const Divider(),

                    DetailRow(label: _labels[index], value: _values[index]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    widget.connection.removeListener(_onUpdate);
    super.dispose();
  }
}
