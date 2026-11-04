import 'package:flutter/material.dart';

import '../navigation/navigation_config.dart';

// ============================================
// TRUCKLINK BOTTOM NAVIGATION
// ============================================

class TruckLinkBottomNavigation extends StatelessWidget {
  const TruckLinkBottomNavigation({
    super.key,
    required this.layout,
    required this.selectedId,
    required this.moreSelected,
    required this.onSelect,
    required this.onMore,
  });

  final NavigationLayout layout;
  final String selectedId;
  final bool moreSelected;

  final ValueChanged<String> onSelect;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final pinnedItems = layout.bottomItems;
    final moreItems = layout.moreItems;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                for (final item in pinnedItems)
                  Expanded(
                    child: _NavigationButton(
                      icon: item.icon,
                      label: item.title,
                      selected: selectedId == item.id,
                      onTap: () => onSelect(item.id),
                    ),
                  ),

                if (moreItems.isNotEmpty)
                  Expanded(
                    child: _NavigationButton(
                      icon: Icons.more_horiz_rounded,
                      label: 'Ещё',
                      selected: moreSelected,
                      onTap: onMore,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// NAVIGATION BUTTON
// ============================================

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 23),

                const SizedBox(height: 5),

                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
