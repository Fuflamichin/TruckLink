import 'package:flutter_test/flutter_test.dart';
import 'package:network_protocol/job_protocol.dart';
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
    cargoMassKg: 12000,
    cargoDamagePercent: 2.5,
    navigationDistanceKm: 427.5,
    navigationTimeSeconds: 21000,
    deliveryTimeAbsoluteMinutes: 110800,
    remainingDeliveryMinutes: 800,
  );

  test('Job survives JSON roundtrip', () {
    final encoded = encodeJobUpdate(job);

    expect(isJobUpdateMessage(encoded), isTrue);

    final decoded = decodeJobUpdate(encoded);

    expect(decoded, isNotNull);
    expect(decoded!.cargoName, job.cargoName);
    expect(decoded.sourceCity, job.sourceCity);
    expect(decoded.destinationCity, job.destinationCity);
    expect(decoded.income, job.income);
    expect(decoded.navigationDistanceKm, job.navigationDistanceKm);
    expect(decoded.remainingDeliveryMinutes, 800);
  });

  test('Null payload clears active job', () {
    final encoded = encodeJobUpdate(null);

    expect(isJobUpdateMessage(encoded), isTrue);

    expect(decodeJobUpdate(encoded), isNull);
  });

  test('Unsupported protocol version fails', () {
    const message =
        '{"version":999,"type":"job_update",'
        '"payload":null}';

    expect(() => decodeJobUpdate(message), throwsFormatException);
  });

  test('Unrelated messages are not job updates', () {
    const message =
        '{"version":1,"type":"snapshot",'
        '"payload":{}}';

    expect(isJobUpdateMessage(message), isFalse);
  });
}
