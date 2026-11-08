import 'package:flutter/material.dart';

import '../../analytics/analytics_screen.dart';
import '../../finance/finance_screen.dart';
import 'job_history_entry.dart';
import 'job_history_store.dart';

// ============================================
// TRUCKLINK JOB HISTORY v0.8.3
// ============================================

enum _HistoryFilter { all, delivered, cancelled }

// ============================================
// HISTORY SCREEN
// ============================================

class JobHistoryScreen extends StatefulWidget {
  const JobHistoryScreen({super.key});

  @override
  State<JobHistoryScreen> createState() => _JobHistoryScreenState();
}

class _JobHistoryScreenState extends State<JobHistoryScreen> {
  final JobHistoryStore _store = JobHistoryStore.instance;

  _HistoryFilter _filter = _HistoryFilter.all;

  // ==========================================
  // FILTER ENTRIES
  // ==========================================

  List<JobHistoryEntry> _filtered(List<JobHistoryEntry> entries) {
    return switch (_filter) {
      _HistoryFilter.all => entries,

      _HistoryFilter.delivered =>
        entries.where((entry) => entry.isDelivered).toList(growable: false),

      _HistoryFilter.cancelled =>
        entries.where((entry) => entry.isCancelled).toList(growable: false),
    };
  }

  // ==========================================
  // OPEN ANALYTICS
  // ==========================================

  void _openAnalytics() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AnalyticsScreen()));
  }

  // ==========================================
  // OPEN FINANCES
  // ==========================================

  void _openFinances() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const FinanceScreen()));
  }

  // ==========================================
  // FILTER CHIP
  // ==========================================

  Widget _filterChip(String title, _HistoryFilter filter) {
    return ChoiceChip(
      label: Text(title),
      selected: _filter == filter,
      onSelected: (_) {
        setState(() {
          _filter = filter;
        });
      },
    );
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История перевозок'),
        actions: [
          IconButton(
            tooltip: 'Аналитика',
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: _openAnalytics,
          ),

          IconButton(
            tooltip: 'Финансы',
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: _openFinances,
          ),

          const SizedBox(width: 5),
        ],
      ),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, child) {
          if (_store.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final allEntries = _store.entries;
          final visibleEntries = _filtered(allEntries);

          return ListView(
            key: const PageStorageKey<String>('trucklink-job-history'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              // ==================================
              // SUMMARY
              // ==================================
              Row(
                children: [
                  Expanded(
                    child: _HistorySummaryCard(
                      title: 'Доставлено',
                      count: _store.deliveredCount,
                      icon: Icons.task_alt_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _HistorySummaryCard(
                      title: 'Отменено',
                      count: _store.cancelledCount,
                      icon: Icons.cancel_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),

              // ==================================
              // STORAGE WARNING
              // ==================================
              if (_store.error != null) ...[
                const SizedBox(height: 12),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),

                        const SizedBox(width: 10),

                        Expanded(child: Text(_store.error!)),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ==================================
              // FILTERS
              // ==================================
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _filterChip('Все', _HistoryFilter.all),

                  _filterChip('Доставлено', _HistoryFilter.delivered),

                  _filterChip('Отменено', _HistoryFilter.cancelled),
                ],
              ),

              const SizedBox(height: 16),

              // ==================================
              // ENTRIES
              // ==================================
              if (visibleEntries.isEmpty)
                _EmptyHistory(filtered: allEntries.isNotEmpty)
              else
                for (final entry in visibleEntries)
                  Padding(
                    key: ValueKey(entry.id),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SavedJobCard(entry: entry),
                  ),

              const SizedBox(height: 16),

              Text(
                'История хранится локально '
                'на этом телефоне. '
                'Нажми значок графика вверху, '
                'чтобы открыть аналитику.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================
// HISTORY SUMMARY CARD
// ============================================

class _HistorySummaryCard extends StatelessWidget {
  const _HistorySummaryCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 23),

            const SizedBox(height: 12),

            Text(
              '$count',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 3),

            Text(title, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ============================================
// SAVED JOB CARD
// ============================================

class _SavedJobCard extends StatelessWidget {
  const _SavedJobCard({required this.entry});

  final JobHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final job = entry.job;

    final accent = entry.isDelivered
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================
            // CARGO
            // ==================================
            Row(
              children: [
                Icon(
                  entry.isDelivered
                      ? Icons.inventory_2_outlined
                      : Icons.cancel_outlined,
                  color: accent,
                  size: 23,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    job.displayCargo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ==================================
            // ROUTE
            // ==================================
            Text(
              job.displayRoute,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 6),

            // ==================================
            // GAME / DATE
            // ==================================
            Text(
              '${job.gameName} · '
              '${_formatDate(entry.completedAtUtc)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // ==================================
            // STATUS / PROMISED REWARD
            // ==================================
            Row(
              children: [
                Icon(
                  entry.isDelivered
                      ? Icons.check_circle_outline
                      : Icons.highlight_off_rounded,
                  color: accent,
                  size: 17,
                ),

                const SizedBox(width: 7),

                Text(
                  entry.statusText,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),

                const Spacer(),

                Flexible(
                  child: Text(
                    'По контракту: '
                    '${_group(job.income)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// EMPTY HISTORY
// ============================================

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          children: [
            Icon(
              Icons.history_rounded,
              size: 44,
              color: theme.colorScheme.primary,
            ),

            const SizedBox(height: 14),

            Text(
              filtered ? 'Нет записей для этого фильтра' : 'История пока пуста',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            if (!filtered) ...[
              const SizedBox(height: 9),

              Text(
                'Заверши или отмени заказ '
                'при подключённом TruckLink Hub. '
                'Сведения о рейсе появятся здесь '
                'автоматически.',
                textAlign: TextAlign.center,
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
// FORMATTING
// ============================================

String _formatDate(DateTime utc) {
  final date = utc.toLocal();

  String two(int value) {
    return value.toString().padLeft(2, '0');
  }

  return '${two(date.day)}.'
      '${two(date.month)}.'
      '${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}

String _group(int value) {
  return value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
}
