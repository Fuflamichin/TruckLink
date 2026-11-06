import 'package:flutter/material.dart';
import 'package:telemetry_core/telemetry_core.dart';

import '../../core/network/telemetry_connection.dart';

// ============================================
// AVAILABLE HOME METRICS
// ============================================

enum HomeMetric {
  speed,
  speedLimit,
  rpm,
  gear,
  fuelPercent,
  fuelLiters,
  engineOn,
  temperature,
  engineWear,
  odometer,
  cruiseControl,
  parkBrake,
  cargo,
  route,
  jobReward,
  remainingDistance,
  balance,
}

// ============================================
// METRIC PRESENTATION
// ============================================

extension HomeMetricInfo on HomeMetric {
  String get title => switch (this) {
    HomeMetric.speed => 'Скорость',
    HomeMetric.speedLimit => 'Ограничение',
    HomeMetric.rpm => 'Обороты',
    HomeMetric.gear => 'Передача',
    HomeMetric.fuelPercent => 'Топливо',
    HomeMetric.fuelLiters => 'Топливо в баке',
    HomeMetric.engineOn => 'Двигатель',
    HomeMetric.temperature => 'Температура',
    HomeMetric.engineWear => 'Износ двигателя',
    HomeMetric.odometer => 'Пробег',
    HomeMetric.cruiseControl => 'Круиз-контроль',
    HomeMetric.parkBrake => 'Стояночный тормоз',
    HomeMetric.cargo => 'Текущий груз',
    HomeMetric.route => 'Маршрут заказа',
    HomeMetric.jobReward => 'Оплата заказа',
    HomeMetric.remainingDistance => 'До пункта назначения',
    HomeMetric.balance => 'Баланс',
  };

  IconData get icon => switch (this) {
    HomeMetric.speed => Icons.speed,
    HomeMetric.speedLimit => Icons.signpost_outlined,
    HomeMetric.rpm => Icons.autorenew,
    HomeMetric.gear => Icons.settings_outlined,
    HomeMetric.fuelPercent => Icons.local_gas_station,
    HomeMetric.fuelLiters => Icons.local_gas_station_outlined,
    HomeMetric.engineOn => Icons.power_settings_new,
    HomeMetric.temperature => Icons.thermostat,
    HomeMetric.engineWear => Icons.build_circle_outlined,
    HomeMetric.odometer => Icons.route,
    HomeMetric.cruiseControl => Icons.speed,
    HomeMetric.parkBrake => Icons.local_parking_outlined,
    HomeMetric.cargo => Icons.inventory_2_outlined,
    HomeMetric.route => Icons.alt_route,
    HomeMetric.jobReward => Icons.payments_outlined,
    HomeMetric.remainingDistance => Icons.route_outlined,
    HomeMetric.balance => Icons.account_balance_wallet_outlined,
  };

  String get category => switch (this) {
    HomeMetric.speed ||
    HomeMetric.speedLimit ||
    HomeMetric.rpm ||
    HomeMetric.gear ||
    HomeMetric.cruiseControl => 'Приборы',

    HomeMetric.fuelPercent ||
    HomeMetric.fuelLiters ||
    HomeMetric.engineOn ||
    HomeMetric.temperature ||
    HomeMetric.engineWear ||
    HomeMetric.odometer ||
    HomeMetric.parkBrake => 'Грузовик',

    HomeMetric.cargo ||
    HomeMetric.route ||
    HomeMetric.jobReward ||
    HomeMetric.remainingDistance => 'Заказ',

    HomeMetric.balance => 'Финансы',
  };

  String formatValue(TruckSnapshot? snapshot) {
    if (snapshot == null) return '—';

    final job = snapshot.job;

    return switch (this) {
      HomeMetric.speed => '${snapshot.speedKmh.abs().toStringAsFixed(1)} км/ч',

      HomeMetric.speedLimit =>
        snapshot.speedLimitKmh == null || snapshot.speedLimitKmh! <= 0
            ? '—'
            : '${snapshot.speedLimitKmh!.toStringAsFixed(0)} км/ч',

      HomeMetric.rpm => '${snapshot.rpm.toStringAsFixed(0)} RPM',

      HomeMetric.gear =>
        snapshot.gear == 0
            ? 'N'
            : snapshot.gear < 0
            ? 'R${snapshot.gear.abs()}'
            : snapshot.gear.toString(),

      HomeMetric.fuelPercent =>
        snapshot.fuelCapacityLiters <= 0
            ? '—'
            : '${snapshot.fuelPercent.toStringAsFixed(0)}%',

      HomeMetric.fuelLiters => '${snapshot.fuelLiters.toStringAsFixed(1)} л',

      HomeMetric.engineOn => snapshot.engineOn ? 'Включён' : 'Выключен',

      HomeMetric.temperature =>
        snapshot.waterTemperatureC == null
            ? '—'
            : '${snapshot.waterTemperatureC!.toStringAsFixed(0)} °C',

      HomeMetric.engineWear =>
        snapshot.engineWearPercent == null
            ? '—'
            : '${snapshot.engineWearPercent!.toStringAsFixed(1)}%',

      HomeMetric.odometer =>
        snapshot.odometerKm == null
            ? '—'
            : '${snapshot.odometerKm!.toStringAsFixed(1)} км',

      HomeMetric.cruiseControl =>
        snapshot.cruiseControlKmh == null
            ? '—'
            : snapshot.cruiseControlKmh! <= 0
            ? 'Выключен'
            : '${snapshot.cruiseControlKmh!.toStringAsFixed(0)} км/ч',

      HomeMetric.parkBrake =>
        snapshot.parkBrake == null
            ? '—'
            : snapshot.parkBrake!
            ? 'Активен'
            : 'Выключен',

      HomeMetric.cargo => job?.cargoName ?? 'Нет данных',

      HomeMetric.route => _formatRoute(job),

      HomeMetric.jobReward =>
        job?.reward == null ? 'Нет данных' : '${job!.reward}',

      HomeMetric.remainingDistance =>
        job?.remainingDistanceKm == null
            ? 'Нет данных'
            : '${job!.remainingDistanceKm!.toStringAsFixed(1)} км',

      // Financial telemetry is not yet connected.
      HomeMetric.balance => 'Нет данных',
    };
  }
}

String _formatRoute(TruckJob? job) {
  if (job == null) return 'Нет данных';

  final source = job.sourceCity;
  final destination = job.destinationCity;

  if (source == null && destination == null) {
    return 'Нет данных';
  }

  if (source == null) return destination!;
  if (destination == null) return source;

  return '$source → $destination';
}

// ============================================
// HOME LAYOUT CONFIGURATION
// ============================================

class _HomeLayout {
  _HomeLayout({
    required List<HomeMetric> order,
    required Set<HomeMetric> visible,
  }) : order = List<HomeMetric>.of(order),
       visible = Set<HomeMetric>.of(visible);

  final List<HomeMetric> order;
  final Set<HomeMetric> visible;
}

// ============================================
// HOME SCREEN
// ============================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.connection});

  final TelemetryConnection connection;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<HomeMetric> _order = List<HomeMetric>.of(HomeMetric.values);

  final Set<HomeMetric> _visible = {
    HomeMetric.speed,
    HomeMetric.speedLimit,
    HomeMetric.cargo,
    HomeMetric.balance,
  };

  List<HomeMetric> get _visibleMetrics {
    return _order.where(_visible.contains).toList(growable: false);
  }

  // ==========================================
  // OPEN CUSTOMIZATION
  // ==========================================

  Future<void> _customize() async {
    final result = await Navigator.of(context).push<_HomeLayout>(
      MaterialPageRoute<_HomeLayout>(
        builder: (_) => _CustomizeHomeScreen(
          initialLayout: _HomeLayout(order: _order, visible: _visible),
        ),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _order
        ..clear()
        ..addAll(result.order);

      _visible
        ..clear()
        ..addAll(result.visible);
    });
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final metrics = _visibleMetrics;

    return CustomScrollView(
      key: const PageStorageKey<String>('trucklink-home'),
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Мой TruckLink',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),

                const SizedBox(height: 6),

                Text(
                  'Персональная панель телеметрии',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

                const SizedBox(height: 18),

                OutlinedButton.icon(
                  onPressed: _customize,
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: const Text('Настроить главную'),
                ),
              ],
            ),
          ),
        ),

        if (metrics.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.dashboard_outlined, size: 44),
                      SizedBox(height: 12),
                      Text(
                        'Нет выбранных карточек',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Нажми «Настроить главную», '
                        'чтобы добавить показатели.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.crossAxisExtent < 280 ? 1 : 2;

                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 158,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final metric = metrics[index];

                      return _HomeMetricCard(
                        key: ValueKey(metric),
                        metric: metric,
                        connection: widget.connection,
                      );
                    },
                    childCount: metrics.length,
                    findChildIndexCallback: (key) {
                      if (key is ValueKey<HomeMetric>) {
                        final index = metrics.indexOf(key.value);

                        return index < 0 ? null : index;
                      }

                      return null;
                    },
                  ),
                );
              },
            ),
          ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          sliver: SliverToBoxAdapter(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),

                    const SizedBox(width: 12),

                    const Expanded(
                      child: Text(
                        'Карточки используют доступные '
                        'данные ETS2/ATS. Для заказов '
                        'и финансов некоторые показатели '
                        'пока могут быть недоступны.',
                      ),
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
// OPTIMIZED HOME METRIC CARD
// ============================================

class _HomeMetricCard extends StatefulWidget {
  const _HomeMetricCard({
    super.key,
    required this.metric,
    required this.connection,
  });

  final HomeMetric metric;
  final TelemetryConnection connection;

  @override
  State<_HomeMetricCard> createState() => _HomeMetricCardState();
}

class _HomeMetricCardState extends State<_HomeMetricCard> {
  late String _value;

  @override
  void initState() {
    super.initState();

    _value = _readValue();

    widget.connection.addListener(_onUpdate);
  }

  String _readValue() {
    return widget.metric.formatValue(widget.connection.snapshot);
  }

  @override
  void didUpdateWidget(covariant _HomeMetricCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onUpdate);
      widget.connection.addListener(_onUpdate);
    }

    _value = _readValue();
  }

  void _onUpdate() {
    if (!mounted) return;

    final nextValue = _readValue();

    if (nextValue == _value) return;

    setState(() {
      _value = nextValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.metric.icon, size: 23, color: scheme.primary),

                  const Spacer(),

                  Flexible(
                    child: Text(
                      widget.metric.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                widget.metric.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),

              const Spacer(),

              Text(
                _value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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

// ============================================
// HOME CUSTOMIZATION SCREEN
// ============================================

class _CustomizeHomeScreen extends StatefulWidget {
  const _CustomizeHomeScreen({required this.initialLayout});

  final _HomeLayout initialLayout;

  @override
  State<_CustomizeHomeScreen> createState() => _CustomizeHomeScreenState();
}

class _CustomizeHomeScreenState extends State<_CustomizeHomeScreen> {
  late List<HomeMetric> _order;
  late Set<HomeMetric> _visible;

  @override
  void initState() {
    super.initState();

    _order = List<HomeMetric>.of(widget.initialLayout.order);

    _visible = Set<HomeMetric>.of(widget.initialLayout.visible);
  }

  // ==========================================
  // REORDER
  // ==========================================

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex--;
      }

      final item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
    });
  }

  // ==========================================
  // TOGGLE
  // ==========================================

  void _toggle(HomeMetric metric, bool enabled) {
    setState(() {
      if (enabled) {
        _visible.add(metric);
      } else {
        _visible.remove(metric);
      }
    });
  }

  // ==========================================
  // SAVE
  // ==========================================

  void _save() {
    Navigator.of(context).pop(_HomeLayout(order: _order, visible: _visible));
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Главная панель'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Готово')),
          const SizedBox(width: 8),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Выбери показатели',
                  style: Theme.of(context).textTheme.titleLarge,
                ),

                const SizedBox(height: 8),

                Text(
                  'Включай нужные карточки и '
                  'перетаскивай их за значок справа, '
                  'чтобы изменить порядок на главной.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  'Выбрано: ${_visible.length} '
                  'из ${_order.length}',
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _order.length,
              onReorder: _reorder,

              itemBuilder: (context, index) {
                final metric = _order[index];
                final enabled = _visible.contains(metric);

                return Card(
                  key: ValueKey(metric),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),

                        Icon(
                          metric.icon,
                          color: enabled
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                metric.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),

                              const SizedBox(height: 3),

                              Text(
                                metric.category,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),

                        Switch.adaptive(
                          value: enabled,
                          onChanged: (value) {
                            _toggle(metric, value);
                          },
                        ),

                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.drag_handle),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Применить изменения'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
