import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trucklink_desktop/services/scs_telemetry_reader.dart';

// ============================================
// TEST MEMORY HELPERS
// ============================================

Uint8List createMemory() {
  final bytes = Uint8List(ScsTelemetryReader.readSize);

  final data = ByteData.sublistView(bytes);

  // Plugin revision 12.
  data.setUint32(40, 12, Endian.little);

  // ETS2.
  data.setUint32(52, 1, Endian.little);

  // SDK active.
  bytes[0] = 1;

  // Telemetry timestamp.
  data.setUint64(8, 12345, Endian.little);

  return bytes;
}

void writeString(Uint8List bytes, int offset, String value) {
  final encoded = utf8.encode(value);

  bytes.setRange(offset, offset + encoded.length, encoded);
}

// ============================================
// TESTS
// ============================================

void main() {
  group('SCS Job Telemetry rev12', () {
    test('Reads a complete active job', () {
      final bytes = createMemory();

      final data = ByteData.sublistView(bytes);

      // Active job.
      bytes[4300] = 1;

      // Cargo flags.
      bytes[1564] = 1;
      bytes[1565] = 0;

      writeString(bytes, 2556, 'medical_equipment');

      writeString(bytes, 2620, 'Medical Equipment');

      writeString(bytes, 3004, 'Berlin');

      writeString(bytes, 2748, 'Paris');

      writeString(bytes, 3132, 'TransiNet');

      writeString(bytes, 2876, 'EuroGoodies');

      writeString(bytes, 3404, 'freight_market');

      // Reward.
      data.setUint64(4000, 18450, Endian.little);

      // Planned distance.
      data.setUint32(100, 1082, Endian.little);

      // Cargo mass.
      data.setFloat32(748, 12000, Endian.little);

      // Cargo damage = 2.5%.
      data.setFloat32(1468, 0.025, Endian.little);

      // Remaining navigation distance.
      data.setFloat32(1060, 427500, Endian.little);

      // Navigation time in seconds.
      data.setFloat32(1064, 21000, Endian.little);

      // Current game time.
      data.setUint32(64, 110000, Endian.little);

      // Delivery deadline.
      data.setUint32(88, 110800, Endian.little);

      final frame = ScsTelemetryFrame.fromBytes(bytes);

      final job = frame.job;

      expect(frame.gameId, 1);
      expect(frame.isLive, isTrue);
      expect(frame.hasActiveJob, isTrue);

      expect(job, isNotNull);

      expect(job!.cargoName, 'Medical Equipment');

      expect(job.sourceCity, 'Berlin');

      expect(job.destinationCity, 'Paris');

      expect(job.income, 18450);

      expect(job.plannedDistanceKm, 1082);

      expect(job.cargoMassKg, 12000);

      expect(job.navigationDistanceKm, 427.5);

      expect(job.cargoDamagePercent, closeTo(2.5, 0.001));

      expect(job.remainingDeliveryMinutes, 800);

      expect(job.cargoLoaded, isTrue);

      expect(job.specialJob, isFalse);
    });

    test('No active job returns null', () {
      final bytes = createMemory();

      // Stale cargo text may still exist.
      writeString(bytes, 2620, 'Old cargo');

      // onJob remains false.
      bytes[4300] = 0;

      final frame = ScsTelemetryFrame.fromBytes(bytes);

      expect(frame.hasActiveJob, isFalse);

      expect(frame.job, isNull);
    });

    test('Rejects unsupported revision', () {
      final bytes = createMemory();

      final data = ByteData.sublistView(bytes);

      data.setUint32(40, 11, Endian.little);

      expect(() => ScsTelemetryFrame.fromBytes(bytes), throwsUnsupportedError);
    });

    test('Rejects incomplete memory buffer', () {
      final bytes = Uint8List(1600);

      expect(() => ScsTelemetryFrame.fromBytes(bytes), throwsFormatException);
    });
  });
}
