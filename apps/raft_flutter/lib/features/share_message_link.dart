import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../platform/content_links.dart';
import '../platform/native_sharing.dart';
import '../platform/content_coordinator.dart';
import '../platform/content_target.dart';

Future<void> shareMessageLink(
  BuildContext context,
  WorkspaceController w,
  RaftMessage message, {
  bool copy = false,
}) async {
  final generation = w.client.generation,
      principal = w.client.user?.id,
      server = w.client.serverId;
  final channel = w.channel;
  if (channel == null || principal == null || server == null) return;
  final parent = message.channelId == w.threadChannelId ? w.threadParent : null;
  final channelId = parent?.channelId ?? message.channelId;
  bool valid() =>
      context.mounted &&
      generation == w.client.generation &&
      principal == w.client.user?.id &&
      server == w.client.serverId &&
      w.channel?.id == channel.id &&
      (w.messages.any((m) => m.id == message.id) ||
          w.replies.any((m) => m.id == message.id) ||
          w.threadParent?.id == message.id);
  try {
    await NativeContentCoordinator.authorize(
      w,
      ContentTarget(
        serverId: server,
        channelId: channelId,
        messageId: message.id,
        parentMessageId: parent?.id,
        threadId: parent == null ? null : w.threadChannelId,
      ),
      valid,
    );
    if (!valid()) return;
    final url = ContentLinks.messageUrl(
      origin: ContentLinks.originFor(w.client.origin),
      slug: w.server!.string('slug'),
      channelId: channelId,
      messageId: message.id,
      kind: channel.type,
      parentMessageId: parent?.id,
    ).toString();
    if (copy) {
      await Clipboard.setData(ClipboardData(text: url));
    } else {
      await NativeSharing().shareText(
        url,
        title: context.mounted ? raftText(context, 'Share message link') : null,
      );
    }
  } catch (_) {
    if (context.mounted && valid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            raftText(context, 'The message link could not be shared.'),
          ),
        ),
      );
    }
  }
}
