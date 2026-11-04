/// TruckLink shared telemetry models.
///
/// Used by Windows, Android and iOS.
/// All speed values use km/h.
/// Fuel and capacity use liters.
/// Engine wear uses a fraction from 0.0 to 1.0.

class TruckSnapshot {
  const TruckSnapshot({
    required this.timestamp,
    required this.speedKmh,
    required this.rpm,
    required this.gear,
    required this.fuelLiters,
    required this.fuelCapacityLiters,
    required this.engineOn,

    // Extended truck telemetry
    this.maxRpm,
    this.odometerKm,
    this.waterTemperatureC,
    this.engineWear,
    this.cruiseControlKmh,
    this.speedLimitKmh,
    this.parkBrake,
    this.dashboardGear,

    // Current delivery
    this.job,
  });

  // ==========================================
  // CORE TELEMETRY
  // ==========================================

  final DateTime timestamp;

  final double speedKmh;
  final double rpm;
  final int gear;

  final double fuelLiters;
  final double fuelCapacityLiters;

  final bool engineOn;

  // ==========================================
  // EXTENDED TRUCK TELEMETRY
  // ==========================================

  final double? maxRpm;
  final double? odometerKm;
  final double? waterTemperatureC;

  /// Engine wear from 0.0 to 1.0.
  final double? engineWear;

  final double? cruiseControlKmh;
  final double? speedLimitKmh;

  final bool? parkBrake;
  final int? dashboardGear;

  // ==========================================
  // CURRENT JOB
  // ==========================================

  final TruckJob? job;

  // ==========================================
  // CALCULATED VALUES
  // ==========================================

  double get fuelFraction {
    if (fuelCapacityLiters <= 0) return 0;

    return (fuelLiters / fuelCapacityLiters).clamp(0.0, 1.0).toDouble();
  }

  double get fuelPercent => fuelFraction * 100;

  double? get engineWearPercent {
    final wear = engineWear;

    if (wear == null) return null;

    return (wear * 100).clamp(0.0, 100.0).toDouble();
  }

  bool get hasJob => job != null;

  // ==========================================
  // JSON SERIALIZATION
  // ==========================================

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toUtc().toIso8601String(),

    'speedKmh': speedKmh,
    'rpm': rpm,
    'gear': gear,

    'fuelLiters': fuelLiters,
    'fuelCapacityLiters': fuelCapacityLiters,

    'engineOn': engineOn,

    if (maxRpm != null) 'maxRpm': maxRpm,

    if (odometerKm != null) 'odometerKm': odometerKm,

    if (waterTemperatureC != null) 'waterTemperatureC': waterTemperatureC,

    if (engineWear != null) 'engineWear': engineWear,

    if (cruiseControlKmh != null) 'cruiseControlKmh': cruiseControlKmh,

    if (speedLimitKmh != null) 'speedLimitKmh': speedLimitKmh,

    if (parkBrake != null) 'parkBrake': parkBrake,

    if (dashboardGear != null) 'dashboardGear': dashboardGear,

    if (job != null) 'job': job!.toJson(),
  };

  factory TruckSnapshot.fromJson(Map<String, dynamic> json) {
    return TruckSnapshot(
      timestamp: DateTime.parse(json['timestamp'] as String),

      speedKmh: (json['speedKmh'] as num).toDouble(),

      rpm: (json['rpm'] as num).toDouble(),

      gear: (json['gear'] as num).toInt(),

      fuelLiters: (json['fuelLiters'] as num).toDouble(),

      fuelCapacityLiters: (json['fuelCapacityLiters'] as num).toDouble(),

      engineOn: json['engineOn'] as bool,

      maxRpm: (json['maxRpm'] as num?)?.toDouble(),

      odometerKm: (json['odometerKm'] as num?)?.toDouble(),

      waterTemperatureC: (json['waterTemperatureC'] as num?)?.toDouble(),

      engineWear: (json['engineWear'] as num?)?.toDouble(),

      cruiseControlKmh: (json['cruiseControlKmh'] as num?)?.toDouble(),

      speedLimitKmh: (json['speedLimitKmh'] as num?)?.toDouble(),

      parkBrake: json['parkBrake'] as bool?,

      dashboardGear: (json['dashboardGear'] as num?)?.toInt(),

      job: _parseJob(json['job']),
    );
  }

  static TruckJob? _parseJob(Object? value) {
    if (value == null) return null;

    if (value is Map<String, dynamic>) {
      return TruckJob.fromJson(value);
    }

    throw const FormatException('Invalid job payload');
  }

  // ==========================================
  // DEMO DATA
  // ==========================================

  factory TruckSnapshot.demo() {
    return TruckSnapshot(
      timestamp: DateTime.now().toUtc(),

      speedKmh: 82.4,
      rpm: 1340,
      gear: 10,

      fuelLiters: 466,
      fuelCapacityLiters: 600,

      engineOn: true,

      maxRpm: 2500,
      odometerKm: 53626.9,
      waterTemperatureC: 87.5,

      engineWear: 0.008,

      cruiseControlKmh: 80,
      speedLimitKmh: 90,

      parkBrake: false,
      dashboardGear: 10,
    );
  }
}

// ============================================
// JOB MODEL
// ============================================

/// Information about the current ETS2/ATS job.
///
/// Fields are optional because not every SDK event
/// provides all delivery information.
///
/// Game time must not be confused with Unix time.

class TruckJob {
  const TruckJob({
    this.cargoName,
    this.cargoMassKg,
    this.sourceCity,
    this.sourceCompany,
    this.destinationCity,
    this.destinationCompany,
    this.reward,
    this.remainingDistanceKm,
    this.deadlineGameMinutes,
  });

  final String? cargoName;
  final double? cargoMassKg;

  final String? sourceCity;
  final String? sourceCompany;

  final String? destinationCity;
  final String? destinationCompany;

  /// Reward in the game's currency units.
  final int? reward;

  final double? remainingDistanceKm;

  /// Deadline in game-clock minutes.
  /// Not a Unix timestamp.
  final int? deadlineGameMinutes;

  Map<String, Object?> toJson() => {
    if (cargoName != null) 'cargoName': cargoName,

    if (cargoMassKg != null) 'cargoMassKg': cargoMassKg,

    if (sourceCity != null) 'sourceCity': sourceCity,

    if (sourceCompany != null) 'sourceCompany': sourceCompany,

    if (destinationCity != null) 'destinationCity': destinationCity,

    if (destinationCompany != null) 'destinationCompany': destinationCompany,

    if (reward != null) 'reward': reward,

    if (remainingDistanceKm != null) 'remainingDistanceKm': remainingDistanceKm,

    if (deadlineGameMinutes != null) 'deadlineGameMinutes': deadlineGameMinutes,
  };

  factory TruckJob.fromJson(Map<String, dynamic> json) {
    return TruckJob(
      cargoName: json['cargoName'] as String?,

      cargoMassKg: (json['cargoMassKg'] as num?)?.toDouble(),

      sourceCity: json['sourceCity'] as String?,

      sourceCompany: json['sourceCompany'] as String?,

      destinationCity: json['destinationCity'] as String?,

      destinationCompany: json['destinationCompany'] as String?,

      reward: (json['reward'] as num?)?.toInt(),

      remainingDistanceKm: (json['remainingDistanceKm'] as num?)?.toDouble(),

      deadlineGameMinutes: (json['deadlineGameMinutes'] as num?)?.toInt(),
    );
  }
}
