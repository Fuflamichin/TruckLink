import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

// ============================================
// TRUCKLINK HUB EVENT JOURNAL v0.8.4
// ============================================

class HubEventJournal {
  HubEventJournal._({required Directory directory, required this.maxEvents})
    : _directory = directory;

  static const int defaultMaxEvents = 1200;

  static const int _formatVersion = 1;

  final Directory _directory;
  final int maxEvents;

  // Insertion-ordered map:
  // event ID -> original WebSocket JSON message.
  final Map<String, String> _events = {};

  Future<void> _writeQueue = Future<void>.value();

  int _generation = 0;

  // ==========================================
  // CREATE / LOAD
  // ==========================================

  static Future<HubEventJournal> open({
    Directory? directory,
    int maxEvents = defaultMaxEvents,
  }) async {
    if (maxEvents < 1) {
      throw ArgumentError.value(maxEvents, 'maxEvents');
    }

    final base = directory ?? _defaultDirectory();

    final journal = HubEventJournal._(directory: base, maxEvents: maxEvents);

    await journal._load();
    return journal;
  }

  // ==========================================
  // DEFAULT WINDOWS STORAGE
  // ==========================================

  static Directory _defaultDirectory() {
    final localAppData = Platform.environment['LOCALAPPDATA'];

    if (localAppData != null && localAppData.trim().isNotEmpty) {
      return Directory(
        '$localAppData'
        '${Platform.pathSeparator}TruckLink',
      );
    }

    return Directory(
      '${Directory.current.path}'
      '${Platform.pathSeparator}.trucklink',
    );
  }

  // ==========================================
  // FILE LOCATIONS
  // ==========================================

  File get _slotA => File(
    '${_directory.path}'
    '${Platform.pathSeparator}events_a.json',
  );

  File get _slotB => File(
    '${_directory.path}'
    '${Platform.pathSeparator}events_b.json',
  );

  // ==========================================
  // LOAD MOST RECENT VALID SNAPSHOT
  // ==========================================

  Future<void> _load() async {
    await _directory.create(recursive: true);

    final snapshots = <_JournalSnapshot>[];

    var existingFiles = 0;

    for (final file in [_slotA, _slotB]) {
      if (!await file.exists()) {
        continue;
      }

      existingFiles++;

      try {
        final content = await file.readAsString();

        final snapshot = _decodeSnapshot(content);

        snapshots.add(snapshot);
      } catch (error) {
        debugPrint(
          'TruckLink: damaged journal slot '
          '${file.path}: $error',
        );
      }
    }

    // Do not silently overwrite a completely
    // unreadable existing journal.
    if (existingFiles > 0 && snapshots.isEmpty) {
      throw StateError('Cannot read the existing Hub event journal');
    }

    if (snapshots.isEmpty) {
      debugPrint('TruckLink: created empty event journal');
      return;
    }

    snapshots.sort((a, b) => b.generation.compareTo(a.generation));

    final latest = snapshots.first;

    _generation = latest.generation;

    for (final record in latest.records) {
      _events[record.id] = record.message;
    }

    _trim();

    debugPrint(
      'TruckLink: restored ${_events.length} '
      'journal events',
    );
  }

  // ==========================================
  // DECODE SNAPSHOT
  // ==========================================

  _JournalSnapshot _decodeSnapshot(String content) {
    final decoded = jsonDecode(content);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid journal document');
    }

    if (decoded['version'] != _formatVersion) {
      throw const FormatException('Unsupported journal version');
    }

    final generation = decoded['generation'];
    final rawEvents = decoded['events'];

    if (generation is! int || generation < 0 || rawEvents is! List) {
      throw const FormatException('Invalid journal structure');
    }

    final records = <_ArchivedEvent>[];
    final ids = <String>{};

    for (final value in rawEvents) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid journal event');
      }

      final id = value['id'];
      final message = value['message'];

      if (id is! String ||
          id.isEmpty ||
          message is! String ||
          message.isEmpty) {
        throw const FormatException('Missing journal event data');
      }

      if (ids.add(id)) {
        records.add(_ArchivedEvent(id: id, message: message));
      }
    }

    return _JournalSnapshot(generation: generation, records: records);
  }

  // ==========================================
  // ADD UNIQUE EVENT
  // ==========================================

  Future<bool> add({required String id, required String message}) async {
    if (id.trim().isEmpty ||
        id.length > 160 ||
        message.isEmpty ||
        message.length > 65536) {
      throw ArgumentError('Invalid event journal entry');
    }

    if (_events.containsKey(id)) {
      return false;
    }

    // Update memory before scheduling a write.
    // A sync request can then see this event
    // once queued writes have finished.
    _events[id] = message;

    _trim();

    final write = _writeQueue.then((_) => _writeSnapshot());

    // Keep the queue usable even if one
    // write fails. The caller still receives
    // the original error from "write".
    _writeQueue = write.catchError((Object error, StackTrace stackTrace) {
      debugPrint('TruckLink journal write queue: $error');
    });

    await write;
    return true;
  }

  // ==========================================
  // TRIM OLDEST RECORDS
  // ==========================================

  void _trim() {
    while (_events.length > maxEvents) {
      final oldestId = _events.keys.first;
      _events.remove(oldestId);
    }
  }

  // ==========================================
  // PERSIST ALTERNATING SNAPSHOT
  // ==========================================

  Future<void> _writeSnapshot() async {
    final nextGeneration = _generation + 1;

    final destination = nextGeneration.isEven ? _slotA : _slotB;

    final temporary = File('${destination.path}.tmp');

    final encoded = jsonEncode({
      'version': _formatVersion,
      'generation': nextGeneration,
      'events': [
        for (final entry in _events.entries)
          {'id': entry.key, 'message': entry.value},
      ],
    });

    // Write the new content before replacing
    // the destination slot.
    await temporary.writeAsString(encoded, flush: true);

    // The opposite slot remains valid if
    // the replacement fails or is interrupted.
    if (await destination.exists()) {
      await destination.delete();
    }

    await temporary.rename(destination.path);

    _generation = nextGeneration;
  }

  // ==========================================
  // READ ARCHIVE IN ORIGINAL ORDER
  // ==========================================

  Future<List<String>> replayMessages() async {
    // Wait for the pending disk writes.
    await _writeQueue;

    return List<String>.unmodifiable(_events.values);
  }

  int get eventCount => _events.length;

  String get directoryPath => _directory.path;
}

// ============================================
// PRIVATE JOURNAL MODELS
// ============================================

class _ArchivedEvent {
  const _ArchivedEvent({required this.id, required this.message});

  final String id;
  final String message;
}

class _JournalSnapshot {
  const _JournalSnapshot({required this.generation, required this.records});

  final int generation;
  final List<_ArchivedEvent> records;
}
