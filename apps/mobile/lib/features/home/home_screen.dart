import 'package:flutter/material.dart';
import 'package:telemetry_core/telemetry_core.dart';

import '../../core/network/telemetry_connection.dart';

// ============================================
// HOME SCREEN
// ============================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.connection});

  final TelemetryConnection connection;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const PageStorageKey<String>('trucklink-home'),
      physics: const ClampingScrollPhysics(),
      slivers: [
        // Header
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Мой TruckLink',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),

                const SizedBox(height: 6),

                const Text(
                  'Основные показатели и информация '
                  'о текущей поездке',
                ),
              ],
            ),
          ),
        ),

        // Live metric cards
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.crossAxisExtent < 280 ? 1 : 2;

              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 154,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _HomeMetricCard(
                    key: ValueKey(index),
                    connection: connection,
                    index: index,
                  ),
                  childCount: 4,
                ),
              );
            },
          ),
        ),

        // Customization placeholder
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          sliver: SliverToBoxAdapter(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Персональная панель',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Здесь можно будет выбирать '
                      'карточки из любых разделов, '
                      'изменять их порядок и размер.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================
// HOME METRIC DATA
// ============================================

const _metricTitles = ['Скорость', 'Ограничение', 'Текущий заказ', 'Баланс'];

const _metricIcons = <IconData>[
  Icons.speed,
  Icons.signpost_outlined,
  Icons.inventory_2_outlined,
  Icons.account_balance_wallet_outlined,
];

String _metricValue(int index, TruckSnapshot? snapshot) {
  return switch (index) {
    0 =>
      snapshot == null
          ? '—'
          : '${snapshot.speedKmh.abs().toStringAsFixed(1)} км/ч',

    1 =>
      snapshot?.speedLimitKmh == null
          ? '—'
          : '${snapshot!.speedLimitKmh!.toStringAsFixed(0)} км/ч',

    2 => snapshot?.job?.cargoName ?? 'Нет данных',

    3 => 'Нет данных',

    _ => '—',
  };
}

// ============================================
// HOME METRIC CARD
// ============================================

class _HomeMetricCard extends StatefulWidget {
  const _HomeMetricCard({
    super.key,
    required this.connection,
    required this.index,
  });

  final TelemetryConnection connection;
  final int index;

  @override
  State<_HomeMetricCard> createState() => _HomeMetricCardState();
}

class _HomeMetricCardState extends State<_HomeMetricCard> {
  late String _value;

  @override
  void initState() {
    super.initState();

    _value = _currentValue();

    widget.connection.addListener(_onUpdate);
  }

  String _currentValue() {
    return _metricValue(widget.index, widget.connection.snapshot);
  }

  @override
  void didUpdateWidget(covariant _HomeMetricCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onUpdate);
      widget.connection.addListener(_onUpdate);
    }

    _value = _currentValue();
  }

  void _onUpdate() {
    if (!mounted) return;

    final nextValue = _currentValue();

    if (nextValue == _value) return;

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
                _metricIcons[widget.index],
                color: Theme.of(context).colorScheme.primary,
              ),

              const SizedBox(height: 12),

              Text(
                _metricTitles[widget.index],
                style: Theme.of(context).textTheme.labelMedium,
              ),

              const Spacer(),

              Text(
                _value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.connection.removeListener(_onUpdate);
    super.dispose();
  }
}
