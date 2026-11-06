import 'package:flutter/material.dart';
import 'package:telemetry_core/telemetry_core.dart';

import '../../core/formatting/telemetry_format.dart';
import '../../core/network/telemetry_connection.dart';

// ============================================
// JOB SCREEN
// ============================================

class JobScreen extends StatelessWidget {
  const JobScreen({super.key, required this.connection});

  final TelemetryConnection connection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      key: const PageStorageKey<String>('trucklink-job-scroll'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // ====================================
        // HEADER
        // ====================================
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Заказ', style: theme.textTheme.headlineMedium),

              const SizedBox(height: 6),

              Text(
                'Информация о текущей перевозке',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ====================================
        // CARGO
        // ====================================
        _JobSection(
          title: 'Информация о грузе',
          icon: Icons.inventory_2_outlined,
          children: [
            _JobValueRow(
              key: const ValueKey('job-cargo'),
              connection: connection,
              label: 'Груз',
              formatter: (snapshot) {
                return _jobText(snapshot?.job?.cargoName);
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ====================================
        // ROUTE
        // ====================================
        _JobSection(
          title: 'Маршрут',
          icon: Icons.route_outlined,
          children: [
            _JobValueRow(
              key: const ValueKey('job-source'),
              connection: connection,
              label: 'Откуда',
              formatter: (snapshot) {
                return _jobText(snapshot?.job?.sourceCity);
              },
            ),

            _JobValueRow(
              key: const ValueKey('job-destination'),
              connection: connection,
              label: 'Куда',
              formatter: (snapshot) {
                return _jobText(snapshot?.job?.destinationCity);
              },
            ),

            _JobValueRow(
              key: const ValueKey('job-route'),
              connection: connection,
              label: 'Направление',
              formatter: (snapshot) {
                return _formatJobRoute(snapshot?.job);
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ====================================
        // PROGRESS
        // ====================================
        _JobSection(
          title: 'Выполнение заказа',
          icon: Icons.flag_outlined,
          children: [
            _JobValueRow(
              key: const ValueKey('job-remaining'),
              connection: connection,
              label: 'Осталось проехать',
              formatter: (snapshot) {
                final distance = snapshot?.job?.remainingDistanceKm;

                if (distance == null) {
                  return 'Нет данных';
                }

                return TelemetryFormat.distance(distance);
              },
            ),

            _JobValueRow(
              key: const ValueKey('job-reward'),
              connection: connection,
              label: 'Вознаграждение',
              formatter: (snapshot) {
                return _formatJobReward(snapshot?.job);
              },
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ====================================
        // INFORMATION NOTE
        // ====================================
        Card(
          color: theme.colorScheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: theme.colorScheme.primary,
                ),

                const SizedBox(width: 12),

                const Expanded(
                  child: Text(
                    'Информация о заказе зависит '
                    'от данных, передаваемых Windows Hub. '
                    'Некоторые поля пока могут быть '
                    'недоступны. Мы подключим их '
                    'на следующем этапе разработки '
                    'телеметрии заказов.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================
// JOB FORMATTING
// ============================================

String _jobText(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Нет данных';
  }

  return value.trim();
}

// ============================================
// ROUTE FORMATTING
// ============================================

String _formatJobRoute(TruckJob? job) {
  if (job == null) {
    return 'Нет данных';
  }

  final source = job.sourceCity?.trim();
  final destination = job.destinationCity?.trim();

  final hasSource = source != null && source.isNotEmpty;

  final hasDestination = destination != null && destination.isNotEmpty;

  if (!hasSource && !hasDestination) {
    return 'Нет данных';
  }

  if (!hasSource) {
    return destination!;
  }

  if (!hasDestination) {
    return source!;
  }

  return '$source → $destination';
}

// ============================================
// REWARD FORMATTING
// ============================================

String _formatJobReward(TruckJob? job) {
  if (job == null || job.reward == null) {
    return 'Нет данных';
  }

  final rawValue = job.reward.toString();

  final numericValue = num.tryParse(rawValue);

  // Numeric rewards use the shared formatter.
  if (numericValue != null) {
    return TelemetryFormat.integer(numericValue);
  }

  // Keep non-numeric values unchanged:
  // they may contain currency information.
  return rawValue;
}

// ============================================
// JOB SECTION
// ============================================

class _JobSection extends StatelessWidget {
  const _JobSection({
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
// JOB TELEMETRY ROW
// ============================================

typedef _JobValueFormatter = String Function(TruckSnapshot? snapshot);

class _JobValueRow extends StatefulWidget {
  const _JobValueRow({
    super.key,
    required this.connection,
    required this.label,
    required this.formatter,
  });

  final TelemetryConnection connection;
  final String label;
  final _JobValueFormatter formatter;

  @override
  State<_JobValueRow> createState() => _JobValueRowState();
}

class _JobValueRowState extends State<_JobValueRow> {
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
  // READ CURRENT VALUE
  // ==========================================

  String _readValue() {
    return widget.formatter(widget.connection.snapshot);
  }

  // ==========================================
  // UPDATE CONNECTION
  // ==========================================

  @override
  void didUpdateWidget(covariant _JobValueRow oldWidget) {
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

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(widget.label, style: theme.textTheme.bodyMedium),
            ),

            const SizedBox(width: 12),

            Flexible(
              child: Text(
                _value,
                textAlign: TextAlign.right,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
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
