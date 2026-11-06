import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/navigation/navigation_config.dart';
import '../../app/navigation/navigation_layout_storage.dart';

// ============================================
// NAVIGATION AREAS
// ============================================

enum _NavigationArea { bottom, more, hidden }

extension _NavigationAreaInfo on _NavigationArea {
  String get label => switch (this) {
    _NavigationArea.bottom => 'Снизу',
    _NavigationArea.more => 'Ещё',
    _NavigationArea.hidden => 'Скрыто',
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
  static const int _maxBottomItems = 4;

  final NavigationLayoutStorage _storage = NavigationLayoutStorage();

  final List<String> _bottom = [];
  final List<String> _more = [];
  final List<String> _hidden = [];

  final Map<String, SavedNavigationGroup> _groups = {};

  late final Map<String, NavigationItemConfig> _catalog;

  late final List<String> _defaultBottom;
  late final List<String> _defaultMore;

  _NavigationArea _selectedArea = _NavigationArea.bottom;

  bool _loading = true;
  bool _saving = false;

  int _nextGroupNumber = 0;

  // ==========================================
  // INITIALIZATION
  // ==========================================

  @override
  void initState() {
    super.initState();

    final defaults = NavigationLayout.defaultLayout;

    _catalog = {
      for (final item in [
        ...defaults.visibleItems,
        ...defaults.bottomItems,
        ...defaults.moreItems,
      ])
        item.id: item,
    };

    _defaultBottom = defaults.bottomItems
        .map((item) => item.id)
        .take(_maxBottomItems)
        .toList();

    final used = _defaultBottom.toSet();

    _defaultMore = [];

    for (final item in [
      ...defaults.bottomItems,
      ...defaults.moreItems,
      ...defaults.visibleItems,
    ]) {
      if (used.add(item.id)) {
        _defaultMore.add(item.id);
      }
    }

    _restoreDefaults();

    unawaited(_load());
  }

  // ==========================================
  // DEFAULT NAVIGATION
  // ==========================================

  void _restoreDefaults() {
    _groups.clear();

    _bottom
      ..clear()
      ..addAll(_defaultBottom);

    _more
      ..clear()
      ..addAll(_defaultMore);

    _hidden.clear();

    _selectedArea = _NavigationArea.bottom;
  }

  // ==========================================
  // LOAD SAVED SETTINGS
  // ==========================================

  Future<void> _load() async {
    try {
      final saved = await _storage.load();

      if (!mounted) return;

      if (saved != null) {
        final groups = <String, SavedNavigationGroup>{};

        final occupiedMembers = <String>{};

        final placedGroupIds = {...saved.bottomIds, ...saved.moreIds};

        // Restore only groups with valid members.
        for (final group in saved.groups) {
          if (!placedGroupIds.contains(group.id) ||
              _catalog.containsKey(group.id) ||
              !group.memberIds.every(_catalog.containsKey) ||
              group.memberIds.any(occupiedMembers.contains)) {
            continue;
          }

          groups[group.id] = group;

          occupiedMembers.addAll(group.memberIds);
        }

        final used = <String>{};

        List<String> takeKnown(Iterable<String> input, {bool hidden = false}) {
          final result = <String>[];

          for (final id in input) {
            final valid =
                _catalog.containsKey(id) || (!hidden && groups.containsKey(id));

            if (!valid || occupiedMembers.contains(id) || !used.add(id)) {
              continue;
            }

            result.add(id);
          }

          return result;
        }

        final bottom = takeKnown(saved.bottomIds);

        final more = takeKnown(saved.moreIds);

        final hidden = takeKnown(saved.hiddenIds, hidden: true);

        // The fifth bottom position is for "Ещё".
        if (bottom.length > _maxBottomItems) {
          more.insertAll(0, bottom.sublist(_maxBottomItems));

          bottom.removeRange(_maxBottomItems, bottom.length);
        }

        // Put new application sections into "Ещё".
        for (final id in _catalog.keys) {
          if (!occupiedMembers.contains(id) && used.add(id)) {
            more.add(id);
          }
        }

        // Keep at least one bottom tab.
        if (bottom.isEmpty) {
          if (more.isNotEmpty) {
            bottom.add(more.removeAt(0));
          } else if (hidden.isNotEmpty) {
            bottom.add(hidden.removeAt(0));
          }
        }

        setState(() {
          _groups
            ..clear()
            ..addAll(groups);

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
        _message('Не удалось загрузить настройки навигации');
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
  // GROUP ACCESS
  // ==========================================

  List<String> _items(_NavigationArea area) {
    return switch (area) {
      _NavigationArea.bottom => _bottom,
      _NavigationArea.more => _more,
      _NavigationArea.hidden => _hidden,
    };
  }

  _NavigationArea? _areaOf(String id) {
    for (final area in _NavigationArea.values) {
      if (_items(area).contains(id)) {
        return area;
      }
    }

    return null;
  }

  // ==========================================
  // SECTION INFORMATION
  // ==========================================

  String _title(String id) {
    return _groups[id]?.title ?? _catalog[id]?.title ?? id;
  }

  String _subtitle(String id) {
    final group = _groups[id];

    if (group != null) {
      return group.memberIds.map(_title).join(' · ');
    }

    final item = _catalog[id];

    if (item == null || item.sections.length == 1) {
      return 'Раздел TruckLink';
    }

    return item.sections.map((section) => section.title).join(' · ');
  }

  IconData _icon(String id) {
    if (_groups.containsKey(id)) {
      return Icons.layers_outlined;
    }

    final item = _catalog[id];

    if (item == null || item.sections.length != 1) {
      return Icons.widgets_outlined;
    }

    return switch (item.sections.first) {
      TruckLinkSection.home => Icons.home_outlined,

      TruckLinkSection.instruments => Icons.speed_outlined,

      TruckLinkSection.truck => Icons.local_shipping_outlined,

      TruckLinkSection.job => Icons.inventory_2_outlined,

      TruckLinkSection.finances => Icons.account_balance_wallet_outlined,

      TruckLinkSection.map => Icons.map_outlined,

      TruckLinkSection.statistics => Icons.bar_chart_outlined,
    };
  }

  // ==========================================
  // REORDER ITEMS
  // ==========================================

  void _reorder(int oldIndex, int newIndex) {
    if (_loading || _saving) return;

    final items = _items(_selectedArea);

    if (oldIndex < 0 ||
        oldIndex >= items.length ||
        newIndex < 0 ||
        newIndex > items.length) {
      return;
    }

    // Flutter's onReorder provides insertion
    // position before the removal adjustment.
    if (newIndex > oldIndex) {
      newIndex--;
    }

    if (newIndex == oldIndex) return;

    setState(() {
      final id = items.removeAt(oldIndex);

      items.insert(newIndex, id);
    });
  }

  // ==========================================
  // MOVE BETWEEN AREAS
  // ==========================================

  void _move(String id, _NavigationArea destination) {
    if (_loading || _saving) return;

    // Combined groups cannot be hidden directly.
    // First split them into regular sections.
    if (_groups.containsKey(id) && destination == _NavigationArea.hidden) {
      _message('Сначала раздели объединённую вкладку');

      return;
    }

    final from = _areaOf(id);

    if (from == null || from == destination) {
      return;
    }

    // Always keep one bottom tab.
    if (from == _NavigationArea.bottom && _bottom.length == 1) {
      _message(
        'В нижней панели должна остаться '
        'хотя бы одна вкладка',
      );

      return;
    }

    // Maximum: four custom tabs + More.
    if (destination == _NavigationArea.bottom &&
        _bottom.length >= _maxBottomItems) {
      _message(
        'Внизу может быть не более '
        'четырёх вкладок',
      );

      return;
    }

    setState(() {
      _items(from).remove(id);

      _items(destination).add(id);

      _selectedArea = destination;
    });
  }

  // ==========================================
  // MERGE AVAILABILITY
  // ==========================================

  bool _canMerge(String id) {
    if (_groups.containsKey(id) || _selectedArea == _NavigationArea.hidden) {
      return false;
    }

    final original = _catalog[id];

    return original != null && original.sections.length == 1;
  }

  List<String> _mergeCandidates(String sourceId) {
    return [..._bottom, ..._more].where((id) {
      if (id == sourceId || _groups.containsKey(id)) {
        return false;
      }

      return _catalog[id]?.sections.length == 1;
    }).toList();
  }

  // ==========================================
  // MERGE TWO SECTIONS
  // ==========================================

  Future<void> _merge(String sourceId) async {
    if (_loading || _saving || !_canMerge(sourceId)) {
      return;
    }

    final candidates = _mergeCandidates(sourceId);

    if (candidates.isEmpty) {
      _message('Нет другого раздела для объединения');

      return;
    }

    String groupTitle = '${_title(sourceId)} + ${_title(candidates.first)}';

    String secondId = candidates.first;

    bool emptyName = false;

    final choice = await showDialog<_MergeChoice>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, refresh) {
            return AlertDialog(
              title: const Text('Объединить разделы'),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Первый: ${_title(sourceId)}'),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: secondId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Второй раздел',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final id in candidates)
                          DropdownMenuItem<String>(
                            value: id,
                            child: Text(_title(id)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          refresh(() {
                            secondId = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      initialValue: groupTitle,
                      maxLength: 30,
                      decoration: InputDecoration(
                        labelText: 'Название новой вкладки',
                        border: const OutlineInputBorder(),
                        errorText: emptyName ? 'Введи название' : null,
                      ),
                      onChanged: (value) {
                        groupTitle = value;

                        if (emptyName) {
                          refresh(() {
                            emptyName = false;
                          });
                        }
                      },
                    ),

                    const Text('Внутри вкладки будут две страницы.'),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Отмена'),
                ),

                FilledButton(
                  onPressed: () {
                    final title = groupTitle.trim();

                    if (title.isEmpty) {
                      refresh(() {
                        emptyName = true;
                      });

                      return;
                    }

                    Navigator.pop(dialogContext, _MergeChoice(secondId, title));
                  },
                  child: const Text('Объединить'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || choice == null) {
      return;
    }

    final partnerId = choice.secondId;

    final sourceArea = _areaOf(sourceId);
    final partnerArea = _areaOf(partnerId);

    if (sourceArea == null || partnerArea == null) {
      return;
    }

    // When either section is pinned,
    // the combined tab will also be pinned.
    final destination =
        sourceArea == _NavigationArea.bottom ||
            partnerArea == _NavigationArea.bottom
        ? _NavigationArea.bottom
        : _NavigationArea.more;

    final target = _items(destination);

    final sourcePos = target.indexOf(sourceId);
    final partnerPos = target.indexOf(partnerId);

    final index = sourcePos >= 0 ? sourcePos : partnerPos;

    final id =
        'group:${DateTime.now().microsecondsSinceEpoch}'
        '-${_nextGroupNumber++}';

    final group = SavedNavigationGroup(
      id: id,
      title: choice.title,
      memberIds: [sourceId, partnerId],
    );

    setState(() {
      _items(sourceArea).remove(sourceId);
      _items(partnerArea).remove(partnerId);

      _groups[id] = group;

      final insertion = index.clamp(0, target.length).toInt();

      target.insert(insertion, id);

      _selectedArea = destination;
    });
  }

  // ==========================================
  // SPLIT COMBINED TAB
  // ==========================================

  void _split(String id) {
    final group = _groups[id];
    final area = _areaOf(id);

    if (_loading || _saving || group == null || area == null) {
      return;
    }

    final list = _items(area);
    final index = list.indexOf(id);

    if (index < 0) return;

    setState(() {
      list.removeAt(index);

      _groups.remove(id);

      if (area == _NavigationArea.bottom) {
        final freeSlots = _maxBottomItems - _bottom.length;

        final pinned = group.memberIds.take(freeSlots).toList();

        final overflow = group.memberIds.skip(freeSlots).toList();

        _bottom.insertAll(index, pinned);

        _more.insertAll(0, overflow);
      } else {
        list.insertAll(index, group.memberIds);
      }
    });

    _message('Разделы снова доступны отдельно');
  }

  // ==========================================
  // SAVE SETTINGS
  // ==========================================

  Future<void> _save() async {
    if (_loading || _saving) return;

    setState(() {
      _saving = true;
    });

    try {
      final layout = SavedNavigationLayout(
        bottomIds: _bottom,
        moreIds: _more,
        hiddenIds: _hidden,
        groups: _groups.values,
      );

      await _storage.save(layout);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      debugPrint('TruckLink: navigation save failed: $error');

      if (mounted) {
        _message('Не удалось сохранить навигацию');
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
  // RESET TO DEFAULT
  // ==========================================

  Future<void> _reset() async {
    if (_loading || _saving) return;

    setState(() {
      _saving = true;
    });

    try {
      await _storage.reset();

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      debugPrint('TruckLink: navigation reset failed: $error');

      if (mounted) {
        _message('Не удалось сбросить настройки');
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
  // SNACKBAR
  // ==========================================

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(text)));
  }

  // ==========================================
  // BUILD NAVIGATION ROW
  // ==========================================

  Widget _buildRow(String id, int index) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final isGroup = _groups.containsKey(id);
    final area = _selectedArea;

    return Card(
      key: ValueKey('$area:$id'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(_icon(id), color: scheme.primary),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title(id),
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  Text(
                    _subtitle(id),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          PopupMenuButton<String>(
            tooltip: 'Действия с разделом',
            enabled: !_saving,
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'merge') {
                unawaited(_merge(id));
              } else if (value == 'split') {
                _split(id);
              } else if (value.startsWith('move:')) {
                final destination = _NavigationArea.values.firstWhere((area) {
                  return area.name == value.substring(5);
                });

                _move(id, destination);
              }
            },
            itemBuilder: (context) {
              return [
                if (_canMerge(id) && _mergeCandidates(id).isNotEmpty)
                  const PopupMenuItem<String>(
                    value: 'merge',
                    child: Text('Объединить с другим'),
                  ),

                if (isGroup)
                  const PopupMenuItem<String>(
                    value: 'split',
                    child: Text('Разделить вкладку'),
                  ),

                for (final destination in _NavigationArea.values)
                  if (destination != area &&
                      !(isGroup && destination == _NavigationArea.hidden))
                    PopupMenuItem<String>(
                      value: 'move:${destination.name}',
                      child: Text(
                        'Переместить: '
                        '${destination.label}',
                      ),
                    ),
              ];
            },
          ),

          ReorderableDragStartListener(
            index: index,
            enabled: !_saving,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.drag_handle_rounded),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BUILD SCREEN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final ids = _items(_selectedArea);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Навигация'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _reset,
            child: const Text('Сбросить'),
          ),
        ],
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Расположение разделов', style: theme.textTheme.titleLarge),

              const SizedBox(height: 8),

              Text(
                'Перетаскивай разделы за значок '
                'справа. Через меню ⋮ можно '
                'перемещать, объединять '
                'и разделять вкладки.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 18),

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
                    : (selection) {
                        setState(() {
                          _selectedArea = selection.first;
                        });
                      },
              ),

              const SizedBox(height: 14),

              Text(
                'Снизу: ${_bottom.length} · '
                'Ещё: ${_more.length} · '
                'Скрыто: ${_hidden.length} · '
                'Группы: ${_groups.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: ids.isEmpty
                    ? const Center(child: Text('В этой группе нет разделов.'))
                    : ReorderableListView.builder(
                        key: ValueKey(_selectedArea),
                        buildDefaultDragHandles: false,
                        itemCount: ids.length,
                        onReorder: _reorder,
                        itemBuilder: (context, index) {
                          return _buildRow(ids[index], index);
                        },
                      ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Объединённая вкладка занимает '
                  'одно место внизу. Если при '
                  'разделении не хватает места, '
                  'лишние разделы переходят '
                  'в «Ещё».',
                ),
              ),

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

// ============================================
// MERGE DIALOG RESULT
// ============================================

class _MergeChoice {
  const _MergeChoice(this.secondId, this.title);

  final String secondId;
  final String title;
}
