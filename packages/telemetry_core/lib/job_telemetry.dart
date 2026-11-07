/// Active ETS2 / ATS delivery.
///
/// This model is shared by Windows Hub and
/// the mobile application.
///
/// Null job means there is no active delivery.
class TruckLinkJobTelemetry {
  const TruckLinkJobTelemetry({
    required this.gameId,
    required this.cargoId,
    required this.cargoName,
    required this.sourceCity,
    required this.destinationCity,
    required this.sourceCompany,
    required this.destinationCompany,
    required this.jobMarket,
    required this.income,
    required this.plannedDistanceKm,
    required this.unitCount,
    required this.cargoLoaded,
    required this.specialJob,
    this.cargoMassKg,
    this.cargoDamagePercent,
    this.navigationDistanceKm,
    this.navigationTimeSeconds,
    this.deliveryTimeAbsoluteMinutes,
    this.remainingDeliveryMinutes,
  });

  final int gameId;

  final String cargoId;
  final String cargoName;

  final String sourceCity;
  final String destinationCity;

  final String sourceCompany;
  final String destinationCompany;

  final String jobMarket;

  /// Reward in the game's configured currency.
  final int income;

  /// Original job distance in kilometres.
  final int plannedDistanceKm;

  final int unitCount;
  final bool cargoLoaded;
  final bool specialJob;

  final double? cargoMassKg;
  final double? cargoDamagePercent;

  /// Current navigation distance in kilometres.
  final double? navigationDistanceKm;

  /// Route advisor ETA in seconds.
  final double? navigationTimeSeconds;

  /// Absolute game-time deadline in minutes.
  final int? deliveryTimeAbsoluteMinutes;

  /// Remaining delivery time in game minutes.
  final int? remainingDeliveryMinutes;

  String get gameName => switch (gameId) {
    1 => 'Euro Truck Simulator 2',
    2 => 'American Truck Simulator',
    _ => 'Unknown',
  };

  String get displayCargo =>
      cargoName.trim().isEmpty ? 'Неизвестный груз' : cargoName;

  String get displayRoute {
    final source = sourceCity.isEmpty ? 'Неизвестно' : sourceCity;

    final destination = destinationCity.isEmpty
        ? 'Неизвестно'
        : destinationCity;

    return '$source → $destination';
  }

  // ==========================================
  // SERIALIZE
  // ==========================================

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'cargoId': cargoId,
      'cargoName': cargoName,
      'sourceCity': sourceCity,
      'destinationCity': destinationCity,
      'sourceCompany': sourceCompany,
      'destinationCompany': destinationCompany,
      'jobMarket': jobMarket,
      'income': income,
      'plannedDistanceKm': plannedDistanceKm,
      'unitCount': unitCount,
      'cargoLoaded': cargoLoaded,
      'specialJob': specialJob,
      'cargoMassKg': cargoMassKg,
      'cargoDamagePercent': cargoDamagePercent,
      'navigationDistanceKm': navigationDistanceKm,
      'navigationTimeSeconds': navigationTimeSeconds,
      'deliveryTimeAbsoluteMinutes': deliveryTimeAbsoluteMinutes,
      'remainingDeliveryMinutes': remainingDeliveryMinutes,
    };
  }

  // ==========================================
  // DESERIALIZE
  // ==========================================

  factory TruckLinkJobTelemetry.fromJson(Map<String, dynamic> json) {
    String stringValue(String key) {
      final value = json[key];
      return value is String ? value : '';
    }

    int intValue(String key) {
      final value = json[key];

      if (value is num && value.isFinite) {
        return value.toInt();
      }

      return 0;
    }

    int? optionalInt(String key) {
      final value = json[key];

      if (value is num && value.isFinite) {
        return value.toInt();
      }

      return null;
    }

    double? optionalDouble(String key) {
      final value = json[key];

      if (value is num && value.isFinite) {
        return value.toDouble();
      }

      return null;
    }

    bool boolValue(String key) {
      return json[key] == true;
    }

    return TruckLinkJobTelemetry(
      gameId: intValue('gameId'),
      cargoId: stringValue('cargoId'),
      cargoName: stringValue('cargoName'),
      sourceCity: stringValue('sourceCity'),
      destinationCity: stringValue('destinationCity'),
      sourceCompany: stringValue('sourceCompany'),
      destinationCompany: stringValue('destinationCompany'),
      jobMarket: stringValue('jobMarket'),
      income: intValue('income'),
      plannedDistanceKm: intValue('plannedDistanceKm'),
      unitCount: intValue('unitCount'),
      cargoLoaded: boolValue('cargoLoaded'),
      specialJob: boolValue('specialJob'),
      cargoMassKg: optionalDouble('cargoMassKg'),
      cargoDamagePercent: optionalDouble('cargoDamagePercent'),
      navigationDistanceKm: optionalDouble('navigationDistanceKm'),
      navigationTimeSeconds: optionalDouble('navigationTimeSeconds'),
      deliveryTimeAbsoluteMinutes: optionalInt('deliveryTimeAbsoluteMinutes'),
      remainingDeliveryMinutes: optionalInt('remainingDeliveryMinutes'),
    );
  }
}
