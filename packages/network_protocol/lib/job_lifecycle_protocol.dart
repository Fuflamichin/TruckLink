import 'dart:convert';

import 'network_protocol.dart' show protocolVersion;

// ============================================
// JOB LIFECYCLE EVENTS
// ============================================

enum JobLifecycleEventKind { started, delivered, cancelled }

const String jobEventMessageType = 'job_event';

// ============================================
// ENCODE EVENT
// ============================================

String encodeJobEvent(JobLifecycleEventKind event) {
  return jsonEncode({
    'version': protocolVersion,
    'type': jobEventMessageType,
    'event': event.name,
  });
}

// ============================================
// IDENTIFY EVENT MESSAGE
// ============================================

bool isJobEventMessage(String message) {
  try {
    final decoded = jsonDecode(message);

    return decoded is Map<String, dynamic> &&
        decoded['type'] == jobEventMessageType;
  } on FormatException {
    return false;
  }
}

// ============================================
// DECODE EVENT
// ============================================

JobLifecycleEventKind decodeJobEvent(String message) {
  final decoded = jsonDecode(message);

  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Invalid job event envelope');
  }

  if (decoded['version'] != protocolVersion ||
      decoded['type'] != jobEventMessageType) {
    throw const FormatException('Unsupported job event message');
  }

  return switch (decoded['event']) {
    'started' => JobLifecycleEventKind.started,
    'delivered' => JobLifecycleEventKind.delivered,
    'cancelled' => JobLifecycleEventKind.cancelled,
    _ => throw const FormatException('Unknown job event'),
  };
}
