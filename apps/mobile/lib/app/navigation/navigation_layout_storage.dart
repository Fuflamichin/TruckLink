import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// ============================================
// CUSTOM GROUP (COMBINED TAB)
// ============================================

/// A user-created tab containing at least two existing navigation items.
///
/// [memberIds] contains NavigationItemConfig.id values, not screen titles.
/// Nested groups are deliberately unsupported in the first implementation.
class SavedNavigationGroup {
  SavedNavigationGroup({
    required String id,
    required String title,
    required Iterable<String> memberIds,
  }) : id = id.trim(),
       title = title.trim(),
       memberIds = List<String>.unmodifiable(_normalizeMembers(memberIds)) {
    if (!this.id.startsWith(idPrefix) || this.id.length <= idPrefix.length) {
      throw ArgumentError.value(
        id,
        'id',
        'Group ID must start with "$idPrefix" and have a suffix',
      );
    }
    if (this.title.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Title cannot be empty');
    }
    if (this.memberIds.length < 2) {
      throw ArgumentError.value(
        memberIds,
        'memberIds',
        'A group must contain at least two different items',
      );
    }
  }

  static const String idPrefix = 'group:';

  final String id;
  final String title;
  final List<String> memberIds;

  static List<String> _normalizeMembers(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];

    for (final raw in values) {
      final id = raw.trim();
      if (id.isEmpty || id == '__more__' || id.startsWith(idPrefix)) {
        continue;
      }
      if (seen.add(id)) result.add(id);
    }

    return result;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'members': memberIds,
  };

  factory SavedNavigationGroup.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid navigation group object');
    }

    final id = value['id'];
    final title = value['title'];
    final members = value['members'];

    if (id is! String ||
        title is! String ||
        members is! List ||
        members.any((member) => member is! String)) {
      throw const FormatException('Invalid navigation group fields');
    }

    try {
      return SavedNavigationGroup(
        id: id,
        title: title,
        memberIds: members.cast<String>(),
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid navigation group: $error');
    }
  }
}

// ============================================
// SAVED NAVIGATION LAYOUT (VERSION 2)
// ============================================

/// The current placement of items, including user-created combined tabs.
///
/// A group is represented by its `group:...` ID in [bottomIds] or [moreIds].
/// Its members must not appear as independent items at the same time.
///
/// The original bottomIds/moreIds/hiddenIds API is preserved for AppShell
/// and NavigationSettingsScreen from TruckLink v0.6.3.
class SavedNavigationLayout {
  SavedNavigationLayout._({
    required this.bottomIds,
    required this.moreIds,
    required this.hiddenIds,
    required this.groups,
  });

  final List<String> bottomIds;
  final List<String> moreIds;
  final List<String> hiddenIds;
  final List<SavedNavigationGroup> groups;

  static const int schemaVersion = 2;

  factory SavedNavigationLayout({
    required Iterable<String> bottomIds,
    required Iterable<String> moreIds,
    Iterable<String> hiddenIds = const <String>[],
    Iterable<SavedNavigationGroup> groups = const <SavedNavigationGroup>[],
  }) {
    final groupList = List<SavedNavigationGroup>.of(groups);
    final groupIds = <String>{};
    final allMembers = <String>{};

    for (final group in groupList) {
      if (!groupIds.add(group.id)) {
        throw ArgumentError.value(group.id, 'groups', 'Duplicate group ID');
      }
      for (final member in group.memberIds) {
        if (!allMembers.add(member)) {
          throw ArgumentError.value(
            member,
            'groups',
            'The same item cannot belong to multiple groups',
          );
        }
      }
    }

    final seen = <String>{};

    List<String> normalize(
      Iterable<String> values, {
      required bool allowGroups,
    }) {
      final result = <String>[];
      for (final raw in values) {
        final id = raw.trim();
        if (id.isEmpty || id == '__more__') continue;
        if (id.startsWith(SavedNavigationGroup.idPrefix) &&
            (!allowGroups || !groupIds.contains(id))) {
          continue;
        }
        if (seen.add(id)) result.add(id);
      }
      return result;
    }

    final bottom = normalize(bottomIds, allowGroups: true);
    final more = normalize(moreIds, allowGroups: true);
    final hidden = normalize(hiddenIds, allowGroups: false);

    // Only groups actually placed in bottom/more are active.
    final placedIds = <String>{...bottom, ...more};
    final activeGroups = groupList
        .where((group) => placedIds.contains(group.id))
        .toList(growable: false);
    final activeMembers = <String>{
      for (final group in activeGroups) ...group.memberIds,
    };

    // If an editor accidentally leaves a grouped item in a regular list,
    // the group wins. The same screen cannot appear twice.
    bottom.removeWhere(activeMembers.contains);
    more.removeWhere(activeMembers.contains);
    hidden.removeWhere(activeMembers.contains);

    return SavedNavigationLayout._(
      bottomIds: List<String>.unmodifiable(bottom),
      moreIds: List<String>.unmodifiable(more),
      hiddenIds: List<String>.unmodifiable(hidden),
      groups: List<SavedNavigationGroup>.unmodifiable(activeGroups),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'bottom': bottomIds,
    'more': moreIds,
    'hidden': hiddenIds,
    'groups': [for (final group in groups) group.toJson()],
  };

  String toJsonString() => jsonEncode(toJson());

  /// Reads both legacy v1 JSON and new v2 JSON.
  factory SavedNavigationLayout.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid navigation layout');
    }

    final version = decoded['version'];
    if (version != 1 && version != schemaVersion) {
      throw const FormatException('Unsupported navigation layout version');
    }

    List<String> readIds(String key) {
      final value = decoded[key];
      if (value is! List || value.any((id) => id is! String)) {
        throw FormatException('Invalid navigation field: $key');
      }
      return value.cast<String>();
    }

    final parsedGroups = <SavedNavigationGroup>[];
    if (version == schemaVersion) {
      final rawGroups = decoded['groups'];
      if (rawGroups is! List) {
        throw const FormatException('Invalid navigation groups field');
      }
      for (final group in rawGroups) {
        parsedGroups.add(SavedNavigationGroup.fromJson(group));
      }
    }

    try {
      return SavedNavigationLayout(
        bottomIds: readIds('bottom'),
        moreIds: readIds('more'),
        hiddenIds: readIds('hidden'),
        groups: parsedGroups,
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid navigation layout: $error');
    }
  }
}

// ============================================
// PERSISTENT STORAGE WITH V1 COMPATIBILITY
// ============================================

class NavigationLayoutStorage {
  NavigationLayoutStorage({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  static const String _keyV1 = 'trucklink.navigation.layout.v1';
  static const String _keyV2 = 'trucklink.navigation.layout.v2';

  // Shared between instances used by AppShell and SettingsScreen.
  // A failed write does not prevent subsequent operations.
  static Future<void> _pendingWrite = Future<void>.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _pendingWrite.then((_) => action());
    _pendingWrite = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation;
  }

  Future<SavedNavigationLayout?> load() async {
    await _pendingWrite;

    final current = await _preferences.getString(_keyV2);
    if (current != null && current.isNotEmpty) {
      try {
        return SavedNavigationLayout.fromJsonString(current);
      } on FormatException {
        // A damaged v2 entry may still have a usable v1 predecessor.
      }
    }

    final legacy = await _preferences.getString(_keyV1);
    if (legacy != null && legacy.isNotEmpty) {
      try {
        return SavedNavigationLayout.fromJsonString(legacy);
      } on FormatException {
        return null;
      }
    }

    return null;
  }

  Future<void> save(SavedNavigationLayout layout) {
    final encoded = layout.toJsonString();
    return _enqueue(() => _preferences.setString(_keyV2, encoded));
  }

  /// Both versions must be removed so old settings cannot reappear.
  Future<void> reset() {
    return _enqueue(() async {
      await _preferences.remove(_keyV2);
      await _preferences.remove(_keyV1);
    });
  }
}
