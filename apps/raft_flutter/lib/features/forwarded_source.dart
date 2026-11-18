import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/message_window_snapshot.dart' show acceptedWindowRows;
import '../data/raft_location.dart';
import '../data/task_conversation_thread.dart' show authorizeTaskConversation;
import '../data/workspace_controller.dart';
import 'private_route_guard.dart' show workspaceAuthority;
import 'task_content_slot.dart' show openTaskFromList;

sealed class ForwardedSource {
  const ForwardedSource(this.channelId, this.messageId, this.conversationId);

  final String channelId, messageId, conversationId;

  static ForwardedSource? read(
    WorkspaceController w,
    Map<String, dynamic> item,
  ) {
    final server = item['sourceServerId'];
    final provenance = item['provenanceState'];
    if (provenance != null && provenance != 'available' ||
        server != null && server != w.server?.id) {
      return null;
    }
    final target = item['sourceTargetSnapshot'];
    final message = _id(item['sourceMessageId']);
    if (target is! Map ||
        target['labelVisibility'] != 'public' ||
        message == null) {
      return null;
    }
    final thread = _id(item['sourceThreadId']);
    final task = _id(item['sourceTaskId']);
    final source = switch ((
      target['type'],
      _id(item['sourceTargetId']),
      _id(item['parentChannelId']),
    )) {
      ('thread', _, final String parent) when thread != null =>
        _ForwardedThread(parent, message, thread),
      ('task', final String conversation, final String parent)
          when task != null =>
        _ForwardedTask(parent, message, conversation, task),
      ('channel' || 'joint', final String channel, _) => _ForwardedMessage(
        channel,
        message,
      ),
      _ => null,
    };
    return source?._canRead(w) == true ? source : null;
  }

  bool _canRead(WorkspaceController w) =>
      _canReadChannel(w, channelId) &&
      !w.sessionScope.revokedChannels.contains(conversationId);
}

final class _ForwardedMessage extends ForwardedSource {
  const _ForwardedMessage(String channelId, String messageId)
    : super(channelId, messageId, channelId);
}

final class _ForwardedThread extends ForwardedSource {
  const _ForwardedThread(
    super.channelId,
    super.messageId,
    super.conversationId,
  );
}

final class _ForwardedTask extends ForwardedSource {
  const _ForwardedTask(
    super.channelId,
    super.messageId,
    super.conversationId,
    this.taskId,
  );

  final String taskId;
}

String? _id(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

bool _canReadChannel(WorkspaceController w, String id) {
  final channel = w.channels.where((row) => row.id == id).firstOrNull;
  return channel != null &&
      (channel.type == 'channel' || channel.type == 'joint') &&
      !w.sessionScope.revokedChannels.contains(id) &&
      w.can('viewChannel', resource: channel);
}

const _unavailable = RaftApiException(
  'Unable to open source. It may be unavailable or deleted.',
);

bool _hasOriginal(Map data, String channelId, String messageId) =>
    data['channelId'] == channelId &&
    data['targetMessageId'] == messageId &&
    acceptedWindowRows(
      data['messages'],
      channelId,
    ).any((row) => row['id'] == messageId && !RaftMessage(row).retracted);

Future<void> openForwardedSource(
  BuildContext context,
  WorkspaceController w,
  ForwardedSource source,
) async {
  final authority = workspaceAuthority(w), revision = w.navigationRevision;
  bool current() =>
      context.mounted &&
      revision == w.navigationRevision &&
      authority == workspaceAuthority(w) &&
      source._canRead(w);

  if (!current()) return;
  final message = source.messageId;
  final path = '/messages/context/${Uri.encodeComponent(message)}';
  try {
    switch (source) {
      case _ForwardedMessage(:final channelId):
        await w.jumpToMessage(channelId, message);
      case _ForwardedThread(:final channelId, conversationId: final threadId):
        Map data;
        var limited = false;
        try {
          data = await w.query(path, query: {'channelId': channelId});
        } on RaftApiException catch (error) {
          if (error.status != 404 || error.code != 'history_limited') rethrow;
          limited = true;
          data = error.details;
        }
        if (!current()) return;
        final target = data['canonicalTarget'];
        final parentChannel = target is Map
            ? _id(target['channelId']) ?? channelId
            : channelId;
        final conversation = target is Map
            ? _id(target['threadChannelId']) ?? threadId
            : threadId;
        final focus = target is Map
            ? _id(target['messageId']) ?? message
            : message;
        final parent = switch (target) {
          {'kind': 'thread', 'threadParentMessageId': final String id} => id,
          null when !limited && _hasOriginal(data, channelId, message) =>
            message,
          _ => null,
        };
        if (parent == null ||
            parent.isEmpty ||
            !_canReadChannel(w, parentChannel) ||
            w.sessionScope.revokedChannels.contains(conversation) ||
            !limited &&
                target != null &&
                !_hasOriginal(data, conversation, focus)) {
          throw _unavailable;
        }
        w.navigation.navigate(
          RaftLocation.at(
            serverSlug: w.location.serverSlug,
            route: RaftRoute.channel,
            entityId: parentChannel,
            query: {'thread': '$parentChannel:$parent', 'msg': focus},
          ),
        );
        unawaited(
          w.resolveConversationChannel(parentChannel, preserveThread: true),
        );
        await w.openThreadIdentity(
          parentChannelId: parentChannel,
          parentMessageId: parent,
          focusedMessageId: focus,
          initialThreadChannelId: conversation,
          navigate: false,
        );
      case _ForwardedTask(
        :final channelId,
        :final conversationId,
        :final taskId,
      ):
        await authorizeTaskConversation(
          w.client,
          conversationId: conversationId,
          serverId: w.server!.id,
          taskId: taskId,
          parentChannelId: channelId,
          current: current,
        );
        if (!current()) return;
        final result = await w.query(
          path,
          query: {'channelId': conversationId, 'before': 0, 'after': 0},
        );
        if (!current()) return;
        if (result is! Map || !_hasOriginal(result, conversationId, message)) {
          throw _unavailable;
        }
        openTaskFromList(
          w,
          {'kind': 'task', 'taskId': taskId, 'parentChannelId': channelId},
          wide: !RaftAdaptiveWorkspace.compactOf(context),
          focusedMessageId: message,
          conversationId: conversationId,
        );
    }
  } catch (_) {
    if (current()) {
      showRaftToast(context, _unavailable.message);
    }
  }
}

/// Web `forwardedBundleBodyContent`: the forwarding note a person typed, or
/// empty when the message holds only the text the server writes ("Forwarded 2
/// messages") or nothing.
String forwardedNote(Object? metadata, String content) {
  final items = metadata is Map ? metadata['forwardedItems'] : null;
  final count = items is List ? items.length : 0;
  final generated = 'Forwarded $count message${count == 1 ? '' : 's'}';
  return content.trim() == generated
      ? ''
      : content.trim().isEmpty
      ? ''
      : content;
}
