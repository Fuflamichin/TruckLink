import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'job_history_entry.dart';

// ============================================
// JOB HISTORY STORAGE
// ============================================

class JobHistoryStore extends ChangeNotifier {
  JobHistoryStore._() : _preferences = SharedPreferencesAsync() {
    _loading = _load();
  }

  // One shared store for the mobile app.
  static final JobHistoryStore instance = JobHistoryStore._();

  static const String _storageKey = 'trucklink_job_history_v1';

  static const int maxEntries = 500;

  final SharedPreferencesAsync _preferences;

  late final Future<void> _loading;

  Future<void> _writeQueue = Future<void>.value();

  final List<JobHistoryEntry> _entries = [];

  bool _loaded = false;
  bool _loadFailed = false;

  String? _error;

  // ==========================================
  // PUBLIC STATE
  // ==========================================

  bool get isLoading => !_loaded;

  String? get error => _error;

  Future<void> get ready => _loading;

  List<JobHistoryEntry> get entries =>
      List<JobHistoryEntry>.unmodifiable(_entries);

  int get deliveredCount => _entries.where((entry) => entry.isDelivered).length;

  int get cancelledCount => _entries.where((entry) => entry.isCancelled).length;

  // ==========================================
  // LOAD SAVED ENTRIES
  // ==========================================

  Future<void> _load() async {
    try {
      final raw = await _preferences.getString(_storageKey);

      if (raw == null || raw.isEmpty) {
        return;
      }

      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        throw const FormatException('History storage is not a list');
      }

      final loaded = <JobHistoryEntry>[];
      final ids = <String>{};

      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        try {
          final entry = JobHistoryEntry.fromJson(item);

          if (ids.add(entry.id)) {
            loaded.add(entry);
          }
        } catch (error) {
          debugPrint(
            'TruckLink: skipped invalid history '
            'entry: $error',
          );
        }
      }

      loaded.sort((a, b) => b.completedAtUtc.compareTo(a.completedAtUtc));

      _entries
        ..clear()
        ..addAll(loaded.take(maxEntries));
    } catch (error) {
      // Do not overwrite unreadable existing data.
      _loadFailed = true;
      _error = 'Не удалось загрузить историю рейсов';

      debugPrint('TruckLink history load error: $error');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  // ==========================================
  // SAVE CONFIRMED DELIVERY
  // ==========================================

  Future<void> addEntry(JobHistoryEntry entry) async {
    // Ensure data is loaded before inserting.
    await _loading;

    if (_loadFailed) {
      throw StateError('History storage could not be loaded');
    }

    // WebSocket messages may be retried.
    // Never save the same event ID twice.
    if (_entries.any((existing) => existing.id == entry.id)) {
      return;
    }

    if (!entry.isDelivered && !entry.isCancelled) {
      return;
    }

    _entries.insert(0, entry);

    _entries.sort((a, b) => b.completedAtUtc.compareTo(a.completedAtUtc));

    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }

    notifyListeners();

    // Capture the payload now. Writes themselves
    // are performed sequentially.
    final encoded = jsonEncode(_entries.map((item) => item.toJson()).toList());

    final write = _writeQueue.then(
      (_) => _preferences.setString(_storageKey, encoded),
    );

    // Keep the write queue usable even when
    // an individual write fails.
    _writeQueue = write.catchError((Object error, StackTrace stackTrace) {
      debugPrint('TruckLink history write queue: $error');
    });

    try {
      await write;

      if (_error != null) {
        _error = null;
        notifyListeners();
      }

      debugPrint('TruckLink: saved delivery ${entry.id}');
    } catch (error) {
      _error = 'Не удалось сохранить последнее изменение';

      notifyListeners();

      rethrow;
    }
  }
}
