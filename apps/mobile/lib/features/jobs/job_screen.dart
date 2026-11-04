import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:telemetry_core/telemetry_core.dart';

import '../../core/network/telemetry_connection.dart';
import '../common/detail_row.dart';
import '../common/empty_state.dart';

// ============================================
// CURRENT JOB SCREEN
// ============================================

class JobScreen extends StatefulWidget {
  const JobScreen({super.key, required this.connection});

  final TelemetryConnection connection;

  @override
  State<JobScreen> createState() => _JobScreenState();
}

class _JobScreenState extends State<JobScreen> {
  TruckJob? _job;
  Map<String, Object?>? _jobData;

  @override
  void initState() {
    super.initState();

    _readJob();

    widget.connection.addListener(_onUpdate);
  }

  void _readJob() {
    _job = widget.connection.snapshot?.job;
    _jobData = _job?.toJson();
  }

  @override
  void didUpdateWidget(covariant JobScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onUpdate);
      widget.connection.addListener(_onUpdate);
    }

    _readJob();
  }

  // ==========================================
  // OPTIMIZED UPDATES
  // ==========================================

  void _onUpdate() {
    if (!mounted) return;

    final nextJob = widget.connection.snapshot?.job;
    final nextData = nextJob?.toJson();

    // The job screen is not rebuilt when only
    // speed, RPM or fuel changes.
    if (mapEquals(_jobData, nextData)) {
      return;
    }

    setState(() {
      _job = nextJob;
      _jobData = nextData;
    });
  }

  // ==========================================
  // UI
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final job = _job;

    if (job == null) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Нет данных о заказе',
        message:
            'Информация о текущем заказе '
            'появится после расширения '
            'SDK-адаптера TruckLink.',
      );
    }

    return ListView(
      key: const PageStorageKey<String>('job-screen'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Текущая перевозка',
          style: Theme.of(context).textTheme.titleLarge,
        ),

        const SizedBox(height: 12),

        RepaintBoundary(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DetailRow(label: 'Груз', value: job.cargoName ?? '—'),

                  const Divider(),

                  DetailRow(
                    label: 'Масса',
                    value: job.cargoMassKg == null
                        ? '—'
                        : '${job.cargoMassKg!.toStringAsFixed(0)} кг',
                  ),

                  const Divider(),

                  DetailRow(label: 'Откуда', value: job.sourceCity ?? '—'),

                  const Divider(),

                  DetailRow(
                    label: 'Компания отправителя',
                    value: job.sourceCompany ?? '—',
                  ),

                  const Divider(),

                  DetailRow(label: 'Куда', value: job.destinationCity ?? '—'),

                  const Divider(),

                  DetailRow(
                    label: 'Компания получателя',
                    value: job.destinationCompany ?? '—',
                  ),

                  const Divider(),

                  DetailRow(
                    label: 'Вознаграждение',
                    value: job.reward?.toString() ?? '—',
                  ),

                  const Divider(),

                  DetailRow(
                    label: 'Осталось',
                    value: job.remainingDistanceKm == null
                        ? '—'
                        : '${job.remainingDistanceKm!.toStringAsFixed(1)} км',
                  ),
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
