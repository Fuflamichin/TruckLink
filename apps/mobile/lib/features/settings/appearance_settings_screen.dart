import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation/trucklink_pill_navigation.dart';
import '../../core/appearance/appearance_controller.dart';
import '../../core/appearance/appearance_provider.dart';
import '../../core/appearance/appearance_settings.dart';

// ============================================
// APPEARANCE SETTINGS SCREEN
// ============================================

class AppearanceSettingsScreen extends ConsumerStatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  ConsumerState<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

// ============================================
// APPEARANCE SETTINGS STATE
// ============================================

class _AppearanceSettingsScreenState
    extends ConsumerState<AppearanceSettingsScreen> {
  int _previewBottomIndex = 2;
  int _previewGroupIndex = 0;

  // ==========================================
  // SHARED CONTROLLER
  // ==========================================

  TruckLinkAppearanceController get _controller =>
      ref.read(appearanceControllerProvider);

  // ==========================================
  // APPLY CHANGE
  // ==========================================

  Future<void> _apply(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('TruckLink: appearance update failed: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить оформление.')),
      );
    }
  }

  // ==========================================
  // RESET CONFIRMATION
  // ==========================================

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Сбросить оформление?'),
          content: const Text(
            'Вернутся стандартный зелёный цвет, '
            'обычная навигация и классические '
            'карточки TruckLink.',
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
              child: const Text('Сбросить'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    await _apply(() => _controller.restoreDefaults());
  }

  // ==========================================
  // LIVE PREVIEW
  // ==========================================

  Widget _buildPreview(TruckLinkAppearanceSettings settings) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF091018),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF293541)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, color: accent, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Предпросмотр',
                style: TextStyle(
                  color: Color(0xFFF0F3F8),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ==================================
          // ACTUAL CARD THEME PREVIEW
          // ==================================
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _PreviewMetric(
                      label: 'Скорость',
                      value: '82 км/ч',
                      icon: Icons.speed_outlined,
                      accent: accent,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Container(
                    height: 42,
                    width: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _PreviewMetric(
                      label: 'Топливо',
                      value: '68%',
                      icon: Icons.local_gas_station_outlined,
                      accent: accent,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),

          const Text(
            'Нижняя панель',
            style: TextStyle(
              color: Color(0xFFADB5C6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          // Use the SAME component as AppShell.
          TruckLinkPillNavigation(
            style: TruckLinkPillStyle.bottom,
            selectedIndex: _previewBottomIndex,
            items: const [
              TruckLinkPillItem(label: 'Главная', icon: Icons.home_outlined),
              TruckLinkPillItem(
                label: 'Грузовик',
                icon: Icons.local_shipping_outlined,
              ),
              TruckLinkPillItem(label: 'Кабина', icon: Icons.layers_outlined),
              TruckLinkPillItem(label: 'Ещё', icon: Icons.more_horiz_rounded),
            ],
            onSelected: (index) {
              setState(() {
                _previewBottomIndex = index;
              });
            },
          ),

          const SizedBox(height: 22),

          const Text(
            'Вкладки объединённой группы',
            style: TextStyle(
              color: Color(0xFFADB5C6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          TruckLinkPillNavigation(
            style: TruckLinkPillStyle.group,
            selectedIndex: _previewGroupIndex,
            items: const [
              TruckLinkPillItem(label: 'Приборы', icon: Icons.speed_outlined),
              TruckLinkPillItem(
                label: 'Грузовик',
                icon: Icons.local_shipping_outlined,
              ),
            ],
            onSelected: (index) {
              setState(() {
                _previewGroupIndex = index;
              });
            },
          ),

          const SizedBox(height: 12),

          const Text(
            'Изменения сразу применяются '
            'ко всему приложению.',
            style: TextStyle(color: Color(0xFF8492A2), fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // COLOR SELECTOR
  // ==========================================

  Widget _buildColors(TruckLinkAppearanceSettings settings) {
    return Wrap(
      spacing: 10,
      runSpacing: 12,
      children: [
        for (final accent in TruckLinkAccent.values)
          _AccentColorButton(
            accent: accent,
            selected: settings.accent == accent,
            onTap: () {
              unawaited(_apply(() => _controller.setAccent(accent)));
            },
          ),
      ],
    );
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appearanceControllerProvider);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        if (!controller.isReady) {
          return Scaffold(
            appBar: AppBar(title: const Text('Оформление')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final settings = controller.settings;
        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Оформление'),
            actions: [
              IconButton(
                tooltip: 'Сбросить оформление',
                onPressed: () {
                  unawaited(_confirmReset());
                },
                icon: const Icon(Icons.restart_alt_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: ListView(
              key: const PageStorageKey<String>(
                'trucklink-appearance-settings',
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text('Персонализация', style: theme.textTheme.headlineMedium),

                const SizedBox(height: 8),

                Text(
                  'Настрой оформление TruckLink '
                  'под свой стиль.',
                  style: theme.textTheme.bodyMedium,
                ),

                if (controller.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(controller.errorMessage!)),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ==========================
                // PREVIEW
                // ==========================
                _buildPreview(settings),

                const SizedBox(height: 24),

                // ==========================
                // ACCENT
                // ==========================
                _AppearanceSection(
                  icon: Icons.palette_outlined,
                  title: 'Акцентный цвет',
                  description:
                      'Цвет подсветки, кнопок '
                      'и элементов интерфейса.',
                  child: _buildColors(settings),
                ),

                const SizedBox(height: 16),

                // ==========================
                // NAVIGATION SIZE
                // ==========================
                _AppearanceSection(
                  icon: Icons.space_dashboard_outlined,
                  title: 'Размер навигации',
                  description:
                      'Высота нижней панели '
                      'и вкладок внутри групп.',
                  child: _AppearanceChoiceList<TruckLinkNavigationSize>(
                    values: TruckLinkNavigationSize.values,
                    selected: settings.navigationSize,
                    labelOf: (value) => value.title,
                    onSelected: (value) {
                      unawaited(
                        _apply(() => _controller.setNavigationSize(value)),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // ==========================
                // HIGHLIGHT
                // ==========================
                _AppearanceSection(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Подсветка',
                  description:
                      'Яркость активной капсулы '
                      'в панелях навигации.',
                  child: _AppearanceChoiceList<TruckLinkHighlightIntensity>(
                    values: TruckLinkHighlightIntensity.values,
                    selected: settings.highlightIntensity,
                    labelOf: (value) => value.title,
                    onSelected: (value) {
                      unawaited(
                        _apply(() => _controller.setHighlightIntensity(value)),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // ==========================
                // CARD STYLE
                // ==========================
                _AppearanceSection(
                  icon: Icons.widgets_outlined,
                  title: 'Стиль карточек',
                  description:
                      'Выбери фон и обводку '
                      'карточек телеметрии.',
                  child: _AppearanceChoiceList<TruckLinkCardStyle>(
                    values: TruckLinkCardStyle.values,
                    selected: settings.cardStyle,
                    labelOf: (value) => value.title,
                    onSelected: (value) {
                      unawaited(_apply(() => _controller.setCardStyle(value)));
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // ==========================
                // ROUNDING
                // ==========================
                _AppearanceSection(
                  icon: Icons.rounded_corner,
                  title: 'Скругление',
                  description:
                      'Форма карточек '
                      'и навигационных панелей.',
                  child: _AppearanceChoiceList<TruckLinkCornerStyle>(
                    values: TruckLinkCornerStyle.values,
                    selected: settings.cornerStyle,
                    labelOf: (value) => value.title,
                    onSelected: (value) {
                      unawaited(
                        _apply(() => _controller.setCornerStyle(value)),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                OutlinedButton.icon(
                  onPressed: () {
                    unawaited(_confirmReset());
                  },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Восстановить стандартный стиль'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Настройки сохраняются автоматически.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================
// SETTINGS SECTION
// ============================================

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(description, style: theme.textTheme.bodySmall),

            const SizedBox(height: 18),

            child,
          ],
        ),
      ),
    );
  }
}

// ============================================
// ACCENT COLOR BUTTON
// ============================================

class _AccentColorButton extends StatelessWidget {
  const _AccentColorButton({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final TruckLinkAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = accent.color;

    return SizedBox(
      width: 90,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    color: selected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    if (selected)
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        color: color.computeLuminance() > 0.55
                            ? Colors.black
                            : Colors.white,
                      )
                    : null,
              ),

              const SizedBox(height: 8),

              Text(
                accent.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// CHOICE CHIPS
// ============================================

class _AppearanceChoiceList<T extends Object> extends StatelessWidget {
  const _AppearanceChoiceList({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    final outline = Theme.of(context).colorScheme.outlineVariant;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(labelOf(value)),
            selected: value == selected,
            showCheckmark: true,
            checkmarkColor: accent,
            selectedColor: accent.withValues(alpha: 0.16),
            side: BorderSide(
              color: value == selected
                  ? accent.withValues(alpha: 0.75)
                  : outline,
            ),
            onSelected: (_) {
              onSelected(value);
            },
          ),
      ],
    );
  }
}

// ============================================
// TELEMETRY PREVIEW METRIC
// ============================================

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: accent, size: 18),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
