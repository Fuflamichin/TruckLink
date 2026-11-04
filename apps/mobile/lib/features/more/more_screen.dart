import 'package:flutter/material.dart';

import '../../app/navigation/navigation_config.dart';

/// Full-screen navigation page for sections
/// that are not pinned to the bottom navigation bar.
///
/// The parent AppShell is responsible for:
/// - The shared application header.
/// - The bottom navigation bar.
/// - Switching between screens.
class MoreScreen extends StatelessWidget {
  const MoreScreen({
    super.key,
    required this.items,
    required this.onSelect,
    this.selectedId,
  });

  final List<NavigationItemConfig> items;
  final ValueChanged<String> onSelect;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return CustomScrollView(
      key: const PageStorageKey<String>('trucklink-more-scroll'),
      physics: const ClampingScrollPhysics(),
      slivers: [
        // ======================================
        // HEADER
        // ======================================
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ещё', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Дополнительные разделы TruckLink',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(Icons.apps_outlined, size: 20, color: scheme.primary),
                    const SizedBox(width: 10),
                    Text('Все разделы', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    Text(
                      '${items.length}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ======================================
        // EMPTY STATE
        // ======================================
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 52,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Все разделы закреплены',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Дополнительных разделов нет.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ======================================
        // NAVIGATION ITEMS
        // ======================================
        if (items.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = items[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MoreSectionTile(
                    key: ValueKey(item.id),
                    item: item,
                    selected: selectedId == item.id,
                    onTap: () => onSelect(item.id),
                  ),
                );
              }, childCount: items.length),
            ),
          ),

        // ======================================
        // FOOTER
        // ======================================
        if (items.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.tune_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'В будущем ты сможешь изменять '
                      'порядок разделов, закреплять их '
                      'внизу и объединять в группы '
                      'через настройки навигации.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
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
// NAVIGATION SECTION TILE
// ============================================

class _MoreSectionTile extends StatelessWidget {
  const _MoreSectionTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavigationItemConfig item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final subtitle = item.isGroup
        ? item.sections.map((section) => section.title).join(' · ')
        : 'Открыть раздел';

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 84),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Section icon
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(item.icon, color: scheme.primary, size: 24),
                ),

                const SizedBox(width: 16),

                // Title and description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Active state / navigation arrow
                Icon(
                  selected
                      ? Icons.check_circle_outline
                      : Icons.chevron_right_rounded,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
