/// Shared game state. Values in the starter app are DEMO data, not ETS2 telemetry.
class TruckSnapshot {
  const TruckSnapshot({
    required this.timestamp,
    required this.speedKmh,
    required this.rpm,
    required this.gear,
    required this.fuelLiters,
    required this.fuelCapacityLiters,
    required this.engineOn,
  });

  final DateTime timestamp;
  final double speedKmh;
  final double rpm;
  final int gear;
  final double fuelLiters;
  final double fuelCapacityLiters;
  final bool engineOn;

  double get fuelFraction => fuelCapacityLiters <= 0
      ? 0
      : (fuelLiters / fuelCapacityLiters).clamp(0.0, 1.0);

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toUtc().toIso8601String(),
    'speedKmh': speedKmh,
    'rpm': rpm,
    'gear': gear,
    'fuelLiters': fuelLiters,
    'fuelCapacityLiters': fuelCapacityLiters,
    'engineOn': engineOn,
  };

  factory TruckSnapshot.fromJson(Map<String, dynamic> json) => TruckSnapshot(
    timestamp: DateTime.parse(json['timestamp'] as String),
    speedKmh: (json['speedKmh'] as num).toDouble(),
    rpm: (json['rpm'] as num).toDouble(),
    gear: (json['gear'] as num).toInt(),
    fuelLiters: (json['fuelLiters'] as num).toDouble(),
    fuelCapacityLiters: (json['fuelCapacityLiters'] as num).toDouble(),
    engineOn: json['engineOn'] as bool,
  );

  factory TruckSnapshot.demo() => TruckSnapshot(
    timestamp: DateTime.now().toUtc(),
    speedKmh: 82.4,
    rpm: 1340,
    gear: 10,
    fuelLiters: 466,
    fuelCapacityLiters: 600,
    engineOn: true,
  );
}
