// The server Tasks page's board (Web v1.24 components/task/tasksPage/
// TasksBoardView.tsx, the TasksPanel BoardColumn it hosts, useTaskBoardDrag.ts
// and raft-ui task-dnd): a column per status, each its server total, its
// cards read a page at a time as the column's end scrolls into view. A card
// dragged to another column changes its status (Backlog asks why first), its
// status chip changes it in place. Cmd/Ctrl- or Shift-click on a card, or any
// click while something is selected, picks it; dragging a selected card while
// several are selected hands the move to the page (`onMoveSelected`).
//
// A pointer drags with a press and a move, a finger with a long press, the
// keyboard with Space on the focused card (task_board_keyboard_drag.dart).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/workspace_controller.dart';
import '../task_content_slot.dart' show TaskSlotRow;
import '../task_status_request.dart';
import '../task_v2_mode.dart' show taskV2StatusOptions;
import 'task_board_keyboard_drag.dart';
import 'task_card_facts.dart';
import 'tasks_page_model.dart';
import 'tasks_page_store.dart';
import 'tasks_selection.dart';

/// What a card dragged by a pointer or a finger carries: the task it is.
@immutable
class _BoardDrag {
  const _BoardDrag(this.taskId);
  final String taskId;
}

/// Where focus goes once the card shows in [status] (a keyboard drop's end).
@immutable
class _FocusRequest {
  const _FocusRequest(this.taskId, this.status);
  final String taskId, status;
}

/// A move into Backlog waiting for its reason: the popover hangs from
/// [anchor] (the column's heading, or the card's status chip).
@immutable
class _BacklogPrompt {
  const _BacklogPrompt(this.taskId, this.anchor, {required this.fromKeyboard});
  final String taskId;
  final GlobalKey anchor;
  final bool fromKeyboard;
}

bool _truthy(Object? value) => value != null && value != '' && value != false;

/// Web `canEditTaskStatus`: any member who can see the task may move it,
/// unless it is read-only (a historical joint task).
bool canEditTaskStatus(Map<String, dynamic> task) =>
    !_truthy(task['readOnlyReason']);

/// Each status the dragged card may move to; its own column takes it back
/// (Web `allowedDropStatuses`).
Set<String> allowedDropStatuses(Map<String, dynamic> task) {
  if (!canEditTaskStatus(task)) return const {};
  return {'${task['status']}', ...taskV2StatusOptions(task, true)};
}

class TasksBoardView extends StatefulWidget {
  const TasksBoardView({
    super.key,
    required this.controller,
    required this.store,
    required this.tab,
    required this.filters,
    required this.sort,
    required this.columns,
    required this.countCurrent,
    required this.selection,
    required this.order,
    required this.currentTaskId,
    required this.onOpenTask,
    required this.onMoveSelected,
  });

  final WorkspaceController controller;
  final TasksPageStore store;
  final TasksPageTab tab;
  final PageFilters filters;
  final ServerTaskSort sort;

  /// Each column's server total; null while searching (a search is not
  /// counted: a column shows what it has read).
  final Map<String, int>? columns;
  final bool countCurrent;
  final TaskSelection selection;

  /// The ids on screen, top to bottom and column by column (a Shift-click's
  /// run).
  final List<String> Function() order;
  final String? currentTaskId;
  final void Function(Map<String, dynamic> task) onOpenTask;

  /// A selected card was dropped on [status] while several are selected: move
  /// them all.
  final void Function(String status) onMoveSelected;

  @override
  State<TasksBoardView> createState() => _TasksBoardViewState();
}

class _TasksBoardViewState extends State<TasksBoardView> {
  final scroll = ScrollController();
  final cards = <String, _BoardCardState>{};

  /// The card a hand has lifted, if any: its column hides it while its copy
  /// follows the hand (Web `useTaskBoardDrag` `activeTaskId`, which
  /// `BoardColumn` filters out of `visibleTasks`).
  final dragging = ValueNotifier<String?>(null);
  final columnKeys = {for (final s in boardStatuses) s: GlobalKey()};
  final backlogHeading = GlobalKey();
  final reasonPanel = GlobalKey<RaftTaskReasonPanelState>();
  late final TaskBoardKeyboardDrag keyboard;
  EdgeDraggingAutoScroller? autoScroller;
  _BacklogPrompt? prompt;
  _FocusRequest? focusRequest;
  bool focusQueued = false;

  TasksPageStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    keyboard = TaskBoardKeyboardDrag(
      centers: columnCenters,
      onPickUp: (id, status) => announce(
        'Picked up task #{number}. Over {place}.',
        id,
        place: status,
      ),
      onOver: keyboardOver,
      onDrop: keyboardDrop,
      onCancel: keyboardCancel,
    );
  }

  @override
  void dispose() {
    keyboard.dispose();
    dragging.dispose();
    scroll.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ the tasks

  Map<String, dynamic>? taskOf(String id) => store.knownById[id];

  bool allowed(String id, String status) {
    final task = taskOf(id);
    return task != null && allowedDropStatuses(task).contains(status);
  }

  String statusLabel(String status) =>
      raftText(context, raftTaskStatusLabel(status));

  /// Why the dragged card can't be dropped on [status] (a historical joint
  /// task, or a status this task doesn't have).
  String blockedReason(Map<String, dynamic> task, String status) {
    if (_truthy(task['readOnlyReason'])) {
      return raftText(
        context,
        'This task was created before other servers connected. Only the host server can change it.',
      );
    }
    return raftFormat(context, "Can't move from {from} to {to}", {
      'from': statusLabel('${task['status']}'),
      'to': statusLabel(status),
    });
  }

  // -------------------------------------------------------- announcements

  /// [text] as a sentence (raft-ui `sentence`): ended with a full stop.
  String sentence(String text) =>
      RegExp(r'[.!?。！？]$').hasMatch(text) ? text : '$text.';

  void say(String text) {
    final view = View.maybeOf(context);
    if (view == null) return;
    unawaited(
      SemanticsService.sendAnnouncement(view, text, Directionality.of(context)),
    );
  }

  /// Says [source] for task [id]: `{number}` the task's number, `{place}` the
  /// column [place] by its name.
  void announce(String source, String id, {String? place, String? reason}) {
    final task = taskOf(id);
    say(
      raftFormat(context, source, {
        'number': task?['taskNumber'] ?? '',
        'place': place == null ? '' : statusLabel(place),
        'reason': reason ?? '',
      }),
    );
  }

  void announceMoved(Map<String, dynamic> task, String status) => say(
    raftFormat(context, 'Task #{taskNumber} moved to {status}', {
      'taskNumber': task['taskNumber'] ?? '',
      'status': statusLabel(status),
    }),
  );

  // ------------------------------------------------------ keyboard drags

  Map<String, double> columnCenters() => {
    for (final status in boardColumns(widget.filters))
      if (columnKeys[status]?.currentContext?.findRenderObject()
          case final RenderBox box when box.attached)
        status: box.localToGlobal(box.size.center(Offset.zero)).dx,
  };

  void keyboardOver(String id, String status) {
    final task = taskOf(id);
    if (task != null && !allowedDropStatuses(task).contains(status)) {
      announce(
        "Task #{number} can't go to {place}. {reason}",
        id,
        place: status,
        reason: sentence(blockedReason(task, status)),
      );
    } else {
      announce('Over {place}.', id, place: status);
    }
    final context = columnKeys[status]?.currentContext;
    if (context != null) {
      unawaited(Scrollable.ensureVisible(context, alignment: .5));
    }
  }

  void keyboardDrop(String id, String status) {
    final task = taskOf(id);
    if (task == null) return;
    if (!allowedDropStatuses(task).contains(status)) {
      announce(
        '{reason} Cancelled. Task #{number} is back in {place}.',
        id,
        place: boardStatusOf(task),
        reason: sentence(blockedReason(task, status)),
      );
      focusAfterDrag(id);
      return;
    }
    announce('Dropped task #{number} in {place}.', id, place: status);
    unawaited(drop(id, status, fromKeyboard: true));
  }

  void keyboardCancel(String id) {
    final task = taskOf(id);
    announce(
      'Cancelled. Task #{number} is back in {place}.',
      id,
      place: task == null ? null : boardStatusOf(task),
    );
    focusAfterDrag(id);
  }

  /// A drag over: focus goes back to the card where it stands (in its column
  /// once a move lands, see [moveTask]).
  void focusAfterDrag(String id) {
    final task = taskOf(id);
    if (task == null) return;
    requestFocus(_FocusRequest(id, '${task['status']}'));
  }

  void requestFocus(_FocusRequest request) {
    focusRequest = request;
    queueFocus();
  }

  /// Waits until the store shows the card in the column it lands in, then
  /// focuses it (Web: a card remounts as it changes column).
  void queueFocus() {
    if (focusQueued || focusRequest == null) return;
    focusQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusQueued = false;
      if (!mounted) return;
      final request = focusRequest;
      if (request == null) return;
      final task = taskOf(request.taskId);
      if (task == null || task['status'] != request.status) return;
      final card = cards[request.taskId];
      if (card == null || !card.mounted) return;
      card.focus.requestFocus();
      unawaited(
        Scrollable.ensureVisible(
          card.context,
          duration: Duration.zero,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ),
      );
      focusRequest = null;
    });
  }

  // ---------------------------------------------------------------- drops

  /// A card was dropped on [status] (Web `onMove` then `handleMove`).
  Future<void> drop(
    String id,
    String status, {
    bool fromKeyboard = false,
  }) async {
    final task = taskOf(id);
    if (task == null || !allowedDropStatuses(task).contains(status)) {
      return;
    }
    final selection = widget.selection;
    if (selection.selected.length > 1 && selection.isSelected(id)) {
      widget.onMoveSelected(status);
      if (fromKeyboard) focusAfterDrag(id);
      return;
    }
    if (task['status'] == status) {
      if (fromKeyboard) focusAfterDrag(id);
      return;
    }
    if (status == 'backlog') {
      askBacklogReason(id, backlogHeading, fromKeyboard: fromKeyboard);
      return;
    }
    if (fromKeyboard) focusAfterDrag(id);
    final moved = await moveTask(task, status);
    if (moved && fromKeyboard && mounted) {
      requestFocus(_FocusRequest(id, status));
    }
  }

  /// The status chip of a card: the same move, from where it is.
  Future<void> chipStatus(Map<String, dynamic> task, String next) async {
    if (next == task['status']) return;
    if (next == 'backlog') {
      final anchor = cards['${task['id']}']?.anchor;
      if (anchor != null) {
        askBacklogReason('${task['id']}', anchor, fromKeyboard: false);
      }
      return;
    }
    await moveTask(task, next);
  }

  /// The write of [taskStatusRequest] (a todo task nobody holds moving to In
  /// progress is the claim), its answer applied to the store at once. A
  /// failure is a toast, unless [toast] is false and the caller says it.
  Future<bool> moveTask(
    Map<String, dynamic> task,
    String status, {
    String reason = '',
    bool toast = true,
  }) async {
    final request = taskStatusRequest(task, status, reason: reason);
    try {
      final data = await widget.controller.client.request(
        'PATCH',
        request.path,
        data: request.data,
      );
      if (data is Map && data['task'] is Map) {
        store.applyWritten(Map<String, dynamic>.from(data['task'] as Map));
      }
      if (mounted) announceMoved(task, status);
      return true;
    } catch (error) {
      if (toast && mounted) {
        showRaftErrorToast(
          context,
          error,
          fallback: "Couldn't move the task. Try again.",
        );
      }
      return false;
    }
  }

  void askBacklogReason(
    String id,
    GlobalKey anchor, {
    required bool fromKeyboard,
  }) {
    setState(
      () => prompt = _BacklogPrompt(id, anchor, fromKeyboard: fromKeyboard),
    );
  }

  void closeBacklogReason({required bool moved}) {
    final closing = prompt;
    if (closing == null) return;
    setState(() => prompt = null);
    if (!closing.fromKeyboard) return;
    final task = taskOf(closing.taskId);
    if (task == null) return;
    requestFocus(
      _FocusRequest(closing.taskId, moved ? 'backlog' : '${task['status']}'),
    );
  }

  Future<bool> submitBacklogReason(String reason) async {
    final id = prompt?.taskId;
    final task = id == null ? null : taskOf(id);
    if (task == null) return false;
    final moved = await moveTask(task, 'backlog', reason: reason, toast: false);
    // The popover shows the failure under its field.
    if (moved && mounted) closeBacklogReason(moved: true);
    return moved;
  }

  // --------------------------------------------------------------- clicks

  void tapCard(Map<String, dynamic> task) {
    if (keyboard.active) return;
    final keys = HardwareKeyboard.instance;
    final range = keys.isShiftPressed;
    final modified = keys.isMetaPressed || keys.isControlPressed || range;
    if (widget.selection.selecting || modified) {
      final id = '${task['id']}';
      widget.selection.select(id, range: range, order: widget.order());
      return;
    }
    widget.onOpenTask(task);
  }

  // ----------------------------------------------------------- autoscroll

  void dragUpdate(DragUpdateDetails details) {
    final context = columnKeys.values.first.currentContext;
    if (context == null) return;
    final scrollable = Scrollable.maybeOf(context, axis: Axis.horizontal);
    final box = scrollable?.context.findRenderObject();
    if (scrollable == null || box is! RenderBox || !box.attached) return;
    final scroller = autoScroller?.scrollable == scrollable
        ? autoScroller!
        : autoScroller = EdgeDraggingAutoScroller(
            scrollable,
            velocityScalar: 7,
          );
    final at = box.globalToLocal(details.globalPosition);
    // The board scrolls while the hand is within half of this of its edge.
    final reach = box.size.width < 96 ? box.size.width : 96.0;
    scroller.startAutoScrollIfNecessary(
      Rect.fromCenter(center: at, width: reach, height: 8),
    );
  }

  void dragEnd() {
    autoScroller?.stopAutoScroll();
    dragging.value = null;
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final inline =
        MediaQuery.sizeOf(context).width < RaftLayoutMetrics.desktopBreakpoint
        ? 16.0
        : t.size('space.tasksViewportInline', fallback: 20);
    final p = prompt;
    final promptTask = p == null ? null : taskOf(p.taskId);
    if (focusRequest != null) queueFocus();
    return Stack(
      fit: StackFit.passthrough,
      children: [
        ListenableBuilder(
          listenable: Listenable.merge([
            store,
            widget.selection,
            keyboard,
            dragging,
          ]),
          builder: (context, _) {
            // The card may have landed in its column with this change.
            queueFocus();
            return SingleChildScrollView(
              controller: scroll,
              primary: false,
              scrollDirection: Axis.horizontal,
              padding: raftScrollPadding(
                context,
                // ds-allow: Web VIEWPORT_CONTENT_CLASS `px-(--surface-inset) py-4 @max-md/tasks:px-4`
                EdgeInsets.symmetric(horizontal: inline, vertical: 16),
              ),
              child: Row(
                key: const ValueKey('tasks-page-board'),
                crossAxisAlignment: CrossAxisAlignment.start,
                // ds-allow: Web TaskBoardRoot `gap-4`
                spacing: 16,
                children: [
                  for (final status in boardColumns(widget.filters))
                    _StatusColumn(
                      key: ValueKey('task-board-column-$status'),
                      board: this,
                      status: status,
                    ),
                ],
              ),
            );
          },
        ),
        if (p != null)
          RaftTaskReasonPopover(
            // Someone else may park the task meanwhile: nothing left to ask.
            open: promptTask != null && promptTask['status'] != 'backlog',
            anchorKey: p.anchor,
            panelKey: reasonPanel,
            onSubmit: submitBacklogReason,
            onDismiss: () => closeBacklogReason(moved: false),
            child: const SizedBox.shrink(),
          ),
      ],
    );
  }
}

/// One status column: its heading, its cards, its drop zone.
class _StatusColumn extends StatefulWidget {
  const _StatusColumn({super.key, required this.board, required this.status});
  final _TasksBoardViewState board;
  final String status;

  @override
  State<_StatusColumn> createState() => _StatusColumnState();
}

class _StatusColumnState extends State<_StatusColumn> {
  bool settleQueued = false;

  _TasksBoardViewState get board => widget.board;
  TasksPageStore get store => board.store;

  /// What the lanes need to show the truth, after every change (Web
  /// `useMergedTasksLanes`'s effect).
  void queueSettle(List<LaneSpec> lanes, int? count, bool folded) {
    if (settleQueued) return;
    settleQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      settleQueued = false;
      if (mounted) store.settleLanes(lanes, count: count, folded: folded);
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = board.widget, status = widget.status;
    final folded = boardColumnFolded(status, w.filters, store.collapsed);
    final lanes = boardColumnLanes(w.tab, w.filters, status, w.sort);
    final total = w.columns?[status];
    final view = store.laneView(lanes);
    queueSettle(lanes, w.countCurrent ? total : null, folded);
    final empty = total != null && total == 0;
    final hasMore = (total == null || total > 0) && view.hasMore;
    final pendingFirstPage =
        (total == null || total > 0) && !view.loaded && !view.failed;
    final keyboardOver = board.keyboard.over == status;
    return KeyedSubtree(
      key: board.columnKeys[status],
      child: DragTarget<_BoardDrag>(
        key: ValueKey('task-drop-$status'),
        onWillAcceptWithDetails: (details) =>
            board.allowed(details.data.taskId, status),
        onAcceptWithDetails: (details) =>
            unawaited(board.drop(details.data.taskId, status)),
        builder: (context, candidates, rejected) {
          final hoveredId =
              candidates.firstOrNull?.taskId ??
              rejected.firstOrNull?.taskId ??
              (keyboardOver ? board.keyboard.taskId : null);
          final hovered = hoveredId == null ? null : board.taskOf(hoveredId);
          final canDrop = hovered != null && board.allowed(hoveredId!, status);
          return RaftTaskBoardColumn(
            status: status,
            count: '${total ?? view.tasks.length}',
            collapsed: folded,
            dropActive: canDrop,
            dropBlockedLabel: hovered != null && !canDrop
                ? board.blockedReason(hovered, status)
                : null,
            triggerKey: status == 'backlog'
                ? board.backlogHeading
                : ValueKey('task-board-column-trigger-$status'),
            onToggle: () {
              // Unfolded by hand, a column never read reads its first page at
              // once: a folded column is no lane of the view, so nothing has
              // read it (Web `toggleColumn`).
              if (folded && !view.loaded && !view.loading && !view.failed) {
                store.loadMore(lanes);
              }
              store.setCollapsed(boardFoldKey(status), !folded);
            },
            body: _ColumnBody(
              board: board,
              status: status,
              lanes: lanes,
              view: view,
              hasMore: hasMore && !empty,
              pendingFirstPage: pendingFirstPage,
            ),
          );
        },
      ),
    );
  }
}

class _ColumnBody extends StatelessWidget {
  const _ColumnBody({
    required this.board,
    required this.status,
    required this.lanes,
    required this.view,
    required this.hasMore,
    required this.pendingFirstPage,
  });
  final _TasksBoardViewState board;
  final String status;
  final List<LaneSpec> lanes;
  final LaneView view;
  final bool hasMore, pendingFirstPage;

  @override
  Widget build(BuildContext context) {
    final tasks = view.tasks;
    final skeleton = view.loading || pendingFirstPage;
    final indices = {
      for (final (index, task) in tasks.indexed)
        'task-board-draggable-${task['id']}': index,
    };
    final items = <Widget Function(BuildContext)>[
      if (tasks.isEmpty)
        (context) => skeleton
            ? const RaftTaskCardSkeleton(
                key: ValueKey('task-board-card-skeleton'),
              )
            : RaftTaskLaneEmpty(
                board: true,
                label: raftFormat(context, 'No {status} tasks', {
                  'status': raftText(context, raftTaskStatusLabel(status)),
                }),
              )
      else ...[
        for (final task in tasks)
          (context) => _BoardCard(
            key: ValueKey('task-board-draggable-${task['id']}'),
            board: board,
            task: task,
          ),
        if (skeleton)
          (context) => const RaftTaskCardSkeleton(
            key: ValueKey('task-board-card-skeleton'),
          ),
      ],
      if (hasMore)
        (context) => _LoadMoreEnd(
          key: ValueKey('task-load-more-$status'),
          loading: view.loading,
          failed: view.failed,
          onLoadMore: () => board.store.loadMore(lanes),
        ),
    ];
    // The lifted card is no item of the column: its gap goes with it (the
    // one after it, or the one before it when it was the last).
    final lifted = indices['task-board-draggable-${board.dragging.value}'];
    return ListView.separated(
      key: PageStorageKey(('task-board-lane', status)),
      primary: false,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, index) =>
          lifted != null &&
              (index == lifted ||
                  (index == lifted - 1 && lifted == items.length - 1))
          ? const SizedBox.shrink()
          // ds-allow: Web BoardColumn `TaskBoardColumnItems` `gap-2`
          : const SizedBox(height: 8),
      findItemIndexCallback: (key) =>
          key is ValueKey<String> ? indices[key.value] : null,
      itemBuilder: (context, index) => items[index](context),
    );
  }
}

/// The end of a column: reaching it (built, within a screenful's margin of
/// the view) reads the next page; the read starts over after every page, so
/// a short page that leaves the end in view reads on. After a failed read it
/// waits for a press (Web `LoadMoreSentinel`).
class _LoadMoreEnd extends StatefulWidget {
  const _LoadMoreEnd({
    super.key,
    required this.loading,
    required this.failed,
    required this.onLoadMore,
  });
  final bool loading, failed;
  final VoidCallback onLoadMore;

  @override
  State<_LoadMoreEnd> createState() => _LoadMoreEndState();
}

class _LoadMoreEndState extends State<_LoadMoreEnd> {
  @override
  void initState() {
    super.initState();
    read();
  }

  @override
  void didUpdateWidget(_LoadMoreEnd old) {
    super.didUpdateWidget(old);
    if (old.loading != widget.loading || old.failed != widget.failed) read();
  }

  void read() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && !widget.loading && !widget.failed) widget.onLoadMore();
  });

  @override
  Widget build(BuildContext context) {
    if (widget.failed) {
      return RaftButton(
        label: 'Try again',
        uiVariant: RaftButtonVariant.outline,
        uiSize: RaftButtonSize.md,
        expand: true,
        onPressed: widget.onLoadMore,
      );
    }
    // ds-allow: Web LoadMoreSentinel `h-px w-full` (2px: the spacing grid has no 1)
    return const SizedBox(height: 2, width: double.infinity);
  }
}

/// A task card on the board: the card, its drag, and its keyboard stop (Web
/// `BoardTaskItem` / `TaskDraggable`: a draggable that is a tab stop of its
/// own beside the card's open button).
class _BoardCard extends StatefulWidget {
  const _BoardCard({super.key, required this.board, required this.task});
  final _TasksBoardViewState board;
  final Map<String, dynamic> task;

  @override
  State<_BoardCard> createState() => _BoardCardState();
}

class _BoardCardState extends State<_BoardCard> {
  final focus = FocusNode(debugLabel: 'task board card');
  final anchor = GlobalKey();

  String get id => '${widget.task['id']}';

  @override
  void initState() {
    super.initState();
    widget.board.cards[id] = this;
    focus.addListener(focusChanged);
  }

  @override
  void didUpdateWidget(_BoardCard old) {
    super.didUpdateWidget(old);
    widget.board.cards[id] = this;
  }

  @override
  void dispose() {
    focus.removeListener(focusChanged);
    final cards = widget.board.cards;
    if (identical(cards[id], this)) cards.remove(id);
    focus.dispose();
    super.dispose();
  }

  /// A drag by keyboard ends where focus leaves its card.
  void focusChanged() {
    final keyboard = widget.board.keyboard;
    if (!focus.hasFocus && keyboard.taskId == id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => keyboard.cancel());
    }
  }

  RaftTaskCard card(
    BuildContext context, {
    required bool interactive,
    required Map<String, dynamic> task,
  }) {
    final board = widget.board, w = board.widget;
    final taskId = '${task['id']}';
    final editable = canEditTaskStatus(task);
    return RaftTaskCard(
      key: interactive ? ValueKey('task-board-card-$taskId') : null,
      title: '${task['title'] ?? ''}',
      number: '${task['taskNumber'] ?? ''}',
      channel: _truthy(task['channelName'])
          ? '${task['channelName']}'
          : raftTextZh(context, 'unknown', '未知'),
      description: '${task['description'] ?? task['descriptionPreview'] ?? ''}',
      status: '${task['status']}',
      legacy: task['isLegacy'] == true,
      selected: w.selection.isSelected(taskId),
      current: w.currentTaskId == taskId,
      onTap: interactive ? () => board.tapCard(task) : null,
      // The lifted copy shows the editable chip too (Web's overlay card).
      statusOptions: editable ? taskV2StatusOptions(task, true) : const [],
      onStatus: editable
          ? interactive
                ? (next) => unawaited(board.chipStatus(task, next))
                : (_) {}
          : null,
      titleEnd: taskCardReplies(w.controller, task),
      footerEnd: TaskCardFacts(controller: w.controller, task: task),
    );
  }

  @override
  Widget build(BuildContext context) {
    final board = widget.board, task = widget.task;
    final touch = RaftInteraction.of(context).mode == RaftInputMode.touch;
    final content = TaskSlotRow(
      taskId: id,
      child: card(context, interactive: true, task: task),
    );
    final payload = _BoardDrag(id);
    return Focus(
      key: ValueKey('task-board-focus-$id'),
      focusNode: focus,
      onKeyEvent: (node, event) => node.hasPrimaryFocus
          ? board.keyboard.handle(id, boardStatusOf(task), event)
          : KeyEventResult.ignored,
      child: Semantics(
        container: true,
        focusable: true,
        hint: raftText(
          context,
          'To pick up an item, press Space. Use the arrow keys to move it, Space to drop it, Escape to cancel.',
        ),
        child: KeyedSubtree(
          key: anchor,
          child: LayoutBuilder(
            builder: (context, box) {
              final feedback = RaftTaskDragFeedback(
                width: box.maxWidth,
                child: card(
                  context,
                  interactive: false,
                  task: board.taskOf(id) ?? task,
                ),
              );
              // Web hides the lifted card in its column: its copy is the card.
              const gone = SizedBox.shrink(
                key: ValueKey('task-board-card-lifted'),
              );
              return touch
                  ? LongPressDraggable<_BoardDrag>(
                      data: payload,
                      maxSimultaneousDrags: 1,
                      feedback: feedback,
                      childWhenDragging: gone,
                      onDragStarted: () => board.dragging.value = id,
                      onDragUpdate: board.dragUpdate,
                      onDragEnd: (_) => board.dragEnd(),
                      onDraggableCanceled: (_, _) => board.dragEnd(),
                      child: content,
                    )
                  : Draggable<_BoardDrag>(
                      data: payload,
                      maxSimultaneousDrags: 1,
                      feedback: feedback,
                      childWhenDragging: gone,
                      onDragStarted: () => board.dragging.value = id,
                      onDragUpdate: board.dragUpdate,
                      onDragEnd: (_) => board.dragEnd(),
                      onDraggableCanceled: (_, _) => board.dragEnd(),
                      child: content,
                    );
            },
          ),
        ),
      ),
    );
  }
}
