import 'package:telemetry_core/job_telemetry.dart';

import 'scs_telemetry_reader.dart';

// ============================================
// SCS JOB -> TRUCKLINK JOB
// ============================================

/// Convert the rev12 SCS job fields into
/// a shared TruckLink job model.
///
/// Returns null when there is no active job.
TruckLinkJobTelemetry? jobTelemetryFromScs(ScsTelemetryFrame frame) {
  final job = frame.job;

  if (job == null) {
    return null;
  }

  return TruckLinkJobTelemetry(
    gameId: frame.gameId,

    // Cargo.
    cargoId: job.cargoId,
    cargoName: job.cargoName,
    cargoMassKg: job.cargoMassKg,
    cargoDamagePercent: job.cargoDamagePercent,
    unitCount: job.unitCount,
    cargoLoaded: job.cargoLoaded,
    specialJob: job.specialJob,

    // Route.
    sourceCity: job.sourceCity,
    destinationCity: job.destinationCity,
    sourceCompany: job.sourceCompany,
    destinationCompany: job.destinationCompany,

    // Job details.
    jobMarket: job.jobMarket,
    income: job.income,
    plannedDistanceKm: job.plannedDistanceKm,

    // Live GPS.
    navigationDistanceKm: job.navigationDistanceKm,
    navigationTimeSeconds: job.navigationTimeSeconds,

    // Delivery deadline.
    deliveryTimeAbsoluteMinutes: job.deliveryTimeAbsoluteMinutes,
    remainingDeliveryMinutes: job.remainingDeliveryMinutes,
  );
}
