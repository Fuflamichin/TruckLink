import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:telemetry_core/telemetry_core.dart';

import '../../core/network/telemetry_connection.dart';
import 'data/home_layout_storage.dart';

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
// NUMBER FORMATTING
// ============================================

/// Displays whole numbers without decimals.
String _wholeNumber(double? value, {String unit = ''}) {
  if (value == null || !value.isFinite) {
    return '—';
  }

  return '${value.round()}$unit';
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

  // ==========================================
  // LIVE TELEMETRY VALUES
  // ==========================================

  String formatValue(TruckSnapshot? snapshot) {
    // Finance integration is not available yet.
    if (this == HomeMetric.balance) {
      return 'Нет данных';
    }

    if (snapshot == null) {
      return '—';
    }

    final job = snapshot.job;

    return switch (this) {
      HomeMetric.speed => _wholeNumber(snapshot.speedKmh.abs(), unit: ' км/ч'),

      HomeMetric.speedLimit =>
        snapshot.speedLimitKmh == null || snapshot.speedLimitKmh! <= 0
            ? '—'
            : _wholeNumber(snapshot.speedLimitKmh, unit: ' км/ч'),

      HomeMetric.rpm => _wholeNumber(snapshot.rpm, unit: ' RPM'),

      HomeMetric.gear =>
        snapshot.gear == 0
            ? 'N'
            : snapshot.gear < 0
            ? 'R${snapshot.gear.abs()}'
            : snapshot.gear.toString(),

      HomeMetric.fuelPercent =>
        snapshot.fuelCapacityLiters <= 0
            ? '—'
            : _wholeNumber(snapshot.fuelPercent, unit: '%'),

      HomeMetric.fuelLiters => _wholeNumber(snapshot.fuelLiters, unit: ' л'),

      HomeMetric.engineOn => snapshot.engineOn ? 'Включён' : 'Выключен',

      HomeMetric.temperature => _wholeNumber(
        snapshot.waterTemperatureC,
        unit: ' °C',
      ),

      HomeMetric.engineWear => _wholeNumber(
        snapshot.engineWearPercent,
        unit: '%',
      ),

      HomeMetric.odometer => _wholeNumber(snapshot.odometerKm, unit: ' км'),

      HomeMetric.cruiseControl =>
        snapshot.cruiseControlKmh == null
            ? '—'
            : snapshot.cruiseControlKmh! <= 0
            ? 'Выключен'
            : _wholeNumber(snapshot.cruiseControlKmh, unit: ' км/ч'),

      HomeMetric.parkBrake =>
        snapshot.parkBrake == null
            ? '—'
            : snapshot.parkBrake!
            ? 'Активен'
            : 'Выключен',

      HomeMetric.cargo => job?.cargoName ?? 'Нет данных',

      HomeMetric.route => _formatRoute(job),

      HomeMetric.jobReward =>
        job?.reward == null ? 'Нет данных' : job!.reward.toString(),

      HomeMetric.remainingDistance =>
        job?.remainingDistanceKm == null
            ? 'Нет данных'
            : _wholeNumber(job!.remainingDistanceKm, unit: ' км'),

      HomeMetric.balance => 'Нет данных',
    };
  }
}

// ============================================
// HOME SCREEN
// ============================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.connection,
    required this.editMode,
  });

  final TelemetryConnection connection;
  final ValueListenable<bool> editMode;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Shared storage instance keeps write ordering
  // consistent even if this screen is recreated.
  static final HomeLayoutStorage _storage = HomeLayoutStorage();

  // Default cards used on the first launch.
  static const List<HomeMetric> _defaultMetrics = [
    HomeMetric.speed,
    HomeMetric.speedLimit,
    HomeMetric.cargo,
    HomeMetric.balance,
  ];

  final List<HomeMetric> _metrics = List<HomeMetric>.of(_defaultMetrics);

  bool _layoutLoaded = false;
  bool _saveWarningShown = false;

  @override
  void initState() {
    super.initState();

    // Load saved layout without blocking the
    // Flutter application startup.
    unawaited(_loadSavedLayout());
  }

  // ==========================================
  // LOAD SAVED LAYOUT
  // ==========================================

  Future<void> _loadSavedLayout() async {
    try {
      final savedIds = await _storage.loadMetricIds();

      if (!mounted) return;

      // null means first launch: keep defaults.
      if (savedIds == null) {
        setState(() {
          _layoutLoaded = true;
        });
        return;
      }

      // Map stored names to available enum values.
      //
      // Unknown identifiers are ignored so future
      // changes to telemetry do not crash the app.
      final metricById = {
        for (final metric in HomeMetric.values) metric.name: metric,
      };

      final restored = <HomeMetric>[];
      final seen = <HomeMetric>{};

      for (final id in savedIds) {
        final metric = metricById[id];

        if (metric == null) continue;

        if (seen.add(metric)) {
          restored.add(metric);
        }
      }

      // An empty saved list is valid:
      // the user intentionally removed everything.
      //
      // If the saved list contains only unknown IDs,
      // keep the defaults rather than showing
      // an unexpectedly empty dashboard.
      final useRestored = savedIds.isEmpty || restored.isNotEmpty;

      setState(() {
        if (useRestored) {
          _metrics
            ..clear()
            ..addAll(restored);
        }

        _layoutLoaded = true;
      });
    } catch (error) {
      debugPrint('TruckLink: unable to load home layout: $error');

      if (!mounted) return;

      // Keep the default layout when local
      // preferences cannot be read.
      setState(() {
        _layoutLoaded = true;
      });

      _showStorageWarning('Не удалось загрузить настройки главной.');
    }
  }

  // ==========================================
  // SAVE CURRENT LAYOUT
  // ==========================================

  void _saveLayout() {
    if (!_layoutLoaded) return;

    // Save identifiers, not enum indexes.
    //
    // Adding new enum values later will not
    // invalidate existing saved layouts.
    final ids = _metrics.map((metric) => metric.name).toList(growable: false);

    unawaited(
      _storage
          .saveMetricIds(ids)
          .then<void>(
            (_) {
              _saveWarningShown = false;
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint(
                'TruckLink: unable to save home layout: '
                '$error',
              );

              if (!mounted || _saveWarningShown) {
                return;
              }

              _saveWarningShown = true;

              _showStorageWarning(
                'Не удалось сохранить расположение '
                'карточек.',
              );
            },
          ),
    );
  }

  void _showStorageWarning(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);

    messenger?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  // ==========================================
  // REMOVE METRIC
  // ==========================================

  void _removeMetric(HomeMetric metric) {
    if (!_layoutLoaded) return;

    if (!_metrics.contains(metric)) return;

    setState(() {
      _metrics.remove(metric);
    });

    _saveLayout();
  }

  // ==========================================
  // MOVE METRIC
  // ==========================================

  void _moveMetric(HomeMetric source, HomeMetric destination) {
    if (!_layoutLoaded) return;
    if (source == destination) return;

    final sourceIndex = _metrics.indexOf(source);
    final destinationIndex = _metrics.indexOf(destination);

    if (sourceIndex < 0 || destinationIndex < 0) {
      return;
    }

    setState(() {
      final item = _metrics.removeAt(sourceIndex);
      _metrics.insert(destinationIndex, item);
    });

    _saveLayout();
  }

  // ==========================================
  // ADD METRICS BOTTOM SHEET
  // ==========================================

  Future<void> _showAddMetrics() async {
    if (!_layoutLoaded) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final available = HomeMetric.values
                .where((metric) => !_metrics.contains(metric))
                .toList(growable: false);

            return SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.72,
              child: Column(
                children: [
                  // ==========================
                  // SHEET HEADER
                  // ==========================
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Добавить показатели',
                                style: Theme.of(
                                  sheetContext,
                                ).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Выбери нужные карточки '
                                'для главной панели',
                                style: Theme.of(
                                  sheetContext,
                                ).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Закрыть',
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // ==========================
                  // AVAILABLE METRICS
                  // ==========================
                  Expanded(
                    child: available.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 52,
                                    color: Theme.of(
                                      sheetContext,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Все показатели добавлены',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            itemCount: available.length,
                            itemBuilder: (context, index) {
                              final metric = available[index];

                              return Card(
                                key: ValueKey(metric),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 5,
                                  ),
                                  leading: Icon(
                                    metric.icon,
                                    color: Theme.of(
                                      sheetContext,
                                    ).colorScheme.primary,
                                  ),
                                  title: Text(metric.title),
                                  subtitle: Text(metric.category),
                                  trailing: const Icon(
                                    Icons.add_circle_outline,
                                  ),
                                  onTap: () {
                                    if (!mounted) return;

                                    if (!_metrics.contains(metric)) {
                                      setState(() {
                                        _metrics.add(metric);
                                      });

                                      _saveLayout();
                                    }

                                    // Keep the sheet open
                                    // to add several metrics.
                                    setSheetState(() {});
                                  },
                                ),
                              );
                            },
                          ),
                  ),

                  // ==========================
                  // FINISH ADDING
                  // ==========================
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                          },
                          child: const Text('Готово'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    // Wait for preferences before allowing edits.
    // Otherwise an asynchronous load could replace
    // the user's newly made changes.
    if (!_layoutLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return ValueListenableBuilder<bool>(
      valueListenable: widget.editMode,
      builder: (context, isEditing, child) {
        final metrics = List<HomeMetric>.of(_metrics);

        return Column(
          children: [
            Expanded(
              child: CustomScrollView(
                key: const PageStorageKey<String>('trucklink-home'),
                physics: const ClampingScrollPhysics(),
                slivers: [
                  // ============================
                  // PAGE DESCRIPTION
                  // ============================
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Редактирование' : 'Мой TruckLink',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            isEditing
                                ? 'Удерживай карточку и '
                                      'перетащи на место другой. '
                                      'Нажми крестик, чтобы убрать её.'
                                : 'Персональная панель '
                                      'телеметрии',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ============================
                  // EMPTY HOME
                  // ============================
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
                                  'Добавь показатели, '
                                  'чтобы они появились '
                                  'на главной странице.',
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
                          final columns = constraints.crossAxisExtent < 280
                              ? 1
                              : 2;

                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisExtent: 158,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final metric = metrics[index];

                                return _HomeGridItem(
                                  key: ValueKey(metric),
                                  metric: metric,
                                  connection: widget.connection,
                                  isEditing: isEditing,
                                  onRemove: () {
                                    _removeMetric(metric);
                                  },
                                  onMove: _moveMetric,
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

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),

            // ================================
            // EDIT MODE BOTTOM ACTION
            // ================================
            if (isEditing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _showAddMetrics,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Добавить показатели'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ============================================
// GRID ITEM / DRAG & DROP
// ============================================

class _HomeGridItem extends StatelessWidget {
  const _HomeGridItem({
    super.key,
    required this.metric,
    required this.connection,
    required this.isEditing,
    required this.onRemove,
    required this.onMove,
  });

  final HomeMetric metric;
  final TelemetryConnection connection;
  final bool isEditing;
  final VoidCallback onRemove;

  final void Function(HomeMetric source, HomeMetric destination) onMove;

  @override
  Widget build(BuildContext context) {
    if (!isEditing) {
      return _HomeMetricCard(
        metric: metric,
        connection: connection,
        isEditing: false,
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return DragTarget<HomeMetric>(
          onWillAcceptWithDetails: (details) {
            return details.data != metric;
          },

          onAcceptWithDetails: (details) {
            onMove(details.data, metric);
          },

          builder: (context, candidateData, rejectedData) {
            final highlighted = candidateData.isNotEmpty;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  width: highlighted ? 2 : 0,
                  color: highlighted ? scheme.primary : Colors.transparent,
                ),
              ),
              child: LongPressDraggable<HomeMetric>(
                data: metric,
                maxSimultaneousDrags: 1,

                feedback: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: 158,
                    child: _DraggingPreview(
                      metric: metric,
                      value: metric.formatValue(connection.snapshot),
                    ),
                  ),
                ),

                childWhenDragging: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Icon(
                    Icons.open_with_rounded,
                    color: scheme.primary,
                    size: 32,
                  ),
                ),

                child: _HomeMetricCard(
                  metric: metric,
                  connection: connection,
                  isEditing: true,
                  onRemove: onRemove,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================
// DRAGGING PREVIEW
// ============================================

class _DraggingPreview extends StatelessWidget {
  const _DraggingPreview({required this.metric, required this.value});

  final HomeMetric metric;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 10,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.primary, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(metric.icon, color: scheme.primary),
            const SizedBox(height: 12),
            Text(metric.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// LIVE TELEMETRY CARD
// ============================================

class _HomeMetricCard extends StatefulWidget {
  const _HomeMetricCard({
    required this.metric,
    required this.connection,
    required this.isEditing,
    this.onRemove,
  });

  final HomeMetric metric;
  final TelemetryConnection connection;
  final bool isEditing;
  final VoidCallback? onRemove;

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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

                  if (widget.isEditing)
                    IconButton(
                      tooltip: 'Убрать показатель',
                      onPressed: widget.onRemove,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      icon: Icon(
                        Icons.close_rounded,
                        color: scheme.error,
                        size: 23,
                      ),
                    )
                  else
                    Flexible(
                      child: Text(
                        widget.metric.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                widget.metric.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium,
              ),

              const Spacer(),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      _value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  if (widget.isEditing)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: scheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
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
    widget.connection.removeListener(_onUpdate);
    super.dispose();
  }
}
