import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:network_protocol/finance_protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FinanceStore extends ChangeNotifier {
  FinanceStore._() {
    _loading = _load();
  }

  static final FinanceStore instance = FinanceStore._();

  static const String _storageKey = 'trucklink_finance_events_v1';

  static const int maxEntries = 1000;

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  final List<FinanceEvent> _entries = [];

  late final Future<void> _loading;

  Future<void> _writeQueue = Future<void>.value();

  bool _loaded = false;
  bool _loadFailed = false;

  String? _error;

  bool get isLoading => !_loaded;
  String? get error => _error;

  Future<void> get ready => _loading;

  List<FinanceEvent> get entries => List<FinanceEvent>.unmodifiable(_entries);

  // ==========================================
  // LOAD
  // ==========================================

  Future<void> _load() async {
    try {
      final saved = await _preferences.getString(_storageKey);

      if (saved == null || saved.isEmpty) {
        return;
      }

      final decoded = jsonDecode(saved);

      if (decoded is! List) {
        throw const FormatException('Finance storage is not a list');
      }

      final restored = <FinanceEvent>[];
      final ids = <String>{};

      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        try {
          final event = FinanceEvent.fromJson(item);

          if (ids.add(event.id)) {
            restored.add(event);
          }
        } catch (error) {
          debugPrint(
            'TruckLink: skipped invalid finance '
            'entry: $error',
          );
        }
      }

      restored.sort((a, b) => b.occurredAtUtc.compareTo(a.occurredAtUtc));

      _entries
        ..clear()
        ..addAll(restored.take(maxEntries));
    } catch (error) {
      _loadFailed = true;
      _error = 'Не удалось загрузить финансовую историю';

      debugPrint('TruckLink finance load error: $error');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  // ==========================================
  // INSERT REAL GAME EVENT
  // ==========================================

  Future<void> addEvent(FinanceEvent event) async {
    await _loading;

    if (_loadFailed) {
      throw StateError('Finance storage could not be loaded');
    }

    if (_entries.any((existing) => existing.id == event.id)) {
      return;
    }

    _entries.insert(0, event);

    _entries.sort((a, b) => b.occurredAtUtc.compareTo(a.occurredAtUtc));

    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }

    notifyListeners();

    final encoded = jsonEncode(_entries.map((item) => item.toJson()).toList());

    // Serialize writes so rapidly arriving
    // events cannot overwrite each other
    // in the wrong order.
    final write = _writeQueue.then(
      (_) => _preferences.setString(_storageKey, encoded),
    );

    _writeQueue = write.catchError((Object error, StackTrace stackTrace) {
      debugPrint('TruckLink finance queue error: $error');
    });

    try {
      await write;

      if (_error != null) {
        _error = null;
        notifyListeners();
      }
    } catch (error) {
      _error = 'Не удалось сохранить финансовую операцию';

      notifyListeners();
      rethrow;
    }
  }

  // ==========================================
  // PER-GAME QUERIES
  // ==========================================

  List<FinanceEvent> forGame(int gameId) {
    return List<FinanceEvent>.unmodifiable(
      _entries.where((event) => event.gameId == gameId),
    );
  }

  int deliveredRevenueForGame(int gameId) {
    return _entries
        .where(
          (event) =>
              event.gameId == gameId &&
              event.kind == FinanceEventKind.deliveredRevenue,
        )
        .fold<int>(0, (total, event) => total + event.amount);
  }

  int expensesForGame(int gameId) {
    return _entries
        .where((event) => event.gameId == gameId && event.amount < 0)
        .fold<int>(0, (total, event) => total + event.amount.abs());
  }

  int observedNetForGame(int gameId) {
    return _entries
        .where((event) => event.gameId == gameId)
        .fold<int>(0, (total, event) => total + event.amount);
  }
}
