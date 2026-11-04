import 'package:test/test.dart';
import 'package:telemetry_core/telemetry_core.dart';

void main() {
  test('snapshot JSON roundtrip', () {
    final first = TruckSnapshot.demo();
    final second = TruckSnapshot.fromJson(first.toJson());
    expect(second.speedKmh, first.speedKmh);
    expect(second.gear, first.gear);
    expect(second.fuelFraction, closeTo(466 / 600, 0.00001));
  });
}
