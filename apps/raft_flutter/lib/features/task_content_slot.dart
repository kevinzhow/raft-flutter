// Web v1.24 TaskContentSlot (components/layout/TaskContentSlot.tsx) and the
// Tasks page's open (components/task/tasksPage/tasksPageOpen.ts): a task
// conversation opened from a row of the Tasks page, an Activity row or a
// Search hit shows in place beside the list (`?open=task:<taskId>` beside
// `?task=<channelId>:task:<taskId>`), the dialog's frameless page; Escape and
// its × close it and focus goes back to the task's row. On a phone it is the
// task's page in place of the list, its Back returning to it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart';
import '../data/raft_navigation_history.dart';
import '../data/workspace_controller.dart';
import 'page_layout.dart';
import 'panel_width_store.dart';
import 'message_task_actions.dart' show TaskV2ConversationsFlag;
import 'task_v2_mode.dart';

/// The routes whose list a task opens beside (Web TasksRoute, InboxContentRoute,
/// SearchContentRoute).
const taskSlotRoutes = {RaftRoute.tasks, RaftRoute.activity, RaftRoute.search};

/// Web `COLUMN_BOUNDS.detail`: the task's column beside the Tasks list, 400 by
/// default, remembered; the list keeps [taskSlotListMin] beside it.
const taskSlotWidth = PanelWidthStore(
  'raft.layout.taskSlotWidth',
  320,
  8192,
  400,
);
const taskSlotListMin = 360.0;

/// The task id of the slot [location] shows, when its `?task=` names it.
String? taskSlotId(RaftLocation location) {
  final content = location.content, task = location.task;
  if (content?.kind != RaftContentKind.task || task == null) return null;
  if (!taskSlotRoutes.contains(location.route)) return null;
  return taskIdOfTaskItem(task.itemId) == content!.id ? content.id : null;
}

/// Whether [row] opens beside the list on this route (Web
/// useOpenTaskOnTasksPage / openTaskConversationRow / a task hit): a task with
/// its own conversation, not a legacy or message-keyed one, on a desktop. The
/// Tasks page has the slot with task v2 only (off, it is the status board,
/// whose tasks open as the dialog: TasksRoute).
bool opensInTaskSlot(
  WorkspaceController w,
  Map<String, dynamic> row, {
  required bool wide,
}) {
  final route = w.location.route;
  final v2 = TaskV2ConversationsFlag.of(w).enabled;
  return wide &&
      taskSlotRoutes.contains(route) &&
      (route != RaftRoute.tasks || v2) &&
      row['id'] is String &&
      taskSurfaceItemId(row, v2) == '$taskConversationItemPrefix${row['id']}';
}

/// Where a task opened from [row] starts: beside the list when it came from
/// a list ([fromList]: the Tasks page's board) or from the task already
/// beside it (a task reference: the slot follows it), else over the current
/// location.
RaftLocation taskOpenLocation(
  WorkspaceController w,
  Map<String, dynamic> row,
  bool fromList,
  bool wide,
) =>
    (fromList || taskSlotId(w.location) != null) &&
        opensInTaskSlot(w, row, wide: wide)
    ? taskSlotLocation(w.location, row)
    : w.location;

/// What the workspace task host lends the slot: the task it owns and how to
/// close it. Null [surface] while there is no task to show.
class TaskSlotScope extends InheritedWidget {
  const TaskSlotScope({
    super.key,
    required this.taskId,
    required this.surface,
    required this.onClose,
    required super.child,
  });

  /// The task the slot shows; null when no slot is open.
  final String? taskId;
  final Widget Function(VoidCallback onClose)? surface;
  final VoidCallback onClose;

  static TaskSlotScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TaskSlotScope>();

  @override
  bool updateShouldNotify(TaskSlotScope old) =>
      old.taskId != taskId || old.surface != surface || old.onClose != onClose;
}

/// The task beside the list. Escape inside it (not a field's, nor a menu's:
/// those take their own) closes it, as its × does.
class TaskContentSlot extends StatelessWidget {
  const TaskContentSlot({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = TaskSlotScope.maybeOf(context);
    final taskId = scope?.taskId;
    if (scope == null || taskId == null) return const SizedBox.expand();
    void close() {
      scope.onClose();
      focusTaskSlotRow(taskId);
    }

    final surface = scope.surface;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent ||
            event.logicalKey != LogicalKeyboardKey.escape) {
          return KeyEventResult.ignored;
        }
        final focused = FocusManager.instance.primaryFocus?.context;
        // A field's Escape (the composer's, an input method's) is its own.
        if (focused == null ||
            focused.widget is EditableText ||
            focused.findAncestorWidgetOfExactType<EditableText>() != null) {
          return KeyEventResult.ignored;
        }
        close();
        return KeyEventResult.handled;
      },
      child: KeyedSubtree(
        key: const ValueKey('task-content-slot'),
        child: surface == null
            ? _TaskUnavailable(onClose: close)
            : surface(close),
      ),
    );
  }
}

/// Web TaskContentSlot's unavailable state: the task closed from inside
/// (deleted) or is not one this account can open.
class _TaskUnavailable extends StatelessWidget {
  const _TaskUnavailable({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      RaftPageHeader(
        title: raftText(context, 'Task'),
        height: raftPageHeaderHeight(context),
        actions: [
          RaftIconButton(
            key: const ValueKey('activity-task-gone-close'),
            glyph: RaftGlyph.x,
            tooltip: 'Close task',
            onPressed: onClose,
          ),
        ],
      ),
      Expanded(
        child: RaftEmptyState(
          key: const ValueKey('activity-task-gone'),
          title: raftText(context, "This task isn't available"),
          detail: '',
        ),
      ),
    ],
  );
}

/// The rows a task opens from, by task id, so closing the task can put focus
/// back on its row (Web focusTasksPageRowAfterClose: the row's button).
final _rows = <String, FocusNode>{};

/// Marks [child] as the row of task [taskId].
class TaskSlotRow extends StatefulWidget {
  const TaskSlotRow({super.key, required this.taskId, required this.child});
  final Object? taskId;
  final Widget child;

  @override
  State<TaskSlotRow> createState() => _TaskSlotRowState();
}

class _TaskSlotRowState extends State<TaskSlotRow> {
  final node = FocusNode(
    debugLabel: 'task slot row',
    canRequestFocus: false,
    skipTraversal: true,
  );
  String? registered;

  void register() {
    final id = widget.taskId;
    if (registered == id) return;
    if (_rows[registered] == node) _rows.remove(registered);
    registered = id is String ? id : null;
    if (registered != null) _rows[registered!] = node;
  }

  @override
  void didUpdateWidget(TaskSlotRow old) {
    super.didUpdateWidget(old);
    register();
  }

  @override
  void dispose() {
    if (_rows[registered] == node) _rows.remove(registered);
    node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    register();
    return Focus(focusNode: node, child: widget.child);
  }
}

/// After the slot has left the tree: focus the row's first control.
void focusTaskSlotRow(String taskId) =>
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _rows[taskId];
      if (row == null || row.context == null) return;
      row.descendants
          .where((n) => n.canRequestFocus && !n.skipTraversal)
          .firstOrNull
          ?.requestFocus();
    });

/// The location that opens [row]'s task beside the list.
RaftLocation taskSlotLocation(RaftLocation at, Map<String, dynamic> row) =>
    at.withQuery({
      'open': 'task:${row['id']}',
      'msg': null,
      'thread': null,
      'profile': null,
      'legacyTask': null,
    });

/// Whether opening [next] from [previous] replaces the entry (another task in
/// the open slot) rather than pushing one.
RaftNavigationKind taskSlotNavigationKind(RaftLocation previous) =>
    taskSlotId(previous) != null
    ? RaftNavigationKind.replace
    : RaftNavigationKind.push;

/// Web openTaskConversationRow (an Activity task row: served `kind: task`)
/// and a Search task hit (`channelType: task`): the task opens in the list's
/// detail slot, on a phone its page over the list. False for any other row.
bool openTaskFromList(
  WorkspaceController w,
  Map<String, dynamic> row, {
  required bool wide,
}) {
  final taskId = row['taskId'], channelId = row['parentChannelId'];
  final task =
      row['kind'] == 'task' ||
      row['conversationKind'] == 'task' ||
      row['channelType'] == 'task';
  if (!task || taskId is! String || channelId is! String) return false;
  final at = w.location;
  final base = wide
      ? taskSlotLocation(at, {'id': taskId})
      : at.withQuery({'thread': null, 'profile': null, 'legacyTask': null});
  w.closeThread(navigate: false);
  w.navigation.navigateTask(
    base.withQuery({'task': '$channelId:$taskConversationItemPrefix$taskId'}),
    kind: taskSlotNavigationKind(at),
  );
  w.notifyListeners();
  return true;
}
