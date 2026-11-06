import 'package:shared_preferences/shared_preferences.dart';

import 'appearance_settings.dart';

// ============================================
// APPEARANCE SETTINGS STORAGE
// ============================================

class AppearanceSettingsStorage {
  AppearanceSettingsStorage({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  // ==========================================
  // STORAGE KEY
  // ==========================================

  static const String _storageKey = 'trucklink.appearance.settings.v1';

  // ==========================================
  // SHARED WRITE QUEUE
  // ==========================================

  // Multiple storage instances may be used by
  // different parts of the application.
  //
  // Keep their writes ordered so that the
  // latest user action is saved last.
  static Future<void> _pendingWrite = Future<void>.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _pendingWrite.then((_) => action());

    // An individual operation may fail,
    // but later writes must still be possible.
    _pendingWrite = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    return operation;
  }

  // ==========================================
  // LOAD
  // ==========================================

  /// Returns null if no valid saved settings
  /// are available.
  ///
  /// The caller can then use the standard
  /// TruckLinkAppearanceSettings.defaults.
  Future<TruckLinkAppearanceSettings?> load() async {
    // Wait for previously scheduled writes.
    await _pendingWrite;

    final source = await _preferences.getString(_storageKey);

    if (source == null || source.isEmpty) {
      return null;
    }

    try {
      return TruckLinkAppearanceSettings.fromJsonString(source);
    } on FormatException {
      // Never crash startup because of
      // damaged or outdated preferences.
      return null;
    }
  }

  // ==========================================
  // SAVE
  // ==========================================

  Future<void> save(TruckLinkAppearanceSettings settings) {
    // Serialize immediately to preserve the
    // exact state passed into this operation.
    final encoded = settings.toJsonString();

    return _enqueue(() => _preferences.setString(_storageKey, encoded));
  }

  // ==========================================
  // RESET
  // ==========================================

  /// Removes the custom appearance settings.
  ///
  /// On the next launch, the application
  /// will use the default TruckLink theme.
  Future<void> reset() {
    return _enqueue(() => _preferences.remove(_storageKey));
  }
}
