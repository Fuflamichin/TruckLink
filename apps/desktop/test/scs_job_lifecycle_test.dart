import 'package:flutter_test/flutter_test.dart';
import 'package:network_protocol/job_lifecycle_protocol.dart';
import 'package:trucklink_desktop/services/scs_job_lifecycle_tracker.dart';

JobLifecycleEventKind? observe(
  ScsJobLifecycleTracker tracker, {
  int gameId = 1,
  bool onJob = false,
  bool delivered = false,
  bool cancelled = false,
}) {
  return tracker.observe(
    gameId: gameId,
    onJob: onJob,
    deliveredFlag: delivered,
    cancelledFlag: cancelled,
  );
}

void main() {
  group('SCS job lifecycle', () {
    test('Initial state never replays old events', () {
      final tracker = ScsJobLifecycleTracker();

      expect(
        observe(tracker, onJob: false, delivered: true, cancelled: true),
        isNull,
      );

      expect(
        observe(tracker, onJob: false, delivered: true, cancelled: true),
        isNull,
      );
    });

    test('Detects new job', () {
      final tracker = ScsJobLifecycleTracker();

      observe(tracker);

      expect(observe(tracker, onJob: true), JobLifecycleEventKind.started);

      expect(observe(tracker, onJob: true), isNull);
    });

    test('Detects successful delivery once', () {
      final tracker = ScsJobLifecycleTracker();

      observe(tracker, onJob: true);

      expect(
        observe(tracker, onJob: false, delivered: true),
        JobLifecycleEventKind.delivered,
      );

      expect(observe(tracker, onJob: false, delivered: true), isNull);
    });

    test('Detects cancellation once', () {
      final tracker = ScsJobLifecycleTracker();

      observe(tracker, onJob: true);

      expect(
        observe(tracker, onJob: false, cancelled: true),
        JobLifecycleEventKind.cancelled,
      );

      expect(observe(tracker, onJob: false, cancelled: true), isNull);
    });

    test('Detects toggle from true back to false', () {
      final tracker = ScsJobLifecycleTracker();

      observe(tracker, onJob: true, delivered: true);

      expect(
        observe(tracker, onJob: false, delivered: false),
        JobLifecycleEventKind.delivered,
      );
    });

    test('Disappearance alone is not delivery', () {
      final tracker = ScsJobLifecycleTracker();

      observe(tracker, onJob: true);

      expect(observe(tracker, onJob: false), isNull);
    });

    test('Game switch establishes new baseline', () {
      final tracker = ScsJobLifecycleTracker();

      observe(tracker, gameId: 1);

      expect(observe(tracker, gameId: 2, onJob: true, delivered: true), isNull);
    });
  });

  group('Job event protocol', () {
    test('Delivery roundtrip', () {
      final encoded = encodeJobEvent(JobLifecycleEventKind.delivered);

      expect(isJobEventMessage(encoded), isTrue);

      expect(decodeJobEvent(encoded), JobLifecycleEventKind.delivered);
    });

    test('Cancellation roundtrip', () {
      final encoded = encodeJobEvent(JobLifecycleEventKind.cancelled);

      expect(decodeJobEvent(encoded), JobLifecycleEventKind.cancelled);
    });

    test('Rejects invalid events', () {
      const encoded =
          '{"version":1,"type":"job_event",'
          '"event":"unknown"}';

      expect(() => decodeJobEvent(encoded), throwsFormatException);
    });
  });
}
