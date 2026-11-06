import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import 'appearance_settings.dart';

// ============================================
// TRUCKLINK APPEARANCE THEME EXTENSION
// ============================================

@immutable
class TruckLinkAppearanceTokens
    extends ThemeExtension<TruckLinkAppearanceTokens> {
  const TruckLinkAppearanceTokens({required this.settings});

  final TruckLinkAppearanceSettings settings;

  // ==========================================
  // COPY WITH
  // ==========================================

  @override
  TruckLinkAppearanceTokens copyWith({TruckLinkAppearanceSettings? settings}) {
    return TruckLinkAppearanceTokens(settings: settings ?? this.settings);
  }

  // ==========================================
  // THEME ANIMATION
  // ==========================================

  @override
  TruckLinkAppearanceTokens lerp(
    covariant ThemeExtension<TruckLinkAppearanceTokens>? other,
    double t,
  ) {
    if (other is! TruckLinkAppearanceTokens) {
      return this;
    }

    return t < 0.5 ? this : other;
  }
}

// ============================================
// TRUCKLINK DYNAMIC APPEARANCE THEME
// ============================================

abstract final class TruckLinkAppearanceTheme {
  // ==========================================
  // READ SETTINGS FROM THE CURRENT THEME
  // ==========================================

  static TruckLinkAppearanceSettings settingsOf(BuildContext context) {
    final tokens = Theme.of(context).extension<TruckLinkAppearanceTokens>();

    return tokens?.settings ?? TruckLinkAppearanceSettings.defaults;
  }

  // ==========================================
  // BUILD DYNAMIC DARK THEME
  // ==========================================

  static ThemeData build(TruckLinkAppearanceSettings settings) {
    // Preserve the existing TruckLink
    // dark theme, typography and backgrounds.
    final base = TruckLinkTheme.dark;

    // ========================================
    // ACCENT COLOR
    // ========================================

    final Color accent = settings.accentColor;

    const Color foregroundOnAccent = Color(0xFF091018);

    // ========================================
    // COLOR SCHEME
    // ========================================

    final Color surface = base.colorScheme.surface;

    final Color primaryContainer = Color.alphaBlend(
      accent.withValues(alpha: 0.18),
      surface,
    );

    final ColorScheme colorScheme = base.colorScheme.copyWith(
      primary: accent,
      onPrimary: foregroundOnAccent,
      primaryContainer: primaryContainer,
      onPrimaryContainer: accent,
      secondary: accent,
      onSecondary: foregroundOnAccent,
      secondaryContainer: primaryContainer,
      onSecondaryContainer: accent,
    );

    // ========================================
    // CARD BACKGROUND
    // ========================================

    final Color cardColor;

    switch (settings.cardStyle) {
      case TruckLinkCardStyle.filled:
        cardColor = base.cardTheme.color ?? base.colorScheme.surface;

      case TruckLinkCardStyle.outlined:
        cardColor = base.scaffoldBackgroundColor;

      case TruckLinkCardStyle.minimal:
        cardColor = base.scaffoldBackgroundColor;
    }

    // ========================================
    // CARD BORDER
    // ========================================

    final BorderSide cardBorder;

    switch (settings.cardStyle) {
      case TruckLinkCardStyle.filled:
        cardBorder = BorderSide.none;

      case TruckLinkCardStyle.outlined:
        cardBorder = BorderSide(
          color: accent.withValues(alpha: 0.55),
          width: 1.2,
        );

      case TruckLinkCardStyle.minimal:
        cardBorder = BorderSide.none;
    }

    // ========================================
    // CARD SHAPE
    // ========================================

    final RoundedRectangleBorder cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(settings.cardRadius),
      side: cardBorder,
    );

    // ========================================
    // CARD THEME
    // ========================================

    final CardThemeData cardTheme = base.cardTheme.copyWith(
      color: cardColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: cardShape,
    );

    // ========================================
    // CUSTOM APPEARANCE SETTINGS
    // ========================================

    final TruckLinkAppearanceTokens tokens = TruckLinkAppearanceTokens(
      settings: settings,
    );

    // ========================================
    // BUILD RESULTING THEME
    // ========================================

    return base.copyWith(
      colorScheme: colorScheme,
      cardTheme: cardTheme,

      // FIX:
      //
      // Do not spread base.extensions.values.
      // That caused a generic type mismatch
      // with ThemeExtension in Flutter.
      //
      // Install our custom extension directly.
      extensions: [tokens],
    );
  }
}
