import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/appearance/appearance_settings.dart';
import '../../core/appearance/trucklink_appearance_theme.dart';

// ============================================
// TRUCKLINK PILL NAVIGATION STYLE
// ============================================

enum TruckLinkPillStyle { bottom, group }

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
// TRUCKLINK PILL NAVIGATION
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

  static const Duration _duration = Duration(milliseconds: 280);

  static const Curve _curve = Curves.easeInOutCubic;

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    // ========================================
    // APPEARANCE SETTINGS
    // ========================================

    final settings = TruckLinkAppearanceTheme.settingsOf(context);

    final colorScheme = Theme.of(context).colorScheme;

    final Color accent = colorScheme.primary;

    final bool isBottom = style == TruckLinkPillStyle.bottom;

    final double height = isBottom
        ? settings.bottomNavigationHeight
        : settings.groupNavigationHeight;

    final double indicatorHeight = isBottom ? height - 28.0 : height - 12.0;

    final double radius = settings.navigationRadius;

    final double indicatorRadius = indicatorHeight / 2.0;

    final double glow = settings.highlightOpacity;

    final int safeIndex = selectedIndex.clamp(0, items.length - 1).toInt();

    const double horizontalPadding = 8.0;

    // ========================================
    // NAVIGATION BORDER STYLE
    // ========================================

    // The navigation border now follows
    // the SAME card style selected in
    // Settings -> Appearance.
    //
    // Filled:
    //   Original neutral border.
    //
    // Outlined:
    //   Colored border matching the cards.
    //
    // Minimal:
    //   No visible border.

    final Color borderColor = switch (settings.cardStyle) {
      TruckLinkCardStyle.filled => const Color(0xFF4B5063),

      TruckLinkCardStyle.outlined => accent.withValues(alpha: 0.55),

      TruckLinkCardStyle.minimal => Colors.transparent,
    };

    final double borderWidth = switch (settings.cardStyle) {
      TruckLinkCardStyle.filled => 1.15,
      TruckLinkCardStyle.outlined => 1.2,
      TruckLinkCardStyle.minimal => 0.0,
    };

    // ========================================
    // NAVIGATION BACKGROUND
    // ========================================

    // Keep the original dark-purple
    // background from our reference design.
    //
    // The border is personalized separately
    // so the pill retains its familiar shape.

    const LinearGradient backgroundGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1D2030), Color(0xFF151A26)],
    );

    // ========================================
    // BUILD RESPONSIVE NAVIGATION
    // ========================================

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = math.max(0.0, constraints.maxWidth);

        final double contentWidth = math.max(
          0.0,
          availableWidth - horizontalPadding * 2.0,
        );

        final double itemWidth = contentWidth / items.length;

        // ====================================
        // ACTIVE INDICATOR SIZE
        // ====================================

        // Bottom navigation:
        // compact oval around the icon.
        //
        // Combined group navigation:
        // wider oval around icon and text.

        final double indicatorWidth = isBottom
            ? math.max(0.0, math.min(68.0, itemWidth - 10.0))
            : math.max(0.0, itemWidth - 8.0);

        final double indicatorLeft =
            horizontalPadding +
            itemWidth * safeIndex +
            (itemWidth - indicatorWidth) / 2.0;

        // ====================================
        // PILL CONTAINER
        // ====================================

        return AnimatedContainer(
          duration: _duration,
          curve: _curve,
          height: height,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),

            // Original TruckLink gradient.
            gradient: backgroundGradient,

            // =================================
            // DYNAMIC BORDER
            // =================================

            // This is the main change:
            // the outer pill now uses the
            // same accent-colored outline
            // as the telemetry cards.
            border: Border.all(color: borderColor, width: borderWidth),

            // =================================
            // SHADOW
            // =================================
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 6),
              ),
            ],
          ),

          // ==================================
          // CONTENT
          // ==================================
          child: Stack(
            children: [
              // ==============================
              // ANIMATED ACTIVE CAPSULE
              // ==============================
              AnimatedPositioned(
                duration: _duration,
                curve: _curve,
                left: indicatorLeft,
                top: (height - indicatorHeight) / 2.0,
                width: indicatorWidth,
                height: indicatorHeight,

                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(indicatorRadius),

                      // The inner highlight
                      // uses the selected accent.
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: glow),
                          accent.withValues(alpha: glow * 0.60),
                        ],
                      ),

                      border: Border.all(
                        color: accent.withValues(
                          alpha: math.min(1.0, glow * 0.65),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ==============================
              // NAVIGATION BUTTONS
              // ==============================
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                ),

                child: Row(
                  children: [
                    for (var index = 0; index < items.length; index++)
                      Expanded(
                        child: _PillNavigationButton(
                          key: ValueKey(
                            '${style.name}-${index}-'
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
// NAVIGATION BUTTON
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

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;

    const Color inactiveColor = Color(0xFFADB5C6);

    final Color iconColor = selected ? accent : inactiveColor;

    final IconData currentIcon = selected
        ? (item.activeIcon ?? item.icon)
        : item.icon;

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
                    ? _groupContent(currentIcon, iconColor)
                    : _bottomIcon(currentIcon, iconColor),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // BOTTOM NAVIGATION ICON
  // ==========================================

  Widget _bottomIcon(IconData icon, Color color) {
    return AnimatedScale(
      scale: selected ? 1.08 : 1.0,

      duration: const Duration(milliseconds: 220),

      curve: Curves.easeOutCubic,

      child: Icon(icon, size: 27, color: color),
    );
  }

  // ==========================================
  // COMBINED GROUP TAB
  // ==========================================

  Widget _groupContent(IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(icon, size: 18, color: color),

          const SizedBox(width: 7),

          Flexible(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),

              curve: Curves.easeInOut,

              style: TextStyle(
                color: color,
                fontSize: 13,
                height: 1.1,

                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
