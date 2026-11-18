import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/device_preferences.dart';
import '../data/raft_navigation_history.dart';
import '../data/raft_location.dart';
import '../data/workspace_controller.dart';
import '../data/message_task_cache.dart';
import '../data/phone_stack.dart' show taskSlotRemoval;
import '../data/source_task_bucket.dart';
import '../platform/system_bars.dart';
import 'chat_view.dart' show ChatTaskOpener;
import 'route_transition_gate.dart';
import 'task_content_slot.dart';
import 'task_surface.dart';
import 'task_surface_controller.dart';
import 'task_v2_mode.dart';
import 'task_view_in_thread.dart';
import 'mobile_workspace_pages.dart';

export 'task_content_slot.dart' show TaskContentSlot, taskOpenLocation;

/// Accepted task-card facts are tied to the authority that supplied the row.
class TaskSurfaceSeed {
  TaskSurfaceSeed(this.row, this.authority, this.onMutationAccepted);
  final Map<String, dynamic> row;
  final String authority;
  final Future<void> Function()? onMutationAccepted;
}

String taskSurfaceAuthority(WorkspaceController w, String channelId) {
  final channel = [
    ...w.channels,
    ...w.dms,
  ].where((c) => c.id == channelId).firstOrNull;
  return jsonEncode([
    w.navigationAuthority,
    channel?.id,
    channel?.joined,
    channel?.archived,
    channel?.json['channelCapabilities'],
    channel == null ? null : w.can('viewChannel', resource: channel),
    w.can('assignTasks'),
    w.can('deleteAnyTask'),
  ]);
}

/// One task owner follows the accepted URI. Mobile projects it as a page;
/// desktop retains MainLayout's modal/docked presentation. The workspace stays
/// mounted through open, hydration, retarget and close.
class WorkspaceTaskHost extends StatefulWidget {
  const WorkspaceTaskHost({
    super.key,
    required this.controller,
    required this.childBuilder,
    required this.onTask,
    required this.onViewBilling,
    this.leadingExtent = 0,
    this.leadingOnRight = false,
    this.seed,
    this.presented = true,
  });
  final WorkspaceController controller;
  final Widget Function(double legacyDockWidth, VoidCallback? onLegacyEscape)
  childBuilder;

  /// The discussion's task references and plan banner act on the host
  /// workspace: another task replaces this one, billing leaves the modal.
  final ChatTaskOpener? onTask;
  final VoidCallback? onViewBilling;
  final double leadingExtent;

  /// The [leadingExtent] column (rail and sidebar) sits on the right edge: the
  /// side surface keeps clear of it there.
  final bool leadingOnRight;
  final TaskSurfaceSeed? seed;

  /// MainLayout1394 suppresses global task presentation in active workspace.
  /// The separate task identity and request owner survive that layout change.
  final bool presented;
  @override
  State<WorkspaceTaskHost> createState() => _WorkspaceTaskHostState();
}

class _WorkspaceTaskHostState extends State<WorkspaceTaskHost> {
  TaskSurfaceController? owner;
  String? identity;
  bool legacy = false;
  double legacyWidth = 380;
  int widthRevision = 0;
  static const widthPreference = 'slock:legacyTaskPanelWidth';
  WorkspaceController get w => widget.controller;

  @override
  void initState() {
    super.initState();
    synchronize();
    // The preloaded width is used by the first frame; an unloaded store
    // falls back to one asynchronous read.
    final loaded = DevicePreferences.current;
    if (loaded != null) {
      legacyWidth = savedWidth(loaded) ?? legacyWidth;
    } else {
      unawaited(loadWidth());
    }
  }

  double? savedWidth(SharedPreferences prefs) {
    final stored = prefs.get(widthPreference);
    final saved = stored is num
        ? stored.toDouble()
        : stored is String
        ? double.tryParse(stored)
        : null;
    return saved == null || !saved.isFinite || saved < 320 || saved > 560
        ? null
        : saved;
  }

  Future<void> loadWidth() async {
    final revision = widthRevision;
    final prefs = await SharedPreferences.getInstance();
    final saved = savedWidth(prefs);
    if (!mounted || revision != widthRevision || saved == null) return;
    setState(() => legacyWidth = saved);
  }

  void resizeLegacy(double value) {
    if (identity != currentIdentity) return;
    final accepted = value.clamp(320.0, 560.0);
    ++widthRevision;
    setState(() => legacyWidth = accepted);
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setDouble(widthPreference, accepted),
      ),
    );
  }

  @override
  void didUpdateWidget(WorkspaceTaskHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    synchronize();
  }

  String? get currentIdentity {
    if (w.client.user == null || w.server?.id != w.client.serverId) return null;
    final anchor = w.location.task ?? w.location.legacyTask;
    if (anchor == null) return null;
    return jsonEncode([
      identityHashCode(w),
      taskSurfaceAuthority(w, anchor.channelId),
      w.navigation.taskRevision,
      w.location.task != null ? 'modern' : 'legacy',
      anchor.channelId,
      anchor.itemId,
      w.location.taskFocusedMessageId,
      w.location.taskFocusedConversationId,
    ]);
  }

  void synchronize() {
    final next = currentIdentity;
    if (next == identity) return;
    identity = next;
    owner?.dispose();
    owner = null;
    if (next == null) return;
    final anchor = w.location.task ?? w.location.legacyTask!;
    legacy = w.location.task == null;
    // `task=<channel>:task:<id>`: keyed by the task (its own conversation).
    final taskId = legacy ? null : taskIdOfTaskItem(anchor.itemId);
    bool matches(Map row) => legacy
        ? row['id'] == anchor.itemId && row['isLegacy'] == true
        : taskId != null
        ? row['id'] == taskId && row['isLegacy'] != true
        : row['messageId'] == anchor.itemId && row['isLegacy'] != true;
    final sourceScope = taskSurfaceAuthority(w, anchor.channelId);
    final knownChannel = [
      ...w.channels,
      ...w.dms,
    ].where((c) => c.id == anchor.channelId).firstOrNull;
    if (!w.can('viewChannel')) return;
    if (knownChannel != null && !w.can('viewChannel', resource: knownChannel)) {
      return;
    }
    final seed = widget.seed;
    final seeded =
        seed?.authority == sourceScope &&
        seed?.row['channelId'] == anchor.channelId &&
        matches(seed!.row);
    // A task URL for a task whose message chip is already known (the channel's
    // accepted task bucket) shows it at the first frame like a seeded row; the
    // full read then revalidates it in place.
    final bucket = seeded || legacy || knownChannel == null
        ? null
        : MessageTaskCache.of(w.client).tasks(w, anchor.channelId);
    final known = taskId == null
        ? (bucket?[anchor.itemId])
        : bucket?.values.where(matches).firstOrNull;
    final accepted = seeded
        ? seed.row
        : known == null
        ? null
        : <String, dynamic>{...known};
    owner = TaskSurfaceController(
      parent: w,
      hydrateParent: !legacy && knownChannel == null,
      taskKeyed: taskId != null,
      focusedMessageId: w.location.taskFocusedMessageId,
      focusedConversationId: w.location.taskFocusedConversationId,
      row:
          accepted ??
          {
            'channelId': anchor.channelId,
            if (legacy)
              'isLegacy': true
            else if (taskId == null)
              'messageId': anchor.itemId,
          },
      valid: () => mounted && next == currentIdentity,
      onMutationAccepted: seeded ? seed.onMutationAccepted : null,
      resolveTask: accepted != null
          ? null
          : (realParent) async {
              // Source loadTasks is the actual channel bucket, including DM
              // and legacy tasks. A URL gives no honest task-number lookup.
              final response = await readSourceTaskBucket(
                w,
                anchor.channelId,
                parentMetadata: realParent,
              );
              final rows = response['tasks'] as List;
              for (final row in rows.whereType<Map>()) {
                if (row['channelId'] != anchor.channelId ||
                    row['id'] is! String ||
                    '${row['id']}'.isEmpty ||
                    row['title'] is! String ||
                    row['taskNumber'] is! int ||
                    !raftTaskStatusVocabulary.contains(row['status'])) {
                  continue;
                }
                if (matches(row)) return Map<String, dynamic>.from(row);
              }
              return null;
            },
    );
    unawaited(owner!.start());
  }

  void close() {
    if (identity != currentIdentity) return;
    w.navigation.navigateTask(
      w.location.withQuery({
        legacy ? 'legacyTask' : 'task': null,
        // A task beside the list: its slot closes with it.
        ...taskSlotRemoval(w.location),
      }),
      kind: RaftNavigationKind.replace,
    );
    w.notifyListeners();
  }

  /// Web TaskModalBar "View in thread" (null while the task has no thread).
  VoidCallback? viewInThread(TaskSurfaceController? task) {
    // Web MainLayout `canViewInThread`: not for a task on its own
    // conversation (its `messageId` is only its id).
    if (task == null ||
        legacy ||
        task.conversation ||
        !taskHasThreadToView(w, task.task)) {
      return null;
    }
    return () {
      if (identity != currentIdentity) return;
      unawaited(
        viewTaskInThread(
          w,
          task.task,
          compact: RaftAdaptiveWorkspace.compactOf(context),
          closeTask: close,
        ),
      );
    };
  }

  void back() {
    if (identity != currentIdentity) return;
    if (RaftAdaptiveWorkspace.compactOf(context)) {
      backMobilePage(w.navigation);
    } else {
      w.navigation.back();
    }
    w.notifyListeners();
  }

  @override
  void dispose() {
    owner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => QuietListenableBuilder(
    listenable: owner ?? w,
    builder: (context, _) => layout(context, owner),
  );

  Widget layout(BuildContext context, TaskSurfaceController? task) {
    final viewport = MediaQuery.sizeOf(context);
    final tasksRoute = w.location.route == RaftRoute.tasks;
    // MainLayout1377–1417 handles content routes and base thread/profile before
    // legacy. A hidden legacy owner keeps its identity and acceptance fences.
    final legacyVisible =
        !legacy ||
        (task?.hydrated == true &&
            ![
              RaftRoute.search,
              RaftRoute.activity,
            ].contains(w.location.route) &&
            w.location.thread == null &&
            w.location.profile == null);
    final mobilePage = RaftAdaptiveWorkspace.compactOf(context);
    final pageColor = legacy
        ? RaftTokens.of(context).canvas
        : RaftTokens.of(context).panel;
    final visible =
        widget.presented && task != null && (mobilePage || legacyVisible);
    if (mobilePage) {
      // This subtree is the active MaterialPage's body. Keep the underlying
      // workspace mounted (drafts/list state), but remove it from layout, focus
      // and semantics while the task page is presented.
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Offstage(
              offstage: visible,
              child: ExcludeFocus(
                excluding: visible,
                child: TickerMode(
                  enabled: !visible,
                  child: widget.childBuilder(0, null),
                ),
              ),
            ),
          ),
          if (visible)
            // ds-allow: Native page Scaffold owns keyboard insets; raft_ui owns its content/header.
            Scaffold(
              backgroundColor: pageColor,
              body: RaftSystemBarSurface(
                statusBarFallback: pageColor,
                child: SafeArea(
                  bottom: false,
                  child: SourceTaskSurface(
                    key: ValueKey(identity),
                    owner: task,
                    page: true,
                    compact: true,
                    onClose: back,
                    onTask: widget.onTask,
                    onViewBilling: widget.onViewBilling,
                    onBack: back,
                    onViewInThread: viewInThread(task),
                    legacyPresentation: RaftLegacyTaskPresentation.mobileModal,
                  ),
                ),
              ),
            ),
        ],
      );
    }
    final slotId = legacy ? null : taskSlotId(w.location);
    final side = legacy && !tasksRoute;
    final docked = visible && side && viewport.width >= 1024;
    final presentation = side
        ? RaftLegacyTaskPresentation.side
        : RaftLegacyTaskPresentation.modal;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: TaskSlotScope(
            taskId: slotId,
            onClose: close,
            surface: slotId == null || !visible
                ? null
                : (onClose) => SourceTaskSurface(
                    key: ValueKey(identity),
                    owner: task,
                    inPlace: true,
                    onClose: onClose,
                    onTask: widget.onTask,
                    onViewBilling: widget.onViewBilling,
                    onBack: onClose,
                    onViewInThread: viewInThread(task),
                  ),
            child: widget.childBuilder(
              docked ? legacyWidth : 0,
              visible && legacy ? close : null,
            ),
          ),
        ),
        if (visible && slotId == null)
          Positioned(
            top: 0,
            bottom: 0,
            right: side && widget.leadingOnRight && viewport.width >= 768
                ? widget.leadingExtent
                : 0,
            left: side
                ? docked
                      ? viewport.width -
                            legacyWidth -
                            (widget.leadingOnRight ? widget.leadingExtent : 0)
                      : viewport.width >= 768 && !widget.leadingOnRight
                      ? widget.leadingExtent
                      : 0
                : 0,
            // The modal's scrim dims the status bar band too: this overlay sits
            // above the workspace's own host, so it hosts a transparent strip.
            child: RaftStatusBarHost.overlay(
              child: SafeArea(
                child: SourceTaskSurface(
                  key: ValueKey(identity),
                  owner: task,
                  onClose: close,
                  onTask: widget.onTask,
                  onViewBilling: widget.onViewBilling,
                  onBack: back,
                  onViewInThread: viewInThread(task),
                  legacyPresentation: presentation,
                ),
              ),
            ),
          ),
        if (docked)
          Positioned(
            right:
                legacyWidth -
                RaftPanelResizeHandle.hitExtent / 2 +
                (widget.leadingOnRight ? widget.leadingExtent : 0),
            top: 0,
            bottom: 0,
            width: RaftPanelResizeHandle.hitExtent,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): close,
              },
              child: RaftPanelResizeHandle(
                key: const Key('legacy-task-resize-handle'),
                label: 'Resize legacy task panel',
                value: legacyWidth,
                reversed: true,
                onChanged: resizeLegacy,
              ),
            ),
          ),
      ],
    );
  }
}
