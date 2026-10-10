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
import '../data/source_task_bucket.dart';
import 'task_surface.dart';
import 'task_surface_controller.dart';

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

/// MainLayout's task overlay owns its URI identity and independent lifecycle.
/// The child stays mounted through open, hydration, retarget and close.
class WorkspaceTaskHost extends StatefulWidget {
  const WorkspaceTaskHost({
    super.key,
    required this.controller,
    required this.childBuilder,
    this.leadingExtent = 0,
    this.seed,
    this.presented = true,
  });
  final WorkspaceController controller;
  final Widget Function(double legacyDockWidth, VoidCallback? onLegacyEscape)
  childBuilder;
  final double leadingExtent;
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
        (legacy
            ? seed?.row['id'] == anchor.itemId && seed?.row['isLegacy'] == true
            : seed?.row['messageId'] == anchor.itemId &&
                  seed?.row['isLegacy'] != true);
    // A task URL for a task whose message chip is already known (the channel's
    // accepted task bucket) shows it at the first frame like a seeded row; the
    // full read then revalidates it in place.
    final known = seeded || legacy || knownChannel == null
        ? null
        : MessageTaskCache.of(
            w.client,
          ).tasks(w, anchor.channelId)?[anchor.itemId];
    final accepted = seeded
        ? seed!.row
        : known == null
        ? null
        : <String, dynamic>{...known};
    owner = TaskSurfaceController(
      parent: w,
      hydrateParent: !legacy && knownChannel == null,
      row:
          accepted ??
          {
            'channelId': anchor.channelId,
            if (legacy) 'isLegacy': true else 'messageId': anchor.itemId,
          },
      valid: () => mounted && next == currentIdentity,
      onMutationAccepted: seeded ? seed?.onMutationAccepted : null,
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
                    !raftTaskStatuses.contains(row['status'])) {
                  continue;
                }
                if (legacy
                    ? row['id'] == anchor.itemId && row['isLegacy'] == true
                    : row['messageId'] == anchor.itemId &&
                          row['isLegacy'] != true) {
                  return Map<String, dynamic>.from(row);
                }
              }
              return null;
            },
    );
    unawaited(owner!.start());
  }

  void close() {
    if (identity != currentIdentity) return;
    w.navigation.navigateTask(
      w.location.withQuery({legacy ? 'legacyTask' : 'task': null}),
      kind: RaftNavigationKind.replace,
    );
    w.notifyListeners();
  }

  void back() {
    if (identity != currentIdentity) return;
    w.navigation.back();
    w.notifyListeners();
  }

  @override
  void dispose() {
    owner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: owner ?? w,
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
    final visible = widget.presented && task != null && legacyVisible;
    final side = legacy && !tasksRoute;
    final docked = visible && side && viewport.width >= 1024;
    final presentation = side
        ? RaftLegacyTaskPresentation.side
        : viewport.width < 768
        ? RaftLegacyTaskPresentation.mobileModal
        : RaftLegacyTaskPresentation.modal;
    final t = RaftTokens.of(context);
    final mobileTaskFooter =
        legacy && tasksRoute && viewport.width < 768 && t.brutal
        ? RaftMobileNavRecipe(t, viewportHeight: viewport.height).itemHeight + 2
        : 0.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: widget.childBuilder(
            docked ? legacyWidth : 0,
            visible && legacy ? close : null,
          ),
        ),
        if (visible)
          Positioned(
            top: 0,
            bottom: mobileTaskFooter,
            right: 0,
            left: side
                ? docked
                      ? viewport.width - legacyWidth
                      : viewport.width >= 768
                      ? widget.leadingExtent
                      : 0
                : 0,
            child: SafeArea(
              child: SourceTaskSurface(
                key: ValueKey(identity),
                owner: task,
                onClose: close,
                onBack: back,
                legacyPresentation: presentation,
              ),
            ),
          ),
        if (docked)
          Positioned(
            right: legacyWidth - RaftPanelResizeHandle.hitExtent / 2,
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
