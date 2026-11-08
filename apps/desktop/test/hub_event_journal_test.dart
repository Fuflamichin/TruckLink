import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:network_protocol/event_sync_protocol.dart';
import 'package:trucklink_desktop/services/hub_event_journal.dart';

// ============================================
// TRUCKLINK EVENT JOURNAL TESTS
// ============================================

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'trucklink_event_journal_test_',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  group('Hub event journal', () {
    test('Persists events across restarts', () async {
      final journal = await HubEventJournal.open(directory: temporaryDirectory);

      await journal.add(
        id: 'job-1',
        message: '{"type":"job_event","event":"delivered"}',
      );

      await journal.add(
        id: 'finance-1',
        message: '{"type":"finance_event","amount":12000}',
      );

      final reopened = await HubEventJournal.open(
        directory: temporaryDirectory,
      );

      final messages = await reopened.replayMessages();

      expect(messages, hasLength(2));
      expect(messages.first, contains('"job_event"'));
      expect(messages.last, contains('"finance_event"'));
    });

    test('Rejects duplicate event IDs', () async {
      final journal = await HubEventJournal.open(directory: temporaryDirectory);

      final first = await journal.add(id: 'same-event', message: '{"event":1}');

      final second = await journal.add(
        id: 'same-event',
        message: '{"event":1}',
      );

      expect(first, isTrue);
      expect(second, isFalse);
      expect(journal.eventCount, 1);
    });

    test('Keeps the newest events', () async {
      final journal = await HubEventJournal.open(
        directory: temporaryDirectory,
        maxEvents: 2,
      );

      await journal.add(id: 'first', message: '{"event":1}');

      await journal.add(id: 'second', message: '{"event":2}');

      await journal.add(id: 'third', message: '{"event":3}');

      final reopened = await HubEventJournal.open(
        directory: temporaryDirectory,
        maxEvents: 2,
      );

      final messages = await reopened.replayMessages();

      expect(messages, hasLength(2));
      expect(messages[0], '{"event":2}');
      expect(messages[1], '{"event":3}');
    });

    test('Recovers from damaged newest slot', () async {
      final journal = await HubEventJournal.open(directory: temporaryDirectory);

      await journal.add(id: 'first', message: '{"event":1}');

      await journal.add(id: 'second', message: '{"event":2}');

      // Generation 1 is slot B.
      // Generation 2 is slot A.
      final newestSlot = File(
        '${temporaryDirectory.path}'
        '${Platform.pathSeparator}events_a.json',
      );

      await newestSlot.writeAsString('{ damaged JSON', flush: true);

      final recovered = await HubEventJournal.open(
        directory: temporaryDirectory,
      );

      final messages = await recovered.replayMessages();

      // The previous valid snapshot survives.
      expect(messages, hasLength(1));
      expect(messages.single, '{"event":1}');
    });

    test('Returns ordered events for replay', () async {
      final journal = await HubEventJournal.open(directory: temporaryDirectory);

      for (var index = 0; index < 5; index++) {
        await journal.add(id: 'event-$index', message: '{"number":$index}');
      }

      final messages = await journal.replayMessages();

      expect(messages, hasLength(5));

      for (var index = 0; index < 5; index++) {
        expect(messages[index], '{"number":$index}');
      }
    });
  });

  group('Event sync protocol', () {
    test('Client request is recognized', () {
      final message = encodeEventSyncRequest();

      expect(isEventSyncRequestMessage(message), isTrue);

      expect(() => decodeEventSyncRequest(message), returnsNormally);
    });

    test('Begin and end messages roundtrip', () {
      final begin = encodeEventSyncBegin(eventCount: 42);

      final end = encodeEventSyncEnd(eventCount: 42);

      expect(isEventSyncBeginMessage(begin), isTrue);

      expect(isEventSyncEndMessage(end), isTrue);

      expect(decodeEventSyncBegin(begin), 42);

      expect(decodeEventSyncEnd(end), 42);
    });

    test('Rejects negative event count', () {
      expect(() => encodeEventSyncBegin(eventCount: -1), throwsArgumentError);
    });

    test('Rejects unsupported protocol version', () {
      expect(
        () => decodeEventSyncBegin(
          '{"version":999,'
          '"type":"event_sync_begin",'
          '"count":5}',
        ),
        throwsFormatException,
      );
    });
  });
}
