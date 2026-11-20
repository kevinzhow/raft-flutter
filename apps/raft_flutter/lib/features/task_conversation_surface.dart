// Task v2 dialog glue (Web v1.24 TaskConversationDialog): the facts and
// commands the shared task surface draws for a task's own conversation, the
// steps that ask for a reason before they write, and the delete confirmation.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_time_formatter.dart';
import 'task_conversation_facts.dart';
import 'task_surface_controller.dart';
import 'task_v2_mode.dart';

/// The conversation props of [o]'s task. [onLeave] closes the dialog (the
/// route change that follows owns the history entry); [compact] is a phone
/// page.
RaftTaskConversation taskConversation(
  BuildContext context,
  TaskSurfaceController o,
  TaskConversationFacts facts,
  SourceTimeFormatter formatter, {
  required bool compact,
  required VoidCallback onLeave,
}) {
  final task = o.task;
  final w = o.parent;
  final dm = task['channelType'] == 'dm'
      ? [...w.dms].where((c) => c.id == task['channelId']).firstOrNull
      : null;
  void leaveFor(String? messageId) => unawaited(
    viewTaskInChannel(
      w,
      task,
      compact: compact,
      closeTask: onLeave,
      messageId: messageId,
    ),
  );
  final host = task['hostMessageId'];
  ({String label, VoidCallback onOpen})? earlier;
  if (host is String && host.isNotEmpty) {
    final known = facts.earlier(task, host);
    final count = known.replyCount;
    if (count != 0) {
      earlier = (
        label: count == null
            ? raftText(context, 'View')
            : raftFormat(
                context,
                count == 1 ? '{count} reply' : '{count} replies',
                {'count': count},
              ),
        onOpen: () => unawaited(
          openTaskEarlierDiscussion(
            w,
            task,
            host,
            known.threadChannelId,
            compact: compact,
            closeTask: onLeave,
          ),
        ),
      );
    }
  }
  final discussion = o.discussion;
  return RaftTaskConversation(
    ref: formatTaskConversationRef(
      task,
      dmPeerName: dm?.json['peerName'] as String? ?? dm?.name,
    ),
    onViewInChannel: () => leaveFor(null),
    followed: o.followed,
    onFollow: o.followBusy || discussion == null
        ? null
        : () => unawaited(o.toggleFollow()),
    onSearch: discussion?.threadChannelId == null
        ? null
        : discussion!.threadSearch.open,
    onDelete: o.canDelete
        ? () => unawaited(confirmTaskDelete(context, o))
        : null,
    onAmend: o.canAmend ? o.amend : null,
    source: taskSourceValue(
      context,
      w,
      facts,
      task,
      formatter,
      onOpen: (id) =>
          () => leaveFor(id),
    ),
    createdAt: task['createdAt'] == null
        ? null
        : taskCreatedAtText(formatter, task['createdAt']),
    earlierDiscussion: earlier,
  );
}

Widget taskConversationEmpty(BuildContext context, Map<String, dynamic> task) {
  final host = task['hostMessageId'];
  return RaftProductEmptyState(
    key: const ValueKey('task-conversation-empty'),
    title: raftText(context, 'No discussion in this task yet'),
    description: host is String && host.isNotEmpty
        ? raftText(
            context,
            "Its earlier discussion is in the replies of the message it came from. Write here to start the task's own.",
          )
        : null,
    icon: (context, size, color) => RaftThreadIcon(size: size, color: color),
  );
}

/// A status or assignee write with the reason its popover collected (moving
/// into Backlog, handing to someone else). False when the write failed.
Future<bool> updateWithReason(
  TaskSurfaceController o,
  String field,
  dynamic value,
  String reason,
) async {
  try {
    await o.update(field, value, reason: reason);
    return true;
  } catch (_) {
    return false;
  }
}

/// Web useTaskDeleteMenu: asks before it deletes; once the task is gone the
/// dialog closes (the controller reports [TaskSurfaceController.deleted]).
Future<void> confirmTaskDelete(BuildContext context, TaskSurfaceController o) =>
    showRaftDialog<void>(
      context: context,
      // Web ConfirmDialog: no pointer dismissal (X, Esc and Cancel only).
      barrierDismissible: false,
      builder: (dialogContext) => RaftTaskDeleteConfirmDialog(
        taskNumber: o.task['taskNumber'] as int? ?? 0,
        onCancel: () => Navigator.of(dialogContext).pop(),
        onConfirm: () async {
          final failure = await o.delete();
          if (!dialogContext.mounted) return failure;
          if (failure == null) {
            Navigator.of(dialogContext).pop();
            return null;
          }
          return raftText(dialogContext, failure);
        },
      ),
    );
