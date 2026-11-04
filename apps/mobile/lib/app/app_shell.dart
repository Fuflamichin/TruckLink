import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:telemetry_core/telemetry_core.dart';

import '../core/network/telemetry_connection.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/more/more_screen.dart';
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
  static const String _morePageId = '__more__';

  late String _selectedId;

  String? _lastMoreSelection;

  @override
  void initState() {
    super.initState();

    _selectedId = widget.layout.bottomItems.isNotEmpty
        ? widget.layout.bottomItems.first.id
        : widget.layout.visibleItems.first.id;
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    final isMoreAvailable = widget.layout.moreItems.isNotEmpty;

    final isSelectedVisible = widget.layout.visibleItems.any(
      (item) => item.id == _selectedId,
    );

    if ((_selectedId == _morePageId && !isMoreAvailable) ||
        (_selectedId != _morePageId && !isSelectedVisible)) {
      _selectedId = widget.layout.bottomItems.isNotEmpty
          ? widget.layout.bottomItems.first.id
          : widget.layout.visibleItems.first.id;
    }
  }

  // ==========================================
  // NAVIGATION
  // ==========================================

  void _selectItem(String id) {
    if (_selectedId == id) return;

    final moreItem = widget.layout.moreItems.any((item) => item.id == id);

    if (moreItem) {
      _lastMoreSelection = id;
    }

    setState(() {
      _selectedId = id;
    });
  }

  void _openMore() {
    _selectItem(_morePageId);
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

  bool _isInstrumentsPage(NavigationItemConfig? item) {
    if (item == null) return false;

    return item.sections.length == 1 &&
        item.sections.first == TruckLinkSection.instruments;
  }

  // ==========================================
  // BOTTOM NAVIGATION
  // ==========================================

  Widget _buildBottomNavigation() {
    final scheme = Theme.of(context).colorScheme;

    final pinnedItems = widget.layout.bottomItems;
    final moreItems = widget.layout.moreItems;

    final moreSelected =
        _selectedId == _morePageId ||
        moreItems.any((item) => item.id == _selectedId);

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
    final moreItems = widget.layout.moreItems;

    final isMorePage = _selectedId == _morePageId;

    final selectedItem = widget.layout.findById(_selectedId);

    final isInstruments = _isInstrumentsPage(selectedItem);

    final pageIndex = isMorePage
        ? items.length
        : items.indexWhere((item) => item.id == _selectedId);

    final pageTitle = isMorePage ? 'Ещё' : selectedItem?.title ?? 'TruckLink';

    return Scaffold(
      // Shared header for most screens.
      //
      // The existing DashboardScreen still has
      // its own AppBar. We will remove that in
      // the next refactoring step.
      appBar: isInstruments
          ? null
          : AppBar(
              title: Text(pageTitle),
              actions: [
                IconButton(
                  tooltip: 'Настройки',
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
                const SizedBox(width: 8),
              ],
            ),

      body: Stack(
        children: [
          // All pages preserve their state.
          IndexedStack(
            index: pageIndex < 0 ? 0 : pageIndex,
            children: [
              for (final item in items)
                KeyedSubtree(key: ValueKey(item.id), child: _buildPage(item)),

              // Full-screen More page.
              if (moreItems.isNotEmpty)
                MoreScreen(
                  key: const ValueKey(_morePageId),
                  items: moreItems,
                  selectedId: _lastMoreSelection,
                  onSelect: _selectItem,
                ),
            ],
          ),

          // Temporary settings button for the
          // DashboardScreen's existing AppBar.
          if (isInstruments)
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
// BOTTOM NAVIGATION BUTTON
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
      icon: Icons.account_balance_wallet_outlined,
      message:
          'Баланс, доходы и расходы появятся '
          'после подключения финансовых данных ETS2.',
    ),

    TruckLinkSection.job => _JobScreen(connection: connection),

    TruckLinkSection.map => const _UnavailableScreen(
      icon: Icons.map_outlined,
      message:
          'Игровая карта и маршруты будут '
          'реализованы в отдельном модуле.',
    ),

    TruckLinkSection.statistics => const _UnavailableScreen(
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
    return CustomScrollView(
      key: const PageStorageKey('trucklink-home'),
      physics: const ClampingScrollPhysics(),
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
              (context, index) => _HomeMetricCard(
                key: ValueKey(index),
                connection: connection,
                index: index,
              ),
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
                      'Здесь можно будет выбирать '
                      'карточки из любых разделов, '
                      'изменять их порядок и размер.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================
// HOME METRIC CARD
// ============================================

String _homeMetricValue(int index, TruckSnapshot? snapshot) {
  return switch (index) {
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
}

class _HomeMetricCard extends StatefulWidget {
  const _HomeMetricCard({
    super.key,
    required this.connection,
    required this.index,
  });

  final TelemetryConnection connection;
  final int index;

  @override
  State<_HomeMetricCard> createState() => _HomeMetricCardState();
}

class _HomeMetricCardState extends State<_HomeMetricCard> {
  late String _value;

  @override
  void initState() {
    super.initState();

    _value = _homeMetricValue(widget.index, widget.connection.snapshot);

    widget.connection.addListener(_onUpdate);
  }

  @override
  void didUpdateWidget(covariant _HomeMetricCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onUpdate);
      widget.connection.addListener(_onUpdate);
    }

    _value = _homeMetricValue(widget.index, widget.connection.snapshot);
  }

  void _onUpdate() {
    final nextValue = _homeMetricValue(
      widget.index,
      widget.connection.snapshot,
    );

    if (!mounted || nextValue == _value) return;

    setState(() {
      _value = nextValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Скорость', 'Ограничение', 'Текущий заказ', 'Баланс'];

    const icons = [
      Icons.speed,
      Icons.signpost_outlined,
      Icons.inventory_2_outlined,
      Icons.account_balance_wallet_outlined,
    ];

    return RepaintBoundary(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icons[widget.index],
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                titles[widget.index],
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const Spacer(),
              Text(
                _value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.connection.removeListener(_onUpdate);
    super.dispose();
  }
}

// ============================================
// TRUCK SCREEN
// ============================================

class _TruckScreen extends StatefulWidget {
  const _TruckScreen({required this.connection});

  final TelemetryConnection connection;

  @override
  State<_TruckScreen> createState() => _TruckScreenState();
}

class _TruckScreenState extends State<_TruckScreen> {
  late List<String> _values;

  @override
  void initState() {
    super.initState();

    _values = _buildValues(widget.connection.snapshot);
    widget.connection.addListener(_onUpdate);
  }

  @override
  void didUpdateWidget(covariant _TruckScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onUpdate);
      widget.connection.addListener(_onUpdate);
    }

    _values = _buildValues(widget.connection.snapshot);
  }

  List<String> _buildValues(TruckSnapshot? snapshot) {
    if (snapshot == null) {
      return List<String>.filled(6, '—');
    }

    return [
      snapshot.engineOn ? 'Включён' : 'Выключен',

      snapshot.odometerKm == null
          ? '—'
          : '${snapshot.odometerKm!.toStringAsFixed(1)} км',

      snapshot.waterTemperatureC == null
          ? '—'
          : '${snapshot.waterTemperatureC!.toStringAsFixed(1)} °C',

      snapshot.engineWearPercent == null
          ? '—'
          : '${snapshot.engineWearPercent!.toStringAsFixed(1)}%',

      '${snapshot.fuelLiters.toStringAsFixed(1)} / '
          '${snapshot.fuelCapacityLiters.toStringAsFixed(0)} л',

      snapshot.parkBrake == null
          ? '—'
          : snapshot.parkBrake!
          ? 'Активен'
          : 'Выключен',
    ];
  }

  void _onUpdate() {
    final nextValues = _buildValues(widget.connection.snapshot);

    if (!mounted || listEquals(_values, nextValues)) {
      return;
    }

    setState(() {
      _values = nextValues;
    });
  }

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Двигатель',
      'Пробег',
      'Температура',
      'Износ двигателя',
      'Топливо',
      'Стояночный тормоз',
    ];

    return ListView(
      key: const PageStorageKey('truck-screen'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Техническое состояние',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        RepaintBoundary(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (var index = 0; index < labels.length; index++) ...[
                    if (index != 0) const Divider(),
                    _DetailRow(label: labels[index], value: _values[index]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    widget.connection.removeListener(_onUpdate);
    super.dispose();
  }
}

// ============================================
// JOB SCREEN
// ============================================

class _JobScreen extends StatefulWidget {
  const _JobScreen({required this.connection});

  final TelemetryConnection connection;

  @override
  State<_JobScreen> createState() => _JobScreenState();
}

class _JobScreenState extends State<_JobScreen> {
  TruckJob? _job;
  Map<String, Object?>? _jobData;

  @override
  void initState() {
    super.initState();

    _readJob();
    widget.connection.addListener(_onUpdate);
  }

  void _readJob() {
    _job = widget.connection.snapshot?.job;
    _jobData = _job?.toJson();
  }

  @override
  void didUpdateWidget(covariant _JobScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onUpdate);
      widget.connection.addListener(_onUpdate);
    }

    _readJob();
  }

  void _onUpdate() {
    final nextJob = widget.connection.snapshot?.job;
    final nextData = nextJob?.toJson();

    if (!mounted || mapEquals(_jobData, nextData)) {
      return;
    }

    setState(() {
      _job = nextJob;
      _jobData = nextData;
    });
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;

    if (job == null) {
      return const _EmptyContent(
        icon: Icons.inventory_2_outlined,
        title: 'Нет данных о заказе',
        message:
            'Информацию о заказах подключим '
            'при расширении SDK-адаптера.',
      );
    }

    return ListView(
      key: const PageStorageKey('job-screen'),
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
                _DetailRow(label: 'Куда', value: job.destinationCity ?? '—'),
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
  }

  @override
  void dispose() {
    widget.connection.removeListener(_onUpdate);
    super.dispose();
  }
}

// ============================================
// UNAVAILABLE SECTION
// ============================================

class _UnavailableScreen extends StatelessWidget {
  const _UnavailableScreen({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _EmptyContent(
      icon: icon,
      title: 'Раздел в разработке',
      message: message,
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
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabs: [
                for (final section in item.sections) Tab(text: section.title),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final section in item.sections)
                  _pageForSection(section, connection),
              ],
            ),
          ),
        ],
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
                'Выбор, порядок и размеры '
                'карточек телеметрии.',
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
          Card(
            child: ListTile(
              leading: Icon(Icons.wifi_outlined),
              title: Text('Подключение'),
              subtitle: Text(
                'Отдельный стартовый экран '
                'подключения будет добавлен позже.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
