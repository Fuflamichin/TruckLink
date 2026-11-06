import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_shell.dart';
import 'core/appearance/appearance_provider.dart';
import 'core/appearance/trucklink_appearance_theme.dart';
import 'core/network/telemetry_connection.dart';
import 'features/connection/connection_screen.dart';

// ============================================
// APPLICATION ENTRY POINT
// ============================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TruckLink currently uses portrait mode.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Dark system navigation and status bars.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF091018),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: TruckLinkApp()));
}

// ============================================
// TELEMETRY CONNECTION PROVIDER
// ============================================

/// One WebSocket connection for the application.
///
/// Changing themes or navigation must never
/// create another connection to Windows Hub.
final telemetryConnectionProvider = Provider<TelemetryConnection>((ref) {
  final connection = TelemetryConnection();

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
    // The connection is independent
    // from the appearance controller.
    final connection = ref.watch(telemetryConnectionProvider);

    // One globally shared appearance controller.
    final appearance = ref.watch(appearanceControllerProvider);

    // ChangeNotifier changes trigger a theme
    // rebuild without recreating Riverpod state.
    return ListenableBuilder(
      listenable: appearance,
      builder: (context, child) {
        final theme = TruckLinkAppearanceTheme.build(appearance.settings);

        return MaterialApp(
          title: 'TruckLink',
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: _ConnectionGate(connection: connection),
        );
      },
    );
  }
}

// ============================================
// CONNECTION GATE
// ============================================

/// Displays the connection screen until
/// Windows Hub is connected.
///
/// Once connected, the user gets AppShell
/// with the personalized navigation.
class _ConnectionGate extends StatelessWidget {
  const _ConnectionGate({required this.connection});

  final TelemetryConnection connection;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: connection,
      builder: (context, child) {
        if (connection.isConnected) {
          return AppShell(connection: connection);
        }

        return ConnectionScreen(connection: connection);
      },
    );
  }
}
