// Task v2 dialog glue (Web v1.24 TaskConversationDialog): the facts and
// commands the shared task surface draws for a task's own conversation, the
// steps that ask for a reason before they write, and the delete confirmation.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_time_formatter.dart';
import '../data/user_error.dart';
import 'chat_navigation.dart';
import 'task_conversation_facts.dart';
import 'task_surface_controller.dart';
import 'task_followers_actions.dart';
import 'task_v2_mode.dart';
import 'icu_message.dart';

/// The conversation props of [o]'s task. [onLeave] closes the dialog (the
/// route change that follows owns the history entry); [compact] is a phone
/// page.
RaftTaskConversation taskConversation(
  BuildContext context,
  TaskSurfaceController o,
  TaskConversationFacts facts,
  SourceTimeFormatter formatter, {
  required bool compact,
  required bool tasksPage,
  required VoidCallback onLeave,
  required ChatNavigation? navigation,
}) {
  final task = o.task;
  final w = o.parent;
  final assignee = tasksPage ? taskAssigneeAvatarProjection(w, task) : null;
  final assigneeName = '${task['claimedByName'] ?? ''}';
  final agentAssignee = assignee?.avatar.kind == 'agent';
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
            : replyCountText(context, count),
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
    followers: discussion == null || navigation == null
        ? null
        : (hasExpand, buildHeader) => TaskFollowersActions(
            discussion: discussion,
            navigation: navigation,
            hasExpand: hasExpand,
            buildHeader: buildHeader,
          ),
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
    onPrepareAmend: () async {
      try {
        return await o.prepareAmend();
      } catch (failure) {
        if (context.mounted && o.current) {
          showRaftToast(context, userErrorText(failure, where: 'task editor'));
        }
        return false;
      }
    },
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
    assigneeAvatar: assignee == null
        ? null
        : ListenableBuilder(
            listenable: w.services.entityDirectory,
            builder: (context, _) {
              final current = taskAssigneeAvatarProjection(w, task);
              if (current == null) return const SizedBox.shrink();
              return RaftAvatar(
                name: assigneeName,
                kind: agentAssignee
                    ? RaftAvatarKind.agent
                    : RaftAvatarKind.human,
                imageUrl: current.avatar.uploadedUrl,
                presence: current.presence,
                uiSize: RaftAvatarSize.xs,
                mountedContext: RaftMountedAvatarContext.compactList,
                content: current.avatar.pixelKey == null
                    ? null
                    : RaftAvatarContent(
                        name: assigneeName,
                        kind: agentAssignee
                            ? RaftAvatarContentKind.agent
                            : RaftAvatarContentKind.human,
                        pixelKey: current.avatar.pixelKey,
                      ),
              );
            },
          ),
  );
}

class _TaskDiscussionSubject extends StatelessWidget {
  const _TaskDiscussionSubject({required this.head, required this.empty});

  final Widget head, empty;

  @override
  Widget build(BuildContext context) => head;
}

Widget taskDiscussionSubject(
  BuildContext context,
  Map<String, dynamic> task,
  Widget head,
) {
  final host = task['hostMessageId'];
  return _TaskDiscussionSubject(
    head: head,
    empty: RaftProductEmptyState(
      key: const ValueKey('task-conversation-empty'),
      title: raftText(context, 'No discussion in this task yet'),
      description: host is String && host.isNotEmpty
          ? raftText(
              context,
              "Its earlier discussion is in the replies of the message it came from. Write here to start the task's own.",
            )
          : null,
      icon: (context, size, color) {
        final backdrop = RaftConversationSurfaceRecipe(RaftTokens.of(context))
            .background(RaftConversationSurfaceRole.threadTimeline);
        return RaftIcon(
          RaftGlyph.thread,
          size: size,
          color: color.a < 1 && backdrop.a == 1
              ? raftChromeBlend(color, backdrop)
              : color,
        );
      },
    ),
  );
}

Widget threadEmptyContent(BuildContext context, Widget? subject) =>
    subject is _TaskDiscussionSubject
    ? subject.empty
    : RaftProductEmptyState(
        title: raftText(context, 'No replies yet'),
        icon: (context, size, color) =>
            RaftThreadIcon(size: size, color: color),
      );

bool isTaskDiscussionSubject(Widget? subject) =>
    subject is _TaskDiscussionSubject;

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
