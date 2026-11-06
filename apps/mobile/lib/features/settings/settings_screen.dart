import 'package:flutter/material.dart';

import '../../core/network/telemetry_connection.dart';
import 'connection_settings_screen.dart';
import 'navigation_settings_screen.dart';

// ============================================
// TRUCKLINK SETTINGS SCREEN
// ============================================

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.connection,
    this.onNavigationChanged,
  });

  final TelemetryConnection connection;

  /// Called when the navigation editor saves.
  ///
  /// AppShell uses this to reload navigation
  /// without recreating TelemetryConnection.
  final VoidCallback? onNavigationChanged;

  // ==========================================
  // CONNECTION SETTINGS
  // ==========================================

  void _openConnectionSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConnectionSettingsScreen(connection: connection),
      ),
    );
  }

  // ==========================================
  // NAVIGATION SETTINGS
  // ==========================================

  Future<void> _openNavigationSettings(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const NavigationSettingsScreen()),
    );

    if (!context.mounted) {
      return;
    }

    if (saved == true) {
      // Tell AppShell to reload the saved layout.
      onNavigationChanged?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Настройки навигации сохранены '
            'и применены.',
          ),
        ),
      );
    }
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),

      body: ListView(
        key: const PageStorageKey<String>('trucklink-settings'),
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ==================================
          // CONNECTION
          // ==================================
          _SettingsSection(
            icon: Icons.wifi_outlined,
            title: 'Подключение',
            description:
                'Состояние Windows Hub, IP компьютера, '
                'отключение, смена ПК '
                'и переподключение.',
            active: true,
            onTap: () {
              _openConnectionSettings(context);
            },
          ),

          // ==================================
          // APPEARANCE
          // ==================================
          const _SettingsSection(
            icon: Icons.palette_outlined,
            title: 'Оформление',
            description:
                'Темы, акцентные цвета, градиенты '
                'и внешний вид карточек.',
          ),

          // ==================================
          // HOME
          // ==================================
          const _SettingsSection(
            icon: Icons.dashboard_customize_outlined,
            title: 'Главная панель',
            description:
                'Управление персональной панелью '
                'телеметрии.',
          ),

          // ==================================
          // NAVIGATION
          // ==================================
          _SettingsSection(
            icon: Icons.tab_outlined,
            title: 'Навигация',
            description:
                'Перестановка вкладок, закрепление, '
                'скрытие и настройка меню «Ещё».',
            active: true,
            onTap: () {
              _openNavigationSettings(context);
            },
          ),

          // ==================================
          // TELEMETRY
          // ==================================
          const _SettingsSection(
            icon: Icons.tune_outlined,
            title: 'Телеметрия',
            description:
                'Настройки отображения показателей '
                'и единиц измерения.',
          ),
        ],
      ),
    );
  }
}

// ============================================
// SETTINGS SECTION CARD
// ============================================

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.description,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: scheme.primary),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),

                      const SizedBox(height: 6),

                      Text(description, style: theme.textTheme.bodySmall),

                      const SizedBox(height: 8),

                      Text(
                        active ? 'Открыть настройки' : 'В разработке',
                        style: TextStyle(
                          color: active
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),

                if (active) ...[
                  const SizedBox(width: 8),

                  Icon(Icons.chevron_right_rounded, color: scheme.primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
