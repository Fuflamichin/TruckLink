import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:telemetry_core/telemetry_core.dart';

import 'scs_shared_memory.dart';

// ============================================
// SCS SHARED MEMORY READER
// ============================================

class ScsTelemetryReader {
  ScsTelemetryReader({ScsSharedMemory? memory})
    : _memory = memory ?? ScsSharedMemory();

  final ScsSharedMemory _memory;

  // Revision 12:
  // The job event flags end at offset 4303.
  // The first 4400 bytes contain all fields
  // currently used by TruckLink.
  static const int readSize = 4400;

  ScsTelemetryFrame? read() {
    final bytes = _memory.readBytes(readSize);

    if (bytes == null) {
      return null;
    }

    return ScsTelemetryFrame.fromBytes(bytes);
  }

  Stream<ScsTelemetryFrame?> watch({
    Duration interval = const Duration(milliseconds: 200),
  }) async* {
    if (interval <= Duration.zero) {
      throw ArgumentError.value(interval, 'interval');
    }

    while (true) {
      yield read();
      await Future<void>.delayed(interval);
    }
  }
}

// ============================================
// SCS ACTIVE JOB
// ============================================

class ScsJobFrame {
  const ScsJobFrame({
    required this.cargoName,
    required this.cargoId,
    required this.sourceCity,
    required this.sourceCityId,
    required this.destinationCity,
    required this.destinationCityId,
    required this.sourceCompany,
    required this.sourceCompanyId,
    required this.destinationCompany,
    required this.destinationCompanyId,
    required this.jobMarket,
    required this.income,
    required this.plannedDistanceKm,
    required this.cargoMassKg,
    required this.unitCount,
    required this.unitMassKg,
    required this.cargoDamage,
    required this.cargoLoaded,
    required this.specialJob,
    required this.deliveryTimeAbsoluteMinutes,
    required this.gameTimeAbsoluteMinutes,
    required this.navigationDistanceMeters,
    required this.navigationTimeSeconds,
  });

  // Cargo.
  final String cargoName;
  final String cargoId;
  final double? cargoMassKg;
  final int unitCount;
  final double? unitMassKg;
  final double? cargoDamage;
  final bool cargoLoaded;
  final bool specialJob;

  // Source.
  final String sourceCity;
  final String sourceCityId;
  final String sourceCompany;
  final String sourceCompanyId;

  // Destination.
  final String destinationCity;
  final String destinationCityId;
  final String destinationCompany;
  final String destinationCompanyId;

  // Job.
  final String jobMarket;
  final int income;
  final int plannedDistanceKm;

  // Game time, in minutes.
  final int gameTimeAbsoluteMinutes;
  final int deliveryTimeAbsoluteMinutes;

  // GPS.
  final double? navigationDistanceMeters;
  final double? navigationTimeSeconds;

  double? get navigationDistanceKm {
    final value = navigationDistanceMeters;
    return value == null ? null : value / 1000;
  }

  double? get cargoMassTonnes {
    final value = cargoMassKg;
    return value == null ? null : value / 1000;
  }

  double? get cargoDamagePercent {
    final value = cargoDamage;
    if (value == null) return null;

    return (value * 100).clamp(0.0, 100.0).toDouble();
  }

  int? get remainingDeliveryMinutes {
    if (deliveryTimeAbsoluteMinutes <= 0) {
      return null;
    }

    final difference = deliveryTimeAbsoluteMinutes - gameTimeAbsoluteMinutes;

    return difference < 0 ? 0 : difference;
  }

  String get displayCargo {
    return cargoName.trim().isEmpty ? 'Неизвестный груз' : cargoName;
  }

  String get displayRoute {
    final from = sourceCity.trim().isEmpty ? 'Неизвестно' : sourceCity;

    final to = destinationCity.trim().isEmpty ? 'Неизвестно' : destinationCity;

    return '$from → $to';
  }
}

// ============================================
// COMPLETE SCS TELEMETRY FRAME
// ============================================

class ScsTelemetryFrame {
  const ScsTelemetryFrame({
    required this.pluginRevision,
    required this.gameId,
    required this.timestamp,
    required this.sdkActive,
    required this.paused,
    required this.speedKmh,
    required this.rpm,
    required this.maxRpm,
    required this.gear,
    required this.dashboardGear,
    required this.fuelLiters,
    required this.fuelCapacityLiters,
    required this.engineOn,
    required this.parkBrake,
    required this.odometerKm,
    required this.waterTemperatureC,
    required this.engineWear,
    required this.cruiseControlKmh,
    required this.speedLimitKmh,
    this.job,
    this.jobCancelledEventFlag = false,
    this.jobDeliveredEventFlag = false,
    this.jobFinishedEventFlag = false,
  });

  static const int supportedRevision = 12;
  static const int minimumBytes = 4400;

  // Plugin.
  final int pluginRevision;
  final int gameId;
  final int timestamp;
  final bool sdkActive;
  final bool paused;

  // Engine.
  final double speedKmh;
  final double rpm;
  final double maxRpm;
  final int gear;
  final int dashboardGear;
  final bool engineOn;
  final bool parkBrake;

  // Fuel.
  final double fuelLiters;
  final double fuelCapacityLiters;

  // Truck condition.
  final double odometerKm;
  final double waterTemperatureC;
  final double engineWear;

  // Driver assistance.
  final double cruiseControlKmh;
  final double speedLimitKmh;

  // Current job.
  final ScsJobFrame? job;

  // Revision 12: event toggle flags.
  //
  // These are not persistent boolean statuses.
  // An event is detected when the value changes.
  final bool jobCancelledEventFlag;
  final bool jobDeliveredEventFlag;
  final bool jobFinishedEventFlag;

  bool get hasActiveJob => job != null;

  String get gameName => switch (gameId) {
    1 => 'Euro Truck Simulator 2',
    2 => 'American Truck Simulator',
    _ => 'Unknown',
  };

  bool get isLive => sdkActive && !paused && gameId != 0;

  double get fuelPercent {
    if (fuelCapacityLiters <= 0) {
      return 0;
    }

    return (fuelLiters / fuelCapacityLiters * 100).clamp(0.0, 100.0).toDouble();
  }

  double get engineWearPercent {
    return (engineWear * 100).clamp(0.0, 100.0).toDouble();
  }

  // ==========================================
  // CONVERT TO EXISTING TRUCK SNAPSHOT
  // ==========================================

  TruckSnapshot toTruckSnapshot() {
    double? finiteOrNull(double value) {
      return value.isFinite ? value : null;
    }

    return TruckSnapshot(
      timestamp: DateTime.now().toUtc(),
      speedKmh: speedKmh,
      rpm: rpm,
      gear: gear,
      fuelLiters: fuelLiters,
      fuelCapacityLiters: fuelCapacityLiters,
      engineOn: engineOn,
      maxRpm: finiteOrNull(maxRpm),
      waterTemperatureC: finiteOrNull(waterTemperatureC),
      odometerKm: finiteOrNull(odometerKm),
      engineWear: finiteOrNull(engineWear),
      cruiseControlKmh: finiteOrNull(cruiseControlKmh),
      speedLimitKmh: finiteOrNull(speedLimitKmh),
      parkBrake: parkBrake,
      dashboardGear: dashboardGear,

      // Real job data is transmitted separately
      // through the job_update protocol.
      job: null,
    );
  }

  // ==========================================
  // DECODE SHARED MEMORY REVISION 12
  // ==========================================

  factory ScsTelemetryFrame.fromBytes(Uint8List bytes) {
    if (bytes.length < minimumBytes) {
      throw FormatException(
        'Telemetry buffer too small: '
        '${bytes.length} bytes. '
        'Expected at least $minimumBytes.',
      );
    }

    final data = ByteData.sublistView(bytes);

    int u32(int offset) {
      return data.getUint32(offset, Endian.little);
    }

    int u64(int offset) {
      return data.getUint64(offset, Endian.little);
    }

    int i32(int offset) {
      return data.getInt32(offset, Endian.little);
    }

    double f32(int offset) {
      return data.getFloat32(offset, Endian.little);
    }

    bool flag(int offset) {
      return bytes[offset] != 0;
    }

    double? safeNonNegative(int offset) {
      final value = f32(offset);

      if (!value.isFinite || value < 0) {
        return null;
      }

      return value;
    }

    String readString(int offset, int length) {
      final limit = offset + length;
      var end = offset;

      while (end < limit && bytes[end] != 0) {
        end++;
      }

      if (end == offset) return '';

      return utf8
          .decode(
            Uint8List.sublistView(bytes, offset, end),
            allowMalformed: true,
          )
          .trim();
    }

    // ========================================
    // HEADER VALIDATION
    // ========================================

    final revision = u32(40);

    if (revision != supportedRevision) {
      throw UnsupportedError(
        'Unsupported SCS plugin revision: '
        '$revision. Expected $supportedRevision.',
      );
    }

    final gameId = u32(52);

    if (gameId != 0 && gameId != 1 && gameId != 2) {
      throw FormatException('Unexpected SCS game ID: $gameId');
    }

    // ========================================
    // CORE TRUCK TELEMETRY
    // ========================================

    final speedKmh = f32(948) * 3.6;
    final rpm = f32(952);
    final fuel = f32(1000);
    final fuelCapacity = f32(704);

    if (!speedKmh.isFinite ||
        !rpm.isFinite ||
        !fuel.isFinite ||
        !fuelCapacity.isFinite) {
      throw const FormatException('Non-finite truck telemetry values');
    }

    if (flag(0) && gameId != 0) {
      if (speedKmh.abs() > 500 ||
          rpm < 0 ||
          rpm > 10000 ||
          fuel < 0 ||
          fuel > 10000 ||
          fuelCapacity < 0 ||
          fuelCapacity > 10000) {
        throw const FormatException('Implausible telemetry values');
      }
    }

    // ========================================
    // ACTIVE JOB
    // ========================================

    // onJob is a persistent state flag.
    final onJob = flag(4300);

    ScsJobFrame? currentJob;

    if (onJob) {
      currentJob = ScsJobFrame(
        // Cargo.
        cargoId: readString(2556, 64),
        cargoName: readString(2620, 64),
        cargoMassKg: safeNonNegative(748),
        unitCount: u32(96),
        unitMassKg: safeNonNegative(944),
        cargoDamage: safeNonNegative(1468),
        cargoLoaded: flag(1564),
        specialJob: flag(1565),

        // Destination.
        destinationCityId: readString(2684, 64),
        destinationCity: readString(2748, 64),
        destinationCompanyId: readString(2812, 64),
        destinationCompany: readString(2876, 64),

        // Source.
        sourceCityId: readString(2940, 64),
        sourceCity: readString(3004, 64),
        sourceCompanyId: readString(3068, 64),
        sourceCompany: readString(3132, 64),

        // Job details.
        jobMarket: readString(3404, 32),
        income: u64(4000),
        plannedDistanceKm: u32(100),

        // Game clock / deadline.
        gameTimeAbsoluteMinutes: u32(64),
        deliveryTimeAbsoluteMinutes: u32(88),

        // Route advisor.
        navigationDistanceMeters: safeNonNegative(1060),
        navigationTimeSeconds: safeNonNegative(1064),
      );
    }

    // ========================================
    // RETURN FRAME
    // ========================================

    return ScsTelemetryFrame(
      pluginRevision: revision,
      gameId: gameId,
      timestamp: u64(8),
      sdkActive: flag(0),
      paused: flag(4),

      // Transmission.
      gear: i32(504),
      dashboardGear: i32(508),

      // Engine.
      speedKmh: speedKmh,
      rpm: rpm,
      maxRpm: f32(740),
      engineOn: flag(1576),

      // Brake.
      parkBrake: flag(1566),

      // Fuel.
      fuelLiters: fuel,
      fuelCapacityLiters: fuelCapacity,

      // Vehicle condition.
      odometerKm: f32(1056),
      waterTemperatureC: f32(1024),
      engineWear: f32(1036),

      // Driving assistance.
      cruiseControlKmh: f32(988) * 3.6,
      speedLimitKmh: f32(1068) * 3.6,

      // Job.
      job: currentJob,

      // Event flags.
      // Their changes indicate events.
      jobFinishedEventFlag: flag(4301),
      jobCancelledEventFlag: flag(4302),
      jobDeliveredEventFlag: flag(4303),
    );
  }
}

// ============================================
// WINDOWS CONSOLE DIAGNOSTIC
// ============================================

/// Run from apps/desktop:
///
/// dart run lib/services/scs_telemetry_reader.dart
Future<void> main() async {
  if (!Platform.isWindows) {
    stderr.writeln('Диагностика доступна только на Windows.');
    exitCode = 1;
    return;
  }

  final reader = ScsTelemetryReader();

  stdout.writeln('====================================');
  stdout.writeln(' TruckLink v0.7.4 SCS Diagnostic');
  stdout.writeln('====================================');
  stdout.writeln('Запусти ETS2 / ATS.');
  stdout.writeln('Прими, заверши или отмени заказ.');
  stdout.writeln('Ctrl+C — выход.');
  stdout.writeln();

  bool? previousOnJob;
  bool? previousDelivered;
  bool? previousCancelled;
  int? previousTimestamp;

  while (true) {
    try {
      final frame = reader.read();

      if (frame == null) {
        if (previousTimestamp != null) {
          stdout.writeln('[DISCONNECTED] Shared memory недоступна.');
        }

        previousOnJob = null;
        previousDelivered = null;
        previousCancelled = null;
        previousTimestamp = null;
      } else {
        final onJob = frame.hasActiveJob;

        if (previousOnJob == null) {
          stdout.writeln(
            '[CONNECTED] ${frame.gameName}, '
            'revision ${frame.pluginRevision}',
          );
        } else if (!previousOnJob && onJob) {
          stdout.writeln('[STARTED] Заказ принят.');
        } else if (previousOnJob && !onJob) {
          stdout.writeln('[ENDED] Активный заказ исчез.');
        }

        // Toggle flags: detect changes,
        // including true -> false.
        if (previousDelivered != null &&
            previousDelivered != frame.jobDeliveredEventFlag) {
          stdout.writeln('[DELIVERED] Доставка завершена.');
        }

        if (previousCancelled != null &&
            previousCancelled != frame.jobCancelledEventFlag) {
          stdout.writeln('[CANCELLED] Заказ отменён.');
        }

        if (onJob && previousTimestamp != frame.timestamp) {
          final job = frame.job!;

          stdout.writeln('------------------------------');
          stdout.writeln('Game: ${frame.gameName}');
          stdout.writeln('Cargo: ${job.displayCargo}');
          stdout.writeln('Route: ${job.displayRoute}');
          stdout.writeln('Reward: ${job.income}');
          stdout.writeln(
            'Remaining: '
            '${job.navigationDistanceKm?.toStringAsFixed(1) ?? "N/A"} km',
          );
          stdout.writeln(
            'ETA: '
            '${job.navigationTimeSeconds?.toStringAsFixed(0) ?? "N/A"} s',
          );
          stdout.writeln(
            'Delivery remaining: '
            '${job.remainingDeliveryMinutes ?? "N/A"} game min',
          );
        }

        previousOnJob = onJob;
        previousDelivered = frame.jobDeliveredEventFlag;
        previousCancelled = frame.jobCancelledEventFlag;
        previousTimestamp = frame.timestamp;
      }
    } catch (error) {
      stderr.writeln('[ERROR] $error');
    }

    await Future<void>.delayed(const Duration(seconds: 1));
  }
}
