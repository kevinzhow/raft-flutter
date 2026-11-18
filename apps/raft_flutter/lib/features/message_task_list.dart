// The task list under a message (task v2, Web v1.24 MessageItem
// `linkedTaskList` / TaskChipList): the tasks created from it, one row each.
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'message_task_projection.dart';
import 'private_route_guard.dart' show workspaceAuthority;

/// Web TaskChipList's `ReplyCount` unread pixel: new messages in a task
/// conversation the reader follows, by its channel or (a joint channel's
/// local conversation differs from the canonical one) by its task.
bool taskConversationUnread(WorkspaceController w, Map<String, dynamic> task) {
  final conversation = task['conversationChannelId'];
  for (final row in w.services.followedThreads.threads) {
    final unread = row['unreadCount'];
    if (unread is! num || unread <= 0) continue;
    if (conversation is String && row['threadChannelId'] == conversation) {
      return true;
    }
    if (row['conversationKind'] == 'task' && row['taskId'] == task['id']) {
      return true;
    }
  }
  return false;
}

/// Web `hasOwnConversation`: a pre-v2 task without its own conversation still
/// talks in its host message's replies, already shown under that message.
bool taskHasOwnConversation(Map<String, dynamic> task) {
  final id = task['conversationChannelId'];
  return id is String && id.isNotEmpty;
}

RaftTaskChipRow messageTaskChipRow(
  WorkspaceController w,
  Map<String, dynamic> task,
) {
  final directory = w.services.entityDirectory;
  final type = task['claimedByType'], id = task['claimedById'];
  final assigned = id is String && id.isNotEmpty && type is String;
  final agent = type == 'agent';
  final identity = !assigned
      ? null
      : agent
      ? directory.agent(id)
      : directory.member(id);
  final display = identity?['displayName'] ?? identity?['name'];
  return RaftTaskChipRow(
    id: '${task['id']}',
    number: task['taskNumber'] as int,
    title: '${task['title'] ?? ''}',
    status: '${task['status']}',
    replyCount: taskHasOwnConversation(task)
        ? (task['conversationReplyCount'] as num?)?.toInt() ?? 0
        : 0,
    unread: taskConversationUnread(w, task),
    assigneeName: !assigned
        ? null
        : display is String && display.isNotEmpty
        ? display
        : '${task['claimedByName'] ?? ''}',
    assigneeIsAgent: agent,
    assigneeIsViewer: assigned && !agent && id == w.client.user?.id,
    assigneeAvatarUrl: identity?['avatarUrl'] as String?,
  );
}

/// The list under [message], or null when it has none (it keeps the single
/// footer chip). [onTask] opens the task slot; [active] says whether the
/// timeline is the presented one at tap time.
Widget? messageTaskList(
  WorkspaceController w,
  MessageTaskProjection projection,
  RaftMessage message, {
  required void Function(
    Map<String, dynamic> task,
    Future<void> Function() refresh,
  )?
  onTask,
  required bool Function() active,
}) {
  final tasks = projection.taskListFor(message);
  if (tasks == null || tasks.isEmpty) return null;
  final authority = workspaceAuthority(w);
  return ListenableBuilder(
    listenable: w.services.followedThreads,
    builder: (_, _) => RaftTaskChipList(
      key: ValueKey('message-task-list-${message.id}'),
      tasks: [for (final task in tasks) messageTaskChipRow(w, task)],
      onOpen: onTask == null
          ? null
          : (row) {
              if (!active() || authority != workspaceAuthority(w)) return;
              final current = projection
                  .taskListFor(message)
                  ?.where((task) => task['id'] == row.id)
                  .firstOrNull;
              if (current == null) return;
              onTask(current, () async {
                if (authority == workspaceAuthority(w)) projection.refresh();
              });
            },
    ),
  );
}
