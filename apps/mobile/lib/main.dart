import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/telemetry_connection.dart';
import 'features/dashboard/dashboard_screen.dart';

// ============================================
// APPLICATION ENTRY POINT
// ============================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TruckLink Mobile uses portrait orientation.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: TruckLinkApp()));
}

// ============================================
// GLOBAL DEPENDENCIES
// ============================================

/// Provides one shared telemetry connection.
///
/// The connection is created once and reused
/// across the application's screens.
///
/// Future screens such as Jobs, Truck, GPS and
/// Statistics will use the same connection.
final telemetryConnectionProvider = Provider<TelemetryConnection>((ref) {
  final connection = TelemetryConnection();

  // Release sockets and timers when the
  // provider is disposed.
  ref.onDispose(connection.dispose);

  return connection;
});

// ============================================
// APPLICATION
// ============================================

class TruckLinkApp extends ConsumerWidget {
  const TruckLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider instance, not every
    // individual telemetry update.
    final connection = ref.watch(telemetryConnectionProvider);

    return MaterialApp(
      title: 'TruckLink',
      debugShowCheckedModeBanner: false,

      // Shared application theme.
      // Custom themes will be added later.
      theme: TruckLinkTheme.dark,

      // Application entry screen.
      // AppShell with bottom navigation
      // will replace this in the next stage.
      home: DashboardScreen(connection: connection),
    );
  }
}
