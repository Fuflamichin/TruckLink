import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/material.dart';

import '../core/network/telemetry_connection.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/home/home_screen.dart';
import '../features/jobs/job_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/truck/truck_screen.dart';

import 'navigation/navigation_config.dart';
import 'navigation/navigation_layout_storage.dart';
import 'navigation/trucklink_pill_navigation.dart';

// ============================================
// COMMON SECTION ICONS
// ============================================

IconData _sectionIcon(TruckLinkSection section) {
  return switch (section) {
    TruckLinkSection.home => Icons.home_outlined,

    TruckLinkSection.instruments => Icons.speed_outlined,

    TruckLinkSection.truck => Icons.local_shipping_outlined,

    TruckLinkSection.job => Icons.inventory_2_outlined,

    TruckLinkSection.finances => Icons.account_balance_wallet_outlined,

    TruckLinkSection.map => Icons.map_outlined,

    TruckLinkSection.statistics => Icons.bar_chart_outlined,
  };
}

// ============================================
// APP SHELL
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

// ============================================
// APP SHELL STATE
// ============================================

class _AppShellState extends State<AppShell> {
  static const String _morePageId = '__more__';

  // ==========================================
  // STORAGE AND STATE
  // ==========================================

  final NavigationLayoutStorage _storage = NavigationLayoutStorage();

  final ValueNotifier<bool> _homeEditMode = ValueNotifier<bool>(false);

  final Set<String> _visited = {};

  late _ResolvedNavigation _navigation;
  late String _selectedId;

  String? _lastMoreSelection;

  int _loadGeneration = 0;

  // ==========================================
  // INITIALIZATION
  // ==========================================

  @override
  void initState() {
    super.initState();

    _navigation = _ResolvedNavigation.resolve(widget.layout, null);

    _selectedId = _navigation.bottomItems.isEmpty
        ? _morePageId
        : _navigation.bottomItems.first.id;

    _visited.add(_selectedId);

    unawaited(_reloadNavigation());
  }

  // ==========================================
  // RELOAD SAVED NAVIGATION
  // ==========================================

  Future<void> _reloadNavigation() async {
    final generation = ++_loadGeneration;

    SavedNavigationLayout? saved;

    try {
      saved = await _storage.load();
    } catch (error) {
      debugPrint('TruckLink: cannot load navigation: $error');
    }

    if (!mounted || generation != _loadGeneration) {
      return;
    }

    final next = _ResolvedNavigation.resolve(widget.layout, saved);

    setState(() {
      _navigation = next;
      _validateSelection();
    });
  }

  // ==========================================
  // VALIDATE SELECTED PAGE
  // ==========================================

  void _validateSelection() {
    if (_lastMoreSelection != null &&
        !_navigation.moreItems.any((item) => item.id == _lastMoreSelection)) {
      _lastMoreSelection = null;
    }

    if (_selectedId == _morePageId ||
        _navigation.visibleItems.any((item) => item.id == _selectedId)) {
      return;
    }

    // Current page is hidden or removed.
    _homeEditMode.value = false;

    _selectedId = _navigation.bottomItems.isEmpty
        ? _morePageId
        : _navigation.bottomItems.first.id;

    _visited.add(_selectedId);
  }

  // ==========================================
  // UPDATE APP SHELL
  // ==========================================

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.layout != widget.layout) {
      _navigation = _ResolvedNavigation.resolve(widget.layout, null);

      _validateSelection();

      unawaited(_reloadNavigation());
    }
  }

  // ==========================================
  // SELECT NAVIGATION PAGE
  // ==========================================

  void _selectPage(String id) {
    if (_selectedId == id) {
      return;
    }

    final isMore = id == _morePageId;

    if (!isMore && _navigation.findById(id) == null) {
      return;
    }

    _homeEditMode.value = false;

    setState(() {
      _selectedId = id;
      _visited.add(id);

      if (_navigation.moreItems.any((item) => item.id == id)) {
        _lastMoreSelection = id;
      }
    });
  }

  // ==========================================
  // OPEN SETTINGS
  // ==========================================

  Future<void> _openSettings() async {
    _homeEditMode.value = false;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          connection: widget.connection,

          onNavigationChanged: () {
            unawaited(_reloadNavigation());
          },
        ),
      ),
    );

    if (mounted) {
      await _reloadNavigation();
    }
  }

  // ==========================================
  // CREATE SECTION PAGE
  // ==========================================

  Widget _sectionPage(TruckLinkSection section) {
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

      TruckLinkSection.finances => const _ComingSoonPage(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Финансы',
        description:
            'История заработка, баланс '
            'и расходы появятся позже.',
      ),

      TruckLinkSection.map => const _ComingSoonPage(
        icon: Icons.map_outlined,
        title: 'Карта',
        description:
            'Игровая карта и маршрут '
            'появятся позже.',
      ),

      TruckLinkSection.statistics => const _ComingSoonPage(
        icon: Icons.bar_chart_outlined,
        title: 'Статистика',
        description:
            'Статистика рейсов и история '
            'появятся позже.',
      ),
    };
  }

  // ==========================================
  // CREATE NAVIGATION ITEM PAGE
  // ==========================================

  Widget _itemPage(_ShellNavigationItem item) {
    if (item.sections.length == 1) {
      return _sectionPage(item.sections.first);
    }

    return _CombinedSectionsPage(item: item, pageBuilder: _sectionPage);
  }

  // ==========================================
  // NAVIGATION ITEM ICON
  // ==========================================

  IconData _icon(_ShellNavigationItem item) {
    if (item.sections.length != 1) {
      return Icons.layers_outlined;
    }

    return _sectionIcon(item.sections.first);
  }

  // ==========================================
  // NAVIGATION ITEM ACTIVE ICON
  // ==========================================

  IconData _activeIcon(_ShellNavigationItem item) {
    if (item.sections.length != 1) {
      return Icons.layers_rounded;
    }

    return switch (item.sections.first) {
      TruckLinkSection.home => Icons.home_rounded,

      TruckLinkSection.instruments => Icons.speed,

      TruckLinkSection.truck => Icons.local_shipping_rounded,

      TruckLinkSection.job => Icons.inventory_2_rounded,

      TruckLinkSection.finances => Icons.account_balance_wallet_rounded,

      TruckLinkSection.map => Icons.map_rounded,

      TruckLinkSection.statistics => Icons.bar_chart_rounded,
    };
  }

  // ==========================================
  // APP BAR
  // ==========================================

  PreferredSizeWidget _appBar(_ShellNavigationItem? item) {
    final hasHome =
        item != null && item.sections.contains(TruckLinkSection.home);

    return AppBar(
      title: Text(item?.title ?? 'TruckLink'),

      automaticallyImplyLeading: false,

      actions: [
        // ====================================
        // HOME EDITING
        // ====================================
        if (hasHome)
          ValueListenableBuilder<bool>(
            valueListenable: _homeEditMode,
            builder: (context, editing, child) {
              return IconButton(
                tooltip: editing ? 'Готово' : 'Редактировать главную',

                icon: Icon(editing ? Icons.check_rounded : Icons.edit_outlined),

                onPressed: () {
                  _homeEditMode.value = !editing;
                },
              );
            },
          ),

        // ====================================
        // SETTINGS
        // ====================================
        IconButton(
          tooltip: 'Настройки',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            unawaited(_openSettings());
          },
        ),

        const SizedBox(width: 8),
      ],
    );
  }

  // ==========================================
  // NEW FLOATING BOTTOM NAVIGATION
  // ==========================================

  Widget _bottomBar() {
    final bottom = _navigation.bottomItems;

    final isMoreActive =
        _selectedId == _morePageId ||
        _navigation.moreItems.any((item) => item.id == _selectedId);

    final bottomIndex = bottom.indexWhere((item) => item.id == _selectedId);

    final selectedIndex = isMoreActive
        ? bottom.length
        : bottomIndex >= 0
        ? bottomIndex
        : 0;

    // The bottom bar is now an icon-only
    // floating rounded pill, as in the
    // TruckLink design reference.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
        child: TruckLinkPillNavigation(
          style: TruckLinkPillStyle.bottom,
          selectedIndex: selectedIndex,

          items: [
            for (final item in bottom)
              TruckLinkPillItem(
                label: item.title,
                icon: _icon(item),
                activeIcon: _activeIcon(item),
              ),

            const TruckLinkPillItem(
              label: 'Ещё',
              icon: Icons.more_horiz_rounded,
              activeIcon: Icons.more_rounded,
            ),
          ],

          onSelected: (index) {
            if (index == bottom.length) {
              _selectPage(_morePageId);
              return;
            }

            if (index >= 0 && index < bottom.length) {
              _selectPage(bottom[index].id);
            }
          },
        ),
      ),
    );
  }

  // ==========================================
  // BUILD APP
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final pages = _navigation.visibleItems;

    final isMorePage = _selectedId == _morePageId;

    final selectedItem = _navigation.findById(_selectedId);

    final index = isMorePage
        ? pages.length
        : pages.indexWhere((item) => item.id == _selectedId);

    return Scaffold(
      appBar: _appBar(selectedItem),

      // Keep visited pages mounted.
      body: IndexedStack(
        index: index < 0 ? 0 : index,
        children: [
          for (final item in pages)
            KeyedSubtree(
              key: ValueKey(item.id),
              child: _visited.contains(item.id)
                  ? _itemPage(item)
                  : const SizedBox.shrink(),
            ),

          KeyedSubtree(
            key: const ValueKey(_morePageId),
            child: _visited.contains(_morePageId)
                ? _MoreNavigationPage(
                    items: _navigation.moreItems,
                    selectedId: _lastMoreSelection,
                    iconFor: _icon,
                    onSelect: _selectPage,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),

      // New custom pill navigation.
      bottomNavigationBar: _bottomBar(),
    );
  }

  // ==========================================
  // CLEANUP
  // ==========================================

  @override
  void dispose() {
    ++_loadGeneration;

    _homeEditMode.dispose();

    super.dispose();
  }
}

// ============================================
// SHELL NAVIGATION ITEM
// ============================================

class _ShellNavigationItem {
  const _ShellNavigationItem({
    required this.id,
    required this.title,
    required this.sections,
  });

  final String id;
  final String title;
  final List<TruckLinkSection> sections;

  factory _ShellNavigationItem.fromConfig(NavigationItemConfig item) {
    return _ShellNavigationItem(
      id: item.id,
      title: item.title,
      sections: List<TruckLinkSection>.unmodifiable(item.sections),
    );
  }
}

// ============================================
// RESOLVED NAVIGATION
// ============================================

class _ResolvedNavigation {
  const _ResolvedNavigation({
    required this.bottomItems,
    required this.moreItems,
  });

  final List<_ShellNavigationItem> bottomItems;
  final List<_ShellNavigationItem> moreItems;

  List<_ShellNavigationItem> get visibleItems => [...bottomItems, ...moreItems];

  _ShellNavigationItem? findById(String id) {
    for (final item in visibleItems) {
      if (item.id == id) {
        return item;
      }
    }

    return null;
  }

  // ==========================================
  // RESOLVE SAVED NAVIGATION
  // ==========================================

  factory _ResolvedNavigation.resolve(
    NavigationLayout layout,
    SavedNavigationLayout? saved,
  ) {
    const maxBottom = 4;

    // Existing configuration is the catalog.
    final catalog = <String, NavigationItemConfig>{
      for (final item in [
        ...layout.visibleItems,
        ...layout.bottomItems,
        ...layout.moreItems,
      ])
        item.id: item,
    };

    // ========================================
    // RESTORE COMBINED GROUPS
    // ========================================

    final groupItems = <String, _ShellNavigationItem>{};

    final groupedMemberIds = <String>{};

    final placedGroups = <String>{...?saved?.bottomIds, ...?saved?.moreIds};

    for (final group in saved?.groups ?? const <SavedNavigationGroup>[]) {
      if (!placedGroups.contains(group.id) || catalog.containsKey(group.id)) {
        continue;
      }

      if (!group.memberIds.every(catalog.containsKey) ||
          group.memberIds.any(groupedMemberIds.contains)) {
        continue;
      }

      final sections = <TruckLinkSection>[];

      final seenSections = <TruckLinkSection>{};

      for (final memberId in group.memberIds) {
        for (final section in catalog[memberId]!.sections) {
          if (seenSections.add(section)) {
            sections.add(section);
          }
        }
      }

      if (sections.length < 2) {
        continue;
      }

      groupItems[group.id] = _ShellNavigationItem(
        id: group.id,
        title: group.title,
        sections: List<TruckLinkSection>.unmodifiable(sections),
      );

      groupedMemberIds.addAll(group.memberIds);
    }

    // ========================================
    // BOTTOM / MORE
    // ========================================

    final bottom = <_ShellNavigationItem>[];
    final more = <_ShellNavigationItem>[];

    final used = <String>{};

    void add(String id, List<_ShellNavigationItem> target) {
      if (groupedMemberIds.contains(id) || !used.add(id)) {
        return;
      }

      final item =
          groupItems[id] ??
          (catalog[id] == null
              ? null
              : _ShellNavigationItem.fromConfig(catalog[id]!));

      if (item != null) {
        target.add(item);
      }
    }

    // ========================================
    // BOTTOM ITEMS
    // ========================================

    final requestedBottom =
        saved?.bottomIds ?? layout.bottomItems.map((item) => item.id);

    for (final id in requestedBottom) {
      if (bottom.length < maxBottom) {
        add(id, bottom);
      } else {
        add(id, more);
      }
    }

    // ========================================
    // MORE ITEMS
    // ========================================

    final requestedMore =
        saved?.moreIds ?? layout.moreItems.map((item) => item.id);

    for (final id in requestedMore) {
      add(id, more);
    }

    // ========================================
    // HIDDEN ITEMS
    // ========================================

    for (final id in saved?.hiddenIds ?? const <String>[]) {
      if (catalog.containsKey(id) && !groupedMemberIds.contains(id)) {
        used.add(id);
      }
    }

    // ========================================
    // NEW SECTIONS
    // ========================================

    for (final id in catalog.keys) {
      if (!used.contains(id) && !groupedMemberIds.contains(id)) {
        add(id, more);
      }
    }

    // ========================================
    // SAFE FALLBACK
    // ========================================

    if (bottom.isEmpty && more.isNotEmpty) {
      bottom.add(more.removeAt(0));
    }

    if (bottom.isEmpty && catalog.isNotEmpty) {
      bottom.add(_ShellNavigationItem.fromConfig(catalog.values.first));
    }

    return _ResolvedNavigation(
      bottomItems: List<_ShellNavigationItem>.unmodifiable(bottom),
      moreItems: List<_ShellNavigationItem>.unmodifiable(more),
    );
  }
}

// ============================================
// COMBINED GROUP PAGE
// ============================================

class _CombinedSectionsPage extends StatelessWidget {
  const _CombinedSectionsPage({required this.item, required this.pageBuilder});

  final _ShellNavigationItem item;

  final Widget Function(TruckLinkSection) pageBuilder;

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      key: ValueKey(
        '${item.id}:'
        '${item.sections.map((section) => section.name).join(",")}',
      ),

      length: item.sections.length,

      child: Builder(
        builder: (tabContext) {
          final controller = DefaultTabController.of(tabContext);

          return Column(
            children: [
              // ==============================
              // FLOATING INNER TAB BAR
              // ==============================
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),

                child: AnimatedBuilder(
                  animation: controller,

                  builder: (context, child) {
                    return TruckLinkPillNavigation(
                      style: TruckLinkPillStyle.group,
                      selectedIndex: controller.index,

                      items: [
                        for (final section in item.sections)
                          TruckLinkPillItem(
                            label: section.title,
                            icon: _sectionIcon(section),
                          ),
                      ],

                      onSelected: (index) {
                        controller.animateTo(
                          index,
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeInOutCubic,
                        );
                      },
                    );
                  },
                ),
              ),

              // ==============================
              // INNER CONTENT
              // ==============================
              Expanded(
                child: TabBarView(
                  controller: controller,
                  children: [
                    for (final section in item.sections) pageBuilder(section),
                  ],
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
// MORE NAVIGATION PAGE
// ============================================

class _MoreNavigationPage extends StatelessWidget {
  const _MoreNavigationPage({
    required this.items,
    required this.selectedId,
    required this.iconFor,
    required this.onSelect,
  });

  final List<_ShellNavigationItem> items;

  final String? selectedId;

  final IconData Function(_ShellNavigationItem) iconFor;

  final ValueChanged<String> onSelect;

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _ComingSoonPage(
        icon: Icons.widgets_outlined,
        title: 'Нет дополнительных разделов',
        description:
            'Их можно добавить '
            'в настройках навигации.',
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return ListView(
      key: const PageStorageKey<String>('trucklink-more'),

      padding: const EdgeInsets.all(16),

      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),

          child: Text(
            'Дополнительные разделы',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),

        for (final item in items)
          Card(
            margin: const EdgeInsets.only(bottom: 10),

            child: ListTile(
              leading: Icon(iconFor(item), color: scheme.primary),

              title: Text(item.title),

              subtitle: item.sections.length > 1
                  ? Text(
                      item.sections.map((section) => section.title).join(' · '),
                    )
                  : null,

              selected: item.id == selectedId,

              trailing: const Icon(Icons.chevron_right_rounded),

              onTap: () {
                onSelect(item.id);
              },
            ),
          ),
      ],
    );
  }
}

// ============================================
// COMING SOON PAGE
// ============================================

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: theme.colorScheme.primary),

            const SizedBox(height: 16),

            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            Text(description, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
