import 'package:network_protocol/job_lifecycle_protocol.dart';
import 'package:telemetry_core/job_telemetry.dart';

// ============================================
// SAVED DELIVERY
// ============================================

class JobHistoryEntry {
  const JobHistoryEntry({
    required this.id,
    required this.result,
    required this.completedAtUtc,
    required this.job,
  });

  final String id;
  final JobLifecycleEventKind result;
  final DateTime completedAtUtc;
  final TruckLinkJobTelemetry job;

  bool get isDelivered => result == JobLifecycleEventKind.delivered;

  bool get isCancelled => result == JobLifecycleEventKind.cancelled;

  String get statusText => isDelivered ? 'Доставлено' : 'Отменено';

  // ==========================================
  // JSON SERIALIZATION
  // ==========================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'result': result.name,
      'completedAtUtc': completedAtUtc.toUtc().toIso8601String(),
      'job': job.toJson(),
    };
  }

  factory JobHistoryEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final resultValue = json['result'];
    final timeValue = json['completedAtUtc'];
    final jobValue = json['job'];

    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Missing history entry ID');
    }

    final result = switch (resultValue) {
      'delivered' => JobLifecycleEventKind.delivered,
      'cancelled' => JobLifecycleEventKind.cancelled,
      _ => throw const FormatException('Invalid history entry result'),
    };

    if (timeValue is! String) {
      throw const FormatException('Missing history entry date');
    }

    final time = DateTime.tryParse(timeValue);

    if (time == null) {
      throw const FormatException('Invalid history entry date');
    }

    if (jobValue is! Map<String, dynamic>) {
      throw const FormatException('Invalid stored job');
    }

    return JobHistoryEntry(
      id: id,
      result: result,
      completedAtUtc: time.toUtc(),
      job: TruckLinkJobTelemetry.fromJson(jobValue),
    );
  }
}
