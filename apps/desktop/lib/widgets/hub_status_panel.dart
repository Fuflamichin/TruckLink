import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================
// HUB DEVICE INFORMATION
// ============================================

class HubConnectedDevice {
  const HubConnectedDevice({
    required this.id,
    required this.address,
    required this.connectedAt,
    this.name,
  });

  final String id;
  final String address;
  final DateTime connectedAt;
  final String? name;

  String get displayName {
    final value = name?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
    return 'Устройство $address';
  }
}

// ============================================
// PLUGIN STATUS
// ============================================

enum HubPluginStatus { checking, installed, missing, unknown }

extension HubPluginStatusText on HubPluginStatus {
  String get title => switch (this) {
    HubPluginStatus.checking => 'Проверка...',
    HubPluginStatus.installed => 'Установлен',
    HubPluginStatus.missing => 'Не найден',
    HubPluginStatus.unknown => 'Не проверен',
  };
}

// ============================================
// GAME STATUS
// ============================================

enum HubGameStatus { waiting, active, paused }

extension HubGameStatusText on HubGameStatus {
  String get title => switch (this) {
    HubGameStatus.waiting => 'Ожидание телеметрии',
    HubGameStatus.active => 'Телеметрия поступает',
    HubGameStatus.paused => 'Телеметрия на паузе',
  };
}

// ============================================
// COMPACT HUB STATUS PANEL
// ============================================

class HubStatusPanel extends StatelessWidget {
  const HubStatusPanel({
    super.key,
    required this.serverRunning,
    required this.clients,
    required this.onStartServer,
    required this.onStopServer,
    this.gameStatus = HubGameStatus.waiting,
    this.gameName,
    this.pluginStatus = HubPluginStatus.unknown,
    this.pluginDetails,
    this.onInstallPlugin,
    this.serverAddress = 'ws://IP_ПК:8787',
    this.errorMessage,
  });

  final bool serverRunning;
  final List<HubConnectedDevice> clients;

  final VoidCallback? onStartServer;
  final VoidCallback? onStopServer;
  final VoidCallback? onInstallPlugin;

  final HubGameStatus gameStatus;
  final String? gameName;

  final HubPluginStatus pluginStatus;
  final String? pluginDetails;

  final String serverAddress;
  final String? errorMessage;

  static const Color _background = Color(0xFF091018);

  static const Color _surface = Color(0xFF172530);

  static const Color _accent = Color(0xFF10EF78);

  static const Color _muted = Color(0xFFA7B6C4);

  // ==========================================
  // STATUS COLOR
  // ==========================================

  Color _statusColor(bool enabled) {
    return enabled ? _accent : const Color(0xFFFFB547);
  }

  // ==========================================
  // STATUS ROW
  // ==========================================

  Widget _statusRow({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? detail,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 37,
            height: 37,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (detail != null && detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CARD
  // ==========================================

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2D404B), width: 1),
      ),
      child: child,
    );
  }

  // ==========================================
  // GAME NAME
  // ==========================================

  String get _gameLabel {
    final name = gameName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    return gameStatus.title;
  }

  // ==========================================
  // CONNECTED DEVICE
  // ==========================================

  Widget _deviceRow(HubConnectedDevice device) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          const Icon(Icons.smartphone_rounded, size: 22, color: _accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (device.name != null)
                  Text(
                    device.address,
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
              ],
            ),
          ),
          const Icon(Icons.circle, size: 9, color: _accent),
        ],
      ),
    );
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================
                // HEADER
                // ==========================
                const Row(
                  children: [
                    Icon(
                      Icons.local_shipping_rounded,
                      color: _accent,
                      size: 26,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'TruckLink Hub',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 23,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                const Text(
                  'Соединение компьютера и телефона',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),

                const SizedBox(height: 17),

                // ==========================
                // GAME / PLUGIN
                // ==========================
                _card(
                  child: Column(
                    children: [
                      _statusRow(
                        icon: Icons.sports_esports_outlined,
                        title: 'Игра',
                        value: _gameLabel,
                        color: _statusColor(gameStatus == HubGameStatus.active),
                      ),

                      const Divider(height: 15),

                      _statusRow(
                        icon: Icons.extension_outlined,
                        title: 'Плагин телеметрии',
                        value: pluginStatus.title,
                        color: _statusColor(
                          pluginStatus == HubPluginStatus.installed,
                        ),
                        detail: pluginDetails,
                      ),

                      if (pluginStatus == HubPluginStatus.missing &&
                          onInstallPlugin != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: onInstallPlugin,
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Установить плагин'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ==========================
                // SERVER
                // ==========================
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statusRow(
                        icon: Icons.wifi_tethering,
                        title: 'Сервер',
                        value: serverRunning
                            ? 'Запущен · порт 8787'
                            : 'Остановлен',
                        color: _statusColor(serverRunning),
                      ),

                      const SizedBox(height: 7),

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              serverAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Копировать адрес',
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: serverAddress),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: serverRunning
                              ? onStopServer
                              : onStartServer,
                          icon: Icon(
                            serverRunning
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          label: Text(
                            serverRunning
                                ? 'Остановить сервер'
                                : 'Запустить сервер',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ==========================
                // CONNECTED DEVICES
                // ==========================
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.devices_rounded,
                            size: 20,
                            color: _accent,
                          ),
                          const SizedBox(width: 9),
                          const Expanded(
                            child: Text(
                              'Устройства',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Text(
                            '${clients.length}',
                            style: const TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),

                      if (clients.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Нет подключённых устройств',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        )
                      else
                        ...clients.map(_deviceRow),
                    ],
                  ),
                ),

                if (errorMessage != null && errorMessage!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
