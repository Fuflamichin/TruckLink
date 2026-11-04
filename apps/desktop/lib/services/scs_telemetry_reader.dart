import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:telemetry_core/telemetry_core.dart';

import 'scs_shared_memory.dart';

/// Reads real ETS2 / ATS telemetry from Windows Shared Memory.
///
/// Supported plugin:
/// truckermudgeon/scs-sdk-plugin
///
/// Supported telemetry layout revision: 12.
class ScsTelemetryReader {
  ScsTelemetryReader({ScsSharedMemory? memory})
    : _memory = memory ?? ScsSharedMemory();

  final ScsSharedMemory _memory;

  static const int readSize = 1600;

  /// Returns null when the telemetry mapping is absent.
  ScsTelemetryFrame? read() {
    final bytes = _memory.readBytes(readSize);

    if (bytes == null) {
      return null;
    }

    return ScsTelemetryFrame.fromBytes(bytes);
  }

  /// Periodically reads telemetry from the game.
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

/// Represents one complete sample of truck telemetry.
///
/// Units:
/// - Speed: km/h
/// - Fuel: liters
/// - Odometer: km
/// - Temperature: Celsius
/// - Engine wear: fraction (0.0 - 1.0)
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
  });

  static const int supportedRevision = 12;
  static const int minimumBytes = 1577;

  // ==========================================
  // PLUGIN INFORMATION
  // ==========================================

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
  // CONVERT TO TRUCKLINK MODEL
  // ==========================================

  /// Converts the SCS SDK telemetry into the shared
  /// TruckSnapshot model used by Windows and mobile.
  ///
  /// The plugin timestamp is not a Unix timestamp.
  /// We use the local UTC sampling time instead.
  ///
  /// Invalid optional floating-point values are
  /// converted to null to keep JSON serialization safe.
  TruckSnapshot toTruckSnapshot() {
    double? finiteOrNull(double value) {
      return value.isFinite ? value : null;
    }

    return TruckSnapshot(
      // Core telemetry
      timestamp: DateTime.now().toUtc(),
      speedKmh: speedKmh,
      rpm: rpm,
      gear: gear,
      fuelLiters: fuelLiters,
      fuelCapacityLiters: fuelCapacityLiters,
      engineOn: engineOn,

      // Extended engine telemetry
      maxRpm: finiteOrNull(maxRpm),
      waterTemperatureC: finiteOrNull(waterTemperatureC),

      // Truck condition
      odometerKm: finiteOrNull(odometerKm),
      engineWear: finiteOrNull(engineWear),

      // Driving assistance
      cruiseControlKmh: finiteOrNull(cruiseControlKmh),
      speedLimitKmh: finiteOrNull(speedLimitKmh),

      // Additional vehicle state
      parkBrake: parkBrake,
      dashboardGear: dashboardGear,

      // Job information will be added separately.
      job: null,
    );
  }

  // ==========================================
  // BINARY DECODING
  // ==========================================

  /// Decodes revision 12 of scsTelemetryMap_t.
  factory ScsTelemetryFrame.fromBytes(Uint8List bytes) {
    if (bytes.length < minimumBytes) {
      throw FormatException(
        'Telemetry buffer too small: '
        '${bytes.length} bytes',
      );
    }

    final data = ByteData.sublistView(bytes);

    int uint32(int offset) {
      return data.getUint32(offset, Endian.little);
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

    // ========================================
    // PLUGIN HEADER
    // ========================================

    final revision = uint32(40);

    if (revision != supportedRevision) {
      throw UnsupportedError(
        'Unsupported telemetry revision: '
        '$revision. Expected: $supportedRevision.',
      );
    }

    final gameId = uint32(52);

    if (gameId != 0 && gameId != 1 && gameId != 2) {
      throw FormatException('Unexpected game ID: $gameId');
    }

    // ========================================
    // CORE DATA
    // ========================================

    // SCS SDK speed values are in m/s.
    // Convert to km/h.
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
    // BUILD FRAME
    // ========================================

    return ScsTelemetryFrame(
      pluginRevision: revision,
      gameId: gameId,

      timestamp: data.getUint64(8, Endian.little),

      sdkActive: boolean(0),
      paused: boolean(4),

      // Transmission
      gear: int32(504),
      dashboardGear: int32(508),

      // Engine
      speedKmh: speedKmh,
      rpm: rpm,
      maxRpm: float32(740),
      engineOn: boolean(1576),

      // Brakes
      parkBrake: boolean(1566),

      // Fuel
      fuelLiters: fuel,
      fuelCapacityLiters: fuelCapacity,

      // Vehicle condition
      odometerKm: float32(1056),
      waterTemperatureC: float32(1024),
      engineWear: float32(1036),

      // Driving assistance
      cruiseControlKmh: float32(988) * 3.6,

      speedLimitKmh: float32(1068) * 3.6,
    );
  }
}

// ============================================
// CONSOLE DIAGNOSTICS
// ============================================

/// Run from apps/desktop:
///
/// dart run lib/services/scs_telemetry_reader.dart
Future<void> main() async {
  if (!Platform.isWindows) {
    stderr.writeln('TruckLink telemetry requires Windows.');

    exitCode = 1;
    return;
  }

  final reader = ScsTelemetryReader();

  stdout.writeln('===================================');

  stdout.writeln(' TruckLink - Extended Telemetry');

  stdout.writeln('===================================');

  stdout.writeln('Start ETS2 and enter your truck.');

  stdout.writeln('Press Ctrl+C to stop.');

  stdout.writeln();

  int? previousTimestamp;

  try {
    await for (final frame in reader.watch(
      interval: const Duration(seconds: 1),
    )) {
      if (frame == null) {
        previousTimestamp = null;

        stdout.writeln('[WAITING] SCS Plugin not found.');

        continue;
      }

      if (!frame.sdkActive) {
        previousTimestamp = null;

        stdout.writeln('[WAITING] SDK not active.');

        continue;
      }

      if (frame.paused) {
        stdout.writeln('[PAUSED] Telemetry paused.');

        continue;
      }

      final changed = previousTimestamp != frame.timestamp;

      previousTimestamp = frame.timestamp;

      final snapshot = frame.toTruckSnapshot();

      stdout.writeln('-----------------------------------');

      stdout.writeln('Game: ${frame.gameName}');

      stdout.writeln('Revision: ${frame.pluginRevision}');

      stdout.writeln('Data changed: ${changed ? "YES" : "NO"}');

      stdout.writeln(
        'Speed: '
        '${snapshot.speedKmh.toStringAsFixed(1)} km/h',
      );

      stdout.writeln('RPM: ${snapshot.rpm.toStringAsFixed(0)}');

      stdout.writeln('Gear: ${snapshot.gear}');

      stdout.writeln(
        'Dashboard gear: '
        '${snapshot.dashboardGear}',
      );

      stdout.writeln(
        'Engine: '
        '${snapshot.engineOn ? "ON" : "OFF"}',
      );

      stdout.writeln(
        'Fuel: '
        '${snapshot.fuelLiters.toStringAsFixed(1)} L '
        '/ '
        '${snapshot.fuelCapacityLiters.toStringAsFixed(1)} L',
      );

      stdout.writeln(
        'Fuel percent: '
        '${snapshot.fuelPercent.toStringAsFixed(1)}%',
      );

      stdout.writeln(
        'Odometer: '
        '${snapshot.odometerKm?.toStringAsFixed(1) ?? "N/A"} km',
      );

      stdout.writeln(
        'Water temperature: '
        '${snapshot.waterTemperatureC?.toStringAsFixed(1) ?? "N/A"} C',
      );

      stdout.writeln(
        'Engine wear: '
        '${snapshot.engineWearPercent?.toStringAsFixed(1) ?? "N/A"}%',
      );

      stdout.writeln(
        'Cruise control: '
        '${snapshot.cruiseControlKmh?.toStringAsFixed(1) ?? "N/A"} km/h',
      );

      stdout.writeln(
        'Speed limit: '
        '${snapshot.speedLimitKmh?.toStringAsFixed(1) ?? "N/A"} km/h',
      );

      stdout.writeln(
        'Parking brake: '
        '${snapshot.parkBrake == true ? "ON" : "OFF"}',
      );

      stdout.writeln('===================================');
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
