import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_shell.dart';
import 'core/network/telemetry_connection.dart';
import 'features/connection/connection_screen.dart';

// ============================================
// TRUCKLINK MOBILE
// ============================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TruckLink is designed for portrait mode.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Match Android system bars with the
  // dark TruckLink branding.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: TruckLinkColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: TruckLinkApp()));
}

// ============================================
// SHARED TELEMETRY CONNECTION
// ============================================

/// One TelemetryConnection for the entire app.
///
/// The connection is created once and shared
/// between ConnectionScreen, AppShell,
/// DashboardScreen and SettingsScreen.
///
/// The provider disposes the connection
/// when its lifetime ends.
final telemetryConnectionProvider = Provider<TelemetryConnection>((ref) {
  final connection = TelemetryConnection();

  ref.onDispose(connection.dispose);

  return connection;
});

// ============================================
// ROOT APPLICATION
// ============================================

class TruckLinkApp extends ConsumerWidget {
  const TruckLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(telemetryConnectionProvider);

    return MaterialApp(
      title: 'TruckLink',

      debugShowCheckedModeBanner: false,

      // Shared branded theme from design_system.
      theme: TruckLinkTheme.dark,

      themeMode: ThemeMode.dark,

      // The gate controls the active screen
      // according to WebSocket status.
      home: _ConnectionGate(connection: connection),
    );
  }
}

// ============================================
// CONNECTION GATE
// ============================================

/// Switches automatically between:
///
/// 1. ConnectionScreen - no connection
/// 2. AppShell         - Windows Hub connected
///
/// A connected WebSocket does not require
/// ETS2/ATS to be running.
///
/// TelemetryConnection.isConnected includes
/// waiting, connected and stale statuses.
///
/// No onConnected callback is needed.
class _ConnectionGate extends StatelessWidget {
  const _ConnectionGate({required this.connection});

  final TelemetryConnection connection;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: connection,
      builder: (context, child) {
        // ====================================
        // CONNECTED TO WINDOWS HUB
        // ====================================

        if (connection.isConnected) {
          return AppShell(
            key: const ValueKey('trucklink-app-shell'),
            connection: connection,
          );
        }

        // ====================================
        // NOT CONNECTED
        // ====================================

        return ConnectionScreen(
          key: const ValueKey('trucklink-connection-screen'),
          connection: connection,
        );
      },
    );
  }
}
