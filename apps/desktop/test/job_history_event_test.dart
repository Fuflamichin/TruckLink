import 'package:flutter_test/flutter_test.dart';
import 'package:network_protocol/job_lifecycle_protocol.dart';
import 'package:telemetry_core/job_telemetry.dart';

void main() {
  const job = TruckLinkJobTelemetry(
    gameId: 1,
    cargoId: 'medical_equipment',
    cargoName: 'Medical Equipment',
    sourceCity: 'Berlin',
    destinationCity: 'Paris',
    sourceCompany: 'TransiNet',
    destinationCompany: 'EuroGoodies',
    jobMarket: 'freight_market',
    income: 18450,
    plannedDistanceKm: 1082,
    unitCount: 1,
    cargoLoaded: true,
    specialJob: false,
  );

  test('Delivered event carries complete job', () {
    final when = DateTime.utc(2026, 11, 7, 12);

    final message = encodeJobEvent(
      JobLifecycleEventKind.delivered,
      eventId: 'test-123',
      occurredAtUtc: when,
      finalJob: job,
    );

    expect(isJobEventMessage(message), isTrue);

    final decoded = decodeJobEventDetails(message);

    expect(decoded.event, JobLifecycleEventKind.delivered);

    expect(decoded.eventId, 'test-123');
    expect(decoded.occurredAtUtc, when);

    expect(decoded.finalJob?.cargoName, 'Medical Equipment');

    expect(decoded.finalJob?.sourceCity, 'Berlin');

    expect(decoded.finalJob?.destinationCity, 'Paris');

    expect(decoded.finalJob?.income, 18450);
  });

  test('Old job event format still works', () {
    final message = encodeJobEvent(JobLifecycleEventKind.cancelled);

    final decoded = decodeJobEventDetails(message);

    expect(decoded.event, JobLifecycleEventKind.cancelled);

    expect(decoded.finalJob, isNull);
    expect(decoded.eventId, isNull);

    expect(decodeJobEvent(message), JobLifecycleEventKind.cancelled);
  });

  test('Started event is still supported', () {
    final message = encodeJobEvent(JobLifecycleEventKind.started);

    expect(decodeJobEvent(message), JobLifecycleEventKind.started);
  });
}
