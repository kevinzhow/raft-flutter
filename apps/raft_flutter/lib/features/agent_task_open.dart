import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_navigation_history.dart';
import '../data/workspace_controller.dart';
import 'message_task_actions.dart' show taskSurfaceItemFor;
import 'qualified_task_navigation.dart';
import 'task_content_slot.dart' show taskOpenLocation;

/// Web `useRefNavigation().openTask(channelId, number)` for a task ref in an
/// agent's Activity (the overview's pills and the raw log): reads the task
/// (`GET /tasks/channel/:channelId/number/:n`) and opens it the way a task
/// reference in a message does (`WorkspaceView.openTaskSurface`, not from a
/// board): beside the current page where the window has the room, else over it.
/// The task surface loads the task by its URL, so no seed is needed.
Future<void> openAgentActivityTask(
  BuildContext context,
  WorkspaceController w,
  String channelId,
  int taskNumber,
) async {
  final row = await readTaskReference(w, channelId, taskNumber);
  if (!context.mounted) return;
  final rowChannel = row['channelId'];
  final itemId = taskSurfaceItemFor(w, row);
  if (rowChannel is! String || itemId == null || itemId.isEmpty) return;
  final wide = !RaftAdaptiveWorkspace.compactOf(context);
  openQualifiedTaskSurface(w, row, (task) {
    _presentTask(w, task, rowChannel, itemId, wide);
  });
}

void _presentTask(
  WorkspaceController w,
  Map<String, dynamic> row,
  String rowChannel,
  String itemId,
  bool wide,
) {
  final legacy = row['isLegacy'] == true;
  final next = taskOpenLocation(w, row, false, wide).withQuery({
    if (legacy) 'legacyTask': '$rowChannel:$itemId',
    if (!legacy) 'task': '$rowChannel:$itemId',
  });
  if (!wide) {
    // A phone replaces a profile or an older task page instead of stacking.
    if (w.location.task == null && w.location.legacyTask == null) {
      final base = next.withQuery({'task': null, 'legacyTask': null});
      if (base.uri.query != w.location.uri.query) {
        w.navigation.navigate(base, kind: RaftNavigationKind.replace);
      }
    }
    w.navigation.navigateTask(next);
  } else {
    w.navigation.navigateTask(
      next,
      kind: w.location.panelNavigationKindTo(next),
    );
  }
  w.notifyListeners();
}
