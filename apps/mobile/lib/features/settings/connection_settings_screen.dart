import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/telemetry_connection.dart';

// ============================================
// CONNECTION SETTINGS SCREEN
// ============================================

class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({super.key, required this.connection});

  final TelemetryConnection connection;

  @override
  State<ConnectionSettingsScreen> createState() =>
      _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  late TelemetryConnectionStatus _status;
  late String _statusMessage;
  String? _host;

  bool _wasConnected = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();

    _readConnectionState();

    widget.connection.addListener(_onConnectionChanged);
  }

  void _readConnectionState() {
    _status = widget.connection.status;
    _statusMessage = widget.connection.statusMessage;
    _host = widget.connection.connectedHost;
    _wasConnected = widget.connection.isConnected;
  }

  @override
  void didUpdateWidget(covariant ConnectionSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onConnectionChanged);

      widget.connection.addListener(_onConnectionChanged);

      _readConnectionState();
    }
  }

  // ==========================================
  // CONNECTION LISTENER
  // ==========================================

  void _onConnectionChanged() {
    if (!mounted || _leaving) return;

    final connected = widget.connection.isConnected;

    // If the Hub disconnects while settings are
    // open, close the settings routes so that
    // the application's connection gate is visible.
    if (_wasConnected && !connected) {
      _leaving = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        Navigator.of(context).popUntil((route) => route.isFirst);
      });

      return;
    }

    final nextStatus = widget.connection.status;
    final nextMessage = widget.connection.statusMessage;
    final nextHost = widget.connection.connectedHost;

    _wasConnected = connected;

    if (_status == nextStatus &&
        _statusMessage == nextMessage &&
        _host == nextHost) {
      return;
    }

    setState(() {
      _status = nextStatus;
      _statusMessage = nextMessage;
      _host = nextHost;
    });
  }

  // ==========================================
  // NAVIGATION HELPERS
  // ==========================================

  void _returnToAppRoot() {
    if (_leaving) return;

    _leaving = true;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ==========================================
  // RECONNECT TO SAME COMPUTER
  // ==========================================

  void _reconnect() {
    final host = _host;

    if (host == null || host.isEmpty || _leaving) {
      return;
    }

    _returnToAppRoot();

    // The connection gate will temporarily show
    // ConnectionScreen during reconnection.
    unawaited(widget.connection.connect(host));
  }

  // ==========================================
  // CHANGE COMPUTER
  // ==========================================

  void _changeComputer() {
    if (_leaving) return;

    _returnToAppRoot();

    // Disconnecting returns the application
    // to its dedicated ConnectionScreen.
    unawaited(widget.connection.disconnect());
  }

  // ==========================================
  // DISCONNECT
  // ==========================================

  Future<void> _confirmDisconnect() async {
    if (_leaving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Отключиться от компьютера?'),
          content: const Text(
            'Соединение с Windows Hub будет '
            'закрыто. Ты вернёшься на экран '
            'подключения TruckLink.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Отключиться'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    _changeComputer();
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

  IconData get _statusIcon {
    return switch (_status) {
      TelemetryConnectionStatus.connected => Icons.check_circle_rounded,

      TelemetryConnectionStatus.waiting => Icons.hourglass_top_rounded,

      TelemetryConnectionStatus.connecting => Icons.sync_rounded,

      TelemetryConnectionStatus.stale => Icons.warning_amber_rounded,

      TelemetryConnectionStatus.error => Icons.error_outline_rounded,

      TelemetryConnectionStatus.disconnected => Icons.wifi_off_rounded,
    };
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final connected = widget.connection.isConnected;
    final host = _host;

    return Scaffold(
      appBar: AppBar(title: const Text('Подключение')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ==================================
          // STATUS CARD
          // ==================================
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _statusColor(scheme).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _statusIcon,
                          color: _statusColor(scheme),
                          size: 28,
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Windows Hub',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              connected
                                  ? 'Соединение установлено'
                                  : 'Нет подключения',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _statusColor(scheme),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Text(_statusMessage, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ==================================
          // CONNECTION DETAILS
          // ==================================
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _ConnectionDetailRow(
                    label: 'IP компьютера',
                    value: host ?? 'Не указан',
                  ),

                  const Divider(),

                  const _ConnectionDetailRow(label: 'Порт', value: '8787'),

                  const Divider(),

                  const _ConnectionDetailRow(
                    label: 'Протокол',
                    value: 'WebSocket',
                  ),

                  const Divider(),

                  _ConnectionDetailRow(
                    label: 'Телеметрия',
                    value: _status == TelemetryConnectionStatus.connected
                        ? 'Активна'
                        : _status == TelemetryConnectionStatus.stale
                        ? 'Нет новых данных'
                        : 'Ожидание',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ==================================
          // CONNECTION ACTIONS
          // ==================================
          Text('Управление подключением', style: theme.textTheme.titleLarge),

          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: connected && host != null && !_leaving
                ? _reconnect
                : null,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Переподключиться'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),

          const SizedBox(height: 10),

          OutlinedButton.icon(
            onPressed: connected && !_leaving ? _changeComputer : null,
            icon: const Icon(Icons.computer_rounded),
            label: const Text('Сменить компьютер'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),

          const SizedBox(height: 10),

          TextButton.icon(
            onPressed: connected && !_leaving ? _confirmDisconnect : null,
            icon: Icon(Icons.link_off_rounded, color: scheme.error),
            label: Text(
              'Отключиться от Windows Hub',
              style: TextStyle(color: scheme.error),
            ),
          ),

          const SizedBox(height: 20),

          // ==================================
          // HELP
          // ==================================
          Card(
            color: scheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: scheme.primary),

                  const SizedBox(width: 12),

                  const Expanded(
                    child: Text(
                      'Подключение к Windows Hub '
                      'не требует запущенной ETS2/ATS. '
                      'Если игра закрыта, TruckLink '
                      'просто ожидает телеметрию.\n\n'
                      'При смене компьютера приложение '
                      'вернётся на стартовый экран, '
                      'где можно ввести другой IP.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

// ============================================
// REUSABLE CONNECTION DETAIL ROW
// ============================================

class _ConnectionDetailRow extends StatelessWidget {
  const _ConnectionDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),

        const SizedBox(width: 12),

        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
