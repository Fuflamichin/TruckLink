import 'package:flutter/material.dart';

// ============================================
// TRUCKLINK SETTINGS SCREEN
// ============================================

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        key: const PageStorageKey<String>('trucklink-settings'),
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: const [
          _SettingsSection(
            icon: Icons.palette_outlined,
            title: 'Оформление',
            description:
                'Тёмная, светлая и системная темы, '
                'акцентные цвета, градиенты '
                'и внешний вид карточек.',
          ),

          _SettingsSection(
            icon: Icons.dashboard_customize_outlined,
            title: 'Главная панель',
            description:
                'Выбор показателей из разных разделов, '
                'порядок карточек, размеры '
                'и видимость элементов.',
          ),

          _SettingsSection(
            icon: Icons.tab_outlined,
            title: 'Навигация',
            description:
                'Закрепление, скрытие и перестановка '
                'разделов. Объединение нескольких '
                'экранов в одну группу.',
          ),

          _SettingsSection(
            icon: Icons.tune_outlined,
            title: 'Телеметрия',
            description:
                'Включение и отключение отдельных '
                'показателей, частота обновления '
                'и отображение значений.',
          ),

          _SettingsSection(
            icon: Icons.wifi_outlined,
            title: 'Подключение',
            description:
                'Состояние Windows Hub, IP компьютера, '
                'отключение и переподключение.',
          ),
        ],
      ),
    );
  }
}

// ============================================
// SETTINGS SECTION
// ============================================

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
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
                    Text(title, style: Theme.of(context).textTheme.titleMedium),

                    const SizedBox(height: 6),

                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'В разработке',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
