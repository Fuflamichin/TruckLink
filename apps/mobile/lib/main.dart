import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_shell.dart';
import 'core/network/telemetry_connection.dart';
import 'features/connection/connection_screen.dart';

// ============================================
// APPLICATION ENTRY POINT
// ============================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mobile application uses portrait orientation.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: TruckLinkApp()));
}

// ============================================
// SHARED TELEMETRY CONTROLLER
// ============================================

/// One telemetry connection for the entire app.
///
/// It survives navigation between screens and
/// is reused by the connection screen and AppShell.
final telemetryConnectionProvider = Provider<TelemetryConnection>((ref) {
  final connection = TelemetryConnection();

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
    final connection = ref.watch(telemetryConnectionProvider);

    return MaterialApp(
      title: 'TruckLink',
      debugShowCheckedModeBanner: false,

      // Will be replaced with customizable themes.
      theme: TruckLinkTheme.dark,

      // Controls access to the main application.
      home: _ConnectionGate(connection: connection),
    );
  }
}

// ============================================
// CONNECTION GATE
// ============================================

/// Switches between:
///
/// 1. ConnectionScreen - no active PC connection.
/// 2. AppShell - PC connection established.
///
/// It does not create its own WebSocket.
/// The same TelemetryConnection instance is used
/// on both sides of the gate.
class _ConnectionGate extends StatefulWidget {
  const _ConnectionGate({required this.connection});

  final TelemetryConnection connection;

  @override
  State<_ConnectionGate> createState() => _ConnectionGateState();
}

class _ConnectionGateState extends State<_ConnectionGate> {
  bool _enteredApp = false;

  @override
  void initState() {
    super.initState();

    widget.connection.addListener(_onConnectionChanged);
  }

  // ==========================================
  // CONTROLLER REPLACEMENT
  // ==========================================

  @override
  void didUpdateWidget(covariant _ConnectionGate oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onConnectionChanged);

      widget.connection.addListener(_onConnectionChanged);

      // A new connection must pass through the
      // connection screen again.
      _enteredApp = false;
    }
  }

  // ==========================================
  // CONNECTION LOST
  // ==========================================

  void _onConnectionChanged() {
    if (!mounted) return;

    // Waiting for ETS2 telemetry is NOT the same
    // as losing the connection to Windows Hub.
    //
    // isConnected remains true while the
    // WebSocket is alive and telemetry is waiting
    // or temporarily stale.
    if (_enteredApp && !widget.connection.isConnected) {
      setState(() {
        _enteredApp = false;
      });
    }
  }

  // ==========================================
  // ENTER APPLICATION
  // ==========================================

  void _onConnected() {
    if (!mounted) return;

    if (!widget.connection.isConnected) {
      return;
    }

    if (_enteredApp) return;

    setState(() {
      _enteredApp = true;
    });
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    if (!_enteredApp) {
      return ConnectionScreen(
        key: const ValueKey('trucklink-connection'),
        connection: widget.connection,
        onConnected: _onConnected,
      );
    }

    return AppShell(
      key: const ValueKey('trucklink-app-shell'),
      connection: widget.connection,
    );
  }

  // ==========================================
  // CLEANUP
  // ==========================================

  @override
  void dispose() {
    widget.connection.removeListener(_onConnectionChanged);

    super.dispose();
  }
}
