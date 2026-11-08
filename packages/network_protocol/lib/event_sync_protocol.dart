import 'dart:convert';

import 'network_protocol.dart' show protocolVersion;

// ============================================
// TRUCKLINK EVENT SYNC PROTOCOL v0.8.4
// ============================================

const String eventSyncRequestType = 'event_sync_request';
const String eventSyncBeginType = 'event_sync_begin';
const String eventSyncEndType = 'event_sync_end';

// ============================================
// SHARED MESSAGE READER
// ============================================

Map<String, dynamic> _readEnvelope(String message, String expectedType) {
  final decoded = jsonDecode(message);

  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object');
  }

  if (decoded['version'] != protocolVersion ||
      decoded['type'] != expectedType) {
    throw FormatException('Unsupported message: $expectedType');
  }

  return decoded;
}

bool _isMessageType(String message, String type) {
  try {
    final decoded = jsonDecode(message);

    return decoded is Map<String, dynamic> && decoded['type'] == type;
  } on FormatException {
    return false;
  }
}

// ============================================
// CLIENT REQUEST
// ============================================

String encodeEventSyncRequest() {
  return jsonEncode({'version': protocolVersion, 'type': eventSyncRequestType});
}

bool isEventSyncRequestMessage(String message) {
  return _isMessageType(message, eventSyncRequestType);
}

void decodeEventSyncRequest(String message) {
  _readEnvelope(message, eventSyncRequestType);
}

// ============================================
// HUB: BEGIN REPLAY
// ============================================

String encodeEventSyncBegin({required int eventCount}) {
  if (eventCount < 0) {
    throw ArgumentError.value(eventCount, 'eventCount');
  }

  return jsonEncode({
    'version': protocolVersion,
    'type': eventSyncBeginType,
    'count': eventCount,
  });
}

bool isEventSyncBeginMessage(String message) {
  return _isMessageType(message, eventSyncBeginType);
}

int decodeEventSyncBegin(String message) {
  final decoded = _readEnvelope(message, eventSyncBeginType);

  final count = decoded['count'];

  if (count is! int || count < 0) {
    throw const FormatException('Invalid sync event count');
  }

  return count;
}

// ============================================
// HUB: END REPLAY
// ============================================

String encodeEventSyncEnd({required int eventCount}) {
  if (eventCount < 0) {
    throw ArgumentError.value(eventCount, 'eventCount');
  }

  return jsonEncode({
    'version': protocolVersion,
    'type': eventSyncEndType,
    'count': eventCount,
  });
}

bool isEventSyncEndMessage(String message) {
  return _isMessageType(message, eventSyncEndType);
}

int decodeEventSyncEnd(String message) {
  final decoded = _readEnvelope(message, eventSyncEndType);

  final count = decoded['count'];

  if (count is! int || count < 0) {
    throw const FormatException('Invalid completed sync event count');
  }

  return count;
}
