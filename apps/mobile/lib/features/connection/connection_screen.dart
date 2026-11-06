import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/telemetry_connection.dart';
import 'data/hub_address_storage.dart';

// ============================================
// TRUCKLINK CONNECTION SCREEN
// ============================================

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key, required this.connection});

  final TelemetryConnection connection;

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final TextEditingController _ipController = TextEditingController();

  final HubAddressStorage _addressStorage = HubAddressStorage();

  bool _loadingSavedIp = true;
  bool _userEditedAddress = false;
  bool _submitting = false;

  String? _lastSuccessfulIp;
  String? _unexpectedError;

  // ==========================================
  // INITIALIZATION
  // ==========================================

  @override
  void initState() {
    super.initState();

    unawaited(_restoreSavedIp());
  }

  // ==========================================
  // RESTORE LAST SUCCESSFUL IP
  // ==========================================

  Future<void> _restoreSavedIp() async {
    String? savedIp;

    try {
      savedIp = await _addressStorage.loadLastSuccessfulIp();
    } catch (error) {
      debugPrint('TruckLink: failed to load saved IP: $error');
    }

    if (!mounted) return;

    setState(() {
      _lastSuccessfulIp = savedIp;
      _loadingSavedIp = false;

      // Do not overwrite an address that the user
      // has already started typing.
      if (!_userEditedAddress &&
          _ipController.text.trim().isEmpty &&
          savedIp != null) {
        _ipController.text = savedIp;
      }
    });
  }

  // ==========================================
  // CONNECT TO WINDOWS HUB
  // ==========================================

  Future<void> _connect() async {
    if (_submitting) return;

    final connection = widget.connection;

    if (connection.status == TelemetryConnectionStatus.connecting) {
      return;
    }

    final host = _ipController.text.trim();

    FocusScope.of(context).unfocus();

    setState(() {
      _submitting = true;
      _userEditedAddress = true;
      _unexpectedError = null;
    });

    try {
      // Connection errors and timeouts are handled
      // by the shared TelemetryConnection controller.
      await connection.connect(host);

      // IMPORTANT:
      //
      // Save ONLY after a real WebSocket connection
      // has been established.
      //
      // TelemetryConnection.isConnected is true
      // for waiting, connected and stale states.
      //
      // The game itself does not have to be running.
      if (connection.isConnected && connection.connectedHost == host) {
        try {
          await _addressStorage.saveLastSuccessfulIp(host);

          debugPrint('TruckLink: saved successful Hub IP');

          // The connection gate may already have
          // switched to AppShell at this point.
          // Therefore no BuildContext is required.
          if (mounted) {
            setState(() {
              _lastSuccessfulIp = host;
            });
          }
        } catch (error) {
          // A storage failure must not disconnect
          // an otherwise healthy WebSocket.
          debugPrint('TruckLink: failed to save Hub IP: $error');
        }
      }
    } catch (error) {
      // The network controller normally reports
      // errors through its status/statusMessage.
      // This handles unexpected exceptions.
      debugPrint(
        'TruckLink: unexpected connection error: '
        '$error',
      );

      if (mounted) {
        setState(() {
          _unexpectedError =
              'Не удалось выполнить подключение: '
              '$error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  // ==========================================
  // INPUT EVENTS
  // ==========================================

  void _onAddressChanged(String value) {
    setState(() {
      _userEditedAddress = true;
      _unexpectedError = null;
    });
  }

  void _clearAddress() {
    _ipController.clear();

    setState(() {
      _userEditedAddress = true;
      _unexpectedError = null;
    });
  }

  // ==========================================
  // STATUS COLORS
  // ==========================================

  Color _statusColor(TelemetryConnectionStatus status, ColorScheme scheme) {
    return switch (status) {
      TelemetryConnectionStatus.connected => scheme.primary,

      TelemetryConnectionStatus.waiting => scheme.primary,

      TelemetryConnectionStatus.connecting => scheme.tertiary,

      TelemetryConnectionStatus.stale => scheme.tertiary,

      TelemetryConnectionStatus.error => scheme.error,

      TelemetryConnectionStatus.disconnected => scheme.onSurfaceVariant,
    };
  }

  IconData _statusIcon(TelemetryConnectionStatus status) {
    return switch (status) {
      TelemetryConnectionStatus.connected => Icons.check_circle_outline,

      TelemetryConnectionStatus.waiting => Icons.hourglass_empty_rounded,

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

    return AnimatedBuilder(
      animation: widget.connection,
      builder: (context, child) {
        final status = widget.connection.status;

        final busy =
            _submitting || status == TelemetryConnectionStatus.connecting;

        final color = _statusColor(status, scheme);

        final statusMessage =
            _unexpectedError ?? widget.connection.statusMessage;

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ======================
                      // BRAND HEADER
                      // ======================
                      Center(
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.local_shipping_outlined,
                            size: 42,
                            color: scheme.primary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      Text(
                        'TruckLink',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Подключение к Windows Hub',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ======================
                      // CONNECTION CARD
                      // ======================
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'IP-адрес компьютера',
                                style: theme.textTheme.titleMedium,
                              ),

                              const SizedBox(height: 8),

                              Text(
                                'Укажи локальный IPv4-адрес '
                                'компьютера, на котором '
                                'запущен Windows Hub.',
                                style: theme.textTheme.bodySmall,
                              ),

                              const SizedBox(height: 18),

                              TextField(
                                controller: _ipController,

                                enabled: !busy,

                                keyboardType: TextInputType.url,

                                textInputAction: TextInputAction.done,

                                autocorrect: false,
                                enableSuggestions: false,

                                onChanged: _onAddressChanged,

                                onSubmitted: (_) {
                                  if (!busy) {
                                    unawaited(_connect());
                                  }
                                },

                                decoration: InputDecoration(
                                  hintText: '192.168.1.100',
                                  labelText: 'IPv4-адрес',
                                  prefixIcon: const Icon(
                                    Icons.computer_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: 'Очистить IP',
                                    onPressed: busy ? null : _clearAddress,
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              if (_loadingSavedIp)
                                Text(
                                  'Проверяем сохранённый адрес...',
                                  style: theme.textTheme.bodySmall,
                                )
                              else if (_lastSuccessfulIp != null)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.history_rounded,
                                      size: 16,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        'Последний успешный IP: '
                                        '$_lastSuccessfulIp',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  'Адрес будет сохранён '
                                  'после успешного подключения.',
                                  style: theme.textTheme.bodySmall,
                                ),

                              const SizedBox(height: 22),

                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () {
                                          unawaited(_connect());
                                        },
                                  icon: busy
                                      ? const SizedBox(
                                          width: 19,
                                          height: 19,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.link_rounded),
                                  label: Text(
                                    busy ? 'Подключение...' : 'Подключиться',
                                  ),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ======================
                      // CONNECTION STATUS
                      // ======================
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _unexpectedError != null
                                    ? Icons.error_outline_rounded
                                    : _statusIcon(status),
                                color: _unexpectedError != null
                                    ? scheme.error
                                    : color,
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Text(
                                  statusMessage,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: _unexpectedError != null
                                        ? scheme.error
                                        : color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ======================
                      // HELP
                      // ======================
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: scheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Телефон и ПК должны быть '
                              'в одной локальной сети. '
                              'Windows Hub использует '
                              'порт 8787. Саму игру '
                              'можно запустить после '
                              'подключения.',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // CLEANUP
  // ==========================================

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }
}
