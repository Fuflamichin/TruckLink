import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:telemetry_core/telemetry_core.dart';
import 'package:telemetry_core/job_telemetry.dart';

import '../../core/formatting/telemetry_format.dart';
import '../../core/network/telemetry_connection.dart';
import 'data/home_layout_storage.dart';

// ============================================
// HOME METRICS
// ============================================

// IMPORTANT:
// These identifiers are saved in shared_preferences.
// Do not rename them, or users may lose their layout.
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
// JOB FORMATTING
// ============================================

String _formatRoute(TruckLinkJobTelemetry? job) {
  if (job == null) {
    return 'Нет данных';
  }

  final source = job.sourceCity.trim();
  final destination = job.destinationCity.trim();

  if (source.isEmpty && destination.isEmpty) {
    return 'Нет данных';
  }

  if (source.isEmpty) {
    return destination;
  }

  if (destination.isEmpty) {
    return source;
  }

  return '$source → $destination';
}

String _formatReward(TruckLinkJobTelemetry? job) {
  if (job == null) {
    return 'Нет данных';
  }

  return TelemetryFormat.integer(job.income);
}

// ============================================
// METRIC INFORMATION
// ============================================

extension HomeMetricInfo on HomeMetric {
  // ==========================================
  // TITLE
  // ==========================================

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

  // ==========================================
  // ICON
  // ==========================================

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

  // ==========================================
  // CATEGORY
  // ==========================================

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
  // FORMAT METRIC VALUE
  // ==========================================

  String formatValue(
    TruckSnapshot? snapshot, {
    TruckLinkJobTelemetry? activeJob,
  }) {
    // ========================================
    // REAL JOB DATA - v0.7.3
    // ========================================

    // Job data is received via "job_update".
    //
    // It is stored in connection.activeJob,
    // NOT in snapshot.job.
    //
    // Therefore job metrics must be handled
    // before checking whether snapshot is null.

    // Current cargo.
    if (this == HomeMetric.cargo) {
      final cargo = activeJob?.cargoName.trim() ?? '';

      return cargo.isEmpty ? 'Нет данных' : cargo;
    }

    // Source city -> destination city.
    if (this == HomeMetric.route) {
      return _formatRoute(activeJob);
    }

    // Actual job reward.
    if (this == HomeMetric.jobReward) {
      return _formatReward(activeJob);
    }

    // Remaining route distance.
    if (this == HomeMetric.remainingDistance) {
      final remaining = activeJob?.navigationDistanceKm;

      if (remaining == null || !remaining.isFinite || remaining <= 0) {
        return 'Нет данных';
      }

      return TelemetryFormat.distance(remaining);
    }

    // Balance will be added in the
    // financial telemetry update.
    if (this == HomeMetric.balance) {
      return 'Нет данных';
    }

    // ========================================
    // EXISTING TRUCK TELEMETRY
    // ========================================

    if (snapshot == null) {
      return TelemetryFormat.unavailable;
    }

    return switch (this) {
      HomeMetric.speed => TelemetryFormat.speed(snapshot.speedKmh),

      HomeMetric.speedLimit => TelemetryFormat.speedLimit(
        snapshot.speedLimitKmh,
      ),

      HomeMetric.rpm => TelemetryFormat.rpm(snapshot.rpm),

      HomeMetric.gear => TelemetryFormat.gear(snapshot.gear),

      HomeMetric.fuelPercent =>
        snapshot.fuelCapacityLiters <= 0
            ? TelemetryFormat.unavailable
            : TelemetryFormat.percent(snapshot.fuelPercent),

      HomeMetric.fuelLiters => TelemetryFormat.liters(snapshot.fuelLiters),

      HomeMetric.engineOn => TelemetryFormat.onOff(snapshot.engineOn),

      HomeMetric.temperature => TelemetryFormat.temperature(
        snapshot.waterTemperatureC,
      ),

      HomeMetric.engineWear => TelemetryFormat.percent(
        snapshot.engineWearPercent,
      ),

      HomeMetric.odometer => TelemetryFormat.distance(snapshot.odometerKm),

      HomeMetric.cruiseControl => TelemetryFormat.cruiseControl(
        snapshot.cruiseControlKmh,
      ),

      HomeMetric.parkBrake => TelemetryFormat.onOff(
        snapshot.parkBrake,
        enabled: 'Активен',
      ),

      // Already handled above.
      HomeMetric.cargo ||
      HomeMetric.route ||
      HomeMetric.jobReward ||
      HomeMetric.remainingDistance ||
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
  // ==========================================
  // LAYOUT STORAGE
  // ==========================================

  static final HomeLayoutStorage _storage = HomeLayoutStorage();

  static const List<HomeMetric> _defaultMetrics = [
    HomeMetric.speed,
    HomeMetric.speedLimit,
    HomeMetric.cargo,
    HomeMetric.balance,
  ];

  final List<HomeMetric> _metrics = List<HomeMetric>.of(_defaultMetrics);

  bool _layoutLoaded = false;
  bool _saveWarningShown = false;

  // ==========================================
  // INITIALIZATION
  // ==========================================

  @override
  void initState() {
    super.initState();

    unawaited(_loadSavedLayout());
  }

  // ==========================================
  // LOAD SAVED LAYOUT
  // ==========================================

  Future<void> _loadSavedLayout() async {
    try {
      final savedIds = await _storage.loadMetricIds();

      if (!mounted) return;

      if (savedIds == null) {
        setState(() {
          _layoutLoaded = true;
        });

        return;
      }

      final metricById = {
        for (final metric in HomeMetric.values) metric.name: metric,
      };

      final restored = <HomeMetric>[];
      final seen = <HomeMetric>{};

      for (final id in savedIds) {
        final metric = metricById[id];

        if (metric != null && seen.add(metric)) {
          restored.add(metric);
        }
      }

      // An empty list means the user removed
      // all cards intentionally.
      //
      // A list containing only unknown IDs
      // falls back to the default layout.
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
      debugPrint(
        'TruckLink: unable to load home layout: '
        '$error',
      );

      if (!mounted) return;

      setState(() {
        _layoutLoaded = true;
      });

      _showStorageWarning('Не удалось загрузить настройки главной.');
    }
  }

  // ==========================================
  // SAVE LAYOUT
  // ==========================================

  void _saveLayout() {
    if (!_layoutLoaded) return;

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
                'TruckLink: unable to save home '
                'layout: $error',
              );

              if (!mounted || _saveWarningShown) {
                return;
              }

              _saveWarningShown = true;

              _showStorageWarning(
                'Не удалось сохранить '
                'расположение карточек.',
              );
            },
          ),
    );
  }

  // ==========================================
  // STORAGE WARNING
  // ==========================================

  void _showStorageWarning(String message) {
    if (!mounted) return;

    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  // ==========================================
  // REMOVE CARD
  // ==========================================

  void _removeMetric(HomeMetric metric) {
    if (!_layoutLoaded || !_metrics.contains(metric)) {
      return;
    }

    setState(() {
      _metrics.remove(metric);
    });

    _saveLayout();
  }

  // ==========================================
  // REORDER CARDS
  // ==========================================

  void _moveMetric(HomeMetric source, HomeMetric destination) {
    if (!_layoutLoaded || source == destination) {
      return;
    }

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
                  // HEADER
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
                                'Выбери нужные '
                                'карточки для '
                                'главной панели',
                                style: Theme.of(
                                  sheetContext,
                                ).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Закрыть',
                          onPressed: () => Navigator.of(sheetContext).pop(),
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
                                    'Все показатели '
                                    'добавлены',
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
                                    if (!mounted) {
                                      return;
                                    }

                                    if (!_metrics.contains(metric)) {
                                      setState(() {
                                        _metrics.add(metric);
                                      });

                                      _saveLayout();
                                    }

                                    setSheetState(() {});
                                  },
                                ),
                              );
                            },
                          ),
                  ),

                  // ==========================
                  // DONE BUTTON
                  // ==========================
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
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
  // HOME PAGE BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
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
                  // ==========================
                  // PAGE HEADER
                  // ==========================
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
                                ? 'Удерживай карточку '
                                      'и перетащи на место '
                                      'другой. Нажми крестик, '
                                      'чтобы убрать её.'
                                : 'Персональная панель '
                                      'телеметрии',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ==========================
                  // EMPTY LAYOUT
                  // ==========================
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
                  // ==========================
                  // METRIC GRID
                  // ==========================
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
                                  onRemove: () => _removeMetric(metric),
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

                  // Leave space for the
                  // floating navigation pill.
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),

            // ================================
            // EDIT MODE BUTTON
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
// GRID ITEM + DRAG AND DROP
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
    // ========================================
    // NORMAL MODE
    // ========================================

    if (!isEditing) {
      return _HomeMetricCard(
        metric: metric,
        connection: connection,
        isEditing: false,
      );
    }

    // ========================================
    // EDIT MODE
    // ========================================

    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return DragTarget<HomeMetric>(
          onWillAcceptWithDetails: (details) => details.data != metric,

          onAcceptWithDetails: (details) => onMove(details.data, metric),

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

                // ========================
                // DRAG PREVIEW
                // ========================
                feedback: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: 158,
                    child: _DraggingPreview(
                      metric: metric,

                      // NEW:
                      // Use real active job.
                      value: metric.formatValue(
                        connection.snapshot,
                        activeJob: connection.activeJob,
                      ),
                    ),
                  ),
                ),

                // ========================
                // PLACEHOLDER
                // ========================
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

                // ========================
                // ACTUAL CARD
                // ========================
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
// DRAG PREVIEW
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
// HOME METRIC CARD
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

  // ==========================================
  // SUBSCRIBE TO CONNECTION
  // ==========================================

  @override
  void initState() {
    super.initState();

    _value = _readValue();

    widget.connection.addListener(_onUpdate);
  }

  // ==========================================
  // READ LATEST CARD VALUE
  // ==========================================

  String _readValue() {
    return widget.metric.formatValue(
      widget.connection.snapshot,

      // NEW:
      // Cargo, route, reward and remaining
      // distance are read from activeJob.
      activeJob: widget.connection.activeJob,
    );
  }

  // ==========================================
  // HANDLE WIDGET UPDATES
  // ==========================================

  @override
  void didUpdateWidget(covariant _HomeMetricCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onUpdate);

      widget.connection.addListener(_onUpdate);
    }

    _value = _readValue();
  }

  // ==========================================
  // UPDATE ONLY WHEN VALUE CHANGES
  // ==========================================

  void _onUpdate() {
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
  // BUILD CARD
  // ==========================================

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
              // ==========================
              // ICON AND CATEGORY
              // ==========================
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

              // ==========================
              // METRIC TITLE
              // ==========================
              Text(
                widget.metric.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium,
              ),

              const Spacer(),

              // ==========================
              // LIVE VALUE
              // ==========================
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

  // ==========================================
  // UNSUBSCRIBE
  // ==========================================

  @override
  void dispose() {
    widget.connection.removeListener(_onUpdate);

    super.dispose();
  }
}
