import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier;
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
import 'navigation/navigation_layout_storage.dart';

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

  final NavigationLayoutStorage _navigationStorage = NavigationLayoutStorage();

  final Set<String> _visitedPages = {};

  final ValueNotifier<bool> _homeEditMode = ValueNotifier<bool>(false);

  late _ResolvedNavigation _navigation;
  late String _selectedId;

  String? _lastMoreSelection;

  int _navigationLoadGeneration = 0;

  // ==========================================
  // INITIALIZATION
  // ==========================================

  @override
  void initState() {
    super.initState();

    // Start with the default navigation.
    // Saved preferences are loaded asynchronously.
    _navigation = _ResolvedNavigation.resolve(widget.layout, null);

    _selectedId = _navigation.bottomItems.isNotEmpty
        ? _navigation.bottomItems.first.id
        : _morePageId;

    _visitedPages.add(_selectedId);

    unawaited(_reloadNavigation());
  }

  // ==========================================
  // LOAD SAVED NAVIGATION
  // ==========================================

  Future<void> _reloadNavigation() async {
    final generation = ++_navigationLoadGeneration;

    SavedNavigationLayout? saved;

    try {
      saved = await _navigationStorage.load();
    } catch (error) {
      debugPrint('TruckLink: failed to load navigation: $error');
    }

    if (!mounted || generation != _navigationLoadGeneration) {
      return;
    }

    final resolved = _ResolvedNavigation.resolve(widget.layout, saved);

    setState(() {
      _navigation = resolved;
      _validateCurrentSelection();
    });
  }

  // ==========================================
  // KEEP CURRENT PAGE VALID
  // ==========================================

  void _validateCurrentSelection() {
    if (_lastMoreSelection != null &&
        !_navigation.moreItems.any((item) => item.id == _lastMoreSelection)) {
      _lastMoreSelection = null;
    }

    // The "Ещё" page is always accessible.
    if (_selectedId == _morePageId) {
      return;
    }

    final stillVisible = _navigation.visibleItems.any(
      (item) => item.id == _selectedId,
    );

    if (stillVisible) {
      return;
    }

    // The selected page was hidden or removed.
    // Switch to the first pinned tab.
    _homeEditMode.value = false;

    _selectedId = _navigation.bottomItems.isNotEmpty
        ? _navigation.bottomItems.first.id
        : _morePageId;

    _visitedPages.add(_selectedId);
  }

  // ==========================================
  // UPDATED WIDGET CONFIGURATION
  // ==========================================

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.layout != widget.layout) {
      _navigation = _ResolvedNavigation.resolve(widget.layout, null);

      _validateCurrentSelection();

      unawaited(_reloadNavigation());
    }
  }

  // ==========================================
  // SELECT A PAGE
  // ==========================================

  void _selectPage(String id) {
    if (id == _selectedId) {
      return;
    }

    final isMorePage = id == _morePageId;

    final item = _navigation.findById(id);

    if (!isMorePage && item == null) {
      return;
    }

    final belongsToMore = _navigation.moreItems.any(
      (candidate) => candidate.id == id,
    );

    _homeEditMode.value = false;

    setState(() {
      _selectedId = id;
      _visitedPages.add(id);

      if (belongsToMore) {
        _lastMoreSelection = id;
      }
    });
  }

  // ==========================================
  // SETTINGS
  // ==========================================

  Future<void> _openSettings() async {
    _homeEditMode.value = false;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          connection: widget.connection,

          // Apply changes immediately after
          // the navigation editor saves them.
          onNavigationChanged: () {
            unawaited(_reloadNavigation());
          },
        ),
      ),
    );

    if (!mounted) return;

    // Also reload after the Settings route closes.
    // This catches Reset and other storage changes,
    // even when the navigation editor was closed
    // using the Android Back button.
    await _reloadNavigation();
  }

  // ==========================================
  // BUILD CONTENT FOR A SECTION
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

      TruckLinkSection.job => JobScreen(connection: widget.connection),

      TruckLinkSection.finances => const EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Финансы',
        message:
            'Баланс, доходы и расходы появятся '
            'после подключения финансовых данных ETS2.',
      ),

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

  // ==========================================
  // BUILD CONTENT FOR A NAVIGATION ITEM
  // ==========================================

  Widget _buildNavigationItem(NavigationItemConfig item) {
    if (item.sections.length == 1) {
      return _buildSection(item.sections.first);
    }

    return _CombinedSectionsPage(item: item, pageBuilder: _buildSection);
  }

  // ==========================================
  // NAVIGATION ICONS
  // ==========================================

  IconData _iconFor(NavigationItemConfig item) {
    if (item.sections.length != 1) {
      return Icons.layers_outlined;
    }

    return switch (item.sections.first) {
      TruckLinkSection.home => Icons.home_outlined,

      TruckLinkSection.instruments => Icons.speed,

      TruckLinkSection.truck => Icons.local_shipping_outlined,

      TruckLinkSection.job => Icons.inventory_2_outlined,

      TruckLinkSection.finances => Icons.account_balance_wallet_outlined,

      TruckLinkSection.map => Icons.map_outlined,

      TruckLinkSection.statistics => Icons.bar_chart_outlined,
    };
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
        // Home editing remains available even
        // if Home was moved to the "Ещё" menu.
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

        // Always accessible: even if all the
        // optional sections are hidden.
        IconButton(
          tooltip: 'Настройки TruckLink',
          onPressed: () {
            unawaited(_openSettings());
          },
          icon: const Icon(Icons.settings_outlined),
        ),

        const SizedBox(width: 8),
      ],
    );
  }

  // ==========================================
  // BOTTOM NAVIGATION
  // ==========================================

  Widget _buildBottomNavigation() {
    final bottomItems = _navigation.bottomItems;

    final moreSelected =
        _selectedId == _morePageId ||
        _navigation.moreItems.any((item) => item.id == _selectedId);

    final selectedBottomIndex = bottomItems.indexWhere(
      (item) => item.id == _selectedId,
    );

    final selectedIndex = moreSelected
        ? bottomItems.length
        : selectedBottomIndex < 0
        ? 0
        : selectedBottomIndex;

    return NavigationBar(
      selectedIndex: selectedIndex,

      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,

      // Brand colors come from TruckLinkTheme.dark.
      // No hardcoded colors are needed here.
      destinations: [
        for (final item in bottomItems)
          NavigationDestination(icon: Icon(_iconFor(item)), label: item.title),

        const NavigationDestination(
          icon: Icon(Icons.more_horiz_rounded),
          selectedIcon: Icon(Icons.more_rounded),
          label: 'Ещё',
        ),
      ],

      onDestinationSelected: (index) {
        if (index == bottomItems.length) {
          _selectPage(_morePageId);
          return;
        }

        if (index >= 0 && index < bottomItems.length) {
          _selectPage(bottomItems[index].id);
        }
      },
    );
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final bottomItems = _navigation.bottomItems;
    final moreItems = _navigation.moreItems;
    final items = _navigation.visibleItems;

    if (bottomItems.isEmpty) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.warning_amber_rounded,
          title: 'Нет разделов',
          message:
              'В конфигурации навигации '
              'отсутствуют доступные разделы.',
        ),
      );
    }

    final isMorePage = _selectedId == _morePageId;

    final selectedItem = _navigation.findById(_selectedId);

    final pageIndex = isMorePage
        ? items.length
        : items.indexWhere((item) => item.id == _selectedId);

    return Scaffold(
      appBar: _buildAppBar(selectedItem, isMorePage),

      // Keep visited pages mounted.
      //
      // Their keys are based on stable IDs,
      // not their position in the tab bar.
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

          KeyedSubtree(
            key: const ValueKey(_morePageId),
            child: _visitedPages.contains(_morePageId)
                ? moreItems.isEmpty
                      ? const EmptyState(
                          icon: Icons.widgets_outlined,
                          title: 'Нет дополнительных разделов',
                          message:
                              'Все доступные разделы '
                              'закреплены или скрыты. '
                              'Изменить это можно '
                              'в настройках навигации.',
                        )
                      : MoreScreen(
                          items: moreItems,
                          selectedId: _lastMoreSelection,
                          onSelect: _selectPage,
                        )
                : const SizedBox.shrink(),
          ),
        ],
      ),

      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // ==========================================
  // DISPOSE
  // ==========================================

  @override
  void dispose() {
    ++_navigationLoadGeneration;

    _homeEditMode.dispose();

    super.dispose();
  }
}

// ============================================
// RESOLVED NAVIGATION
// ============================================

/// Converts a saved list of navigation IDs into
/// real NavigationItemConfig objects.
///
/// This adapter leaves navigation_config.dart
/// and its existing public API unchanged.
class _ResolvedNavigation {
  const _ResolvedNavigation({
    required this.bottomItems,
    required this.moreItems,
  });

  final List<NavigationItemConfig> bottomItems;
  final List<NavigationItemConfig> moreItems;

  List<NavigationItemConfig> get visibleItems => [...bottomItems, ...moreItems];

  NavigationItemConfig? findById(String id) {
    for (final item in visibleItems) {
      if (item.id == id) {
        return item;
      }
    }

    return null;
  }

  // ==========================================
  // RESOLVE DEFAULT OR SAVED CONFIGURATION
  // ==========================================

  factory _ResolvedNavigation.resolve(
    NavigationLayout layout,
    SavedNavigationLayout? saved,
  ) {
    const maxBottomItems = 4;

    // Existing NavigationLayout is the catalog.
    // Saving a layout never creates new sections.
    final catalog = <String, NavigationItemConfig>{
      for (final item in [
        ...layout.visibleItems,
        ...layout.bottomItems,
        ...layout.moreItems,
      ])
        item.id: item,
    };

    final bottom = <NavigationItemConfig>[];
    final more = <NavigationItemConfig>[];
    final used = <String>{};

    void addItem(String id, List<NavigationItemConfig> target) {
      final item = catalog[id];

      if (item == null || !used.add(id)) {
        return;
      }

      target.add(item);
    }

    // ========================================
    // BOTTOM ITEMS
    // ========================================

    final requestedBottom =
        saved?.bottomIds ?? layout.bottomItems.map((item) => item.id);

    for (final id in requestedBottom) {
      if (bottom.length < maxBottomItems) {
        addItem(id, bottom);
      } else {
        // Move overflow to "Ещё".
        addItem(id, more);
      }
    }

    // ========================================
    // MORE ITEMS
    // ========================================

    final requestedMore =
        saved?.moreIds ?? layout.moreItems.map((item) => item.id);

    for (final id in requestedMore) {
      addItem(id, more);
    }

    // ========================================
    // HIDDEN ITEMS
    // ========================================

    // Hidden sections are marked as handled,
    // but are not included in either visible list.
    for (final id in saved?.hiddenIds ?? const <String>[]) {
      if (catalog.containsKey(id)) {
        used.add(id);
      }
    }

    // ========================================
    // NEW SECTIONS
    // ========================================

    // Newly added sections that are absent from
    // old saved preferences appear in "Ещё".
    for (final id in catalog.keys) {
      if (!used.contains(id)) {
        addItem(id, more);
      }
    }

    // ========================================
    // SAFE FALLBACK
    // ========================================

    // At least one regular bottom tab must exist.
    // This also protects against damaged settings.
    if (bottom.isEmpty) {
      if (more.isNotEmpty) {
        bottom.add(more.removeAt(0));
      } else if (catalog.isNotEmpty) {
        bottom.add(catalog.values.first);
      }
    }

    return _ResolvedNavigation(
      bottomItems: List.unmodifiable(bottom),
      moreItems: List.unmodifiable(more),
    );
  }
}

// ============================================
// COMBINED NAVIGATION SECTIONS
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
