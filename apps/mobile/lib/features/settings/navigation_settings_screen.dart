import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/navigation/navigation_config.dart';
import '../../app/navigation/navigation_layout_storage.dart';

// ============================================
// NAVIGATION AREAS
// ============================================

enum _NavigationArea { bottom, more, hidden }

extension _NavigationAreaInfo on _NavigationArea {
  String get destination => switch (this) {
    _NavigationArea.bottom => 'нижнюю панель',
    _NavigationArea.more => 'меню «Ещё»',
    _NavigationArea.hidden => 'скрытые',
  };
}

// ============================================
// NAVIGATION SETTINGS SCREEN
// ============================================

class NavigationSettingsScreen extends StatefulWidget {
  const NavigationSettingsScreen({super.key});

  @override
  State<NavigationSettingsScreen> createState() =>
      _NavigationSettingsScreenState();
}

class _NavigationSettingsScreenState extends State<NavigationSettingsScreen> {
  // ==========================================
  // CONFIGURATION
  // ==========================================

  /// Maximum number of regular bottom tabs.
  ///
  /// The fifth position is reserved for "Ещё".
  static const int _maxBottomItems = 4;

  // ==========================================
  // STORAGE
  // ==========================================

  final NavigationLayoutStorage _storage = NavigationLayoutStorage();

  // ==========================================
  // NAVIGATION CATALOG
  // ==========================================

  late final Map<String, NavigationItemConfig> _catalog;

  late final List<String> _defaultBottom;
  late final List<String> _defaultMore;

  // ==========================================
  // CURRENT NAVIGATION LAYOUT
  // ==========================================

  final List<String> _bottom = [];
  final List<String> _more = [];
  final List<String> _hidden = [];

  _NavigationArea _selectedArea = _NavigationArea.bottom;

  bool _loading = true;
  bool _saving = false;

  // ==========================================
  // INITIALIZATION
  // ==========================================

  @override
  void initState() {
    super.initState();

    final layout = NavigationLayout.defaultLayout;

    // Build a catalog from the existing
    // navigation configuration.
    //
    // This preserves existing section IDs
    // and titles used by AppShell.
    _catalog = {
      for (final item in [
        ...layout.visibleItems,
        ...layout.bottomItems,
        ...layout.moreItems,
      ])
        item.id: item,
    };

    // Store default bottom tab order.
    _defaultBottom = layout.bottomItems.map((item) => item.id).toSet().toList();

    // Find the remaining visible sections.
    final used = _defaultBottom.toSet();

    _defaultMore = [];

    for (final item in [...layout.moreItems, ...layout.visibleItems]) {
      if (used.add(item.id)) {
        _defaultMore.add(item.id);
      }
    }

    // Display default values immediately,
    // then restore saved values from storage.
    _restoreDefaultLists();

    unawaited(_loadSavedLayout());
  }

  // ==========================================
  // RESTORE DEFAULT LISTS
  // ==========================================

  void _restoreDefaultLists() {
    _bottom
      ..clear()
      ..addAll(_defaultBottom);

    _more
      ..clear()
      ..addAll(_defaultMore);

    _hidden.clear();
  }

  // ==========================================
  // LOAD SAVED NAVIGATION
  // ==========================================

  Future<void> _loadSavedLayout() async {
    try {
      final saved = await _storage.load();

      if (!mounted) return;

      if (saved != null) {
        final known = _catalog.keys.toSet();

        // Prevent duplicates across all groups.
        final used = <String>{};

        List<String> filterIds(Iterable<String> ids) {
          final result = <String>[];

          for (final id in ids) {
            // Ignore sections removed in a
            // future or older app version.
            if (!known.contains(id)) {
              continue;
            }

            // One section can appear in
            // only one navigation area.
            if (!used.add(id)) {
              continue;
            }

            result.add(id);
          }

          return result;
        }

        // ====================================
        // RESTORE GROUPS
        // ====================================

        final bottom = filterIds(saved.bottomIds);

        final more = filterIds(saved.moreIds);

        final hidden = filterIds(saved.hiddenIds);

        // ====================================
        // INCLUDE NEW SECTIONS
        // ====================================

        // If a future TruckLink version adds
        // new sections, place them in "Ещё".
        for (final id in _catalog.keys) {
          if (used.add(id)) {
            more.add(id);
          }
        }

        // ====================================
        // ENFORCE BOTTOM TAB LIMIT
        // ====================================

        if (bottom.length > _maxBottomItems) {
          final overflow = bottom.sublist(_maxBottomItems);

          bottom.removeRange(_maxBottomItems, bottom.length);

          more.insertAll(0, overflow);
        }

        // ====================================
        // KEEP ONE BOTTOM TAB
        // ====================================

        // Always keep at least one regular
        // section in the bottom navigation.
        if (bottom.isEmpty) {
          if (more.isNotEmpty) {
            bottom.add(more.removeAt(0));
          } else if (hidden.isNotEmpty) {
            bottom.add(hidden.removeAt(0));
          }
        }

        // ====================================
        // APPLY RESTORED LAYOUT
        // ====================================

        setState(() {
          _bottom
            ..clear()
            ..addAll(bottom);

          _more
            ..clear()
            ..addAll(more);

          _hidden
            ..clear()
            ..addAll(hidden);
        });
      }
    } catch (error) {
      debugPrint('TruckLink: navigation load failed: $error');

      if (mounted) {
        _showMessage('Не удалось загрузить настройки навигации.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ==========================================
  // GET ACTIVE GROUP
  // ==========================================

  List<String> _listFor(_NavigationArea area) {
    return switch (area) {
      _NavigationArea.bottom => _bottom,
      _NavigationArea.more => _more,
      _NavigationArea.hidden => _hidden,
    };
  }

  // ==========================================
  // REORDER SECTIONS
  // ==========================================

  /// Called by ReorderableListView.onReorder.
  ///
  /// Flutter passes an insertion index.
  /// When moving an item down, its removal
  /// shifts subsequent positions by one.
  ///
  /// We must adjust newIndex accordingly.
  void _reorder(int oldIndex, int newIndex) {
    if (_saving || _loading) return;

    final items = _listFor(_selectedArea);

    // ========================================
    // VALIDATE INDEXES
    // ========================================

    if (oldIndex < 0 || oldIndex >= items.length) {
      return;
    }

    if (newIndex < 0 || newIndex > items.length) {
      return;
    }

    // ========================================
    // CORRECT INDEX WHEN MOVING DOWN
    // ========================================

    if (newIndex > oldIndex) {
      newIndex--;
    }

    if (oldIndex == newIndex) {
      return;
    }

    // ========================================
    // APPLY NEW ORDER
    // ========================================

    setState(() {
      final item = items.removeAt(oldIndex);

      items.insert(newIndex, item);
    });
  }

  // ==========================================
  // MOVE BETWEEN GROUPS
  // ==========================================

  void _moveItem(String id, _NavigationArea destination) {
    if (_saving || _loading) return;

    final source = _selectedArea;

    if (source == destination) {
      return;
    }

    // ========================================
    // REQUIRE ONE BOTTOM TAB
    // ========================================

    if (source == _NavigationArea.bottom && _bottom.length == 1) {
      _showMessage(
        'Нужно оставить хотя бы одну '
        'вкладку в нижней панели.',
      );

      return;
    }

    // ========================================
    // ENFORCE BOTTOM TAB LIMIT
    // ========================================

    if (destination == _NavigationArea.bottom &&
        _bottom.length >= _maxBottomItems) {
      _showMessage(
        'В нижней панели может быть '
        'не более четырёх вкладок.',
      );

      return;
    }

    // ========================================
    // APPLY MOVE
    // ========================================

    setState(() {
      // Remove from any current group.
      _bottom.remove(id);
      _more.remove(id);
      _hidden.remove(id);

      // Add to the destination group.
      _listFor(destination).add(id);

      // Show the destination group.
      _selectedArea = destination;
    });
  }

  // ==========================================
  // SAVE NAVIGATION
  // ==========================================

  Future<void> _save() async {
    if (_saving || _loading) return;

    setState(() {
      _saving = true;
    });

    final layout = SavedNavigationLayout(
      bottomIds: _bottom,
      moreIds: _more,
      hiddenIds: _hidden,
    );

    try {
      await _storage.save(layout);

      if (!mounted) return;

      // Return success to SettingsScreen.
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('TruckLink: navigation save failed: $error');

      if (mounted) {
        _showMessage('Не удалось сохранить настройки навигации.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ==========================================
  // RESET TO DEFAULTS
  // ==========================================

  Future<void> _reset() async {
    if (_saving || _loading) return;

    setState(() {
      _saving = true;
    });

    try {
      // Remove stored custom navigation.
      await _storage.reset();

      if (!mounted) return;

      setState(() {
        _restoreDefaultLists();

        _selectedArea = _NavigationArea.bottom;
      });

      _showMessage('Стандартная конфигурация восстановлена.');
    } catch (error) {
      debugPrint('TruckLink: navigation reset failed: $error');

      if (mounted) {
        _showMessage('Не удалось сбросить настройки.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ==========================================
  // SHOW MESSAGE
  // ==========================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  // ==========================================
  // SECTION ICON
  // ==========================================

  IconData _iconFor(NavigationItemConfig item) {
    // Multiple sections may share a tab.
    if (item.sections.length != 1) {
      return Icons.layers_outlined;
    }

    return switch (item.sections.first) {
      TruckLinkSection.home => Icons.dashboard_outlined,

      TruckLinkSection.instruments => Icons.speed_outlined,

      TruckLinkSection.truck => Icons.local_shipping_outlined,

      TruckLinkSection.job => Icons.inventory_2_outlined,

      TruckLinkSection.finances => Icons.account_balance_wallet_outlined,

      TruckLinkSection.map => Icons.map_outlined,

      TruckLinkSection.statistics => Icons.bar_chart_outlined,
    };
  }

  // ==========================================
  // SECTION SUBTITLE
  // ==========================================

  String _subtitleFor(NavigationItemConfig item) {
    if (item.sections.length <= 1) {
      return 'Раздел TruckLink';
    }

    return item.sections.map((section) => section.title).join(' · ');
  }

  // ==========================================
  // SECTION ROW
  // ==========================================

  Widget _buildItem(String id, int index) {
    final item = _catalog[id]!;

    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Card(
      key: ValueKey('${_selectedArea.name}-$id'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        child: Row(
          children: [
            // =================================
            // SECTION ICON
            // =================================
            Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(_iconFor(item), color: scheme.primary),
            ),

            const SizedBox(width: 4),

            // =================================
            // SECTION INFORMATION
            // =================================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),

                  const SizedBox(height: 4),

                  Text(
                    _subtitleFor(item),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            // =================================
            // MOVE MENU
            // =================================
            PopupMenuButton<_NavigationArea>(
              tooltip: 'Переместить раздел',
              enabled: !_saving,

              icon: const Icon(Icons.more_vert_rounded),

              onSelected: (destination) {
                _moveItem(id, destination);
              },

              itemBuilder: (context) {
                return [
                  for (final area in _NavigationArea.values)
                    if (area != _selectedArea)
                      PopupMenuItem<_NavigationArea>(
                        value: area,
                        child: Text(
                          'Переместить в '
                          '${area.destination}',
                        ),
                      ),
                ];
              },
            ),

            // =================================
            // REORDER HANDLE
            // =================================

            // Dragging starts immediately from
            // this handle.
            ReorderableDragStartListener(
              index: index,
              enabled: !_saving,

              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.drag_handle_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // ========================================
    // LOADING
    // ========================================

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final ids = _listFor(_selectedArea);

    return Scaffold(
      // ======================================
      // APP BAR
      // ======================================
      appBar: AppBar(
        title: const Text('Навигация'),

        actions: [
          TextButton(
            onPressed: _saving ? null : _reset,
            child: const Text('Сбросить'),
          ),

          const SizedBox(width: 8),
        ],
      ),

      // ======================================
      // BODY
      // ======================================
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ================================
              // HEADER
              // ================================
              Text('Расположение разделов', style: theme.textTheme.titleLarge),

              const SizedBox(height: 8),

              Text(
                'Перетаскивай разделы за значок '
                'справа. Через меню с тремя точками '
                'можно переместить раздел '
                'в другую группу.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 20),

              // ================================
              // GROUP SELECTOR
              // ================================
              SegmentedButton<_NavigationArea>(
                showSelectedIcon: false,

                segments: const [
                  ButtonSegment(
                    value: _NavigationArea.bottom,
                    label: Text('Снизу'),
                  ),

                  ButtonSegment(
                    value: _NavigationArea.more,
                    label: Text('Ещё'),
                  ),

                  ButtonSegment(
                    value: _NavigationArea.hidden,
                    label: Text('Скрыто'),
                  ),
                ],

                selected: {_selectedArea},

                onSelectionChanged: _saving
                    ? null
                    : (selected) {
                        setState(() {
                          _selectedArea = selected.first;
                        });
                      },
              ),

              const SizedBox(height: 14),

              // ================================
              // SECTION COUNTERS
              // ================================
              Text(
                'Снизу: ${_bottom.length}  ·  '
                'Ещё: ${_more.length}  ·  '
                'Скрыто: ${_hidden.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              // ================================
              // REORDERABLE LIST
              // ================================
              Expanded(
                child: ids.isEmpty
                    ? Center(
                        child: Text(
                          'В этой группе пока '
                          'нет разделов.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    : ReorderableListView.builder(
                        // Recreate list when
                        // switching navigation areas.
                        key: ValueKey(_selectedArea),

                        buildDefaultDragHandles: false,

                        itemCount: ids.length,

                        // Flutter 3.41.4:
                        //
                        // The correct callback
                        // is onReorder.
                        //
                        // Our _reorder method
                        // adjusts newIndex when
                        // moving items downward.
                        onReorder: _reorder,

                        itemBuilder: (context, index) {
                          return _buildItem(ids[index], index);
                        },
                      ),
              ),

              // ================================
              // INFORMATION
              // ================================
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: scheme.primary,
                      size: 20,
                    ),

                    const SizedBox(width: 10),

                    const Expanded(
                      child: Text(
                        'Изменения сохраняются на телефоне '
                        'и применяются после сохранения. '
                        'Скрытые разделы можно восстановить '
                        'здесь в любой момент.',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ================================
              // SAVE BUTTON
              // ================================
              FilledButton.icon(
                onPressed: _saving ? null : _save,

                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),

                label: Text(
                  _saving ? 'Сохранение...' : 'Сохранить расположение',
                ),

                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
