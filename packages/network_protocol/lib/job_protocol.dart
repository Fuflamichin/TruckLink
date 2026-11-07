import 'dart:convert';

import 'package:telemetry_core/job_telemetry.dart';

import 'network_protocol.dart' show protocolVersion;

// ============================================
// JOB MESSAGE PROTOCOL
// ============================================

const String jobUpdateMessageType = 'job_update';

/// Encode an active job or a job-cleared event.
///
/// Examples:
///
/// {"version":1,"type":"job_update","payload":{...}}
///
/// {"version":1,"type":"job_update","payload":null}
///
/// The existing snapshot message format
/// remains unchanged.
String encodeJobUpdate(TruckLinkJobTelemetry? job) {
  return jsonEncode({
    'version': protocolVersion,
    'type': jobUpdateMessageType,
    'payload': job?.toJson(),
  });
}

// ============================================
// RECOGNIZE MESSAGE TYPE
// ============================================

bool isJobUpdateMessage(String encoded) {
  try {
    final decoded = jsonDecode(encoded);

    return decoded is Map<String, dynamic> &&
        decoded['type'] == jobUpdateMessageType;
  } on FormatException {
    return false;
  }
}

// ============================================
// DECODE JOB UPDATE
// ============================================

TruckLinkJobTelemetry? decodeJobUpdate(String encoded) {
  final decoded = jsonDecode(encoded);

  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Invalid job update envelope');
  }

  if (decoded['version'] != protocolVersion ||
      decoded['type'] != jobUpdateMessageType) {
    throw const FormatException('Unsupported job update message');
  }

  final payload = decoded['payload'];

  // Explicitly tells mobile to clear the job.
  if (payload == null) {
    return null;
  }

  if (payload is! Map<String, dynamic>) {
    throw const FormatException('Invalid job update payload');
  }

  return TruckLinkJobTelemetry.fromJson(payload);
}
