import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/telemetry_connection.dart';

// ============================================
// TRUCKLINK CONNECTION SCREEN
// ============================================

/// Start screen shown before entering the app.
///
/// The existing TelemetryConnection is reused.
/// No new WebSocket controller is created here.
class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({
    super.key,
    required this.connection,
    required this.onConnected,
  });

  final TelemetryConnection connection;

  /// Called once when the Windows Hub connection
  /// has been successfully established.
  final VoidCallback onConnected;

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final TextEditingController _hostController = TextEditingController();

  late TelemetryConnectionStatus _status;
  late String _statusMessage;

  bool _completed = false;

  @override
  void initState() {
    super.initState();

    _status = widget.connection.status;
    _statusMessage = widget.connection.statusMessage;

    _hostController.text = widget.connection.connectedHost ?? '';

    widget.connection.addListener(_onConnectionChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _completeIfConnected();
    });
  }

  @override
  void didUpdateWidget(covariant ConnectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onConnectionChanged);

      widget.connection.addListener(_onConnectionChanged);

      _completed = false;

      _status = widget.connection.status;
      _statusMessage = widget.connection.statusMessage;

      _hostController.text = widget.connection.connectedHost ?? '';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _completeIfConnected();
      });
    }
  }

  // ==========================================
  // CONNECTION STATE
  // ==========================================

  void _onConnectionChanged() {
    if (!mounted) return;

    final nextStatus = widget.connection.status;
    final nextMessage = widget.connection.statusMessage;

    if (_status != nextStatus || _statusMessage != nextMessage) {
      setState(() {
        _status = nextStatus;
        _statusMessage = nextMessage;
      });
    }

    _completeIfConnected();
  }

  void _completeIfConnected() {
    if (!mounted || _completed || !widget.connection.isConnected) {
      return;
    }

    _completed = true;

    // Navigate after the current frame, avoiding
    // navigation while widgets are being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (!widget.connection.isConnected) {
        _completed = false;
        return;
      }

      widget.onConnected();
    });
  }

  // ==========================================
  // CONNECT ACTION
  // ==========================================

  Future<void> _connect() async {
    if (_status == TelemetryConnectionStatus.connecting) {
      return;
    }

    FocusScope.of(context).unfocus();

    await widget.connection.connect(_hostController.text.trim());
  }

  // ==========================================
  // STATUS APPEARANCE
  // ==========================================

  Color _statusColor(ColorScheme scheme) {
    return switch (_status) {
      TelemetryConnectionStatus.connected => scheme.primary,

      TelemetryConnectionStatus.waiting => scheme.primary,

      TelemetryConnectionStatus.connecting => scheme.tertiary,

      TelemetryConnectionStatus.stale => scheme.tertiary,

      TelemetryConnectionStatus.error => scheme.error,

      TelemetryConnectionStatus.disconnected => scheme.onSurfaceVariant,
    };
  }

  IconData _statusIcon() {
    return switch (_status) {
      TelemetryConnectionStatus.disconnected => Icons.wifi_off_rounded,

      TelemetryConnectionStatus.connecting => Icons.sync_rounded,

      TelemetryConnectionStatus.waiting => Icons.hourglass_top_rounded,

      TelemetryConnectionStatus.connected => Icons.check_circle_outline_rounded,

      TelemetryConnectionStatus.stale => Icons.warning_amber_rounded,

      TelemetryConnectionStatus.error => Icons.error_outline_rounded,
    };
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isConnecting = _status == TelemetryConnectionStatus.connecting;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ============================
                  // BRANDING
                  // ============================
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Icon(
                        Icons.local_shipping_rounded,
                        size: 43,
                        color: scheme.primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'TruckLink',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Подключение к компьютеру',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ============================
                  // CONNECTION FORM
                  // ============================
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.computer_rounded,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Windows Hub',
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          Text(
                            'Укажи IP-адрес компьютера, '
                            'на котором запущен TruckLink '
                            'и установлен SCS Telemetry Plugin.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),

                          const SizedBox(height: 22),

                          TextField(
                            controller: _hostController,
                            enabled: !isConnecting,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.done,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: const InputDecoration(
                              labelText: 'IP компьютера',
                              hintText: '192.168.1.20',
                              prefixIcon: Icon(Icons.lan_outlined),
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) {
                              if (!isConnecting) {
                                unawaited(_connect());
                              }
                            },
                          ),

                          const SizedBox(height: 16),

                          FilledButton.icon(
                            onPressed: isConnecting
                                ? null
                                : () {
                                    unawaited(_connect());
                                  },
                            icon: isConnecting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward_rounded),
                            label: Text(
                              isConnecting ? 'Подключение...' : 'Подключиться',
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ============================
                  // CONNECTION STATUS
                  // ============================
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(_statusIcon(), color: _statusColor(scheme)),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Состояние подключения',
                                  style: theme.textTheme.labelLarge,
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  _statusMessage,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: _statusColor(scheme),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ============================
                  // NETWORK HINT
                  // ============================
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          'Телефон и компьютер должны '
                          'находиться в одной локальной '
                          'сети. Windows Hub использует '
                          'WebSocket-порт 8787.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  Text(
                    'TruckLink • ETS2 / ATS',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // CLEANUP
  // ==========================================

  @override
  void dispose() {
    widget.connection.removeListener(_onConnectionChanged);

    _hostController.dispose();

    super.dispose();
  }
}
