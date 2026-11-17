// Acting on the selected tasks at once (the Tasks page's selection bar).
// There is no batch endpoint: the per-task APIs are called one task at a
// time, a few in flight. A task the viewer may not change is skipped, and so
// is one the server refuses; the toast says how many.
//
// Source: Web v1.24 components/task/tasksPage/tasksBatch.ts and
// useBatchViewer.ts.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/workspace_controller.dart';
import '../task_v2_mode.dart' show directTaskConversationChannelId;
import 'tasks_page_store.dart';

@immutable
class TaskAssigneeRef {
  const TaskAssigneeRef(this.type, this.id);

  /// `user` or `agent`.
  final String type, id;

  @override
  bool operator ==(Object other) =>
      other is TaskAssigneeRef && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

@immutable
sealed class BatchAction {
  const BatchAction();
}

class BatchStatus extends BatchAction {
  const BatchStatus(this.status);
  final String status;

  @override
  bool operator ==(Object other) =>
      other is BatchStatus && other.status == status;

  @override
  int get hashCode => Object.hash(BatchStatus, status);
}

/// Null clears the assignee.
class BatchAssignee extends BatchAction {
  const BatchAssignee(this.assignee);
  final TaskAssigneeRef? assignee;

  @override
  bool operator ==(Object other) =>
      other is BatchAssignee && other.assignee == assignee;

  @override
  int get hashCode => Object.hash(BatchAssignee, assignee);
}

class BatchFollow extends BatchAction {
  const BatchFollow();

  @override
  bool operator ==(Object other) => other is BatchFollow;

  @override
  int get hashCode => (BatchFollow).hashCode;
}

class BatchDelete extends BatchAction {
  const BatchDelete();

  @override
  bool operator ==(Object other) => other is BatchDelete;

  @override
  int get hashCode => (BatchDelete).hashCode;
}

/// Who is acting, for the permissions below.
@immutable
class BatchViewer {
  const BatchViewer({
    required this.userId,
    required this.canAssign,
    required this.canDeleteAny,
  });

  /// A Guest assigns in its own channel without the capability (the server's
  /// rule).
  factory BatchViewer.of(WorkspaceController c) => BatchViewer(
    userId: c.client.user?.id,
    canAssign: c.can('assignTasks') || c.server?.string('role') == 'guest',
    canDeleteAny: c.can('deleteAnyTask'),
  );

  final String? userId;

  /// Server capability `assignTasks`.
  final bool canAssign;

  /// Server capability `deleteAnyTask`.
  final bool canDeleteAny;
}

@immutable
class BatchOutcome {
  const BatchOutcome({
    required this.done,
    required this.skipped,
    this.failedIds = const [],
    this.firstError,
  });

  /// Tasks the action reached (or that already were so).
  final int done;

  /// Tasks it left: not the viewer's to change, or refused by the server.
  final int skipped;

  /// The tasks the server refused (or that failed on the way): they stay
  /// selected, to try again.
  final List<String> failedIds;

  /// The first failure, for the page's toast.
  final Object? firstError;

  @override
  bool operator ==(Object other) =>
      other is BatchOutcome &&
      other.done == done &&
      other.skipped == skipped &&
      listEquals(other.failedIds, failedIds);

  @override
  int get hashCode => Object.hash(done, skipped, Object.hashAll(failedIds));
}

bool _truthy(Object? v) => v != null && v != false && v != '';

/// Whether [action] may be applied to [task] by [viewer]: per action, the rule
/// the same change on one task follows (and the server's), so a batch does
/// what the viewer could do task by task.
/// - Status: anyone who may write the task (no `readOnlyReason`), except
///   moving an unassigned To-do to In progress, which the server refuses (a
///   single task's move is its mover's claim; one status for many tasks
///   claims none of them).
/// - Assignee: the `assignTasks` capability, on a task not done and writable.
/// - Delete: its creator, or `deleteAnyTask`.
/// - Follow: anyone who sees it.
/// Never a legacy task.
bool canApplyBatchAction(
  BatchAction action,
  Map<String, dynamic> task,
  BatchViewer viewer,
) {
  if (_truthy(task['isLegacy'])) return false;
  final writable = !_truthy(task['readOnlyReason']);
  switch (action) {
    case BatchFollow():
      return true;
    case BatchStatus(:final status):
      if (status == 'in_progress' &&
          task['status'] == 'todo' &&
          !_truthy(task['claimedById'])) {
        return false;
      }
      return writable;
    case BatchAssignee():
      return viewer.canAssign && task['status'] != 'done' && writable;
    case BatchDelete():
      final creator =
          viewer.userId != null &&
          task['createdByType'] == 'user' &&
          task['createdById'] == viewer.userId;
      return writable && (creator || viewer.canDeleteAny);
  }
}

/// The task already is what the action would make it: nothing to send.
bool isBatchNoop(BatchAction action, Map<String, dynamic> task) =>
    switch (action) {
      BatchStatus(:final status) => task['status'] == status,
      BatchAssignee(assignee: null) => !_truthy(task['claimedById']),
      BatchAssignee(:final assignee?) =>
        task['claimedByType'] == assignee.type &&
            task['claimedById'] == assignee.id,
      _ => false,
    };

/// One task's write for the action through [controller]'s client.
Future<void> Function(BatchAction, Map<String, dynamic>) taskBatchPerformer(
  WorkspaceController controller,
  TasksPageStore store,
) => taskBatchWriter(
  store,
  (method, path, {data}) => controller.client.request(method, path, data: data),
);

/// A write to the server: the controller client's `request`.
typedef TaskBatchRequest = Future<dynamic> Function(
  String method,
  String path, {
  dynamic data,
});

/// One task's write for the action over [request], its answer applied to
/// [store] at once (so the page updates before the socket's event). A
/// failure is thrown.
Future<void> Function(BatchAction, Map<String, dynamic>) taskBatchWriter(
  TasksPageStore store,
  TaskBatchRequest request,
) {
  void apply(dynamic data) {
    if (data is Map && data['task'] is Map) {
      store.applyWritten(Map<String, dynamic>.from(data['task'] as Map));
    }
  }

  return (action, task) async {
    final id = Uri.encodeComponent('${task['id']}');
    switch (action) {
      case BatchStatus(:final status):
        // Never /claim: canApplyBatchAction leaves out what would need one.
        // Backlog asks no reason here: one reason would not fit many tasks.
        apply(
          await request('PATCH', '/tasks/$id/status', data: {'status': status}),
        );
      case BatchAssignee(:final assignee):
        apply(
          await request(
            'PATCH',
            '/tasks/$id/assignee',
            data: {
              'assignee': assignee == null
                  ? null
                  : {'type': assignee.type, 'id': assignee.id},
            },
          ),
        );
      case BatchFollow():
        // Follow a task's conversation, creating it first where it has none
        // yet (as the task's own Follow does). The server answers this
        // server's local conversation (a joint task's too).
        var channelId = directTaskConversationChannelId(task);
        if (channelId == null) {
          final data = await request('POST', '/tasks/$id/conversation');
          final created = data is Map ? data['conversationChannelId'] : null;
          if (created is! String || created.isEmpty) {
            throw StateError(
              'Task conversation creation did not return a channel id',
            );
          }
          channelId = created;
        }
        await request(
          'POST',
          '/channels/threads/follow',
          data: {'threadChannelId': channelId},
        );
        store.patchRow('${task['id']}', {'conversationFollowed': true});
      case BatchDelete():
        await request('DELETE', '/tasks/$id');
        store.removeTask('${task['id']}');
    }
  };
}

/// Writes in flight at once.
const batchConcurrency = 4;

/// Apply [action] to [tasks]: the ones the viewer may change, each with its
/// own request (a few at a time); the rest, and any the server refuses,
/// skipped. [perform] is the write ([taskBatchPerformer]). [afterFollow] runs
/// once when a follow reached any task (the followed threads read again); its
/// failure is not the batch's.
Future<BatchOutcome> runTaskBatch(
  BatchAction action,
  List<Map<String, dynamic>> tasks,
  BatchViewer viewer, {
  required Future<void> Function(BatchAction action, Map<String, dynamic> task)
  perform,
  Future<void> Function()? afterFollow,
}) async {
  final permitted = [
    for (final task in tasks)
      if (canApplyBatchAction(action, task, viewer)) task,
  ];
  var done = 0;
  var next = 0;
  final failedIds = <String>[];
  Object? firstError;
  Future<void> worker() async {
    while (next < permitted.length) {
      final task = permitted[next++];
      if (isBatchNoop(action, task)) {
        done += 1;
        continue;
      }
      try {
        await perform(action, task);
        done += 1;
      } catch (error) {
        firstError ??= error;
        failedIds.add('${task['id']}');
      }
    }
  }

  await Future.wait([
    for (var i = 0; i < batchConcurrency && i < permitted.length; i++) worker(),
  ]);
  if (action is BatchFollow && done > 0 && afterFollow != null) {
    unawaited(afterFollow().catchError((Object _) {}));
  }
  return BatchOutcome(
    done: done,
    skipped: tasks.length - permitted.length + failedIds.length,
    failedIds: failedIds,
    firstError: firstError,
  );
}
