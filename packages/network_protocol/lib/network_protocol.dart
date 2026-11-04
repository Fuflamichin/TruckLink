import 'dart:convert';
import 'package:telemetry_core/telemetry_core.dart';

const protocolVersion = 1;

/// JSON wire format: {version:1, type:"snapshot", payload:{...}}
String encodeSnapshot(TruckSnapshot value) => jsonEncode({
  'version': protocolVersion,
  'type': 'snapshot',
  'payload': value.toJson(),
});

TruckSnapshot decodeSnapshot(String encoded) {
  final message = jsonDecode(encoded) as Map<String, dynamic>;
  if (message['version'] != protocolVersion || message['type'] != 'snapshot') {
    throw const FormatException('Unsupported protocol message');
  }
  return TruckSnapshot.fromJson(message['payload'] as Map<String, dynamic>);
}
