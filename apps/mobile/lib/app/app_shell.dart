import 'package:flutter/material.dart';
import 'package:telemetry_core/telemetry_core.dart';

import '../core/network/telemetry_connection.dart';
import '../features/dashboard/dashboard_screen.dart';
import 'navigation/navigation_config.dart';

// ============================================
// APPLICATION SHELL
// ============================================

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.connection,
    this.layout = NavigationLayout.defaultLayout,
  });

  final TelemetryConnection connection;
  final NavigationLayout layout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();

    _selectedId = widget.layout.bottomItems.first.id;
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    final exists = widget.layout.visibleItems.any(
      (item) => item.id == _selectedId,
    );

    if (!exists) {
      _selectedId = widget.layout.visibleItems.first.id;
    }
  }

  void _selectItem(String id) {
    if (_selectedId == id) return;

    setState(() {
      _selectedId = id;
    });
  }

  // ==========================================
  // MORE MENU
  // ==========================================

  Future<void> _openMore() async {
    final moreItems = widget.layout.moreItems;

    if (moreItems.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.65,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Все разделы',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              for (final item in moreItems)
                ListTile(
                  leading: Icon(item.icon),
                  title: Text(item.title),
                  selected: _selectedId == item.id,
                  selectedColor: Theme.of(sheetContext).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop(item.id);
                  },
                ),
            ],
          ),
        );
      },
    );

    if (!mounted || selected == null) return;

    _selectItem(selected);
  }

  // ==========================================
  // SETTINGS
  // ==========================================

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const _SettingsPreviewScreen(),
      ),
    );
  }

  // ==========================================
  // PAGE FACTORY
  // ==========================================

  Widget _buildPage(NavigationItemConfig item) {
    if (item.sections.length == 1) {
      return _pageForSection(item.sections.first, widget.connection);
    }

    return _CombinedSectionsPage(item: item, connection: widget.connection);
  }

  // ==========================================
  // BOTTOM NAVIGATION
  // ==========================================

  Widget _buildBottomNavigation() {
    final scheme = Theme.of(context).colorScheme;
    final pinnedItems = widget.layout.bottomItems;
    final moreItems = widget.layout.moreItems;

    final moreSelected = moreItems.any((item) => item.id == _selectedId);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                for (final item in pinnedItems)
                  Expanded(
                    child: _NavigationButton(
                      icon: item.icon,
                      label: item.title,
                      selected: _selectedId == item.id,
                      onTap: () => _selectItem(item.id),
                    ),
                  ),
                if (moreItems.isNotEmpty)
                  Expanded(
                    child: _NavigationButton(
                      icon: Icons.more_horiz_rounded,
                      label: 'Ещё',
                      selected: moreSelected,
                      onTap: _openMore,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final items = widget.layout.visibleItems;

    final selectedIndex = items.indexWhere((item) => item.id == _selectedId);

    return Scaffold(
      body: Stack(
        children: [
          // Keep existing tab states and scroll offsets.
          IndexedStack(
            index: selectedIndex < 0 ? 0 : selectedIndex,
            children: [
              for (final item in items)
                KeyedSubtree(key: ValueKey(item.id), child: _buildPage(item)),
            ],
          ),

          // Temporary settings action above the
          // existing screen AppBars.
          //
          // Later we will unify the headers inside
          // a shared AppScaffold.
          Positioned(
            top: 0,
            right: 8,
            child: SafeArea(
              bottom: false,
              child: IconButton(
                tooltip: 'Настройки',
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }
}

// ============================================
// NAVIGATION BUTTON
// ============================================

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 23),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
// SECTION ROUTING
// ============================================

Widget _pageForSection(
  TruckLinkSection section,
  TelemetryConnection connection,
) {
  return switch (section) {
    TruckLinkSection.home => _HomeScreen(connection: connection),
    TruckLinkSection.instruments => DashboardScreen(connection: connection),
    TruckLinkSection.truck => _TruckScreen(connection: connection),
    TruckLinkSection.finances => const _UnavailableScreen(
      title: 'Финансы',
      icon: Icons.account_balance_wallet_outlined,
      message:
          'Баланс, доходы и расходы появятся после '
          'подключения финансовых данных ETS2.',
    ),
    TruckLinkSection.job => _JobScreen(connection: connection),
    TruckLinkSection.map => const _UnavailableScreen(
      title: 'Карта',
      icon: Icons.map_outlined,
      message:
          'Игровая карта и маршруты будут '
          'реализованы в отдельном модуле.',
    ),
    TruckLinkSection.statistics => const _UnavailableScreen(
      title: 'Статистика',
      icon: Icons.bar_chart_outlined,
      message:
          'Здесь будут история рейсов, пробег, '
          'доходы и статистика перевозок.',
    ),
  };
}

// ============================================
// HOME SCREEN
// ============================================

class _HomeScreen extends StatelessWidget {
  const _HomeScreen({required this.connection});

  final TelemetryConnection connection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Главная')),
      body: CustomScrollView(
        key: const PageStorageKey('trucklink-home'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Мой TruckLink',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Основные показатели и информация '
                    'о текущей поездке',
                  ),
                ],
              ),
            ),
          ),

          // Live metrics are isolated from
          // the surrounding scroll view.
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 154,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _HomeMetricCard(connection: connection, index: index),
                childCount: 4,
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            sliver: SliverToBoxAdapter(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Персональная панель',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Позже здесь можно будет добавлять '
                        'и убирать карточки, менять их '
                        'размеры и порядок отображения.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// HOME METRIC CARD
// ============================================

class _HomeMetricCard extends StatelessWidget {
  const _HomeMetricCard({required this.connection, required this.index});

  final TelemetryConnection connection;
  final int index;

  @override
  Widget build(BuildContext context) {
    const titles = ['Скорость', 'Ограничение', 'Текущий заказ', 'Баланс'];

    const icons = [
      Icons.speed,
      Icons.signpost_outlined,
      Icons.inventory_2_outlined,
      Icons.account_balance_wallet_outlined,
    ];

    return ListenableBuilder(
      listenable: connection,
      builder: (context, child) {
        final snapshot = connection.snapshot;

        final value = switch (index) {
          0 =>
            snapshot == null
                ? '—'
                : '${snapshot.speedKmh.abs().toStringAsFixed(1)} км/ч',
          1 =>
            snapshot?.speedLimitKmh == null
                ? '—'
                : '${snapshot!.speedLimitKmh!.toStringAsFixed(0)} км/ч',
          2 => snapshot?.job?.cargoName ?? 'Нет данных',
          3 => 'Нет данных',
          _ => '—',
        };

        return RepaintBoundary(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icons[index],
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    titles[index],
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Spacer(),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================
// TRUCK SCREEN
// ============================================

class _TruckScreen extends StatelessWidget {
  const _TruckScreen({required this.connection});

  final TelemetryConnection connection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Грузовик')),
      body: ListenableBuilder(
        listenable: connection,
        builder: (context, child) {
          final snapshot = connection.snapshot;

          return ListView(
            key: const PageStorageKey('truck-screen'),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Техническое состояние',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'Двигатель',
                        value: snapshot == null
                            ? '—'
                            : snapshot.engineOn
                            ? 'Включён'
                            : 'Выключен',
                      ),
                      const Divider(),
                      _DetailRow(
                        label: 'Пробег',
                        value: snapshot?.odometerKm == null
                            ? '—'
                            : '${snapshot!.odometerKm!.toStringAsFixed(1)} км',
                      ),
                      const Divider(),
                      _DetailRow(
                        label: 'Температура',
                        value: snapshot?.waterTemperatureC == null
                            ? '—'
                            : '${snapshot!.waterTemperatureC!.toStringAsFixed(1)} °C',
                      ),
                      const Divider(),
                      _DetailRow(
                        label: 'Износ двигателя',
                        value: snapshot?.engineWearPercent == null
                            ? '—'
                            : '${snapshot!.engineWearPercent!.toStringAsFixed(1)}%',
                      ),
                      const Divider(),
                      _DetailRow(
                        label: 'Топливо',
                        value: snapshot == null
                            ? '—'
                            : '${snapshot.fuelLiters.toStringAsFixed(1)} / '
                                  '${snapshot.fuelCapacityLiters.toStringAsFixed(0)} л',
                      ),
                      const Divider(),
                      _DetailRow(
                        label: 'Стояночный тормоз',
                        value: snapshot?.parkBrake == null
                            ? '—'
                            : snapshot!.parkBrake!
                            ? 'Активен'
                            : 'Выключен',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================
// JOB SCREEN
// ============================================

class _JobScreen extends StatelessWidget {
  const _JobScreen({required this.connection});

  final TelemetryConnection connection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Текущий заказ')),
      body: ListenableBuilder(
        listenable: connection,
        builder: (context, child) {
          final job = connection.snapshot?.job;

          if (job == null) {
            return const _EmptyContent(
              icon: Icons.inventory_2_outlined,
              title: 'Нет данных о заказе',
              message:
                  'Поддержку информации о заказах '
                  'добавим при расширении SDK-адаптера.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _DetailRow(label: 'Груз', value: job.cargoName ?? '—'),
                      const Divider(),
                      _DetailRow(label: 'Откуда', value: job.sourceCity ?? '—'),
                      const Divider(),
                      _DetailRow(
                        label: 'Куда',
                        value: job.destinationCity ?? '—',
                      ),
                      const Divider(),
                      _DetailRow(
                        label: 'Вознаграждение',
                        value: job.reward?.toString() ?? '—',
                      ),
                      const Divider(),
                      _DetailRow(
                        label: 'Осталось',
                        value: job.remainingDistanceKm == null
                            ? '—'
                            : '${job.remainingDistanceKm!.toStringAsFixed(1)} км',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================
// PLACEHOLDER SCREEN
// ============================================

class _UnavailableScreen extends StatelessWidget {
  const _UnavailableScreen({
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _EmptyContent(
        icon: icon,
        title: 'Раздел в разработке',
        message: message,
      ),
    );
  }
}

class _EmptyContent extends StatelessWidget {
  const _EmptyContent({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ============================================
// COMBINED NAVIGATION GROUP
// ============================================

class _CombinedSectionsPage extends StatelessWidget {
  const _CombinedSectionsPage({required this.item, required this.connection});

  final NavigationItemConfig item;
  final TelemetryConnection connection;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: item.sections.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(item.title),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final section in item.sections) Tab(text: section.title),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final section in item.sections)
              _pageForSection(section, connection),
          ],
        ),
      ),
    );
  }
}

// ============================================
// DETAIL ROW
// ============================================

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.right)),
      ],
    );
  }
}

// ============================================
// TEMPORARY SETTINGS SCREEN
// ============================================

class _SettingsPreviewScreen extends StatelessWidget {
  const _SettingsPreviewScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: ListTile(
              leading: Icon(Icons.palette_outlined),
              title: Text('Оформление'),
              subtitle: Text(
                'Темы, акценты, градиенты '
                'и параметры интерфейса — скоро.',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.dashboard_customize),
              title: Text('Главная панель'),
              subtitle: Text(
                'Выбор и порядок карточек телеметрии '
                'добавим в следующих этапах.',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.tab_outlined),
              title: Text('Навигация'),
              subtitle: Text(
                'Закрепление, скрытие и объединение '
                'разделов — в разработке.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
