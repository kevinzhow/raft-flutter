import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import '../platform/content_links.dart';

/// Web v1.24 `MessageItem.handleCopyLink`: build the permalink locally and
/// write the clipboard at once. No request runs first, so a slow or failing
/// network cannot delay or drop the copy.
Future<void> copyMessageLink(WorkspaceController w, RaftMessage message) async {
  final slug = w.server?.string('slug') ?? '';
  if (slug.isEmpty) return;
  final parent = message.channelId == w.threadChannelId
      ? w.messageDomain.state.threadParent
      : null;
  final channelId = parent?.channelId ?? message.channelId;
  final channel = w.channel?.id == channelId
      ? w.channel
      : w.channelById(channelId);
  final url = ContentLinks.messageUrl(
    origin: ContentLinks.originFor(w.client.origin),
    slug: slug,
    channelId: channelId,
    messageId: message.id,
    kind: channel?.type ?? 'channel',
    parentMessageId: parent?.id,
  );
  await Clipboard.setData(ClipboardData(text: url.toString()));
}
