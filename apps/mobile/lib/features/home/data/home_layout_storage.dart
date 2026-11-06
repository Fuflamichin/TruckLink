import 'package:shared_preferences/shared_preferences.dart';

/// Persistent storage for the TruckLink home dashboard.
///
/// Stores the IDs of visible telemetry cards in their
/// display order.
///
/// This class does not depend on Flutter widgets,
/// WebSocket connections or the HomeMetric enum.
///
/// Example stored values:
/// ['speed', 'speedLimit', 'fuelPercent', 'odometer']
///
/// An empty list is valid: it means the user has
/// intentionally removed all home dashboard cards.
class HomeLayoutStorage {
  HomeLayoutStorage({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  // ==========================================
  // STORAGE CONFIGURATION
  // ==========================================

  /// Versioned key allows future changes to the
  /// dashboard configuration format.
  static const String _storageKey = 'trucklink.home.visible_metrics.v1';

  /// Ensures that rapid successive saves are
  /// written in the same order they were requested.
  Future<void> _lastWrite = Future<void>.value();

  // ==========================================
  // LOAD LAYOUT
  // ==========================================

  /// Returns:
  ///
  /// null  - no saved layout exists yet;
  /// []    - the user saved an empty dashboard;
  /// [...] - saved card IDs in display order.
  ///
  /// The caller is responsible for validating IDs
  /// against the available HomeMetric enum values.
  Future<List<String>?> loadMetricIds() async {
    // Do not read outdated data while a write
    // from this storage instance is still pending.
    await _lastWrite;

    final values = await _preferences.getStringList(_storageKey);

    if (values == null) {
      return null;
    }

    return List<String>.unmodifiable(values);
  }

  // ==========================================
  // SAVE LAYOUT
  // ==========================================

  /// Saves the visible card IDs in their current
  /// order.
  ///
  /// Duplicate and empty IDs are ignored.
  ///
  /// A defensive copy is created immediately,
  /// so the caller can safely modify its list
  /// while the write is pending.
  Future<void> saveMetricIds(Iterable<String> metricIds) {
    final uniqueIds = <String>{};
    final values = <String>[];

    for (final rawId in metricIds) {
      final id = rawId.trim();

      if (id.isEmpty) {
        continue;
      }

      if (uniqueIds.add(id)) {
        values.add(id);
      }
    }

    final snapshot = List<String>.unmodifiable(values);

    // Queue writes to avoid an older layout
    // overwriting a newer one.
    final write = _lastWrite.then(
      (_) => _preferences.setStringList(_storageKey, snapshot),
    );

    // Keep the queue usable even if one write
    // fails. The caller still receives the error
    // through the original `write` future.
    _lastWrite = write.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    return write;
  }

  // ==========================================
  // RESET LAYOUT
  // ==========================================

  /// Removes the saved layout.
  ///
  /// The next load will return null, allowing
  /// the UI to restore its default cards.
  Future<void> reset() {
    final operation = _lastWrite.then((_) => _preferences.remove(_storageKey));

    _lastWrite = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    return operation;
  }
}
