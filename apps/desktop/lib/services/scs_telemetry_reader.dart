import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:telemetry_core/telemetry_core.dart';

import 'scs_shared_memory.dart';

// ============================================
// SCS TELEMETRY READER
// ============================================

/// Reads ETS2 / ATS telemetry from Windows
/// shared memory.
///
/// Supported plugin:
/// truckermudgeon/scs-sdk-plugin
///
/// Supported memory layout: revision 12.
class ScsTelemetryReader {
  ScsTelemetryReader({ScsSharedMemory? memory})
    : _memory = memory ?? ScsSharedMemory();

  final ScsSharedMemory _memory;

  // ==========================================
  // SHARED MEMORY SIZE
  // ==========================================

  /// Earlier versions read only 1600 bytes.
  ///
  /// Job strings begin at offset 2300.
  /// Job income is stored at offset 4000.
  /// The onJob flag is stored at offset 4300.
  ///
  /// Read the complete first 12 zones.
  ///
  /// The plugin allocates 32 KiB, so 4400
  /// bytes is within the mapping capacity.
  static const int readSize = 4400;

  // ==========================================
  // READ ONE FRAME
  // ==========================================

  /// Returns null when shared memory is absent.
  ScsTelemetryFrame? read() {
    final bytes = _memory.readBytes(readSize);

    if (bytes == null) {
      return null;
    }

    return ScsTelemetryFrame.fromBytes(bytes);
  }

  // ==========================================
  // WATCH TELEMETRY
  // ==========================================

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
// REAL SCS JOB DATA
// ============================================

/// One active ETS2 / ATS job.
///
/// These values come from the SCS plugin's
/// revision-12 memory layout.
///
/// This model is local to the Windows reader.
/// Mobile protocol integration is the next step.
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

  // ==========================================
  // CARGO
  // ==========================================

  final String cargoName;
  final String cargoId;

  final double? cargoMassKg;
  final int unitCount;
  final double? unitMassKg;

  /// Damage fraction, typically 0.0 - 1.0.
  final double? cargoDamage;

  final bool cargoLoaded;
  final bool specialJob;

  // ==========================================
  // SOURCE
  // ==========================================

  final String sourceCity;
  final String sourceCityId;

  final String sourceCompany;
  final String sourceCompanyId;

  // ==========================================
  // DESTINATION
  // ==========================================

  final String destinationCity;
  final String destinationCityId;

  final String destinationCompany;
  final String destinationCompanyId;

  // ==========================================
  // JOB DETAILS
  // ==========================================

  final String jobMarket;

  /// Reward in the game's currency.
  ///
  /// ETS2 normally uses EUR, ATS uses USD,
  /// but the actual in-game currency may
  /// depend on user settings.
  final int income;

  /// Original planned job distance in km.
  final int plannedDistanceKm;

  // ==========================================
  // IN-GAME TIME
  // ==========================================

  /// Absolute game time in minutes.
  /// This is not a Unix timestamp.
  final int gameTimeAbsoluteMinutes;

  /// Absolute in-game delivery deadline,
  /// measured in game minutes.
  final int deliveryTimeAbsoluteMinutes;

  // ==========================================
  // LIVE NAVIGATION
  // ==========================================

  /// Route advisor distance in meters.
  final double? navigationDistanceMeters;

  /// Route advisor time in seconds.
  final double? navigationTimeSeconds;

  // ==========================================
  // CALCULATED PROPERTIES
  // ==========================================

  double? get navigationDistanceKm {
    final value = navigationDistanceMeters;

    if (value == null) {
      return null;
    }

    return value / 1000.0;
  }

  double? get cargoMassTonnes {
    final value = cargoMassKg;

    if (value == null) {
      return null;
    }

    return value / 1000.0;
  }

  double? get cargoDamagePercent {
    final value = cargoDamage;

    if (value == null) {
      return null;
    }

    return (value * 100).clamp(0.0, 100.0).toDouble();
  }

  /// Remaining delivery time in in-game minutes.
  ///
  /// This is not real-world wall-clock time.
  int? get remainingDeliveryMinutes {
    if (deliveryTimeAbsoluteMinutes <= 0) {
      return null;
    }

    final remaining = deliveryTimeAbsoluteMinutes - gameTimeAbsoluteMinutes;

    return remaining < 0 ? 0 : remaining;
  }

  String get displayCargo {
    return cargoName.isEmpty ? 'Неизвестный груз' : cargoName;
  }

  String get displayRoute {
    final start = sourceCity.isEmpty ? 'Неизвестно' : sourceCity;

    final end = destinationCity.isEmpty ? 'Неизвестно' : destinationCity;

    return '$start → $end';
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
  });

  // ==========================================
  // PLUGIN INFORMATION
  // ==========================================

  static const int supportedRevision = 12;

  static const int minimumBytes = 4400;

  final int pluginRevision;
  final int gameId;
  final int timestamp;

  final bool sdkActive;
  final bool paused;

  // ==========================================
  // ENGINE AND TRANSMISSION
  // ==========================================

  final double speedKmh;
  final double rpm;
  final double maxRpm;

  final int gear;
  final int dashboardGear;

  final bool engineOn;
  final bool parkBrake;

  // ==========================================
  // FUEL
  // ==========================================

  final double fuelLiters;
  final double fuelCapacityLiters;

  // ==========================================
  // TRUCK CONDITION
  // ==========================================

  final double odometerKm;
  final double waterTemperatureC;
  final double engineWear;

  // ==========================================
  // CRUISE CONTROL / NAVIGATION
  // ==========================================

  final double cruiseControlKmh;
  final double speedLimitKmh;

  // ==========================================
  // NEW: CURRENT JOB
  // ==========================================

  /// Null when the plugin reports onJob = false.
  final ScsJobFrame? job;

  bool get hasActiveJob => job != null;

  // ==========================================
  // CALCULATED PROPERTIES
  // ==========================================

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
  // CONVERT TO TRUCKLINK SNAPSHOT
  // ==========================================

  /// Preserve the existing mobile protocol.
  ///
  /// ScsJobFrame is not converted to the shared
  /// Job model yet. That belongs to v0.7.2.
  TruckSnapshot toTruckSnapshot() {
    double? finiteOrNull(double value) {
      return value.isFinite ? value : null;
    }

    return TruckSnapshot(
      timestamp: DateTime.now().toUtc(),

      // Core telemetry.
      speedKmh: speedKmh,
      rpm: rpm,
      gear: gear,
      fuelLiters: fuelLiters,
      fuelCapacityLiters: fuelCapacityLiters,
      engineOn: engineOn,

      // Extended engine telemetry.
      maxRpm: finiteOrNull(maxRpm),
      waterTemperatureC: finiteOrNull(waterTemperatureC),

      // Truck condition.
      odometerKm: finiteOrNull(odometerKm),
      engineWear: finiteOrNull(engineWear),

      // Driving assistance.
      cruiseControlKmh: finiteOrNull(cruiseControlKmh),
      speedLimitKmh: finiteOrNull(speedLimitKmh),

      // Vehicle state.
      parkBrake: parkBrake,
      dashboardGear: dashboardGear,

      // Job protocol integration is v0.7.2.
      job: null,
    );
  }

  // ==========================================
  // DECODE REVISION 12
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

    // ========================================
    // LOW-LEVEL READ HELPERS
    // ========================================

    int uint32(int offset) {
      return data.getUint32(offset, Endian.little);
    }

    int uint64(int offset) {
      return data.getUint64(offset, Endian.little);
    }

    int int32(int offset) {
      return data.getInt32(offset, Endian.little);
    }

    double float32(int offset) {
      return data.getFloat32(offset, Endian.little);
    }

    bool boolean(int offset) {
      return bytes[offset] != 0;
    }

    double? nonNegativeFiniteFloat(int offset) {
      final value = float32(offset);

      if (!value.isFinite || value < 0) {
        return null;
      }

      return value;
    }

    // ========================================
    // NULL-TERMINATED UTF-8 STRING
    // ========================================

    String readString(int offset, int maxLength) {
      final end = offset + maxLength;

      var stringEnd = offset;

      while (stringEnd < end && bytes[stringEnd] != 0) {
        stringEnd++;
      }

      if (stringEnd == offset) {
        return '';
      }

      final stringBytes = Uint8List.sublistView(bytes, offset, stringEnd);

      return utf8.decode(stringBytes, allowMalformed: true).trim();
    }

    // ========================================
    // PLUGIN HEADER
    // ========================================

    final revision = uint32(40);

    if (revision != supportedRevision) {
      throw UnsupportedError(
        'Unsupported telemetry revision: '
        '$revision. '
        'Expected: $supportedRevision.',
      );
    }

    final gameId = uint32(52);

    if (gameId != 0 && gameId != 1 && gameId != 2) {
      throw FormatException('Unexpected game ID: $gameId');
    }

    // ========================================
    // CORE DATA
    // ========================================

    // SCS speed values are in m/s.
    final speedKmh = float32(948) * 3.6;

    final rpm = float32(952);

    final fuel = float32(1000);
    final fuelCapacity = float32(704);

    // ========================================
    // BASIC VALIDATION
    // ========================================

    if (!speedKmh.isFinite ||
        !rpm.isFinite ||
        !fuel.isFinite ||
        !fuelCapacity.isFinite) {
      throw const FormatException('Telemetry contains non-finite values.');
    }

    if (boolean(0) && gameId != 0) {
      if (speedKmh.abs() > 500 ||
          rpm < 0 ||
          rpm > 10000 ||
          fuel < 0 ||
          fuel > 10000 ||
          fuelCapacity < 0 ||
          fuelCapacity > 10000) {
        throw const FormatException(
          'Implausible telemetry values. '
          'Check plugin memory layout.',
        );
      }
    }

    // ========================================
    // NEW: READ ACTIVE JOB
    // ========================================

    ScsJobFrame? currentJob;

    // Revision-12 special_b.onJob:
    // offset 4300.
    //
    // Do not infer an active job from old
    // cargo strings or the reward amount:
    // those fields may remain populated
    // temporarily after a delivery.
    final onJob = boolean(4300);

    if (onJob) {
      currentJob = ScsJobFrame(
        // ================================
        // CARGO
        // ================================
        cargoId: readString(2556, 64),
        cargoName: readString(2620, 64),

        cargoMassKg: nonNegativeFiniteFloat(748),

        unitCount: uint32(96),

        unitMassKg: nonNegativeFiniteFloat(944),

        cargoDamage: nonNegativeFiniteFloat(1468),

        cargoLoaded: boolean(1564),
        specialJob: boolean(1565),

        // ================================
        // DESTINATION
        // ================================
        destinationCityId: readString(2684, 64),

        destinationCity: readString(2748, 64),

        destinationCompanyId: readString(2812, 64),

        destinationCompany: readString(2876, 64),

        // ================================
        // SOURCE
        // ================================
        sourceCityId: readString(2940, 64),

        sourceCity: readString(3004, 64),

        sourceCompanyId: readString(3068, 64),

        sourceCompany: readString(3132, 64),

        // ================================
        // JOB MARKET
        // ================================
        jobMarket: readString(3404, 32),

        // ================================
        // REWARD / PLANNED ROUTE
        // ================================
        income: uint64(4000),

        plannedDistanceKm: uint32(100),

        // ================================
        // GAME CLOCK / DEADLINE
        // ================================
        gameTimeAbsoluteMinutes: uint32(64),

        deliveryTimeAbsoluteMinutes: uint32(88),

        // ================================
        // LIVE NAVIGATION
        // ================================

        // Route advisor distance in meters.
        navigationDistanceMeters: nonNegativeFiniteFloat(1060),

        // Route advisor ETA in seconds.
        navigationTimeSeconds: nonNegativeFiniteFloat(1064),
      );
    }

    // ========================================
    // BUILD COMPLETE FRAME
    // ========================================

    return ScsTelemetryFrame(
      pluginRevision: revision,
      gameId: gameId,

      timestamp: uint64(8),

      sdkActive: boolean(0),
      paused: boolean(4),

      // Transmission.
      gear: int32(504),
      dashboardGear: int32(508),

      // Engine.
      speedKmh: speedKmh,
      rpm: rpm,
      maxRpm: float32(740),
      engineOn: boolean(1576),

      // Brakes.
      parkBrake: boolean(1566),

      // Fuel.
      fuelLiters: fuel,
      fuelCapacityLiters: fuelCapacity,

      // Vehicle condition.
      odometerKm: float32(1056),
      waterTemperatureC: float32(1024),
      engineWear: float32(1036),

      // Driving assistance.
      cruiseControlKmh: float32(988) * 3.6,

      speedLimitKmh: float32(1068) * 3.6,

      // New active job data.
      job: currentJob,
    );
  }
}

// ============================================
// CONSOLE DIAGNOSTIC
// ============================================

/// Run from apps/desktop:
///
/// dart run lib/services/scs_telemetry_reader.dart
///
/// This diagnostic reads data directly from
/// the plugin without requiring Windows Hub's
/// WebSocket server or the Android application.
Future<void> main() async {
  if (!Platform.isWindows) {
    stderr.writeln('TruckLink telemetry requires Windows.');

    exitCode = 1;
    return;
  }

  final reader = ScsTelemetryReader();

  stdout.writeln('========================================');

  stdout.writeln(' TruckLink v0.7.1 - Job Telemetry');

  stdout.writeln('========================================');

  stdout.writeln('Запусти ETS2 или ATS и загрузи профиль.');

  stdout.writeln('Прими заказ для проверки его полей.');

  stdout.writeln('Нажми Ctrl+C для завершения.');

  stdout.writeln();

  int? previousTimestamp;
  bool? previousJobState;

  try {
    await for (final frame in reader.watch(
      interval: const Duration(seconds: 1),
    )) {
      if (frame == null) {
        if (previousTimestamp != null || previousJobState != false) {
          stdout.writeln('[WAITING] Shared memory недоступна.');
        }

        previousTimestamp = null;
        previousJobState = false;
        continue;
      }

      if (!frame.sdkActive) {
        stdout.writeln('[WAITING] SDK обнаружен, но не активен.');

        previousTimestamp = null;
        continue;
      }

      if (frame.paused) {
        stdout.writeln('[PAUSED] Игра на паузе.');

        continue;
      }

      final changed = previousTimestamp != frame.timestamp;

      previousTimestamp = frame.timestamp;

      final job = frame.job;

      if (job == null) {
        if (previousJobState != false) {
          stdout.writeln('----------------------------------------');

          stdout.writeln('Game: ${frame.gameName}');

          stdout.writeln('[NO JOB] Активного заказа нет.');
        }

        previousJobState = false;
        continue;
      }

      if (previousJobState != true) {
        stdout.writeln('[JOB STARTED] Обнаружена перевозка.');
      }

      previousJobState = true;

      stdout.writeln('----------------------------------------');

      stdout.writeln('Game: ${frame.gameName}');

      stdout.writeln('Revision: ${frame.pluginRevision}');

      stdout.writeln(
        'Telemetry updating: '
        '${changed ? "YES" : "NO"}',
      );

      stdout.writeln();

      stdout.writeln('Cargo: ${job.displayCargo}');

      stdout.writeln('Cargo ID: ${job.cargoId}');

      stdout.writeln('Route: ${job.displayRoute}');

      stdout.writeln('Source company: ${job.sourceCompany}');

      stdout.writeln(
        'Destination company: '
        '${job.destinationCompany}',
      );

      stdout.writeln('Market: ${job.jobMarket}');

      stdout.writeln('Reward: ${job.income}');

      stdout.writeln(
        'Planned distance: '
        '${job.plannedDistanceKm} km',
      );

      final remainingKm = job.navigationDistanceKm;

      stdout.writeln(
        'Navigation remaining: '
        '${remainingKm?.toStringAsFixed(1) ?? "N/A"} km',
      );

      final routeSeconds = job.navigationTimeSeconds;

      stdout.writeln(
        'Navigation ETA: '
        '${routeSeconds?.toStringAsFixed(0) ?? "N/A"} s',
      );

      stdout.writeln(
        'Cargo mass: '
        '${job.cargoMassKg?.toStringAsFixed(0) ?? "N/A"} kg',
      );

      stdout.writeln(
        'Cargo damage: '
        '${job.cargoDamagePercent?.toStringAsFixed(1) ?? "N/A"}%',
      );

      stdout.writeln('Cargo loaded: ${job.cargoLoaded}');

      stdout.writeln('Special job: ${job.specialJob}');

      stdout.writeln(
        'Delivery deadline (game minutes): '
        '${job.deliveryTimeAbsoluteMinutes}',
      );

      stdout.writeln(
        'Remaining delivery (game minutes): '
        '${job.remainingDeliveryMinutes ?? "N/A"}',
      );
    }
  } on UnsupportedError catch (error) {
    stderr.writeln('[UNSUPPORTED] $error');

    exitCode = 2;
  } on FormatException catch (error) {
    stderr.writeln('[INVALID DATA] $error');

    exitCode = 3;
  } catch (error) {
    stderr.writeln('[ERROR] $error');

    exitCode = 1;
  }
}
