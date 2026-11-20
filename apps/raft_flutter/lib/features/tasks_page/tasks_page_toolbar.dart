// The Tasks page's toolbar, the toolbar over a list (Raft DS: Patterns,
// Responsive), on the shared fit toolbar: 我的 / 全部 with their numbers, the
// search filling the line, the filters Channel, Status, Creator and Assignee
// (the applied first, Clear all at their end), then the sort, List / Board
// and New task. As the page narrows they give way in the rule's steps
// (LIST_TOOLBAR_STEP): the sort and the view to icons, the filters to icons,
// the filters to a scrolling second line with their words back, New task to
// +, the scope to a Select, the sort and the view into More, and last an
// empty search to its button. Both tabs take every filter.
//
// Source: Web v1.24 components/task/tasksPage/TasksPageToolbar.tsx,
// components/ui/listToolbar.ts and ListToolbarParts.tsx.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart'
    show CssNum, RaftFitToolbarRecipe, RaftSlotStyle;

import '../../data/workspace_controller.dart';
import '../resource_filters.dart' show ResourceSender;
import '../sender_avatar_projection.dart';
import '../task_selection_filter.dart';
import 'tasks_page_model.dart';

/// The give-way steps of a list's toolbar (listToolbar.ts
/// `LIST_TOOLBAR_STEP`).
const tasksToolbarDisplayLabels = 10;
const tasksToolbarFilterLabels = 20;
const tasksToolbarFiltersWrap = 30;
const tasksToolbarPrimaryPlus = 40;
const tasksToolbarScopeSelect = 50;
const tasksToolbarDisplayMore = 60;
const tasksToolbarSearchButton = 70;

/// The search waits this long after the last key before it reads.
const tasksSearchDebounce = Duration(milliseconds: 250);

/// One person or agent a task can be created by or assigned to (Web
/// `useTaskIdentityOptions`), sorted by label.
@immutable
class TaskIdentityOption {
  const TaskIdentityOption({
    required this.key,
    required this.type,
    required this.id,
    required this.label,
    required this.handle,
    this.avatarUrl,
  });

  /// `user:<id>` / `agent:<id>`, the filters' encoding.
  final String key, type, id, label, handle;
  final String? avatarUrl;
}

/// The people and agents of the workspace's author directory, a live agent
/// that is not another person's personal assistant (`isSearchableAgent`).
List<TaskIdentityOption> taskIdentityOptions(WorkspaceController w) {
  final directory = w.services.entityDirectory;
  final me = w.client.user?.id;
  String text(Object? v) => v is String ? v : '';
  final options = <TaskIdentityOption>[
    for (final m in directory.authorMembers)
      if (text(m['userId'] ?? m['id']).isNotEmpty)
        TaskIdentityOption(
          key: 'user:${text(m['userId'] ?? m['id'])}',
          type: 'user',
          id: text(m['userId'] ?? m['id']),
          label: text(m['displayName']).isNotEmpty
              ? text(m['displayName'])
              : text(m['name']),
          handle: text(m['name']),
          avatarUrl: m['avatarUrl'] as String?,
        ),
    for (final a in directory.authorAgents)
      if (text(a['id']).isNotEmpty &&
          (a['deletedAt'] == null || a['deletedAt'] == '') &&
          (text(a['assistantOwnerUserId']).isEmpty ||
              a['assistantOwnerUserId'] == me))
        TaskIdentityOption(
          key: 'agent:${text(a['id'])}',
          type: 'agent',
          id: text(a['id']),
          label: text(a['displayName']).isNotEmpty
              ? text(a['displayName'])
              : text(a['name']),
          handle: text(a['name']),
          avatarUrl: a['avatarUrl'] as String?,
        ),
  ];
  options.sort(
    (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
  );
  return options;
}

/// A filter picker as a toolbar item: it gives its label up at the
/// [tasksToolbarFilterLabels] step and shows the count chosen after it.
class _FilterItem extends RaftFitItem {
  _FilterItem({
    required this.itemKey,
    required this.field,
    required this.label,
    required this.glyph,
    required this.options,
    required this.selection,
    required this.onToggle,
    required this.onClear,
    required this.menus,
    this.selfIdentity,
    this.identityAvatars = const {},
    this.aliases = const {},
    this.leadingOf,
  }) : super(labelOrder: tasksToolbarFilterLabels);

  final String itemKey, field, label;
  final RaftGlyph glyph;
  final Map<String, String> options, aliases;
  final Set<String> selection;
  final void Function(String key) onToggle;
  final VoidCallback onClear;
  final Set<MenuController> menus;
  final ResourceSender? selfIdentity;
  final Map<String, SenderAvatarProjection> identityAvatars;
  final Widget? Function(String key)? leadingOf;

  @override
  bool get hasLabelForm => true;

  @override
  Widget buildForm(
    BuildContext context,
    RaftFitForm form, {
    required bool probe,
    List<RaftMenuEntry> moreEntries = const [],
  }) {
    final t = RaftTokens.of(context);
    final gone = form != RaftFitForm.full;
    final fit = RaftFitToolbarRecipe.resolve(
      count: selection.isNotEmpty,
      states: t.recipeStates(
        responsive: true,
        extra: [if (gone) 'data-fit-label'],
      ),
      tokens: t.recipeTokens,
    );
    return TaskSelectionFilter(
      key: probe ? null : ValueKey('tasks-page-filter-$itemKey'),
      field: field,
      label: raftText(context, label),
      glyph: glyph,
      options: options,
      aliases: aliases,
      selection: selection,
      selfIdentity: selfIdentity,
      identityAvatars: identityAvatars,
      leadingOf: leadingOf,
      valid: () => true,
      onToggle: onToggle,
      onClear: onClear,
      beforeOpen: (menu) {
        for (final other in menus) {
          if (!identical(menu, other) && other.isOpen) other.close();
        }
      },
      onController: (menu, add) {
        if (probe) return;
        add ? menus.add(menu) : menus.remove(menu);
      },
      fit: TaskSelectionFilterFit(
        labelHidden: gone,
        valueSlot: fit.pickerValue,
        restyle: gone
            ? (RaftSlotStyle style) => style.copyWith(
                properties: {
                  ...style.properties,
                  'column-gap': CssNum(fit.picker.columnGap ?? 4, 'px'),
                  'padding-left': CssNum(
                    fit.picker.length('padding-left') ?? 8,
                    'px',
                  ),
                  'padding-right': CssNum(
                    fit.picker.length('padding-right') ?? 8,
                    'px',
                  ),
                },
              )
            : null,
      ),
    );
  }
}

/// The scope at the start of the line (Mine / All): a segmented control,
/// each segment with its count, giving way to a Select at the
/// [tasksToolbarScopeSelect] step.
class _ScopeItem extends RaftFitItem {
  _ScopeItem({
    required this.tab,
    required this.counts,
    required this.onChanged,
    required this.label,
  }) : super(labelOrder: tasksToolbarScopeSelect);

  final TasksPageTab tab;
  final Map<TasksPageTab, int?> counts;
  final ValueChanged<TasksPageTab> onChanged;
  final String label;

  @override
  bool get hasLabelForm => true;

  String _name(BuildContext context, TasksPageTab tab) =>
      tab == TasksPageTab.mine
      ? raftText(context, 'Mine')
      : raftTextZh(context, 'All', '全部');

  @override
  Widget buildForm(
    BuildContext context,
    RaftFitForm form, {
    required bool probe,
    List<RaftMenuEntry> moreEntries = const [],
  }) {
    final t = RaftTokens.of(context);
    final line = t.desktop ? RaftDesktopMetrics.controlHeight : 32.0;
    if (form == RaftFitForm.full) {
      // The track is taller than the line's controls: it hangs into the air
      // above and below (`-my-[3px]`), the line stays as tall as the controls.
      // (The segment is the line's height; the track adds 3px around it.)
      final track = line + 6;
      return Align(
        widthFactor: 1,
        heightFactor: line / track,
        child: RaftSegmentedControl<TasksPageTab>(
          value: tab,
          label: label,
          visualHeight: line,
          minimumTargetSize: line,
          onChanged: onChanged,
          items: [
            for (final value in TasksPageTab.values)
              RaftSegmentedOption(
                value: value,
                label: _name(context, value),
                count: counts[value]?.toString(),
                itemKey: ValueKey('tasks-page-tab-${value.name}'),
              ),
          ],
        ),
      );
    }
    final current = _name(context, tab);
    return RaftDropdownMenu(
      key: probe ? null : const ValueKey('tasks-page-scope-select'),
      label: current,
      tooltip: probe ? null : label,
      triggerBuilder: (context, focus, toggle) => RaftButton(
        label: current,
        semanticLabel: '$label, $current',
        tooltip: probe ? null : label,
        uiVariant: RaftButtonVariant.outline,
        uiSize: RaftButtonSize.md,
        trailingGlyph: RaftGlyph.chevronDown,
        glyphSize: 14,
        physicalHeight: line,
        focusNode: focus,
        onPressed: toggle,
      ),
      entries: [
        for (final value in TasksPageTab.values)
          RaftMenuEntry(
            label: _name(context, value),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              // ds-allow: Web ListScopeSelect count `gap-2`
              spacing: 8,
              children: [
                if (counts[value] != null)
                  Text(
                    '${counts[value]}',
                    style: t.scale(
                      RaftTypeScale.monoMeta,
                      mono: true,
                      color: t.ui.foregroundHint,
                    ),
                  ),
                if (value == tab) const RaftIcon(RaftGlyph.check, size: 14),
              ],
            ),
            onPressed: () => onChanged(value),
          ),
      ],
    );
  }
}

/// List / Board: a segmented control with the icons alone from the first
/// step (each word stays its name and tooltip).
class _ViewItem extends RaftFitItem {
  _ViewItem({required this.view, required this.onChanged, required this.label})
    : super(labelOrder: tasksToolbarDisplayLabels);

  final TasksPageView view;
  final ValueChanged<TasksPageView> onChanged;
  final String label;

  @override
  bool get hasLabelForm => true;

  @override
  Widget buildForm(
    BuildContext context,
    RaftFitForm form, {
    required bool probe,
    List<RaftMenuEntry> moreEntries = const [],
  }) {
    final t = RaftTokens.of(context);
    final line = t.desktop ? RaftDesktopMetrics.controlHeight : 32.0;
    final track = line + 6;
    final iconOnly = form != RaftFitForm.full;
    String name(TasksPageView v) =>
        raftText(context, v == TasksPageView.list ? 'List' : 'Board');
    return Align(
      widthFactor: 1,
      heightFactor: line / track,
      child: RaftSegmentedControl<TasksPageView>(
        value: view,
        label: label,
        visualHeight: line,
        minimumTargetSize: line,
        onChanged: onChanged,
        items: [
          for (final value in TasksPageView.values)
            RaftSegmentedOption(
              value: value,
              label: iconOnly ? '' : name(value),
              tooltip: iconOnly ? name(value) : null,
              glyph: value == TasksPageView.list
                  ? RaftGlyph.layoutList
                  : RaftGlyph.columns3,
              itemKey: ValueKey('tasks-page-view-${value.name}'),
            ),
        ],
      ),
    );
  }
}

class TasksPageToolbar extends StatefulWidget {
  const TasksPageToolbar({
    super.key,
    required this.controller,
    required this.tab,
    required this.onTabChange,
    required this.tabCounts,
    required this.query,
    required this.onQueryChange,
    required this.filters,
    required this.setChannelIds,
    required this.setStatuses,
    required this.setCreators,
    required this.setAssignees,
    required this.onClearFilters,
    required this.sort,
    required this.onSortChange,
    required this.view,
    required this.onViewChange,
    required this.onNewTask,
    required this.sideInset,
  });

  final WorkspaceController controller;
  final TasksPageTab tab;
  final ValueChanged<TasksPageTab> onTabChange;
  final Map<TasksPageTab, int?> tabCounts;

  /// The search as the page holds it (untrimmed).
  final String query;
  final ValueChanged<String> onQueryChange;
  final PageFilters filters;
  final ValueChanged<List<String>> setChannelIds,
      setStatuses,
      setCreators,
      setAssignees;
  final VoidCallback onClearFilters;
  final ServerTaskSort sort;
  final ValueChanged<ServerTaskSort> onSortChange;
  final TasksPageView view;
  final ValueChanged<TasksPageView> onViewChange;

  /// Null: the person may not create tasks here (a Guest).
  final VoidCallback? onNewTask;

  /// The page's side padding around the line (16, or the surface inset from
  /// 28rem of page).
  final double sideInset;

  @override
  State<TasksPageToolbar> createState() => _TasksPageToolbarState();
}

class _TasksPageToolbarState extends State<TasksPageToolbar> {
  final _search = TextEditingController();
  final _menus = <MenuController>{};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.text = widget.query;
  }

  @override
  void didUpdateWidget(TasksPageToolbar old) {
    super.didUpdateWidget(old);
    // The address changed the search (Clear): the field shows it, unless a
    // typed one is still waiting to be read.
    if (widget.query != old.query &&
        _debounce == null &&
        _search.text != widget.query) {
      _search.text = widget.query;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// The search as typed: shown at once, read once typing pauses; emptied
  /// (the ×, Esc) it reads at once.
  void _typed(String value) {
    _debounce?.cancel();
    _debounce = null;
    if (value.length > taskSearchMaxLength) {
      final clipped = value.substring(0, taskSearchMaxLength);
      _search.value = TextEditingValue(
        text: clipped,
        selection: TextSelection.collapsed(offset: clipped.length),
      );
      value = clipped;
    }
    if (value.isEmpty) {
      widget.onQueryChange('');
      return;
    }
    _debounce = Timer(tasksSearchDebounce, () {
      _debounce = null;
      widget.onQueryChange(value);
    });
  }

  Map<String, String> _identities(
    BuildContext context,
    List<TaskIdentityOption> people, {
    required bool creator,
  }) {
    final self = widget.controller.client.user;
    return {
      if (self != null)
        'user:${self.id}': creator
            ? raftText(context, 'Created by me')
            : raftText(context, 'Assigned to me'),
      if (!creator) 'unassigned': raftTextZh(context, 'Unassigned', '未分配'),
      for (final person in people)
        if (person.key != 'user:${self?.id}') person.key: person.label,
    };
  }

  List<RaftMenuEntry> _choices<T>({
    required String heading,
    required T value,
    required Map<T, String> options,
    required ValueChanged<T> onChanged,
  }) => [
    RaftMenuEntry(label: heading),
    for (final entry in options.entries)
      RaftMenuEntry(
        label: entry.value,
        trailing: entry.key == value
            ? const RaftIcon(RaftGlyph.check, size: 14)
            : null,
        onPressed: () => onChanged(entry.key),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final w = widget.controller;
    final filters = widget.filters;
    final people = taskIdentityOptions(w);
    final self = w.client.user;
    final avatars = projectTaskFilterAvatars(
      origin: w.client.origin,
      identityKeys: [
        for (final p in people) p.key,
        if (self != null) 'user:${self.id}',
      ],
      agents: w.services.entityDirectory.authorAgents,
      members: w.services.entityDirectory.authorMembers,
      currentUser: self?.json,
    );
    final selfIdentity = self == null
        ? null
        : ResourceSender(self.id, 'user', self.name);
    final aliases = {for (final p in people) p.key: '${p.handle} ${p.label}'};
    final channels = <String, String>{
      for (final c in w.channels.where(
        (c) => ['channel', 'private'].contains(c.type),
      ))
        c.id: '#${c.name}',
    };
    final statusLabels = {
      for (final s in boardStatuses)
        s: raftText(context, raftTaskStatusLabel(s)),
    };

    _FilterItem filter(
      String itemKey,
      String field,
      String label,
      RaftGlyph glyph,
      Map<String, String> options,
      List<String> selected,
      ValueChanged<List<String>> set, {
      bool identity = false,
      Widget? Function(String)? leadingOf,
    }) => _FilterItem(
      itemKey: itemKey,
      field: field,
      label: label,
      glyph: glyph,
      options: options,
      selection: selected.toSet(),
      menus: _menus,
      selfIdentity: identity ? selfIdentity : null,
      identityAvatars: identity ? avatars : const {},
      aliases: identity ? aliases : const {},
      leadingOf: leadingOf,
      onToggle: (key) => set(
        selected.contains(key)
            ? selected.where((value) => value != key).toList()
            : [...selected, key],
      ),
      onClear: () => set(const []),
    );

    final filterItems = <(bool, _FilterItem)>[
      (
        filters.channelIds.isNotEmpty,
        filter(
          'channel',
          'Channel',
          raftText(context, 'Channel'),
          RaftGlyph.hash,
          channels,
          filters.channelIds,
          widget.setChannelIds,
        ),
      ),
      (
        filters.statuses.isNotEmpty,
        filter(
          'status',
          'Status',
          raftText(context, 'Status'),
          RaftGlyph.circleDot,
          statusLabels,
          filters.statuses,
          widget.setStatuses,
          leadingOf: (key) => RaftMessageTaskStatusIcon(
            status: raftTaskStatusOf(key),
            color: t.ui.foreground,
          ),
        ),
      ),
      (
        filters.creators.isNotEmpty,
        filter(
          'creator',
          'Creator',
          raftText(context, 'Creator'),
          RaftGlyph.userCircle2,
          _identities(context, people, creator: true),
          filters.creators,
          widget.setCreators,
          identity: true,
        ),
      ),
      (
        filters.assignees.isNotEmpty,
        filter(
          'assignee',
          'Assignee',
          raftText(context, 'Assignee'),
          RaftGlyph.user,
          _identities(context, people, creator: false),
          filters.assignees,
          widget.setAssignees,
          identity: true,
        ),
      ),
    ];
    // The applied first, so they are in view before any scrolling.
    final ordered = [
      for (final (applied, item) in filterItems)
        if (applied) item,
      for (final (applied, item) in filterItems)
        if (!applied) item,
    ];

    final sortNames = {
      ServerTaskSort.activity: raftText(context, 'Recently updated'),
      ServerTaskSort.created: raftText(context, 'Recently created'),
      ServerTaskSort.activityAsc: raftText(context, 'Least recently updated'),
    };
    final sortOrder = [
      ServerTaskSort.activity,
      ServerTaskSort.activityAsc,
      ServerTaskSort.created,
    ];
    final sortOptions = {for (final s in sortOrder) s: sortNames[s] ?? ''};
    final viewNames = {
      TasksPageView.list: raftText(context, 'List'),
      TasksPageView.board: raftText(context, 'Board'),
    };
    final newTask = raftText(context, 'New task');

    final airTop = t.desktop ? RaftDesktopMetrics.headerAir : 8.0;
    final airBottom = t.desktop ? RaftDesktopMetrics.headerAir - 1 : 8.0;
    return Container(
      key: const ValueKey('tasks-page-toolbar'),
      padding: EdgeInsets.fromLTRB(
        widget.sideInset,
        airTop,
        widget.sideInset,
        airBottom,
      ),
      decoration: BoxDecoration(
        color: t.colors['layer-canvas'],
        border: Border(bottom: BorderSide(color: t.colors['line-seam']!)),
      ),
      child: RaftFitToolbar(
        wrap: true,
        semanticLabel: raftText(context, 'Tasks'),
        children: [
          RaftFitGroup(
            firstLine: true,
            items: [
              _ScopeItem(
                tab: widget.tab,
                counts: widget.tabCounts,
                onChanged: widget.onTabChange,
                label: raftText(context, 'Show your tasks or all tasks'),
              ),
            ],
          ),
          RaftFitSearch(
            semanticLabel: raftText(context, 'Search tasks'),
            hintText: raftText(context, 'Search tasks'),
            clearLabel: raftText(context, 'Clear search'),
            collapseOrder: tasksToolbarSearchButton,
            controller: _search,
            onChanged: _typed,
            fieldKey: const ValueKey('tasks-page-search'),
          ),
          RaftFitGroup(
            scroll: true,
            wrapOrder: tasksToolbarFiltersWrap,
            end: filters.hasToolbarFilter
                ? RaftButton(
                    key: const ValueKey('tasks-page-clear-filters'),
                    uiVariant: RaftButtonVariant.ghost,
                    uiSize: RaftButtonSize.md,
                    label: raftTextZh(context, 'Clear all', '清除筛选'),
                    onPressed: widget.onClearFilters,
                  )
                : null,
            items: ordered,
          ),
          RaftFitGroup(
            firstLine: true,
            moreOrder: tasksToolbarDisplayMore,
            moreItem: [
              ..._choices<ServerTaskSort>(
                heading: raftText(context, 'Sort'),
                value: widget.sort,
                options: sortOptions,
                onChanged: widget.onSortChange,
              ),
              const RaftMenuEntry.separator(),
              ..._choices<TasksPageView>(
                heading: raftText(context, 'View as'),
                value: widget.view,
                options: viewNames,
                onChanged: widget.onViewChange,
              ),
            ],
            items: [
              RaftFitPicker(
                key: const ValueKey('tasks-page-sort'),
                label: sortNames[widget.sort] ?? '',
                glyph: RaftGlyph.arrowDownUp,
                labelOrder: tasksToolbarDisplayLabels,
                menuEntries: [
                  for (final s in sortOrder)
                    RaftMenuEntry(
                      label: sortNames[s],
                      trailing: s == widget.sort
                          ? const RaftIcon(RaftGlyph.check, size: 14)
                          : null,
                      onPressed: () => widget.onSortChange(s),
                    ),
                ],
              ),
              _ViewItem(
                view: widget.view,
                onChanged: widget.onViewChange,
                label: raftText(context, 'Task view'),
              ),
            ],
          ),
          RaftFitGroup(
            firstLine: true,
            items: [
              const RaftFitMore(key: ValueKey('tasks-page-more')),
              if (widget.onNewTask != null)
                RaftFitButton(
                  key: const ValueKey('tasks-page-new-task'),
                  label: newTask,
                  glyph: RaftGlyph.plus,
                  variant: RaftButtonVariant.primary,
                  plusOrder: tasksToolbarPrimaryPlus,
                  onPressed: widget.onNewTask,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
