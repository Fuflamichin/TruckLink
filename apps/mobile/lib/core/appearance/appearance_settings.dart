import 'dart:convert';

import 'package:flutter/material.dart';

// ============================================
// TRUCKLINK ACCENT COLORS
// ============================================

enum TruckLinkAccent { green, blue, violet, amber, rose, ice }

extension TruckLinkAccentInfo on TruckLinkAccent {
  String get title => switch (this) {
    TruckLinkAccent.green => 'TruckLink Green',
    TruckLinkAccent.blue => 'Небесный',
    TruckLinkAccent.violet => 'Фиолетовый',
    TruckLinkAccent.amber => 'Янтарный',
    TruckLinkAccent.rose => 'Розовый',
    TruckLinkAccent.ice => 'Ледяной',
  };

  Color get color => switch (this) {
    TruckLinkAccent.green => const Color(0xFF10EF78),
    TruckLinkAccent.blue => const Color(0xFF40C9FF),
    TruckLinkAccent.violet => const Color(0xFFA78BFA),
    TruckLinkAccent.amber => const Color(0xFFFFB547),
    TruckLinkAccent.rose => const Color(0xFFFF6B8A),
    TruckLinkAccent.ice => const Color(0xFFF2F5F9),
  };
}

// ============================================
// NAVIGATION SIZE
// ============================================

enum TruckLinkNavigationSize { standard, compact }

extension TruckLinkNavigationSizeInfo on TruckLinkNavigationSize {
  String get title => switch (this) {
    TruckLinkNavigationSize.standard => 'Стандартная',
    TruckLinkNavigationSize.compact => 'Компактная',
  };

  double get bottomHeight => switch (this) {
    TruckLinkNavigationSize.standard => 76,
    TruckLinkNavigationSize.compact => 64,
  };

  double get groupHeight => switch (this) {
    TruckLinkNavigationSize.standard => 54,
    TruckLinkNavigationSize.compact => 48,
  };
}

// ============================================
// ACTIVE HIGHLIGHT INTENSITY
// ============================================

enum TruckLinkHighlightIntensity { soft, standard, vivid }

extension TruckLinkHighlightInfo on TruckLinkHighlightIntensity {
  String get title => switch (this) {
    TruckLinkHighlightIntensity.soft => 'Мягкая',
    TruckLinkHighlightIntensity.standard => 'Стандартная',
    TruckLinkHighlightIntensity.vivid => 'Яркая',
  };

  double get opacity => switch (this) {
    TruckLinkHighlightIntensity.soft => 0.12,
    TruckLinkHighlightIntensity.standard => 0.24,
    TruckLinkHighlightIntensity.vivid => 0.40,
  };
}

// ============================================
// CARD STYLE
// ============================================

enum TruckLinkCardStyle { filled, outlined, minimal }

extension TruckLinkCardStyleInfo on TruckLinkCardStyle {
  String get title => switch (this) {
    TruckLinkCardStyle.filled => 'Классический',
    TruckLinkCardStyle.outlined => 'С обводкой',
    TruckLinkCardStyle.minimal => 'Минималистичный',
  };
}

// ============================================
// CORNER ROUNDING
// ============================================

enum TruckLinkCornerStyle { soft, rounded, extraRounded }

extension TruckLinkCornerStyleInfo on TruckLinkCornerStyle {
  String get title => switch (this) {
    TruckLinkCornerStyle.soft => 'Небольшое',
    TruckLinkCornerStyle.rounded => 'Стандартное',
    TruckLinkCornerStyle.extraRounded => 'Максимальное',
  };

  double get cardRadius => switch (this) {
    TruckLinkCornerStyle.soft => 14,
    TruckLinkCornerStyle.rounded => 22,
    TruckLinkCornerStyle.extraRounded => 30,
  };

  double get navigationRadius => switch (this) {
    TruckLinkCornerStyle.soft => 22,
    TruckLinkCornerStyle.rounded => 40,
    TruckLinkCornerStyle.extraRounded => 60,
  };
}

// ============================================
// APPEARANCE SETTINGS MODEL
// ============================================

@immutable
class TruckLinkAppearanceSettings {
  const TruckLinkAppearanceSettings({
    this.accent = TruckLinkAccent.green,
    this.navigationSize = TruckLinkNavigationSize.standard,
    this.highlightIntensity = TruckLinkHighlightIntensity.standard,
    this.cardStyle = TruckLinkCardStyle.filled,
    this.cornerStyle = TruckLinkCornerStyle.rounded,
  });

  static const int schemaVersion = 1;

  static const TruckLinkAppearanceSettings defaults =
      TruckLinkAppearanceSettings();

  // ==========================================
  // SETTINGS VALUES
  // ==========================================

  final TruckLinkAccent accent;

  final TruckLinkNavigationSize navigationSize;

  final TruckLinkHighlightIntensity highlightIntensity;

  final TruckLinkCardStyle cardStyle;

  final TruckLinkCornerStyle cornerStyle;

  // ==========================================
  // DERIVED VALUES
  // ==========================================

  Color get accentColor => accent.color;

  double get cardRadius => cornerStyle.cardRadius;

  double get navigationRadius => cornerStyle.navigationRadius;

  double get bottomNavigationHeight => navigationSize.bottomHeight;

  double get groupNavigationHeight => navigationSize.groupHeight;

  double get highlightOpacity => highlightIntensity.opacity;

  // ==========================================
  // COPY WITH
  // ==========================================

  TruckLinkAppearanceSettings copyWith({
    TruckLinkAccent? accent,
    TruckLinkNavigationSize? navigationSize,
    TruckLinkHighlightIntensity? highlightIntensity,
    TruckLinkCardStyle? cardStyle,
    TruckLinkCornerStyle? cornerStyle,
  }) {
    return TruckLinkAppearanceSettings(
      accent: accent ?? this.accent,
      navigationSize: navigationSize ?? this.navigationSize,
      highlightIntensity: highlightIntensity ?? this.highlightIntensity,
      cardStyle: cardStyle ?? this.cardStyle,
      cornerStyle: cornerStyle ?? this.cornerStyle,
    );
  }

  // ==========================================
  // JSON SERIALIZATION
  // ==========================================

  Map<String, dynamic> toJson() {
    return {
      'version': schemaVersion,
      'accent': accent.name,
      'navigationSize': navigationSize.name,
      'highlightIntensity': highlightIntensity.name,
      'cardStyle': cardStyle.name,
      'cornerStyle': cornerStyle.name,
    };
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  // ==========================================
  // JSON DESERIALIZATION
  // ==========================================

  factory TruckLinkAppearanceSettings.fromJsonString(String source) {
    final decoded = jsonDecode(source);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid appearance settings');
    }

    if (decoded['version'] != schemaVersion) {
      throw const FormatException('Unsupported appearance settings version');
    }

    T readEnum<T extends Enum>(String field, List<T> values) {
      final raw = decoded[field];

      if (raw is! String) {
        throw FormatException('Invalid appearance field: $field');
      }

      for (final value in values) {
        if (value.name == raw) {
          return value;
        }
      }

      throw FormatException('Unknown appearance value: $field=$raw');
    }

    return TruckLinkAppearanceSettings(
      accent: readEnum('accent', TruckLinkAccent.values),
      navigationSize: readEnum(
        'navigationSize',
        TruckLinkNavigationSize.values,
      ),
      highlightIntensity: readEnum(
        'highlightIntensity',
        TruckLinkHighlightIntensity.values,
      ),
      cardStyle: readEnum('cardStyle', TruckLinkCardStyle.values),
      cornerStyle: readEnum('cornerStyle', TruckLinkCornerStyle.values),
    );
  }

  // ==========================================
  // EQUALITY
  // ==========================================

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TruckLinkAppearanceSettings &&
            other.accent == accent &&
            other.navigationSize == navigationSize &&
            other.highlightIntensity == highlightIntensity &&
            other.cardStyle == cardStyle &&
            other.cornerStyle == cornerStyle;
  }

  @override
  int get hashCode => Object.hash(
    accent,
    navigationSize,
    highlightIntensity,
    cardStyle,
    cornerStyle,
  );
}
