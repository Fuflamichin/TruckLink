import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/appearance/appearance_controller.dart';
import '../../core/appearance/appearance_settings.dart';

// ============================================
// APPEARANCE SETTINGS SCREEN
// ============================================

class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  State<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  late final TruckLinkAppearanceController _controller;

  int _previewBottomIndex = 2;
  int _previewGroupIndex = 0;

  // ==========================================
  // INITIALIZATION
  // ==========================================

  @override
  void initState() {
    super.initState();

    _controller = TruckLinkAppearanceController();

    unawaited(_controller.initialize());
  }

  // ==========================================
  // APPLY APPEARANCE CHANGE
  // ==========================================

  Future<void> _apply(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      debugPrint('TruckLink: appearance change failed: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить оформление.')),
      );
    }
  }

  // ==========================================
  // RESTORE DEFAULTS
  // ==========================================

  Future<void> _restoreDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Сбросить оформление?'),
          content: const Text(
            'Вернутся стандартные настройки TruckLink: '
            'зелёный цвет, обычный размер навигации '
            'и классические карточки.',
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

    if (!mounted || confirmed != true) return;

    await _apply(() => _controller.restoreDefaults());
  }

  // ==========================================
  // COLOR SELECTOR
  // ==========================================

  Widget _buildAccentSelector(TruckLinkAppearanceSettings settings) {
    return Wrap(
      spacing: 12,
      runSpacing: 14,
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
  // PREVIEW
  // ==========================================

  Widget _buildPreview(TruckLinkAppearanceSettings settings) {
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
              Icon(
                Icons.visibility_outlined,
                size: 18,
                color: settings.accentColor,
              ),
              const SizedBox(width: 8),
              const Text(
                'Предпросмотр',
                style: TextStyle(
                  color: Color(0xFFF0F3F8),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ==================================
          // TELEMETRY CARD EXAMPLE
          // ==================================
          _AppearanceCardPreview(settings: settings),

          const SizedBox(height: 20),

          const Text(
            'Нижняя навигация',
            style: TextStyle(
              color: Color(0xFFAFB9C6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          _AppearancePillPreview(
            settings: settings,
            selectedIndex: _previewBottomIndex,
            isBottom: true,
            items: const [
              _PreviewItem(label: 'Главная', icon: Icons.home_outlined),
              _PreviewItem(
                label: 'Грузовик',
                icon: Icons.local_shipping_outlined,
              ),
              _PreviewItem(label: 'Кабина', icon: Icons.layers_outlined),
              _PreviewItem(label: 'Ещё', icon: Icons.more_horiz_rounded),
            ],
            onSelected: (index) {
              setState(() {
                _previewBottomIndex = index;
              });
            },
          ),

          const SizedBox(height: 20),

          const Text(
            'Вкладки объединённой группы',
            style: TextStyle(
              color: Color(0xFFAFB9C6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          _AppearancePillPreview(
            settings: settings,
            selectedIndex: _previewGroupIndex,
            isBottom: false,
            items: const [
              _PreviewItem(label: 'Приборы', icon: Icons.speed_outlined),
              _PreviewItem(
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
            'Нажми на иконки и вкладки, '
            'чтобы проверить подсветку.',
            style: TextStyle(color: Color(0xFF8593A3), fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        if (!_controller.isReady) {
          return const Scaffold(
            appBar: _AppearanceAppBar(),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final settings = _controller.settings;
        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Оформление'),
            actions: [
              IconButton(
                tooltip: 'Сбросить оформление',
                onPressed: () {
                  unawaited(_restoreDefaults());
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
                // ==============================
                // TITLE
                // ==============================
                Text('Персонализация', style: theme.textTheme.headlineMedium),

                const SizedBox(height: 8),

                Text(
                  'Настрой внешний вид TruckLink '
                  'под свой стиль.',
                  style: theme.textTheme.bodyMedium,
                ),

                if (_controller.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_controller.errorMessage!)),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ==============================
                // LIVE PREVIEW
                // ==============================
                _buildPreview(settings),

                const SizedBox(height: 24),

                // ==============================
                // ACCENT COLOR
                // ==============================
                _AppearanceSection(
                  icon: Icons.palette_outlined,
                  title: 'Акцентный цвет',
                  description:
                      'Цвет кнопок, выделения вкладок '
                      'и элементов интерфейса.',
                  child: _buildAccentSelector(settings),
                ),

                const SizedBox(height: 16),

                // ==============================
                // NAVIGATION SIZE
                // ==============================
                _AppearanceSection(
                  icon: Icons.space_dashboard_outlined,
                  title: 'Размер навигации',
                  description:
                      'Высота нижней панели '
                      'и переключателей внутри групп.',
                  child: _AppearanceChoiceList<TruckLinkNavigationSize>(
                    values: TruckLinkNavigationSize.values,
                    selected: settings.navigationSize,
                    accent: settings.accentColor,
                    labelOf: (value) => value.title,
                    onSelected: (value) {
                      unawaited(
                        _apply(() => _controller.setNavigationSize(value)),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // ==============================
                // HIGHLIGHT INTENSITY
                // ==============================
                _AppearanceSection(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Подсветка',
                  description:
                      'Интенсивность цветной капсулы '
                      'выбранной вкладки.',
                  child: _AppearanceChoiceList<TruckLinkHighlightIntensity>(
                    values: TruckLinkHighlightIntensity.values,
                    selected: settings.highlightIntensity,
                    accent: settings.accentColor,
                    labelOf: (value) => value.title,
                    onSelected: (value) {
                      unawaited(
                        _apply(() => _controller.setHighlightIntensity(value)),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // ==============================
                // CARD STYLE
                // ==============================
                _AppearanceSection(
                  icon: Icons.widgets_outlined,
                  title: 'Стиль карточек',
                  description:
                      'Фон и оформление карточек '
                      'с показателями телеметрии.',
                  child: _AppearanceChoiceList<TruckLinkCardStyle>(
                    values: TruckLinkCardStyle.values,
                    selected: settings.cardStyle,
                    accent: settings.accentColor,
                    labelOf: (value) => value.title,
                    onSelected: (value) {
                      unawaited(_apply(() => _controller.setCardStyle(value)));
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // ==============================
                // CORNER ROUNDING
                // ==============================
                _AppearanceSection(
                  icon: Icons.rounded_corner,
                  title: 'Скругление',
                  description:
                      'Форма углов карточек '
                      'и навигационных панелей.',
                  child: _AppearanceChoiceList<TruckLinkCornerStyle>(
                    values: TruckLinkCornerStyle.values,
                    selected: settings.cornerStyle,
                    accent: settings.accentColor,
                    labelOf: (value) => value.title,
                    onSelected: (value) {
                      unawaited(
                        _apply(() => _controller.setCornerStyle(value)),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // ==============================
                // RESTORE DEFAULT BUTTON
                // ==============================
                OutlinedButton.icon(
                  onPressed: () {
                    unawaited(_restoreDefaults());
                  },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Восстановить стандартный стиль'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Настройки сохраняются автоматически. '
                  'На следующем этапе подключим их '
                  'к общей теме приложения.',
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

  // ==========================================
  // CLEANUP
  // ==========================================

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ============================================
// LOADING APP BAR
// ============================================

class _AppearanceAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppearanceAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('Оформление'));
  }
}

// ============================================
// APPEARANCE SETTINGS SECTION
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
      width: 88,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
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

              const SizedBox(height: 9),

              Text(
                accent.title,
                maxLines: 2,
                textAlign: TextAlign.center,
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
// GENERIC OPTION CHIPS
// ============================================

class _AppearanceChoiceList<T extends Object> extends StatelessWidget {
  const _AppearanceChoiceList({
    required this.values,
    required this.selected,
    required this.accent,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final Color accent;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
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
                  : Theme.of(context).colorScheme.outlineVariant,
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
// SAMPLE TELEMETRY CARD
// ============================================

class _AppearanceCardPreview extends StatelessWidget {
  const _AppearanceCardPreview({required this.settings});

  final TruckLinkAppearanceSettings settings;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color borderColor;

    switch (settings.cardStyle) {
      case TruckLinkCardStyle.filled:
        background = const Color(0xFF182632);
        borderColor = const Color(0xFF2F414E);

      case TruckLinkCardStyle.outlined:
        background = const Color(0xFF0D1822);
        borderColor = settings.accentColor.withValues(alpha: 0.55);

      case TruckLinkCardStyle.minimal:
        background = const Color(0xFF091018);
        borderColor = Colors.transparent;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(settings.cardRadius),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PreviewMetric(
              icon: Icons.speed_outlined,
              title: 'Скорость',
              value: '82 км/ч',
              accent: settings.accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 45, color: const Color(0xFF32414C)),
          const SizedBox(width: 12),
          Expanded(
            child: _PreviewMetric(
              icon: Icons.local_gas_station_outlined,
              title: 'Топливо',
              value: '68%',
              accent: settings.accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// SAMPLE METRIC
// ============================================

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: accent, size: 19),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(color: Color(0xFFACB8C5), fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFF0F4F8),
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ============================================
// PILL PREVIEW ITEM
// ============================================

class _PreviewItem {
  const _PreviewItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

// ============================================
// LIVE PILL NAVIGATION PREVIEW
// ============================================

class _AppearancePillPreview extends StatelessWidget {
  const _AppearancePillPreview({
    required this.settings,
    required this.items,
    required this.selectedIndex,
    required this.isBottom,
    required this.onSelected,
  });

  final TruckLinkAppearanceSettings settings;
  final List<_PreviewItem> items;
  final int selectedIndex;
  final bool isBottom;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final height = isBottom
        ? settings.bottomNavigationHeight
        : settings.groupNavigationHeight;

    final indicatorHeight = isBottom ? height - 28 : height - 12;

    final accent = settings.accentColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalPadding = 8.0;

        final contentWidth = math.max(
          0.0,
          constraints.maxWidth - horizontalPadding * 2,
        );

        final itemWidth = contentWidth / items.length;

        final double indicatorWidth = isBottom
            ? math.max(0.0, math.min(68.0, itemWidth - 10.0))
            : math.max(0.0, itemWidth - 8.0);

        final left =
            horizontalPadding +
            itemWidth * selectedIndex +
            (itemWidth - indicatorWidth) / 2;

        return Container(
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(settings.navigationRadius),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1D2030), Color(0xFF151A26)],
            ),
            border: Border.all(color: const Color(0xFF4B5063), width: 1.15),
          ),
          child: Stack(
            children: [
              // ==============================
              // MOVING ACTIVE CAPSULE
              // ==============================
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                left: left,
                top: (height - indicatorHeight) / 2,
                width: indicatorWidth,
                height: indicatorHeight,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent.withValues(
                        alpha: settings.highlightOpacity,
                      ),
                      borderRadius: BorderRadius.circular(
                        settings.navigationRadius,
                      ),
                      border: Border.all(color: accent.withValues(alpha: 0.16)),
                    ),
                  ),
                ),
              ),

              // ==============================
              // TAPPABLE ITEMS
              // ==============================
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                ),
                child: Row(
                  children: [
                    for (var index = 0; index < items.length; index++)
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              onSelected(index);
                            },
                            borderRadius: BorderRadius.circular(40),
                            child: SizedBox(
                              height: height,
                              child: Center(
                                child: isBottom
                                    ? Icon(
                                        items[index].icon,
                                        size: 25,
                                        color: index == selectedIndex
                                            ? accent
                                            : const Color(0xFFAFB8C8),
                                      )
                                    : _PreviewGroupLabel(
                                        item: items[index],
                                        selected: index == selectedIndex,
                                        accent: accent,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================
// PREVIEW INNER GROUP ITEM
// ============================================

class _PreviewGroupLabel extends StatelessWidget {
  const _PreviewGroupLabel({
    required this.item,
    required this.selected,
    required this.accent,
  });

  final _PreviewItem item;
  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = selected ? accent : const Color(0xFFAFB8C8);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, size: 17, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
