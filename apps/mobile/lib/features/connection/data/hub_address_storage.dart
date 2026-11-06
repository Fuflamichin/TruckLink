import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Stores the last successfully connected Windows Hub.
///
/// Failed connection attempts must never be saved.
/// The connection screen calls save only after
/// TelemetryConnection confirms a successful
/// WebSocket connection.
class HubAddressStorage {
  HubAddressStorage({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  static const String _key = 'trucklink.connection.last_successful_ipv4.v1';

  // ==========================================
  // LOAD
  // ==========================================

  Future<String?> loadLastSuccessfulIp() async {
    final saved = await _preferences.getString(_key);

    if (saved == null) return null;

    final ip = saved.trim();

    // Ignore invalid old settings.
    if (!_isValidIpv4(ip)) {
      return null;
    }

    return ip;
  }

  // ==========================================
  // SAVE
  // ==========================================

  Future<void> saveLastSuccessfulIp(String host) async {
    final ip = host.trim();

    if (!_isValidIpv4(ip)) {
      throw ArgumentError.value(host, 'host', 'Expected a valid IPv4 address');
    }

    await _preferences.setString(_key, ip);
  }

  // ==========================================
  // VALIDATION
  // ==========================================

  bool _isValidIpv4(String host) {
    final address = InternetAddress.tryParse(host);

    return address != null && address.type == InternetAddressType.IPv4;
  }
}
