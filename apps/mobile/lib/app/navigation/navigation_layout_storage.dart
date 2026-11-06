import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// ============================================
// SAVED NAVIGATION LAYOUT
// ============================================

/// User-selected arrangement of navigation items.
///
/// bottomIds:
///   Sections pinned to the bottom navigation.
///
/// moreIds:
///   Sections displayed inside the "Ещё" page.
///
/// hiddenIds:
///   Sections hidden from normal navigation.
///
/// Each list preserves the user's chosen order.
///
/// The special "Ещё" button is managed by
/// AppShell and should not be stored here.
class SavedNavigationLayout {
  SavedNavigationLayout._({
    required this.bottomIds,
    required this.moreIds,
    required this.hiddenIds,
  });

  final List<String> bottomIds;
  final List<String> moreIds;
  final List<String> hiddenIds;

  // ==========================================
  // CREATE VALID LAYOUT
  // ==========================================

  factory SavedNavigationLayout({
    required Iterable<String> bottomIds,
    required Iterable<String> moreIds,
    Iterable<String> hiddenIds = const [],
  }) {
    final usedIds = <String>{};

    List<String> normalize(Iterable<String> ids) {
      final result = <String>[];

      for (final rawId in ids) {
        final id = rawId.trim();

        if (id.isEmpty || id == '__more__') {
          continue;
        }

        // A section can exist in only one place.
        if (!usedIds.add(id)) {
          continue;
        }

        result.add(id);
      }

      return List<String>.unmodifiable(result);
    }

    // Order matters:
    // bottom takes priority over more,
    // and more takes priority over hidden.
    final bottom = normalize(bottomIds);
    final more = normalize(moreIds);
    final hidden = normalize(hiddenIds);

    return SavedNavigationLayout._(
      bottomIds: bottom,
      moreIds: more,
      hiddenIds: hidden,
    );
  }

  // ==========================================
  // SERIALIZATION
  // ==========================================

  static const int schemaVersion = 1;

  Map<String, dynamic> toJson() {
    return {
      'version': schemaVersion,
      'bottom': bottomIds,
      'more': moreIds,
      'hidden': hiddenIds,
    };
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  // ==========================================
  // DESERIALIZATION
  // ==========================================

  factory SavedNavigationLayout.fromJsonString(String source) {
    final decoded = jsonDecode(source);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid navigation layout');
    }

    if (decoded['version'] != schemaVersion) {
      throw const FormatException('Unsupported navigation layout version');
    }

    List<String> readIds(String key) {
      final value = decoded[key];

      if (value is! List || value.any((item) => item is! String)) {
        throw FormatException('Invalid navigation field: $key');
      }

      return value.cast<String>();
    }

    return SavedNavigationLayout(
      bottomIds: readIds('bottom'),
      moreIds: readIds('more'),
      hiddenIds: readIds('hidden'),
    );
  }
}

// ============================================
// NAVIGATION LAYOUT STORAGE
// ============================================

/// Stores navigation preferences locally.
///
/// Does not depend on:
/// - Flutter widgets
/// - TelemetryConnection
/// - Windows Hub
/// - ETS2 / ATS
///
/// This storage will be connected to
/// NavigationLayout and SettingsScreen
/// during the next development steps.
class NavigationLayoutStorage {
  NavigationLayoutStorage({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  // ==========================================
  // STORAGE KEY
  // ==========================================

  static const String _storageKey = 'trucklink.navigation.layout.v1';

  // Queue writes to prevent older layouts
  // from overwriting newer ones.
  Future<void> _lastWrite = Future<void>.value();

  // ==========================================
  // LOAD
  // ==========================================

  /// Returns null when:
  /// - no layout has been saved;
  /// - the stored JSON is invalid;
  /// - the stored schema version is unsupported.
  ///
  /// A missing layout means the application
  /// should use NavigationLayout.defaultLayout.
  Future<SavedNavigationLayout?> load() async {
    await _lastWrite;

    final source = await _preferences.getString(_storageKey);

    if (source == null || source.isEmpty) {
      return null;
    }

    try {
      return SavedNavigationLayout.fromJsonString(source);
    } on FormatException {
      // Keep saved preferences untouched.
      // The app can use its default layout.
      return null;
    }
  }

  // ==========================================
  // SAVE
  // ==========================================

  /// Persists all navigation areas together.
  ///
  /// Writing one JSON value prevents a mix of
  /// partially updated bottom/more/hidden lists.
  Future<void> save(SavedNavigationLayout layout) {
    final serialized = layout.toJsonString();

    final write = _lastWrite.then(
      (_) => _preferences.setString(_storageKey, serialized),
    );

    // Keep the queue usable after an error.
    // The returned write Future still exposes
    // the original failure to its caller.
    _lastWrite = write.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    return write;
  }

  // ==========================================
  // RESET
  // ==========================================

  /// Clears the user's navigation preferences.
  ///
  /// After reset, the app can restore
  /// NavigationLayout.defaultLayout.
  Future<void> reset() {
    final operation = _lastWrite.then((_) => _preferences.remove(_storageKey));

    _lastWrite = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    return operation;
  }
}
