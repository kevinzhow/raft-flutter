import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart' show raftTaskStatuses;

import '../data/raft_navigation_history.dart';
import '../data/workspace_controller.dart';
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
    required this.child,
    this.seed,
    this.presented = true,
  });
  final WorkspaceController controller;
  final Widget child;
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
  WorkspaceController get w => widget.controller;

  @override
  void initState() {
    super.initState();
    synchronize();
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
    final accepted = seeded ? seed!.row : null;
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
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (widget.presented)
        if (owner case final task?)
          AnimatedBuilder(
            animation: task,
            builder: (context, _) => legacy && !task.hydrated
                // Source preserves the pending legacy URL without inventing a
                // metadata panel before an accepted legacy row exists.
                ? const SizedBox.shrink()
                : SafeArea(
                    child: SourceTaskSurface(
                      key: ValueKey(identity),
                      owner: task,
                      onClose: close,
                      onBack: back,
                    ),
                  ),
          ),
    ],
  );
}
