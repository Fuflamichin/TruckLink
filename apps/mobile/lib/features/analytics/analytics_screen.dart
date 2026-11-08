import 'package:flutter/material.dart';

import '../finance/finance_store.dart';
import '../jobs/history/job_history_store.dart';
import 'analytics_stats.dart';

// ============================================
// TRUCKLINK ANALYTICS SCREEN v0.8.3
// ============================================

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final JobHistoryStore _history = JobHistoryStore.instance;

  final FinanceStore _finance = FinanceStore.instance;

  late final Listenable _dataChanges;

  int _selectedGameId = 1;

  AnalyticsPeriod _period = AnalyticsPeriod.last30Days;

  @override
  void initState() {
    super.initState();

    _dataChanges = Listenable.merge([_history, _finance]);
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Аналитика')),
      body: ListenableBuilder(
        listenable: _dataChanges,
        builder: (context, child) {
          if (_history.isLoading || _finance.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final summary = TruckLinkAnalytics.calculate(
            gameId: _selectedGameId,
            period: _period,
            jobs: _history.entries,
            finances: _finance.entries,
          );

          return _buildDashboard(context, summary);
        },
      ),
    );
  }

  // ==========================================
  // DASHBOARD
  // ==========================================

  Widget _buildDashboard(BuildContext context, AnalyticsSummary summary) {
    final theme = Theme.of(context);

    return ListView(
      key: const PageStorageKey<String>('trucklink-analytics'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          'Статистика перевозок',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Рейсы и финансовые события, '
          'сохранённые TruckLink',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 19),

        // ====================================
        // GAME SELECTOR
        // ====================================
        Text('Игра', style: theme.textTheme.labelLarge),

        const SizedBox(height: 8),

        Wrap(
          spacing: 9,
          runSpacing: 5,
          children: [
            ChoiceChip(
              label: const Text('Euro Truck Simulator 2'),
              selected: _selectedGameId == 1,
              onSelected: (_) {
                setState(() {
                  _selectedGameId = 1;
                });
              },
            ),
            ChoiceChip(
              label: const Text('American Truck Simulator'),
              selected: _selectedGameId == 2,
              onSelected: (_) {
                setState(() {
                  _selectedGameId = 2;
                });
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ====================================
        // PERIOD SELECTOR
        // ====================================
        Text('Период', style: theme.textTheme.labelLarge),

        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          runSpacing: 5,
          children: [
            for (final period in AnalyticsPeriod.values)
              ChoiceChip(
                label: Text(period.title),
                selected: _period == period,
                onSelected: (_) {
                  setState(() {
                    _period = period;
                  });
                },
              ),
          ],
        ),

        // ====================================
        // STORAGE WARNINGS
        // ====================================
        if (_history.error != null || _finance.error != null) ...[
          const SizedBox(height: 12),

          _InformationCard(
            icon: Icons.warning_amber_rounded,
            message: [
              if (_history.error != null) _history.error!,
              if (_finance.error != null) _finance.error!,
            ].join('\n'),
            warning: true,
          ),
        ],

        if (!summary.hasData) ...[
          const SizedBox(height: 16),

          const _EmptyAnalytics(),

          const SizedBox(height: 12),
        ],

        const SizedBox(height: 22),

        // ====================================
        // DELIVERY SECTION
        // ====================================
        const _SectionTitle(
          title: 'Перевозки',
          icon: Icons.local_shipping_outlined,
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _CountCard(
                label: 'Доставлено',
                value: summary.deliveredCount,
                icon: Icons.task_alt_rounded,
                success: true,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _CountCard(
                label: 'Отменено',
                value: summary.cancelledCount,
                icon: Icons.cancel_outlined,
                success: false,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        _CompletionCard(summary: summary),

        const SizedBox(height: 12),

        _MetricGrid(
          metrics: [
            _MetricData(
              title: 'Плановый километраж',
              value: '${_group(summary.plannedDistanceKm)} км',
              icon: Icons.route_outlined,
              note: 'Доставленные заказы',
            ),
            _MetricData(
              title: 'Средний маршрут',
              value: '${_group(summary.averagePlannedDistanceKm)} км',
              icon: Icons.map_outlined,
              note: 'По плану заказа',
            ),
            _MetricData(
              title: 'Награды по контрактам',
              value: _group(summary.promisedRewards),
              icon: Icons.payments_outlined,
              note: 'Не фактический доход',
            ),
            _MetricData(
              title: 'Всего завершённых',
              value: '${summary.totalJobs}',
              icon: Icons.history_rounded,
              note: 'Доставлено + отменено',
            ),
          ],
        ),

        const SizedBox(height: 26),

        // ====================================
        // FINANCE SECTION
        // ====================================
        const _SectionTitle(
          title: 'Финансы',
          icon: Icons.account_balance_wallet_outlined,
        ),

        const SizedBox(height: 12),

        _NetResultCard(
          amount: summary.recordedNet,
          transactionCount: summary.financeEventCount,
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _MoneyCard(
                title: 'Доходы',
                amount: summary.recordedIncome,
                icon: Icons.trending_up_rounded,
                isExpense: false,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _MoneyCard(
                title: 'Расходы',
                amount: summary.recordedExpenses,
                icon: Icons.trending_down_rounded,
                isExpense: true,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        _InformationCard(
          icon: Icons.info_outline_rounded,
          message:
              'Финансы показывают только операции, '
              'полученные от игры при работающем '
              'Hub и подключённом телефоне. '
              'Это не баланс профиля и не '
              'полный финансовый отчёт.',
        ),

        const SizedBox(height: 26),

        // ====================================
        // FINANCIAL TREND
        // ====================================
        _SectionTitle(
          title: 'Динамика операций',
          icon: Icons.bar_chart_rounded,
          subtitle: _period.chartDescription,
        ),

        const SizedBox(height: 12),

        _FinanceTrendChart(points: summary.trend),

        const SizedBox(height: 26),

        // ====================================
        // TOP DESTINATIONS
        // ====================================
        const _SectionTitle(
          title: 'Популярные направления',
          icon: Icons.location_city_outlined,
        ),

        const SizedBox(height: 12),

        _RankingCard(
          title: 'Города доставки',
          entries: summary.topDestinations,
          emptyText: 'Пока нет сохранённых доставок',
        ),

        const SizedBox(height: 12),

        _RankingCard(
          title: 'Частые маршруты',
          entries: summary.topRoutes,
          emptyText: 'Пока нет данных о маршрутах',
        ),

        const SizedBox(height: 20),

        Text(
          'Статистика построена по локальной '
          'истории TruckLink. Плановый километраж '
          'не равен фактически пройденному. '
          'График для периода «Всё время» '
          'показывает последние 6 месяцев, '
          'а итоговые показатели — все '
          'сохранённые записи выбранной игры.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ============================================
// SECTION TITLE
// ============================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon, this.subtitle});

  final String title;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 22),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        if (subtitle != null)
          Text(
            subtitle!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

// ============================================
// DELIVERED / CANCELLED COUNT
// ============================================

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.success,
  });

  final String label;
  final int value;
  final IconData icon;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final accent = success
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 24),

            const SizedBox(height: 12),

            Text(
              '$value',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),

            const SizedBox(height: 3),

            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ============================================
// COMPLETION RATE
// ============================================

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final percent = summary.completionPercent;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Успешность доставок',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                Text(
                  '${percent.toStringAsFixed(0)} %',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 7,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),

            const SizedBox(height: 9),

            Text(
              summary.totalJobs == 0
                  ? 'Нет завершённых рейсов'
                  : '${summary.deliveredCount} из '
                        '${summary.totalJobs} рейсов доставлены',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// METRIC DATA
// ============================================

class _MetricData {
  const _MetricData({
    required this.title,
    required this.value,
    required this.icon,
    required this.note,
  });

  final String title;
  final String value;
  final IconData icon;
  final String note;
}

// ============================================
// RESPONSIVE METRIC GRID
// ============================================

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;

        final columns = constraints.maxWidth < 340 ? 1 : 2;

        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _MetricCard(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

// ============================================
// METRIC CARD
// ============================================

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(metric.icon, color: theme.colorScheme.primary, size: 22),

            const SizedBox(height: 11),

            Text(
              metric.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 7),

            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  metric.value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 5),

            Text(
              metric.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// NET RESULT
// ============================================

class _NetResultCard extends StatelessWidget {
  const _NetResultCard({required this.amount, required this.transactionCount});

  final int amount;
  final int transactionCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final accent = amount < 0
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Учтённый финансовый результат',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              _signed(amount),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              '$transactionCount операций · '
              'в валюте выбранной игры',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// INCOME / EXPENSE CARD
// ============================================

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.isExpense,
  });

  final String title;
  final int amount;
  final IconData icon;
  final bool isExpense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final accent = isExpense
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 22),

            const SizedBox(height: 10),

            Text(title, style: theme.textTheme.labelMedium),

            const SizedBox(height: 6),

            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _group(amount),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// FINANCIAL TREND CHART
// ============================================

class _FinanceTrendChart extends StatelessWidget {
  const _FinanceTrendChart({required this.points});

  final List<AnalyticsTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final incomeColor = theme.colorScheme.primary;
    final expenseColor = theme.colorScheme.error;

    var maximum = 0;

    for (final point in points) {
      if (point.income > maximum) {
        maximum = point.income;
      }

      if (point.expenses > maximum) {
        maximum = point.expenses;
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _LegendItem(title: 'Доходы', color: incomeColor),
                _LegendItem(title: 'Расходы', color: expenseColor),
              ],
            ),

            const SizedBox(height: 16),

            for (var index = 0; index < points.length; index++) ...[
              _TrendRow(point: points[index], maximum: maximum),

              if (index < points.length - 1) const SizedBox(height: 14),
            ],

            if (maximum == 0) ...[
              const SizedBox(height: 15),

              Text(
                'Финансовых операций за '
                'показанные интервалы пока нет.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================
// LEGEND
// ============================================

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),

        const SizedBox(width: 6),

        Text(title, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

// ============================================
// TREND ROW
// ============================================

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.point, required this.maximum});

  final AnalyticsTrendPoint point;
  final int maximum;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final background = theme.colorScheme.surfaceContainerHighest;

    final incomeValue = maximum <= 0 ? 0.0 : point.income / maximum;

    final expenseValue = maximum <= 0 ? 0.0 : point.expenses / maximum;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 92,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                point.label,
                maxLines: 2,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                '${point.deliveries} доставок',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 9),

        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Доход', style: TextStyle(fontSize: 10)),
                  ),

                  Text(
                    _group(point.income),
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              LinearProgressIndicator(
                value: incomeValue.clamp(0.0, 1.0),
                minHeight: 6,
                borderRadius: BorderRadius.circular(5),
                backgroundColor: background,
                color: theme.colorScheme.primary,
              ),

              const SizedBox(height: 9),

              Row(
                children: [
                  const Expanded(
                    child: Text('Расход', style: TextStyle(fontSize: 10)),
                  ),

                  Text(
                    _group(point.expenses),
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              LinearProgressIndicator(
                value: expenseValue.clamp(0.0, 1.0),
                minHeight: 6,
                borderRadius: BorderRadius.circular(5),
                backgroundColor: background,
                color: theme.colorScheme.error,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================
// DESTINATION / ROUTE RANKING
// ============================================

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.title,
    required this.entries,
    required this.emptyText,
  });

  final String title;
  final List<AnalyticsRank> entries;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final maximum = entries.isEmpty ? 1 : entries.first.count;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 15),

            if (entries.isEmpty)
              Text(
                emptyText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (var index = 0; index < entries.length; index++) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 25,
                      child: Text(
                        '${index + 1}.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),

                    Expanded(
                      child: Text(
                        entries[index].name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Text(
                      '${entries[index].count}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 7),

                LinearProgressIndicator(
                  value: entries[index].count / maximum,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(5),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),

                if (index < entries.length - 1) const SizedBox(height: 14),
              ],
          ],
        ),
      ),
    );
  }
}

// ============================================
// INFORMATION
// ============================================

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.icon,
    required this.message,
    this.warning = false,
  });

  final IconData icon;
  final String message;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: warning
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),

            const SizedBox(width: 11),

            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// EMPTY ANALYTICS
// ============================================

class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        child: Column(
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 42,
              color: theme.colorScheme.primary,
            ),

            const SizedBox(height: 13),

            Text(
              'Пока нет данных за этот период',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 9),

            Text(
              'Выполни или отмени перевозку, '
              'либо получи финансовое событие '
              'при подключённом TruckLink Hub. '
              'Данные появятся автоматически.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// NUMBER FORMAT
// ============================================

String _group(int value) {
  return value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
}

String _signed(int value) {
  if (value > 0) {
    return '+${_group(value)}';
  }

  return _group(value);
}
