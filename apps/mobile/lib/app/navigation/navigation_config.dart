import 'package:flutter/material.dart';

// ============================================
// TRUCKLINK SECTIONS
// ============================================

enum TruckLinkSection {
  home,
  instruments,
  truck,
  finances,
  job,
  map,
  statistics,
}

extension TruckLinkSectionInfo on TruckLinkSection {
  String get title => switch (this) {
    TruckLinkSection.home => 'Главная',
    TruckLinkSection.instruments => 'Приборы',
    TruckLinkSection.truck => 'Грузовик',
    TruckLinkSection.finances => 'Финансы',
    TruckLinkSection.job => 'Заказ',
    TruckLinkSection.map => 'Карта',
    TruckLinkSection.statistics => 'Статистика',
  };

  String get shortTitle => switch (this) {
    TruckLinkSection.home => 'Главная',
    TruckLinkSection.instruments => 'Приборы',
    TruckLinkSection.truck => 'Грузовик',
    TruckLinkSection.finances => 'Финансы',
    TruckLinkSection.job => 'Заказ',
    TruckLinkSection.map => 'Карта',
    TruckLinkSection.statistics => 'Статистика',
  };

  IconData get icon => switch (this) {
    TruckLinkSection.home => Icons.space_dashboard_outlined,
    TruckLinkSection.instruments => Icons.speed,
    TruckLinkSection.truck => Icons.local_shipping_outlined,
    TruckLinkSection.finances => Icons.account_balance_wallet_outlined,
    TruckLinkSection.job => Icons.inventory_2_outlined,
    TruckLinkSection.map => Icons.map_outlined,
    TruckLinkSection.statistics => Icons.bar_chart_outlined,
  };
}

// ============================================
// NAVIGATION ITEM
// ============================================

@immutable
class NavigationItemConfig {
  const NavigationItemConfig({
    required this.id,
    required this.title,
    required this.sections,
    this.pinned = false,
    this.visible = true,
  });

  /// Stable identifier used by settings and storage.
  final String id;

  /// Display title of this navigation item.
  final String title;

  /// One section for a normal item.
  /// Multiple sections for a combined group.
  final List<TruckLinkSection> sections;

  /// Whether the item is in the bottom bar.
  final bool pinned;

  /// Whether the item is available in navigation.
  final bool visible;

  bool get isGroup => sections.length > 1;

  IconData get icon {
    if (isGroup || sections.isEmpty) {
      return Icons.layers_outlined;
    }

    return sections.first.icon;
  }

  NavigationItemConfig copyWith({
    String? title,
    List<TruckLinkSection>? sections,
    bool? pinned,
    bool? visible,
  }) {
    return NavigationItemConfig(
      id: id,
      title: title ?? this.title,
      sections: sections ?? this.sections,
      pinned: pinned ?? this.pinned,
      visible: visible ?? this.visible,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'sections': sections.map((e) => e.name).toList(),
      'pinned': pinned,
      'visible': visible,
    };
  }

  factory NavigationItemConfig.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];

    if (rawSections is! List) {
      throw const FormatException('Navigation sections must be a list.');
    }

    return NavigationItemConfig(
      id: json['id'] as String,
      title: json['title'] as String,
      sections: rawSections
          .map((name) => TruckLinkSection.values.byName(name as String))
          .toList(growable: false),
      pinned: json['pinned'] as bool? ?? false,
      visible: json['visible'] as bool? ?? true,
    );
  }
}

// ============================================
// NAVIGATION LAYOUT
// ============================================

@immutable
class NavigationLayout {
  const NavigationLayout({required this.items});

  /// Full ordered list, including hidden items.
  final List<NavigationItemConfig> items;

  /// Four pinned items + an automatic More button.
  static const int maxPinnedItems = 4;

  static const NavigationLayout defaultLayout = NavigationLayout(
    items: [
      NavigationItemConfig(
        id: 'home',
        title: 'Главная',
        sections: [TruckLinkSection.home],
        pinned: true,
      ),
      NavigationItemConfig(
        id: 'instruments',
        title: 'Приборы',
        sections: [TruckLinkSection.instruments],
        pinned: true,
      ),
      NavigationItemConfig(
        id: 'truck',
        title: 'Грузовик',
        sections: [TruckLinkSection.truck],
        pinned: true,
      ),
      NavigationItemConfig(
        id: 'finances',
        title: 'Финансы',
        sections: [TruckLinkSection.finances],
      ),
      NavigationItemConfig(
        id: 'job',
        title: 'Заказ',
        sections: [TruckLinkSection.job],
        pinned: true,
      ),
      NavigationItemConfig(
        id: 'map',
        title: 'Карта',
        sections: [TruckLinkSection.map],
      ),
      NavigationItemConfig(
        id: 'statistics',
        title: 'Статистика',
        sections: [TruckLinkSection.statistics],
      ),
    ],
  );

  // ==========================================
  // VISIBLE NAVIGATION
  // ==========================================

  List<NavigationItemConfig> get bottomItems {
    return items
        .where((item) => item.visible && item.pinned)
        .toList(growable: false);
  }

  List<NavigationItemConfig> get moreItems {
    return items
        .where((item) => item.visible && !item.pinned)
        .toList(growable: false);
  }

  List<NavigationItemConfig> get visibleItems {
    return items.where((item) => item.visible).toList(growable: false);
  }

  NavigationItemConfig? findById(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }

    return null;
  }

  // ==========================================
  // VALIDATION
  // ==========================================

  List<String> validate() {
    final errors = <String>[];
    final ids = <String>{};
    final assignedSections = <TruckLinkSection>{};

    for (final item in items) {
      if (item.id.trim().isEmpty) {
        errors.add('Navigation item has an empty ID.');
      }

      if (!ids.add(item.id)) {
        errors.add('Duplicate navigation ID: ${item.id}');
      }

      if (item.sections.isEmpty) {
        errors.add('Empty navigation item: ${item.id}');
      }

      for (final section in item.sections) {
        if (!assignedSections.add(section)) {
          errors.add(
            'Section assigned more than once: '
            '${section.name}',
          );
        }
      }
    }

    if (bottomItems.length > maxPinnedItems) {
      errors.add('Too many pinned navigation items.');
    }

    final home = items.where(
      (item) =>
          item.visible &&
          item.pinned &&
          item.sections.length == 1 &&
          item.sections.first == TruckLinkSection.home,
    );

    if (home.isEmpty) {
      errors.add('Home must remain a pinned navigation item.');
    }

    for (final section in TruckLinkSection.values) {
      if (!assignedSections.contains(section)) {
        errors.add('Missing navigation section: ${section.name}');
      }
    }

    return errors;
  }

  bool get isValid => validate().isEmpty;

  // ==========================================
  // SERIALIZATION
  // ==========================================

  Map<String, Object?> toJson() {
    return {'schemaVersion': 1, 'items': items.map((e) => e.toJson()).toList()};
  }

  factory NavigationLayout.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported navigation schema.');
    }

    final rawItems = json['items'];

    if (rawItems is! List) {
      throw const FormatException('Navigation items must be a list.');
    }

    final layout = NavigationLayout(
      items: rawItems
          .map((value) {
            if (value is! Map) {
              throw const FormatException('Invalid navigation item.');
            }

            return NavigationItemConfig.fromJson(
              Map<String, dynamic>.from(value),
            );
          })
          .toList(growable: false),
    );

    final errors = layout.validate();

    if (errors.isNotEmpty) {
      throw FormatException(errors.join('; '));
    }

    return layout;
  }
}
