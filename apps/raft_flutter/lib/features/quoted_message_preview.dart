import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'delegated_message.dart';

import '../data/raft_permalink.dart';
import '../data/workspace_controller.dart';
import 'quoted_permalink_cache.dart';

/// Opens a Raft message permalink of this server (Web `handleOpenPermalink` /
/// `handleOpenQuotedPermalink`): a thread link opens its thread focused on the
/// message, any other link jumps to the message in its channel or DM.
Future<void> openRaftPermalink(
  WorkspaceController w,
  RaftPermalink permalink,
) async {
  final channel = [
    ...w.channels,
    ...w.dms,
  ].where((c) => c.id == permalink.channelId).firstOrNull;
  final parent = permalink.threadParentMessageId;
  if (parent != null) {
    if (channel != null && w.channel?.id != channel.id) {
      await w.selectChannel(channel);
    }
    await w.openThreadIdentity(
      parentChannelId: permalink.channelId,
      parentMessageId: parent,
      focusedMessageId: permalink.messageId,
    );
    return;
  }
  await w.jumpToMessage(permalink.channelId, permalink.messageId);
}

/// Web QuotedMessagePermalinkPreview: loads the linked message's context and
/// shows it as a quoted card (a skeleton while loading, nothing when the
/// target cannot be read).
class QuotedMessagePermalinkPreview extends StatefulWidget {
  const QuotedMessagePermalinkPreview({
    super.key,
    required this.controller,
    required this.permalink,
    required this.avatar,
    required this.subtitle,
    required this.formatTimestamp,
    required this.onOpen,
    required this.onUnavailable,
  });
  final WorkspaceController controller;
  final RaftPermalink permalink;

  /// Compact-list avatar and subtitle of the quoted message's sender.
  final Widget Function(RaftMessage target) avatar;
  final String? Function(RaftMessage target) subtitle;

  /// Web `formatShortDateTime`.
  final String Function(DateTime) formatTimestamp;
  final void Function(RaftPermalink permalink) onOpen;
  final VoidCallback onUnavailable;

  @override
  State<QuotedMessagePermalinkPreview> createState() =>
      _QuotedMessagePermalinkPreviewState();
}

class _QuotedMessagePermalinkPreviewState
    extends State<QuotedMessagePermalinkPreview> {
  WorkspaceController get w => widget.controller;
  RaftMessage? target;
  bool archived = false, unavailable = false;
  int ticket = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant QuotedMessagePermalinkPreview old) {
    super.didUpdateWidget(old);
    if (old.permalink != widget.permalink) load();
  }

  @override
  void dispose() {
    ticket++;
    super.dispose();
  }

  /// A link that resolved before shows its last result at once (no
  /// skeleton); the cache refreshes it in the background.
  Future<void> load() async {
    final mine = ++ticket;
    final link = widget.permalink;
    final cache = QuotedPermalinkCache.of(w);
    final cached = cache.peek(link);
    if (cached != null) {
      show(cached);
    } else {
      setState(() {
        target = null;
        unavailable = false;
      });
    }
    try {
      final result = await cache.load(link);
      if (result != null && mounted && mine == ticket) show(result);
    } catch (_) {
      if (mounted && mine == ticket) show((target: null, archived: false));
    }
  }

  void show(QuotedPermalinkResult result) {
    final gone = result.target == null;
    if (gone && unavailable) return;
    setState(() {
      target = result.target;
      archived = result.archived;
      unavailable = gone;
    });
    if (gone) widget.onUnavailable();
  }

  @override
  Widget build(BuildContext context) {
    if (unavailable) return const SizedBox.shrink();
    final message = target;
    if (message == null) return const RaftQuotedMessageSkeleton();
    final link = widget.permalink;
    final channel = [
      ...w.channels,
      ...w.dms,
    ].where((c) => c.id == link.channelId).firstOrNull;
    final type = message.string('senderType');
    final name = message.string('senderName').isNotEmpty
        ? message.string('senderName')
        : raftText(
            context,
            type == 'agent'
                ? 'Agent'
                : type == 'external_projection'
                ? 'External person'
                : 'Member',
          );
    final attachments = quotedAttachmentLabel(message.attachments);
    final created = message.createdAt;
    return RaftQuotedMessageCard(
      channelName: channel != null
          ? (channel.type == 'dm'
                ? channel.string(
                    'peerDisplayName',
                    channel.string('peerName', channel.name),
                  )
                : channel.name)
          : raftText(context, link.isDm ? 'Direct message' : 'Channel'),
      isDm: link.isDm,
      isThread: link.threadParentMessageId != null,
      isArchived: archived || channel?.archived == true,
      timestamp: created == null
          ? ''
          : widget.formatTimestamp(created).replaceFirst(',', ' ·'),
      authorName: name,
      avatar: widget.avatar(message),
      authorSubtitle: widget.subtitle(message),
      authorDelegatedBy: delegatedByLabel(context, message, continuation: true),
      unavailableText: message.retracted
          ? raftText(context, 'This message was retracted.')
          : null,
      content: message.content,
      attachmentLabel: attachments == null
          ? null
          : attachments.count == null
          ? raftText(context, attachments.key)
          : raftFormat(context, attachments.key, {'count': attachments.count}),
      onTap: () => widget.onOpen(link),
    );
  }
}
