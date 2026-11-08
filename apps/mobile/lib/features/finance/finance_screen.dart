import 'package:flutter/material.dart';
import 'package:network_protocol/finance_protocol.dart';

import 'finance_store.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final FinanceStore _store = FinanceStore.instance;

  int? _chosenGameId;

  int _selectedGame(List<FinanceEvent> all) {
    final chosen = _chosenGameId;

    if (chosen != null) return chosen;

    if (all.isNotEmpty) {
      return all.first.gameId;
    }

    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Финансы')),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, child) {
          if (_store.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final gameId = _selectedGame(_store.entries);
          final events = _store.forGame(gameId);

          final income = _store.deliveredRevenueForGame(gameId);

          final expenses = _store.expensesForGame(gameId);

          final net = _store.observedNetForGame(gameId);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text(
                'Финансовая статистика',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Операции, полученные из '
                'игровой телеметрии',
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const SizedBox(height: 18),

              // ETS2 and ATS must not be added
              // together as a single currency.
              Wrap(
                spacing: 9,
                children: [
                  ChoiceChip(
                    label: const Text('ETS2'),
                    selected: gameId == 1,
                    onSelected: (_) {
                      setState(() {
                        _chosenGameId = 1;
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('ATS'),
                    selected: gameId == 2,
                    onSelected: (_) {
                      setState(() {
                        _chosenGameId = 2;
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _FinanceSummaryCard(
                title: 'Учтённый результат',
                value: _formatSigned(net),
                subtitle:
                    'Доходы минус зарегистрированные '
                    'расходы',
                icon: Icons.account_balance_wallet_outlined,
                emphasized: true,
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _FinanceSummaryCard(
                      title: 'Доходы',
                      value: _group(income),
                      subtitle: 'Доставки',
                      icon: Icons.trending_up_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FinanceSummaryCard(
                      title: 'Расходы',
                      value: _group(expenses),
                      subtitle: 'Штрафы и проезд',
                      icon: Icons.trending_down_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Текущий баланс профиля '
                          'недоступен через SCS SDK '
                          'revision 12. Здесь показаны '
                          'только операции, замеченные '
                          'TruckLink во время подключения. '
                          'Покупки, кредиты и стоимость '
                          'заправки не учитываются.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_store.error != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      _store.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Операции',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${events.length}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              if (events.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 42),
                        SizedBox(height: 12),
                        Text(
                          'Финансовых операций пока нет',
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Подключись к Windows Hub '
                          'и выполни перевозку или '
                          'оплати проезд в ETS2 / ATS.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final event in events)
                  Padding(
                    key: ValueKey(event.id),
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _FinanceEventCard(event: event),
                  ),

              const SizedBox(height: 12),

              Text(
                'История хранится локально '
                'на этом телефоне. '
                'Суммы ETS2 и ATS не объединяются.',
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
// FINANCE SUMMARY
// ============================================

class _FinanceSummaryCard extends StatelessWidget {
  const _FinanceSummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.emphasized = false,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final bool emphasized;

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
            Icon(icon, size: 23, color: theme.colorScheme.primary),
            const SizedBox(height: 10),
            Text(title, style: theme.textTheme.labelMedium),
            const SizedBox(height: 7),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (emphasized
                          ? theme.textTheme.headlineSmall
                          : theme.textTheme.titleLarge)
                      ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
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
// FINANCIAL EVENT
// ============================================

class _FinanceEventCard extends StatelessWidget {
  const _FinanceEventCard({required this.event});

  final FinanceEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final income = event.amount >= 0;

    final accent = income ? theme.colorScheme.primary : theme.colorScheme.error;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                income
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.kind.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(event.occurredAtUtc),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatSigned(event.amount),
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// FORMATTERS
// ============================================

String _group(int value) {
  final digits = value.abs().toString();

  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );

  return value < 0 ? '-$grouped' : grouped;
}

String _formatSigned(int amount) {
  return '${amount >= 0 ? "+" : "-"}'
      '${_group(amount.abs())}';
}

String _formatDate(DateTime utc) {
  final date = utc.toLocal();

  String two(int value) => value.toString().padLeft(2, '0');

  return '${two(date.day)}.'
      '${two(date.month)}.'
      '${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}
