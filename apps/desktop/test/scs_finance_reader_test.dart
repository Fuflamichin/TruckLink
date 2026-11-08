import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:network_protocol/finance_protocol.dart';
import 'package:trucklink_desktop/services/scs_finance_reader.dart';

Uint8List financeMemory({
  int gameId = 1,
  bool delivered = false,
  bool cancelled = false,
  bool fined = false,
  bool toll = false,
  int revenue = 0,
  int penalty = 0,
  int fineAmount = 0,
  int tollAmount = 0,
}) {
  final bytes = Uint8List(4400);
  final data = ByteData.sublistView(bytes);

  bytes[0] = 1;

  data.setUint32(40, 12, Endian.little);
  data.setUint32(52, gameId, Endian.little);

  bytes[4302] = cancelled ? 1 : 0;
  bytes[4303] = delivered ? 1 : 0;
  bytes[4304] = fined ? 1 : 0;
  bytes[4305] = toll ? 1 : 0;

  data.setInt64(4200, penalty, Endian.little);
  data.setInt64(4208, revenue, Endian.little);
  data.setInt64(4216, fineAmount, Endian.little);
  data.setInt64(4224, tollAmount, Endian.little);

  return bytes;
}

void main() {
  group('SCS finance flags', () {
    test('Initial sample does not replay events', () {
      final reader = ScsFinanceReader();

      final result = reader.observeBytes(
        financeMemory(delivered: true, revenue: 15000),
      );

      expect(result, isEmpty);
    });

    test('Delivery yields actual revenue once', () {
      final reader = ScsFinanceReader();

      reader.observeBytes(financeMemory());

      final events = reader.observeBytes(
        financeMemory(delivered: true, revenue: 18450),
      );

      expect(events, hasLength(1));

      expect(events.single.kind, FinanceEventKind.deliveredRevenue);

      expect(events.single.signedAmount, 18450);

      expect(
        reader.observeBytes(financeMemory(delivered: true, revenue: 18450)),
        isEmpty,
      );
    });

    test('Toggle from true to false is an event', () {
      final reader = ScsFinanceReader();

      reader.observeBytes(financeMemory(delivered: true, revenue: 10000));

      final events = reader.observeBytes(
        financeMemory(delivered: false, revenue: 25000),
      );

      expect(events, hasLength(1));
      expect(events.single.signedAmount, 25000);
    });

    test('Fines and tolls become expenses', () {
      final reader = ScsFinanceReader();

      reader.observeBytes(financeMemory());

      final events = reader.observeBytes(
        financeMemory(fined: true, toll: true, fineAmount: 800, tollAmount: 25),
      );

      expect(events, hasLength(2));

      expect(events[0].kind, FinanceEventKind.fine);

      expect(events[0].signedAmount, -800);

      expect(events[1].kind, FinanceEventKind.toll);

      expect(events[1].signedAmount, -25);
    });

    test('Switching games resets the baseline', () {
      final reader = ScsFinanceReader();

      reader.observeBytes(financeMemory(gameId: 1));

      final events = reader.observeBytes(
        financeMemory(gameId: 2, delivered: true, revenue: 9000),
      );

      expect(events, isEmpty);
    });
  });

  group('Finance protocol', () {
    test('Round trip', () {
      final event = FinanceEvent(
        id: 'test-event-1',
        gameId: 1,
        kind: FinanceEventKind.deliveredRevenue,
        amount: 18000,
        occurredAtUtc: DateTime.utc(2026, 11, 8, 12),
      );

      final encoded = encodeFinanceEvent(event);
      final decoded = decodeFinanceEvent(encoded);

      expect(isFinanceEventMessage(encoded), isTrue);
      expect(decoded.id, event.id);
      expect(decoded.gameId, 1);

      expect(decoded.kind, FinanceEventKind.deliveredRevenue);

      expect(decoded.amount, 18000);
    });

    test('Rejects unsupported events', () {
      expect(
        () => decodeFinanceEvent(
          '{"version":1,'
          '"type":"finance_event",'
          '"payload":{'
          '"id":"x",'
          '"gameId":1,'
          '"kind":"unknown",'
          '"amount":42,'
          '"occurredAtUtc":'
          '"2026-11-08T12:00:00Z"'
          '}}',
        ),
        throwsFormatException,
      );
    });
  });
}
