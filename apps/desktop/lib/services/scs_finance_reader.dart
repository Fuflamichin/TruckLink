import 'dart:typed_data';

import 'package:network_protocol/finance_protocol.dart';

import 'scs_shared_memory.dart';

// ============================================
// SCS FINANCIAL OCCURRENCE
// ============================================

class ScsFinanceOccurrence {
  const ScsFinanceOccurrence({
    required this.gameId,
    required this.kind,
    required this.signedAmount,
  });

  final int gameId;
  final FinanceEventKind kind;
  final int signedAmount;
}

// ============================================
// SCS FINANCE READER - REVISION 12
// ============================================

class ScsFinanceReader {
  ScsFinanceReader({ScsSharedMemory? memory})
    : _memory = memory ?? ScsSharedMemory();

  final ScsSharedMemory _memory;

  static const int readSize = 4400;
  static const int supportedRevision = 12;

  int? _previousGameId;
  List<bool>? _previousFlags;

  // ==========================================
  // RESET BASELINE
  // ==========================================

  void reset() {
    _previousGameId = null;
    _previousFlags = null;
  }

  // ==========================================
  // POLL SHARED MEMORY
  // ==========================================

  List<ScsFinanceOccurrence> poll() {
    final bytes = _memory.readBytes(readSize);
    return observeBytes(bytes);
  }

  // ==========================================
  // PURE PARSER FOR TESTING
  // ==========================================

  List<ScsFinanceOccurrence> observeBytes(Uint8List? bytes) {
    if (bytes == null || bytes.length < readSize) {
      reset();
      return const [];
    }

    final data = ByteData.sublistView(bytes);

    int uint32(int offset) {
      return data.getUint32(offset, Endian.little);
    }

    int int64(int offset) {
      return data.getInt64(offset, Endian.little);
    }

    bool flag(int offset) => bytes[offset] != 0;

    final revision = uint32(40);
    final gameId = uint32(52);
    final sdkActive = flag(0);

    if (revision != supportedRevision ||
        !sdkActive ||
        (gameId != 1 && gameId != 2)) {
      reset();
      return const [];
    }

    // These flags are TOGGLES, not states.
    //
    // 4302: jobCancelled
    // 4303: jobDelivered
    // 4304: fined
    // 4305: tollgate
    // 4306: ferry
    // 4307: train
    final flags = <bool>[
      flag(4302),
      flag(4303),
      flag(4304),
      flag(4305),
      flag(4306),
      flag(4307),
    ];

    // First sample (or a different game)
    // establishes the baseline.
    //
    // Do not replay old events when
    // TruckLink Hub is first opened.
    final previous = _previousFlags;

    if (previous == null || _previousGameId != gameId) {
      _previousGameId = gameId;
      _previousFlags = flags;
      return const [];
    }

    _previousFlags = flags;

    final kinds = <FinanceEventKind>[
      FinanceEventKind.cancelledPenalty,
      FinanceEventKind.deliveredRevenue,
      FinanceEventKind.fine,
      FinanceEventKind.toll,
      FinanceEventKind.ferry,
      FinanceEventKind.train,
    ];

    final offsets = <int>[4200, 4208, 4216, 4224, 4232, 4240];

    final result = <ScsFinanceOccurrence>[];

    for (var index = 0; index < flags.length; index++) {
      if (flags[index] == previous[index]) {
        continue;
      }

      final kind = kinds[index];
      final rawAmount = int64(offsets[index]);

      // Zero-value events do not change
      // the observed financial result.
      if (rawAmount == 0) {
        continue;
      }

      final signedAmount = kind.isIncome ? rawAmount : -rawAmount.abs();

      result.add(
        ScsFinanceOccurrence(
          gameId: gameId,
          kind: kind,
          signedAmount: signedAmount,
        ),
      );
    }

    return result;
  }
}
