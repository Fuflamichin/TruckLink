import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_shell.dart';
import 'core/network/telemetry_connection.dart';

// ============================================
// APPLICATION ENTRY POINT
// ============================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait orientation for Android and iOS.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: TruckLinkApp()));
}

// ============================================
// SHARED TELEMETRY CONNECTION
// ============================================

/// One connection shared between all screens.
///
/// Switching between Dashboard, Truck, Jobs,
/// Finance and other pages will not recreate
/// the WebSocket connection.
final telemetryConnectionProvider = Provider<TelemetryConnection>((ref) {
  final connection = TelemetryConnection();

  // Dispose of sockets, subscriptions and timers
  // when the provider is destroyed.
  ref.onDispose(connection.dispose);

  return connection;
});

// ============================================
// TRUCKLINK APPLICATION
// ============================================

class TruckLinkApp extends ConsumerWidget {
  const TruckLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the controller instance.
    // Telemetry updates do not rebuild MaterialApp.
    final connection = ref.watch(telemetryConnectionProvider);

    return MaterialApp(
      title: 'TruckLink',
      debugShowCheckedModeBanner: false,

      // Temporary shared theme.
      // User customization will be added later.
      theme: TruckLinkTheme.dark,

      // New application shell with bottom navigation.
      home: AppShell(connection: connection),
    );
  }
}
