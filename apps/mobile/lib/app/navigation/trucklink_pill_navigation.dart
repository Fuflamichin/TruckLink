import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================
// TRUCKLINK PILL NAVIGATION
// ============================================

enum TruckLinkPillStyle {
  // Floating bottom dock: icons only.
  bottom,

  // Inner navigation: icons and titles.
  group,
}

// ============================================
// NAVIGATION ITEM
// ============================================

class TruckLinkPillItem {
  const TruckLinkPillItem({
    required this.label,
    required this.icon,
    this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData? activeIcon;
}

// ============================================
// REUSABLE NAVIGATION BAR
// ============================================

class TruckLinkPillNavigation extends StatelessWidget {
  const TruckLinkPillNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.style = TruckLinkPillStyle.bottom,
  });

  final List<TruckLinkPillItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final TruckLinkPillStyle style;

  static const _duration = Duration(milliseconds: 280);

  static const _curve = Curves.easeInOutCubic;

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final isBottom = style == TruckLinkPillStyle.bottom;

    final height = isBottom ? 76.0 : 54.0;
    final indicatorHeight = isBottom ? 48.0 : 42.0;
    const sidePadding = 8.0;

    final safeIndex = selectedIndex.clamp(0, items.length - 1).toInt();

    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = math.max(0.0, constraints.maxWidth);

        final contentWidth = math.max(0.0, availableWidth - sidePadding * 2);

        final itemWidth = contentWidth / items.length;

        // The bottom indicator is a compact oval.
        // Group indicators fill most of their cells.
        final indicatorWidth = isBottom
            ? math.max(0.0, math.min(68.0, itemWidth - 10.0))
            : math.max(0.0, itemWidth - 8.0);

        final indicatorLeft =
            sidePadding +
            itemWidth * safeIndex +
            (itemWidth - indicatorWidth) / 2;

        return Container(
          height: height,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1D2030), Color(0xFF151A26)],
            ),
            border: Border.all(color: const Color(0xFF4B5063), width: 1.15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 6),
              ),
            ],
          ),

          child: Stack(
            children: [
              // ================================
              // ANIMATED ACTIVE INDICATOR
              // ================================
              AnimatedPositioned(
                duration: _duration,
                curve: _curve,
                left: indicatorLeft,
                top: (height - indicatorHeight) / 2,
                width: indicatorWidth,
                height: indicatorHeight,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(indicatorHeight / 2),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.24),
                          accent.withValues(alpha: 0.13),
                        ],
                      ),
                      border: Border.all(color: accent.withValues(alpha: 0.12)),
                    ),
                  ),
                ),
              ),

              // ================================
              // NAVIGATION ITEMS
              // ================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: sidePadding),
                child: Row(
                  children: [
                    for (var index = 0; index < items.length; index++)
                      Expanded(
                        child: _PillNavigationButton(
                          key: ValueKey(
                            '${style.name}-$index-'
                            '${items[index].label}',
                          ),
                          item: items[index],
                          selected: index == safeIndex,
                          showLabel: !isBottom,
                          onTap: () {
                            if (index != safeIndex) {
                              HapticFeedback.selectionClick();
                            }

                            onSelected(index);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================
// INDIVIDUAL NAVIGATION BUTTON
// ============================================

class _PillNavigationButton extends StatelessWidget {
  const _PillNavigationButton({
    super.key,
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final TruckLinkPillItem item;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    final color = selected ? accent : const Color(0xFFADB5C6);

    final iconData = selected ? (item.activeIcon ?? item.icon) : item.icon;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(40),
            splashColor: accent.withValues(alpha: 0.09),
            highlightColor: Colors.transparent,
            child: SizedBox.expand(
              child: Center(
                child: showLabel
                    ? _buildGroupLabel(color, iconData)
                    : _buildDockIcon(color, iconData),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // BOTTOM DOCK: ICON ONLY
  // ==========================================

  Widget _buildDockIcon(Color color, IconData iconData) {
    return AnimatedScale(
      scale: selected ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Icon(iconData, size: 27, color: color),
    );
  }

  // ==========================================
  // COMBINED GROUP: ICON + LABEL
  // ==========================================

  Widget _buildGroupLabel(Color color, IconData iconData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 18, color: color),

          const SizedBox(width: 7),

          Flexible(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
                height: 1.1,
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
