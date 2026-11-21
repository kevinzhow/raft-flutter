// The task dialog's own facts and ways out (Web v1.24 TaskConversationDialog
// TaskSourceProperty, TaskCreatedAtProperty, TaskEarlierDiscussionProperty
// and the bar's View in channel).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/message_history_pages.dart' show threadParentQuery;
import '../data/raft_location.dart';
import '../data/raft_navigation_history.dart';
import '../data/source_time_formatter.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'agent_avatar_projection.dart';
import 'sender_avatar_projection.dart';
import 'task_v2_mode.dart';
import 'task_view_in_thread.dart';

({SenderAvatarProjection avatar, RaftAvatarPresence? presence})?
taskAssigneeAvatarProjection(
  WorkspaceController workspace,
  Map<String, dynamic> task, {
  DateTime? now,
}) {
  final id = task['claimedById'];
  final type = task['claimedByType'];
  if (id is! String || (type != 'agent' && type != 'user')) return null;
  final directory = workspace.services.entityDirectory;
  final agent = type == 'agent' ? directory.agent(id) : null;
  return (
    avatar: projectSenderAvatar(
      origin: workspace.client.origin,
      senderId: id,
      senderType: type as String,
      agents: [?agent],
      members: type == 'user' ? [?directory.member(id)] : const [],
      currentUser: workspace.client.user?.json,
    ),
    presence: type != 'agent'
        ? null
        : agentRowPresence(agent ?? const {}, now: now ?? sourceTimeNow()),
  );
}

/// Reads the two facts a task dialog shows that its task row does not carry:
/// the source message (who said it, its first line, when) and the size of a
/// pre-v2 task's earlier discussion (its host message's replies).
class TaskConversationFacts extends ChangeNotifier {
  TaskConversationFacts(this.w);
  final WorkspaceController w;
  bool _disposed = false;

  ({String id, RaftMessage? message})? _source;
  final _sourceLoading = <String>{};
  ({String hostId, int replyCount, String? threadChannelId})? _earlier;
  String? _earlierLoading;

  /// The source message, from the channel's loaded window or one read.
  RaftMessage? source(Map<String, dynamic> task, String id) {
    final cached = w.messageDomain.messages
        .where((m) => m.id == id && m.channelId == task['channelId'])
        .firstOrNull;
    if (cached != null) return cached;
    if (_source?.id == id) return _source!.message;
    if (_sourceLoading.add(id)) unawaited(_loadSource(task, id));
    return null;
  }

  Future<void> _loadSource(Map<String, dynamic> task, String id) async {
    RaftMessage? found;
    try {
      final page = await w.client.get(
        '/messages/context/${Uri.encodeComponent(id)}',
        query: threadParentQuery('${task['channelId']}'),
      );
      final rows = page is Map ? page['messages'] : null;
      if (rows is List) {
        for (final row in rows.whereType<Map>()) {
          if (row['id'] == id) {
            found = RaftMessage(Map<String, dynamic>.from(row));
          }
        }
      }
    } catch (_) {
      // Not loaded: the row says so.
    }
    _sourceLoading.remove(id);
    if (_disposed) return;
    _source = (id: id, message: found);
    notifyListeners();
  }

  /// A pre-v2 task's earlier discussion: the host's reply count, or the
  /// task's served count while it has no conversation of its own; null when
  /// not known yet. Zero hides the row.
  ({int? replyCount, String? threadChannelId}) earlier(
    Map<String, dynamic> task,
    String hostId,
  ) {
    final served = task['conversationChannelId'] == null
        ? (task['conversationReplyCount'] as num?)?.toInt()
        : null;
    if (_earlier?.hostId == hostId) {
      return (
        replyCount: _earlier!.replyCount,
        threadChannelId: _earlier!.threadChannelId,
      );
    }
    if (_earlierLoading != hostId) {
      _earlierLoading = hostId;
      unawaited(_loadEarlier(task, hostId));
    }
    return (replyCount: served, threadChannelId: null);
  }

  Future<void> _loadEarlier(Map<String, dynamic> task, String hostId) async {
    var count = 0;
    String? thread;
    try {
      final data = await w.client.get(
        '/channels/${task['channelId']}/threads/${Uri.encodeComponent(hostId)}',
      );
      if (data is Map) {
        count = (data['replyCount'] as num?)?.toInt() ?? 0;
        final id = data['threadChannelId'];
        thread = id is String ? id : null;
      }
    } catch (_) {
      // No thread (404) or not visible: nothing earlier to show.
    }
    if (_disposed) return;
    _earlier = (hostId: hostId, replyCount: count, threadChannelId: thread);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The Source property's value: the sender's avatar and name, the message's
/// first line and its time, leading to the message; "Not recorded" for a task
/// without one. Null: no row.
Widget? taskSourceValue(
  BuildContext context,
  WorkspaceController w,
  TaskConversationFacts facts,
  Map<String, dynamic> task,
  SourceTimeFormatter formatter, {
  required VoidCallback Function(String messageId) onOpen,
}) {
  final t = RaftTokens.of(context);
  switch (taskSourceDisplay(task)) {
    case null:
      return null;
    case TaskSourceNotRecorded():
      return Text(
        raftText(context, 'Not recorded'),
        key: const ValueKey('task-modal-source-not-recorded'),
        style: t.scale(RaftTypeScale.callout, color: t.ui.foregroundMuted),
      );
    case TaskSourceMessage(:final id):
      final message = facts.source(task, id);
      final agent = message?.string('senderType') == 'agent';
      final directory = w.services.entityDirectory;
      final identity = message == null
          ? null
          : agent
          ? directory
                .rows(WorkspaceEntityKind.agents)
                .where((r) => r['id'] == message.string('senderId'))
                .firstOrNull
          : directory.member(message.string('senderId'));
      final sender =
          '${identity?['displayName'] ?? identity?['name'] ?? message?.author ?? ''}';
      final preview =
          message?.content
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .firstOrNull ??
          '';
      return RaftTaskPropertyLink(
        key: const ValueKey('task-modal-source-open'),
        semanticLabel: 'Open the source message',
        onPressed: onOpen(id),
        children: [
          if (message != null)
            RaftAvatar(
              name: sender,
              kind: agent ? RaftAvatarKind.agent : RaftAvatarKind.human,
              imageUrl: identity?['avatarUrl'] as String?,
              mountedContext: RaftMountedAvatarContext.compactList,
            ),
          if (sender.isNotEmpty)
            Text(
              sender,
              key: const ValueKey('task-modal-source-author'),
              style: t.scale(RaftTypeScale.callout, weight: FontWeight.w600),
            ),
          Flexible(
            child: Text(
              message == null
                  ? raftText(context, 'Message not loaded')
                  : preview,
              key: const ValueKey('task-modal-source-preview'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.scale(
                RaftTypeScale.callout,
                color: t.ui.foregroundMuted,
              ),
            ),
          ),
          if (message?.createdAt != null)
            Text(
              formatter.messageTime(message!.json['createdAt']),
              style: t.scale(
                RaftTypeScale.monoMeta,
                mono: true,
                color: t.ui.foregroundHint,
              ),
            ),
        ],
      );
  }
}

/// Web `formatMediumDateTime24`: the medium date and a 24-hour clock.
String taskCreatedAtText(SourceTimeFormatter formatter, Object? value) {
  final date = DateTime.tryParse('$value');
  if (date == null) return '';
  final wall = formatter.wallTime(date);
  return '${DateFormat.yMMMd(formatter.locale).format(wall)}, '
      '${DateFormat('HH:mm', formatter.locale).format(wall)}';
}

/// Web TaskConversationBar `viewInChannel`: leave the dialog for the task's
/// place in its channel, the message it hangs under (its source, or a
/// pre-v2 task's host), or the channel itself for a task created without
/// one. [messageId] overrides the anchor (the Source property).
Future<void> viewTaskInChannel(
  WorkspaceController w,
  Map<String, dynamic> task, {
  required bool compact,
  required VoidCallback closeTask,
  String? messageId,
}) async {
  final channelId = task['channelId'];
  if (channelId is! String) return;
  final channel = [
    ...w.channels,
    ...w.dms,
  ].where((c) => c.id == channelId).firstOrNull;
  if (channel == null || !w.can('viewChannel', resource: channel)) return;
  final source = task['sourceMessageId'], host = task['hostMessageId'];
  final anchor =
      messageId ??
      (source is String && source.isNotEmpty
          ? source
          : host is String && host.isNotEmpty
          ? host
          : null);
  if (!compact) closeTask();
  w.navigation.navigate(
    RaftLocation.at(
      serverSlug: w.location.serverSlug,
      route: channel.type == 'dm' ? RaftRoute.dm : RaftRoute.channel,
      entityId: channelId,
      query: {'msg': ?anchor},
    ),
    kind: compact ? RaftNavigationKind.replace : RaftNavigationKind.push,
  );
  w.channel = channel;
  await w.selectChannel(channel, navigate: false);
}

/// Earlier discussion: a pre-v2 task talked in its host message's replies
/// before it had its own conversation; open that thread.
Future<void> openTaskEarlierDiscussion(
  WorkspaceController w,
  Map<String, dynamic> task,
  String hostId,
  String? threadChannelId, {
  required bool compact,
  required VoidCallback closeTask,
}) => viewTaskInThread(
  w,
  {
    ...task,
    'messageId': hostId,
    'threadChannelId': threadChannelId,
    'isLegacy': false,
  },
  compact: compact,
  closeTask: closeTask,
);
