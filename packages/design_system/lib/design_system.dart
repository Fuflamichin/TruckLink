import 'package:flutter/material.dart';

// ============================================
// TRUCKLINK BRAND COLORS
// ============================================

/// Shared color palette for Windows, Android and iOS.
///
/// Based on the TruckLink v2 logo.
abstract final class TruckLinkColors {
  // Main brand accent
  static const Color accent = Color(0xFF10EF78);

  // Softer accent for secondary elements
  static const Color accentSoft = Color(0xFF82DFB0);

  // Dark backgrounds
  static const Color background = Color(0xFF091018);
  static const Color surface = Color(0xFF111C26);
  static const Color card = Color(0xFF172430);
  static const Color elevated = Color(0xFF20303E);

  // Borders
  static const Color border = Color(0xFF30414C);
  static const Color borderSubtle = Color(0xFF24343F);

  // Text
  static const Color textPrimary = Color(0xFFF1F6FA);
  static const Color textSecondary = Color(0xFFB4C4CD);

  // Semantic colors
  static const Color success = accent;
  static const Color warning = Color(0xFFFFC66D);
  static const Color error = Color(0xFFFF8088);
  static const Color info = Color(0xFF89C5FF);
}

// ============================================
// SHARED TRUCKLINK THEME
// ============================================

abstract final class TruckLinkTheme {
  static ThemeData get dark {
    // Generate Material 3 supporting colors from
    // the brand accent, then override the colors
    // that must match the logo exactly.
    final scheme =
        ColorScheme.fromSeed(
          seedColor: TruckLinkColors.accent,
          brightness: Brightness.dark,
        ).copyWith(
          primary: TruckLinkColors.accent,
          onPrimary: TruckLinkColors.background,

          primaryContainer: const Color(0xFF16412F),
          onPrimaryContainer: const Color(0xFFCBFFE0),

          secondary: TruckLinkColors.accentSoft,
          onSecondary: TruckLinkColors.background,

          tertiary: TruckLinkColors.info,
          onTertiary: TruckLinkColors.background,

          surface: TruckLinkColors.surface,

          surfaceContainerLowest: TruckLinkColors.background,
          surfaceContainerLow: const Color(0xFF121E28),
          surfaceContainer: TruckLinkColors.card,
          surfaceContainerHigh: TruckLinkColors.elevated,
          surfaceContainerHighest: const Color(0xFF293946),

          onSurface: TruckLinkColors.textPrimary,
          onSurfaceVariant: TruckLinkColors.textSecondary,

          outline: TruckLinkColors.border,
          outlineVariant: TruckLinkColors.borderSubtle,

          error: TruckLinkColors.error,
          onError: TruckLinkColors.background,

          surfaceTint: Colors.transparent,
          shadow: Colors.black,
        );

    return ThemeData.from(colorScheme: scheme, useMaterial3: true).copyWith(
      // ======================================
      // GENERAL
      // ======================================
      scaffoldBackgroundColor: TruckLinkColors.background,

      canvasColor: TruckLinkColors.background,

      dividerColor: TruckLinkColors.borderSubtle,

      splashColor: TruckLinkColors.accent.withValues(alpha: 0.09),

      highlightColor: TruckLinkColors.accent.withValues(alpha: 0.05),

      // ======================================
      // APP BAR
      // ======================================
      appBarTheme: const AppBarThemeData(
        backgroundColor: TruckLinkColors.background,

        foregroundColor: TruckLinkColors.textPrimary,

        surfaceTintColor: Colors.transparent,

        elevation: 0,
        scrolledUnderElevation: 0,

        centerTitle: false,

        titleTextStyle: TextStyle(
          color: TruckLinkColors.textPrimary,
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),

        iconTheme: IconThemeData(color: TruckLinkColors.textPrimary, size: 24),

        actionsIconTheme: IconThemeData(color: TruckLinkColors.textPrimary),
      ),

      // ======================================
      // CARDS
      // ======================================
      cardTheme: CardThemeData(
        color: TruckLinkColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: TruckLinkColors.borderSubtle, width: 1),
        ),
      ),

      // ======================================
      // FILLED BUTTONS
      // ======================================
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TruckLinkColors.accent,
          foregroundColor: TruckLinkColors.background,
          disabledBackgroundColor: TruckLinkColors.elevated,
          disabledForegroundColor: TruckLinkColors.textSecondary,

          minimumSize: const Size(0, 48),

          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),

          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // ======================================
      // OUTLINED BUTTONS
      // ======================================
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TruckLinkColors.accent,

          side: const BorderSide(color: TruckLinkColors.border),

          minimumSize: const Size(0, 46),

          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // ======================================
      // TEXT BUTTONS
      // ======================================
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TruckLinkColors.accent,

          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      // ======================================
      // INPUT FIELDS
      // ======================================
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: TruckLinkColors.surface,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),

        labelStyle: const TextStyle(color: TruckLinkColors.textSecondary),

        hintStyle: const TextStyle(color: TruckLinkColors.textSecondary),

        floatingLabelStyle: const TextStyle(color: TruckLinkColors.accent),

        prefixIconColor: TruckLinkColors.accent,
        suffixIconColor: TruckLinkColors.textSecondary,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: TruckLinkColors.border),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: TruckLinkColors.border),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: TruckLinkColors.accent,
            width: 1.6,
          ),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: TruckLinkColors.error),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: TruckLinkColors.error,
            width: 1.6,
          ),
        ),
      ),

      // ======================================
      // LIST TILES
      // ======================================
      listTileTheme: ListTileThemeData(
        iconColor: TruckLinkColors.accent,
        textColor: TruckLinkColors.textPrimary,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ======================================
      // DIVIDERS
      // ======================================
      dividerTheme: const DividerThemeData(
        color: TruckLinkColors.borderSubtle,
        thickness: 1,
        space: 16,
      ),

      // ======================================
      // TABS
      // ======================================
      tabBarTheme: const TabBarThemeData(
        labelColor: TruckLinkColors.accent,

        unselectedLabelColor: TruckLinkColors.textSecondary,

        indicatorColor: TruckLinkColors.accent,

        dividerColor: TruckLinkColors.borderSubtle,
      ),

      // ======================================
      // NAVIGATION BAR
      // ======================================
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: TruckLinkColors.card,
        indicatorColor: Color(0xFF16412F),
        elevation: 0,
      ),

      // ======================================
      // DIALOGS
      // ======================================
      dialogTheme: DialogThemeData(
        backgroundColor: TruckLinkColors.card,
        surfaceTintColor: Colors.transparent,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),

      // ======================================
      // BOTTOM SHEETS
      // ======================================
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: TruckLinkColors.surface,
        modalBackgroundColor: TruckLinkColors.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),

      // ======================================
      // SLIDERS
      // ======================================
      sliderTheme: const SliderThemeData(
        activeTrackColor: TruckLinkColors.accent,
        inactiveTrackColor: TruckLinkColors.border,
        thumbColor: TruckLinkColors.accent,
        overlayColor: Color(0x3310EF78),
      ),

      // ======================================
      // PROGRESS INDICATORS
      // ======================================
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: TruckLinkColors.accent,
        linearTrackColor: TruckLinkColors.border,
        circularTrackColor: TruckLinkColors.border,
      ),

      // ======================================
      // TEXT SELECTION
      // ======================================
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: TruckLinkColors.accent,

        selectionColor: TruckLinkColors.accent.withValues(alpha: 0.25),

        selectionHandleColor: TruckLinkColors.accent,
      ),

      // ======================================
      // SNACKBARS
      // ======================================
      snackBarTheme: SnackBarThemeData(
        backgroundColor: TruckLinkColors.elevated,
        contentTextStyle: const TextStyle(color: TruckLinkColors.textPrimary),
        behavior: SnackBarBehavior.floating,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

// ============================================
// SHARED METRIC TILE
// ============================================

/// Reusable telemetry tile.
///
/// Public API preserved for existing Desktop
/// and Mobile code.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.title,
    required this.value,
    this.icon = Icons.speed,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),

            const SizedBox(height: 14),

            Text(title, style: theme.textTheme.bodyMedium),

            const SizedBox(height: 6),

            Text(value, style: theme.textTheme.headlineMedium),
          ],
        ),
      ),
    );
  }
}
