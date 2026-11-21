// The Tasks page with task v2 (the approved design): the server's tasks, in a
// list (我的: 分配给你 and 你发起的; 全部: one list) or on a board, with the
// toolbar over it (scope, search, filters, sort, view, New task), a selection
// that acts on many tasks at once, and every number the server's count.
//
// - Head: "Tasks", its number (`N / total` once a filter or the search
//   narrows it).
// - Selection: a row's box (on hover), Cmd/Ctrl-click, Shift-click for a run,
//   Cmd/Ctrl+A for everything under the filters, a long press by touch; Esc
//   ends it. The bar at the bottom (TasksSelectionBar) acts on it.
// - A task opens in the page's own slot (beside the list on a desktop, a
//   pushed page on a phone); this page stays mounted under it.
//
// Source: Web v1.24 components/task/tasksPage/TasksPage.tsx.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/server_task_window.dart';
import '../../data/workspace_controller.dart';
import '../create_task_dialog.dart';
import '../page_layout.dart';
import '../task_content_slot.dart' show taskSlotListMin;
import 'tasks_batch.dart';
import 'tasks_board_view.dart';
import 'tasks_list_view.dart';
import 'tasks_page_model.dart';
import 'tasks_page_params.dart';
import 'tasks_page_recent_history.dart';
import 'tasks_page_rows.dart';
import 'tasks_page_store.dart';
import 'tasks_page_toolbar.dart';
import 'tasks_selection.dart';
import 'tasks_selection_bar.dart';
import 'tasks_selection_escape.dart';

/// The page's window onto the socket, kept for the session: the store takes
/// live task changes whether or not the page is on screen (leaving Tasks and
/// coming back finds it current).
final _live = Expando<({RaftClient client, StreamSubscription<RaftEvent> sub})>(
  'tasks page live',
);

/// Feeds [store] the task events of [controller]'s client, once per client.
/// A task the event names is merged; one it doesn't, or a reconnect, starts
/// every read over.
void bindTasksPageLive(WorkspaceController controller, TasksPageStore store) {
  final client = controller.client;
  final held = _live[store];
  if (held != null && identical(held.client, client)) return;
  held?.sub.cancel().ignore();
  // ignore: raft_lints/avoid_unreleased_resource -- kept in _live for the store's life; replaced when the client changes
  final sub = client.events.listen(
    (event) {
      if (event.name != 'connected' && !event.name.startsWith('task:')) return;
      switch (classifyTaskEvent(
        event,
        serverId: controller.server?.string('id'),
      )) {
        case TaskEventIgnored():
          return;
        case TaskEventUnrecognized():
          store.reset();
        case TaskEventPatch(:final patches):
          store.applyLive(patches);
      }
    },
    // The client is gone (its session ended): so is what the store read.
    onDone: () {
      if (identical(_live[store]?.client, client)) store.dispose();
    },
  );
  _live[store] = (client: client, sub: sub);
}

/// The id of the task open beside the list (or pushed over it), or null.
typedef CurrentTaskId = String? Function();

class TasksPage extends StatefulWidget {
  const TasksPage({
    super.key,
    required this.controller,
    required this.onOpenTask,
    required this.currentTaskId,
    this.scroll,
    this.shown = true,
    this.store,
  });

  final WorkspaceController controller;

  /// A row or card was opened: the task row, from the list (it opens beside
  /// it where the shell has the slot).
  final void Function(Map<String, dynamic> task) onOpenTask;

  /// The task open beside the list, read when the page builds (the host
  /// rebuilds it as the location changes).
  final String? currentTaskId;

  /// The list's scroll position, kept by the host across navigation and
  /// scrolled up by a re-tap of the tab.
  final ScrollController? scroll;

  /// Whether the page is on screen (false on a phone while a task covers it).
  final bool shown;

  /// Tests: the store to read through.
  final TasksPageStore? store;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  late final TasksPageStore store;
  late final TasksPageParams params;
  late final TaskSelection selection;
  late final TasksPageRecentHistory history;
  String get doneSince => history.visit.doneSince;
  bool historyQueued = false;
  late String scope;
  bool _batchBusy = false;
  bool _creating = false;
  bool _listening = false;
  final _root = GlobalKey();

  WorkspaceController get w => widget.controller;

  @override
  void initState() {
    super.initState();
    store = widget.store ?? TasksPageStore.of(w);
    bindTasksPageLive(w, store);
    final visit = store.visit(
      serverId: w.server?.string('id'),
      userId: w.client.user?.id,
    );
    params = visit.params;
    scope = params.scope;
    selection = TaskSelection(scope: scope);
    history = TasksPageRecentHistory(store, visit)..watch(shown: widget.shown);
    // The people and agents the filters and the assignee picker list.
    w.services.entityDirectory
      ..ensureAuthors()
      ..addListener(_changed);
    store.addListener(_changed);
    params.addListener(_paramsChanged);
    selection.addListener(_changed);
    _listening = true;
    HardwareKeyboard.instance.addHandler(_key);
    _queueHistoryRefresh();
  }

  @override
  void didUpdateWidget(TasksPage old) {
    super.didUpdateWidget(old);
    if (old.shown != widget.shown) {
      store.setShown(widget.shown);
      _queueHistoryRefresh();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_key);
    if (_listening) {
      w.services.entityDirectory.removeListener(_changed);
      store.removeListener(_changed);
      params.removeListener(_paramsChanged);
      selection.removeListener(_changed);
    }
    history.hide();
    TasksSelectionEscape.active = false;
    TasksSelectionEscape.consumed = false;
    selection.dispose();
    super.dispose();
  }

  void _changed() {
    TasksSelectionEscape.active = selection.selecting;
    if (mounted) setState(() {});
    _queueHistoryRefresh();
  }

  void _queueHistoryRefresh() {
    if (!mounted || !widget.shown || !history.refreshing || historyQueued) {
      return;
    }
    historyQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      historyQueued = false;
      if (!mounted || !widget.shown) return;
      final departed = history.settle();
      if (departed == null) return;
      setState(() {});
      // The displayed lanes may still have end-of-frame reads queued.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        store.evictCompletedSince(departed);
      });
    });
  }

  /// What the page shows changed: the selection ends, 你发起的 keeps what was
  /// done in the last day from now, and the reads it dropped go.
  void _paramsChanged() {
    final next = params.scope;
    if (next != scope) {
      scope = next;
      selection.setScope(next);
      history.scopeChanged();
    }
    _changed();
  }

  TasksCountsPlan get _plan => history.plan;

  List<LaneSpec> get _lanes => viewLanes(
    params.tab,
    params.view,
    params.filters,
    params.sort,
    doneSince,
    store.collapsed,
  );

  /// The ids on screen, top to bottom (board columns left to right): a
  /// Shift-click's run goes from one to the other.
  List<String> _order() {
    final seen = <String>{};
    final groups = params.view == TasksPageView.board
        ? [
            for (final status in boardColumns(params.filters))
              if (!boardColumnFolded(status, params.filters, store.collapsed))
                boardColumnLanes(
                  params.tab,
                  params.filters,
                  status,
                  params.sort,
                ),
          ]
        : tasksListGroups(params.tab, params.filters, params.sort, doneSince);
    return [
      for (final group in groups)
        for (final task in store.laneView(group).tasks)
          if (seen.add('${task['id']}')) '${task['id']}',
    ];
  }

  /// What the bar counts and acts on: the selected tasks still in the lists
  /// (a task deleted, or changed out of the filters, since it was picked has
  /// left them).
  List<Map<String, dynamic>> _selectedTasks(List<LaneSpec> lanes) {
    if (!selection.selecting) return const [];
    final viewer = w.client.user?.id;
    return [
      for (final id in selection.selected)
        if (store.knownById[id] case final task?)
          if (lanes.any((l) => matchesLane(task, l.filters, viewer, true)))
            task,
    ];
  }

  // ------------------------------------------------------------ keyboard

  /// An Esc or Cmd/Ctrl+A the page leaves alone: a field's, one a menu,
  /// popover or dialog takes, or while the page is not on screen.
  bool _othersKey() {
    if (!mounted || !widget.shown) return true;
    if (ModalRoute.of(context)?.isCurrent == false) return true;
    final focus = FocusManager.instance.primaryFocus;
    final focused = focus?.context;
    if (focused == null) return false;
    if (focused.findAncestorStateOfType<EditableTextState>() != null ||
        focused.widget is EditableText) {
      return true;
    }
    var inMenu = false;
    focused.visitAncestorElements((element) {
      // A menu or popover's own layer (Web: a [role=menu] / [role=dialog]
      // in the document takes the key).
      if (element.widget is RawMenuAnchor || element.widget is OverlayPortal) {
        inMenu = true;
      }
      return !inMenu;
    });
    return inMenu;
  }

  bool _key(KeyEvent event) {
    if (event is KeyUpEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      TasksSelectionEscape.consumed = false;
    }
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    final isEscape = key == LogicalKeyboardKey.escape;
    final keyboard = HardwareKeyboard.instance;
    final isSelectAll =
        key == LogicalKeyboardKey.keyA &&
        primaryShortcutModifierDown(keyboard) &&
        !keyboard.isAltPressed &&
        !keyboard.isShiftPressed;
    if (!isEscape && !isSelectAll) return false;
    if (_othersKey()) return false;
    if (isEscape) {
      if (!selection.selecting) return false;
      // Before the page's own Esc (closing the open task), which sees it
      // taken ([TasksSelectionEscape], until the key goes up).
      TasksSelectionEscape.consumed = true;
      selection.clear();
      return true;
    }
    // The list's Select all, not the open task's: only from the list or from
    // nowhere.
    final focus = FocusManager.instance.primaryFocus;
    // Nothing focused is a scope holding the focus (the route's), not a
    // control.
    final inPage =
        focus == null ||
        focus is FocusScopeNode ||
        (focus.context?.findAncestorStateOfType<_TasksPageState>() == this);
    if (!inPage) return false;
    unawaited(_selectAll());
    return true;
  }

  void _toast(String text, {required bool error}) {
    if (!mounted) return;
    showRaftToast(
      context,
      text,
      tone: error ? RaftToastRecipeTone.error : RaftToastRecipeTone.info,
    );
  }

  Future<void> _selectAll() async {
    final at = scope;
    // What is on screen at once; then everything under the filters, read to
    // its end.
    selection.setAll(_order());
    final read = await readAllLaneTaskIds(store, _lanes);
    if (!mounted || scope != at) return;
    selection.setAll(read.ids);
    if (read.capped) {
      _toast(
        tasksPlural(
          context,
          read.ids.length,
          'Selected the first task',
          'Selected the first {count} tasks',
        ),
        error: false,
      );
    } else if (!read.complete) {
      _toast(
        tasksPlural(
          context,
          read.ids.length,
          "Selected {count} task; the rest couldn't be read",
          "Selected {count} tasks; the rest couldn't be read",
        ),
        error: true,
      );
    }
  }

  // --------------------------------------------------------- batch actions

  /// One batch at a time, however fast the clicks: the bar's and a board
  /// drop's. What the server refused stays selected, to try again; what was
  /// done or skipped leaves the selection.
  Future<BatchOutcome?> _runBatch(BatchAction action) async {
    final tasks = _selectedTasks(_lanes);
    if (_batchBusy || tasks.isEmpty) return null;
    _batchBusy = true;
    try {
      final outcome = await runTaskBatch(
        action,
        tasks,
        BatchViewer.of(w),
        perform: taskBatchPerformer(w, store),
        afterFollow: w.services.followedThreads.refresh,
      );
      if (!mounted) return outcome;
      if (outcome.failedIds.isNotEmpty) {
        selection.setAll(outcome.failedIds);
      } else {
        selection.clear();
      }
      return outcome;
    } finally {
      _batchBusy = false;
    }
  }

  /// A drop of a selected card while several are selected moves them all.
  void _moveSelected(String status) {
    final label = raftText(context, raftTaskStatusLabel(status));
    unawaited(
      _runBatch(BatchStatus(status)).then((outcome) {
        if (outcome == null || !mounted) return;
        _toast(
          tasksPlural(
                context,
                outcome.done,
                'Moved {count} task to {status}',
                'Moved {count} tasks to {status}',
                {'status': label},
              ) +
              tasksSkipped(context, outcome.skipped),
          error: outcome.done == 0,
        );
      }),
    );
  }

  /// The bar gone (Esc, x, an action done) with focus in it: focus goes back
  /// to the row picked last.
  void _returnFocus() {
    final id = selection.lastPicked;
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final root = _root.currentContext;
      if (!mounted || root == null) return;
      FocusNode? target;
      for (final node in FocusManager.instance.rootScope.descendants) {
        if (!node.canRequestFocus || node.context == null) continue;
        var inRow = false;
        node.context!.visitAncestorElements((element) {
          final key = element.widget.key;
          if (key == ValueKey('tasks-page-row-cell-$id') ||
              key == ValueKey('task-card-$id')) {
            inRow = true;
          }
          return !inRow;
        });
        if (inRow) {
          target = node;
          break;
        }
      }
      target?.requestFocus();
    });
  }

  // ---------------------------------------------------------------- create

  Future<void> _newTask() async {
    if (_creating) return;
    _creating = true;
    try {
      final channels = params.filters.channelIds;
      await showRaftForm<void>(
        context,
        builder: (_) => CreateTaskDialog.forChannel(
          controller: w,
          defaultChannelId: channels.length == 1 ? channels.first : null,
          onCreatedTasks: (created) {
            // Exactly one made: it opens (beside the list).
            if (created.length == 1 && mounted) widget.onOpenTask(created[0]);
          },
        ),
      );
    } finally {
      _creating = false;
    }
  }

  // ----------------------------------------------------------------- build

  /// The hits a search's list has read: every lane of the view read to its
  /// end, else null (not known yet).
  int? _searchHits(List<LaneSpec> lanes) {
    if (params.view != TasksPageView.list) return null;
    final ids = <String>{};
    for (final lane in lanes) {
      final read = store.lanes[lane.key];
      if (read == null || !read.loaded || read.nextCursor != null) return null;
      ids.addAll(read.ids);
    }
    return ids.length;
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < RaftLayoutMetrics.desktopBreakpoint;
    final plan = _plan;
    final counts = store.countsOf(plan);
    final filters = params.filters;
    final narrowed = filters.isNarrowed;
    final lanes = _lanes;
    final selected = _selectedTasks(lanes);
    final tab = params.tab;
    final tabTotal = counts.tabs[tab];
    final hits = counts.searching ? _searchHits(lanes) : null;
    // A search is not counted (the counts take no `q`): its N is the hits
    // the list has read, once it has read them all; until then, and on the
    // board, the tab's total alone.
    final number = counts.searching
        ? tabTotal == null
              ? null
              : hits != null
              ? '$hits / $tabTotal'
              : '$tabTotal'
        : counts.shown == null
        ? null
        : narrowed && tabTotal != null
        ? '${counts.shown} / $tabTotal'
        : '${counts.shown}';

    // The panel's inset: 16, or the surface inset from 28rem of page.
    final surfaceInset = t.desktop ? 16.0 : 20.0;
    final inset = width >= raftTaskPageNarrowWidth ? surfaceInset : 16.0;
    final board = params.view == TasksPageView.board;

    final toolbar = TasksPageToolbar(
      controller: w,
      tab: tab,
      onTabChange: params.setTab,
      tabCounts: counts.tabs,
      query: params.rawQuery,
      onQueryChange: params.setQuery,
      filters: filters,
      setChannelIds: params.setChannelIds,
      setStatuses: params.setStatuses,
      setCreators: params.setCreators,
      setAssignees: params.setAssignees,
      onClearFilters: params.clearFilters,
      sort: params.sort,
      onSortChange: params.setSort,
      view: params.view,
      onViewChange: params.setView,
      onNewTask: w.server?.string('role') == 'guest' ? null : _newTask,
      sideInset: inset,
    );

    // The body: counts failed / loading / empty / no match / list / board.
    final Widget? message;
    Widget? scrollSliver;
    final searchEmpty = counts.searching && hits == 0;
    if (counts.failed) {
      message = _CountsFailed(onRetry: () => store.retryFailedCounts(plan));
    } else if (counts.shown == null && !counts.searching) {
      message = null;
      scrollSliver = SliverToBoxAdapter(
        child: board ? const _BoardSkeleton() : TasksListSkeleton(tab: tab),
      );
    } else if ((counts.searching ? searchEmpty : counts.shown == 0) &&
        (narrowed || tab == TasksPageTab.all)) {
      message = narrowed
          ? RaftProductEmptyPanel(
              key: const ValueKey('tasks-page-empty'),
              background: t.colors['layer-canvas'],
              titleHeading: true,
              title: raftText(context, 'No tasks match'),
              icon: (context, size, color) =>
                  RaftIcon(RaftGlyph.searchX, size: size, color: color),
            )
          : RaftProductEmptyPanel(
              key: const ValueKey('tasks-page-empty'),
              background: t.colors['layer-canvas'],
              titleHeading: true,
              title: raftText(context, 'No tasks yet'),
              icon: (context, size, color) =>
                  RaftIcon(RaftGlyph.listTodo, size: size, color: color),
            );
    } else if (board) {
      message = null;
      scrollSliver = null;
    } else {
      message = null;
      scrollSliver = TasksListView(
        controller: w,
        store: store,
        tab: tab,
        filters: filters,
        sort: params.sort,
        sections: counts.sections,
        doneSince: doneSince,
        total: counts.shown,
        countCurrent: counts.current,
        selection: selection,
        order: _order,
        currentTaskId: widget.currentTaskId,
        onOpenTask: widget.onOpenTask,
      );
    }

    Widget content;
    if (board && message == null && scrollSliver == null) {
      // Searching, the columns are not counted: each shows what it has read.
      content = counts.columns != null || counts.searching
          ? TasksBoardView(
              controller: w,
              store: store,
              tab: tab,
              filters: filters,
              sort: params.sort,
              columns: counts.columns,
              countCurrent: counts.current,
              selection: selection,
              order: _order,
              currentTaskId: widget.currentTaskId,
              onOpenTask: widget.onOpenTask,
              onMoveSelected: _moveSelected,
            )
          : const SizedBox.shrink();
      content = Column(
        children: [
          toolbar,
          Expanded(child: content),
        ],
      );
    } else if (message != null) {
      content = Column(
        children: [
          toolbar,
          Expanded(child: message),
        ],
      );
    } else {
      final bottom = selected.isNotEmpty ? 96.0 : 0.0;
      final scroller = CustomScrollView(
        key: const ValueKey('tasks-page-scroll'),
        controller: widget.scroll,
        primary: false,
        slivers: [
          if (mobile) PinnedHeaderSliver(child: toolbar),
          SliverPadding(
            // ds-allow: Web page content `px-(--surface-inset) py-4`, `pb-24` under the bar
            padding: EdgeInsets.fromLTRB(inset, 16, inset, 16 + bottom),
            sliver: scrollSliver,
          ),
        ],
      );
      content = Column(
        children: [
          if (!mobile) toolbar,
          Expanded(child: scroller),
        ],
      );
    }

    final header = RaftPageHeader(
      title: raftText(context, 'Tasks'),
      subtitle: number,
      height: raftPageHeaderHeight(context),
      mobile: mobile,
      variant: RaftPanelHeaderVariant.tasks,
    );
    return ColoredBox(
      key: _root,
      color: t.colors['layer-canvas']!,
      child: Column(
        children: [
          header,
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Web row rule 2: the header takes the column width. Its
                // body keeps the readable minimum and fades at the cut.
                final clipped =
                    !mobile && constraints.maxWidth < taskSlotListMin;
                final fade = t.size('css.fade-edge', fallback: RaftSpace.x6);
                final fadeWidth = fade
                    .clamp(0.0, constraints.maxWidth)
                    .toDouble();
                return Stack(
                  children: [
                    Positioned.fill(
                      child: OverflowBox(
                        alignment: AlignmentDirectional.topStart,
                        minWidth: clipped ? taskSlotListMin : null,
                        maxWidth: clipped ? taskSlotListMin : null,
                        child: Stack(
                          children: [
                            Positioned.fill(child: content),
                            if (selected.isNotEmpty)
                              RaftSelectionBarDock(
                                child: TasksSelectionBar(
                                  controller: w,
                                  tasks: selected,
                                  runBatch: _runBatch,
                                  onClear: selection.clear,
                                  onGone: _returnFocus,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (clipped)
                      PositionedDirectional(
                        end: 0,
                        top: 0,
                        bottom: 0,
                        width: fadeWidth,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: AlignmentDirectional.centerStart,
                                end: AlignmentDirectional.centerEnd,
                                colors: [
                                  t.canvas.withValues(alpha: 0),
                                  t.canvas,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The totals could not be read, after the store's retries: said so in place
/// of the groups or the board, with Try again (not an endless skeleton).
class _CountsFailed extends StatelessWidget {
  const _CountsFailed({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => RaftProductEmptyPanel(
    key: const ValueKey('tasks-page-failed'),
    background: RaftTokens.of(context).colors['layer-canvas'],
    titleHeading: true,
    title: raftText(context, 'Tasks didn’t load'),
    icon: (context, size, color) =>
        RaftIcon(RaftGlyph.listTodo, size: size, color: color),
    action: RaftButton(
      key: const ValueKey('tasks-page-failed-retry'),
      uiVariant: RaftButtonVariant.outline,
      uiSize: RaftButtonSize.md,
      label: raftText(context, 'Try again'),
      onPressed: onRetry,
    ),
  );
}

/// The board while the counts load: a few cards.
class _BoardSkeleton extends StatelessWidget {
  const _BoardSkeleton();

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('tasks-page-loading'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    // ds-allow: Web `gap-2` between the loading board's cards
    spacing: 8,
    children: [
      for (var i = 0; i < 4; i++)
        const RaftSkeleton(variant: RaftSkeletonVariant.block, height: 72),
    ],
  );
}
