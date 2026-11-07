import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

// ============================================
// IDENTIFIED WEBSOCKET
// ============================================

/// A normal WebSocket connection that also sends
/// device information to TruckLink Hub.
///
/// The connection remains compatible with the
/// existing TruckLink telemetry protocol.
class IdentifiedWebSocket {
  const IdentifiedWebSocket._();

  // ==========================================
  // CONNECT
  // ==========================================

  static Future<WebSocket> connect(String url) async {
    // Preserve the same WebSocket type and
    // connection behavior as WebSocket.connect.
    final socket = await WebSocket.connect(url);

    // Device identification must never delay
    // receiving game telemetry.
    unawaited(_sendHello(socket));

    return socket;
  }

  // ==========================================
  // SEND HELLO
  // ==========================================

  static Future<void> _sendHello(WebSocket socket) async {
    try {
      final identity = await _readDeviceIdentity();

      if (socket.readyState != WebSocket.open) {
        return;
      }

      final message = jsonEncode({
        'type': 'client_hello',
        'version': 1,
        'name': identity.name,
        'platform': identity.platform,
      });

      socket.add(message);

      debugPrint(
        'TruckLink: device identification sent: '
        '${identity.name}',
      );
    } catch (error) {
      // Device detection is optional.
      // A failed hello must never disconnect
      // an otherwise healthy telemetry stream.
      debugPrint(
        'TruckLink: device identification failed: '
        '$error',
      );
    }
  }

  // ==========================================
  // DETECT DEVICE
  // ==========================================

  static Future<_DeviceIdentity> _readDeviceIdentity() async {
    final plugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;

      final manufacturer = _clean(info.manufacturer);

      final model = _clean(info.model);

      if (model.isEmpty) {
        return const _DeviceIdentity(
          name: 'Android-устройство',
          platform: 'Android',
        );
      }

      final brand = manufacturer.isEmpty ? '' : _capitalize(manufacturer);

      final name =
          brand.isEmpty || model.toLowerCase().startsWith(brand.toLowerCase())
          ? model
          : '$brand $model';

      return _DeviceIdentity(name: name, platform: 'Android');
    }

    if (Platform.isIOS) {
      final info = await plugin.iosInfo;

      final model = _clean(info.model);

      return _DeviceIdentity(
        name: model.isEmpty ? 'iPhone / iPad' : model,
        platform: 'iOS',
      );
    }

    return _DeviceIdentity(
      name: 'TruckLink (${Platform.operatingSystem})',
      platform: Platform.operatingSystem,
    );
  }

  // ==========================================
  // TEXT HELPERS
  // ==========================================

  static String _clean(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;

    return value[0].toUpperCase() + value.substring(1);
  }
}

class _DeviceIdentity {
  const _DeviceIdentity({required this.name, required this.platform});

  final String name;
  final String platform;
}
