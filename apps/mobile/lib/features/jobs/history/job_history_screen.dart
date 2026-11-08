import 'package:flutter/material.dart';

import 'job_history_entry.dart';
import 'job_history_store.dart';

// ============================================
// TRUCKLINK JOB HISTORY SCREEN
// Version 0.8.1
// ============================================

// ============================================
// HISTORY FILTERS
// ============================================

enum _HistoryFilter { all, delivered, cancelled }

// ============================================
// JOB HISTORY SCREEN
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
  // FILTER HISTORY
  // ==========================================

  List<JobHistoryEntry> _filteredEntries(List<JobHistoryEntry> entries) {
    return switch (_filter) {
      _HistoryFilter.all => entries,

      _HistoryFilter.delivered =>
        entries.where((entry) => entry.isDelivered).toList(),

      _HistoryFilter.cancelled =>
        entries.where((entry) => entry.isCancelled).toList(),
    };
  }

  // ==========================================
  // FILTER CHIP
  // ==========================================

  Widget _filterChip(String title, _HistoryFilter value) {
    return ChoiceChip(
      label: Text(title),
      selected: _filter == value,
      onSelected: (_) {
        setState(() {
          _filter = value;
        });
      },
    );
  }

  // ==========================================
  // BUILD SCREEN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('История перевозок')),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, child) {
          if (_store.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final allEntries = _store.entries;

          final visibleEntries = _filteredEntries(allEntries);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              // ==================================
              // SUMMARY CARDS
              // ==================================
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Доставлено',
                      value: _store.deliveredCount,
                      icon: Icons.task_alt_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _SummaryCard(
                      label: 'Отменено',
                      value: _store.cancelledCount,
                      icon: Icons.cancel_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),

              // ==================================
              // STORAGE ERROR
              // ==================================
              if (_store.error != null) ...[
                const SizedBox(height: 12),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
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
              // HISTORY LIST
              // ==================================
              if (visibleEntries.isEmpty)
                _EmptyHistory(hasEntries: allEntries.isNotEmpty)
              else
                for (final entry in visibleEntries)
                  Padding(
                    key: ValueKey(entry.id),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HistoryCard(entry: entry),
                  ),

              const SizedBox(height: 12),

              // ==================================
              // FOOTER
              // ==================================
              Text(
                'История сохраняется на этом '
                'телефоне. Перевозки, завершённые '
                'без подключения к Windows Hub, '
                'пока не записываются.',
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
// SUMMARY CARD
// ============================================

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
              '$value',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),

            const SizedBox(height: 3),

            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ============================================
// SAVED JOB CARD
// ============================================

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final JobHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final statusColor = entry.isDelivered
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    final job = entry.job;

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
                  size: 23,
                  color: statusColor,
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
            // GAME AND DATE
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
            // RESULT AND REWARD
            // ==================================
            Row(
              children: [
                Icon(
                  entry.isDelivered
                      ? Icons.check_circle_outline
                      : Icons.highlight_off_rounded,
                  color: statusColor,
                  size: 17,
                ),

                const SizedBox(width: 7),

                Text(
                  entry.statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),

                const Spacer(),

                Flexible(
                  child: Text(
                    'Награда: '
                    '${_formatNumber(job.income)}',
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

  // ==========================================
  // FORMAT DATE
  // ==========================================

  static String _formatDate(DateTime utc) {
    final date = utc.toLocal();

    String two(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${two(date.day)}.'
        '${two(date.month)}.'
        '${date.year} '
        '${two(date.hour)}:'
        '${two(date.minute)}';
  }

  // ==========================================
  // FORMAT NUMBER
  // ==========================================

  static String _formatNumber(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
  }
}

// ============================================
// EMPTY HISTORY
// ============================================

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.hasEntries});

  final bool hasEntries;

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
              hasEntries
                  ? 'Нет записей для этого фильтра'
                  : 'История пока пуста',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            if (!hasEntries) ...[
              const SizedBox(height: 9),

              Text(
                'Заверши или отмени заказ '
                'при подключённом Windows Hub. '
                'Рейс появится здесь автоматически.',
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
