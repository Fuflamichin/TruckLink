import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/network/telemetry_connection.dart';
import '../features/common/empty_state.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/home/home_screen.dart';
import '../features/jobs/job_screen.dart';
import '../features/more/more_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/truck/truck_screen.dart';
import 'navigation/navigation_config.dart';
import 'widgets/bottom_navigation.dart';

// ============================================
// TRUCKLINK APPLICATION SHELL
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

  final Set<String> _visitedPages = {};

  // Only the HomeScreen listens to this notifier.
  // Toggling edit mode does not rebuild AppShell
  // or recreate the WebSocket connection.
  final ValueNotifier<bool> _homeEditMode = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();

    _selectedId = _defaultPageId();
    _visitedPages.add(_selectedId);
  }

  String _defaultPageId() {
    final pinned = widget.layout.bottomItems;

    if (pinned.isNotEmpty) {
      return pinned.first.id;
    }

    final visible = widget.layout.visibleItems;

    if (visible.isNotEmpty) {
      return visible.first.id;
    }

    return _morePageId;
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    final validSelection = _selectedId == _morePageId
        ? widget.layout.moreItems.isNotEmpty
        : widget.layout.visibleItems.any((item) => item.id == _selectedId);

    if (!validSelection) {
      _selectedId = _defaultPageId();
      _visitedPages.add(_selectedId);
    }
  }

  // ==========================================
  // NAVIGATION
  // ==========================================

  void _selectPage(String id) {
    if (_selectedId == id) return;

    final valid = id == _morePageId
        ? widget.layout.moreItems.isNotEmpty
        : widget.layout.visibleItems.any((item) => item.id == id);

    if (!valid) return;

    final isMoreItem = widget.layout.moreItems.any((item) => item.id == id);

    // Edit mode belongs to the HomeScreen.
    // Finish editing when leaving that page.
    _homeEditMode.value = false;

    setState(() {
      _selectedId = id;
      _visitedPages.add(id);

      if (isMoreItem) {
        _lastMoreSelection = id;
      }
    });
  }

  void _openMore() {
    _selectPage(_morePageId);
  }

  void _openSettings() {
    _homeEditMode.value = false;

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  // ==========================================
  // SECTION FACTORY
  // ==========================================

  Widget _buildSection(TruckLinkSection section) {
    return switch (section) {
      TruckLinkSection.home => HomeScreen(
        connection: widget.connection,
        editMode: _homeEditMode,
      ),

      TruckLinkSection.instruments => DashboardScreen(
        connection: widget.connection,
      ),

      TruckLinkSection.truck => TruckScreen(connection: widget.connection),

      TruckLinkSection.finances => const EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Финансы',
        message:
            'Баланс, доходы и расходы появятся '
            'после подключения финансовых данных ETS2.',
      ),

      TruckLinkSection.job => JobScreen(connection: widget.connection),

      TruckLinkSection.map => const EmptyState(
        icon: Icons.map_outlined,
        title: 'Карта',
        message:
            'Игровая карта, положение грузовика '
            'и маршруты будут реализованы '
            'в отдельном модуле.',
      ),

      TruckLinkSection.statistics => const EmptyState(
        icon: Icons.bar_chart_outlined,
        title: 'Статистика',
        message:
            'Здесь появятся история рейсов, '
            'пробег, доходы и статистика перевозок.',
      ),
    };
  }

  Widget _buildNavigationItem(NavigationItemConfig item) {
    if (item.sections.length == 1) {
      return _buildSection(item.sections.first);
    }

    return _CombinedSectionsPage(item: item, pageBuilder: _buildSection);
  }

  // ==========================================
  // SHARED APP BAR
  // ==========================================

  PreferredSizeWidget _buildAppBar(
    NavigationItemConfig? selectedItem,
    bool isMorePage,
  ) {
    final isInstruments =
        selectedItem != null &&
        selectedItem.sections.length == 1 &&
        selectedItem.sections.first == TruckLinkSection.instruments;

    final isHome =
        selectedItem != null &&
        selectedItem.sections.length == 1 &&
        selectedItem.sections.first == TruckLinkSection.home;

    final title = isMorePage || isInstruments
        ? 'TruckLink'
        : selectedItem?.title ?? 'TruckLink';

    return AppBar(
      title: Text(title),
      centerTitle: false,
      automaticallyImplyLeading: false,
      actions: [
        // Edit action is shown only on Home.
        if (isHome)
          ValueListenableBuilder<bool>(
            valueListenable: _homeEditMode,
            builder: (context, isEditing, child) {
              return IconButton(
                tooltip: isEditing
                    ? 'Завершить редактирование'
                    : 'Редактировать главную',
                icon: Icon(
                  isEditing ? Icons.check_rounded : Icons.edit_outlined,
                ),
                onPressed: () {
                  _homeEditMode.value = !isEditing;
                },
              );
            },
          ),

        IconButton(
          tooltip: 'Настройки TruckLink',
          onPressed: _openSettings,
          icon: const Icon(Icons.settings_outlined),
        ),

        const SizedBox(width: 8),
      ],
    );
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final items = widget.layout.visibleItems;
    final moreItems = widget.layout.moreItems;

    if (items.isEmpty) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.warning_amber_rounded,
          title: 'Нет разделов',
          message:
              'Конфигурация навигации не содержит '
              'доступных экранов.',
        ),
      );
    }

    final isMorePage = _selectedId == _morePageId;

    final selectedItem = widget.layout.findById(_selectedId);

    final pageIndex = isMorePage
        ? items.length
        : items.indexWhere((item) => item.id == _selectedId);

    final moreSelected =
        isMorePage || moreItems.any((item) => item.id == _selectedId);

    return Scaffold(
      appBar: _buildAppBar(selectedItem, isMorePage),

      // Visited pages remain mounted.
      // Scroll positions and WebSocket stay intact.
      body: IndexedStack(
        index: pageIndex < 0 ? 0 : pageIndex,
        children: [
          for (final item in items)
            KeyedSubtree(
              key: ValueKey(item.id),
              child: _visitedPages.contains(item.id)
                  ? _buildNavigationItem(item)
                  : const SizedBox.shrink(),
            ),

          if (moreItems.isNotEmpty)
            KeyedSubtree(
              key: const ValueKey(_morePageId),
              child: _visitedPages.contains(_morePageId)
                  ? MoreScreen(
                      items: moreItems,
                      selectedId: _lastMoreSelection,
                      onSelect: _selectPage,
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),

      bottomNavigationBar: TruckLinkBottomNavigation(
        layout: widget.layout,
        selectedId: _selectedId,
        moreSelected: moreSelected,
        onSelect: _selectPage,
        onMore: _openMore,
      ),
    );
  }

  @override
  void dispose() {
    _homeEditMode.dispose();
    super.dispose();
  }
}

// ============================================
// COMBINED NAVIGATION GROUP
// ============================================

class _CombinedSectionsPage extends StatelessWidget {
  const _CombinedSectionsPage({required this.item, required this.pageBuilder});

  final NavigationItemConfig item;
  final Widget Function(TruckLinkSection) pageBuilder;

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
                for (final section in item.sections) pageBuilder(section),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
