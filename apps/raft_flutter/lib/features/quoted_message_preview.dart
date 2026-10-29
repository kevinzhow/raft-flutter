import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_permalink.dart';
import '../data/workspace_controller.dart';

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

  Future<void> load() async {
    final mine = ++ticket;
    final link = widget.permalink;
    setState(() {
      target = null;
      unavailable = false;
    });
    try {
      final data = await w.client.get(
        '/messages/context/${link.messageId}',
        query: {'channelId': link.channelId},
      );
      if (!mounted || mine != ticket) return;
      final rows = (data is Map ? data['messages'] as List? : null) ?? const [];
      final id =
          (data is Map ? data['targetMessageId'] : null) ?? link.messageId;
      final row = rows.whereType<Map>().where((m) => m['id'] == id).firstOrNull;
      if (row == null) {
        fail();
        return;
      }
      setState(() {
        target = RaftMessage(Map<String, dynamic>.from(row));
        archived = data is Map && data['channelArchived'] == true;
      });
    } catch (_) {
      if (mounted && mine == ticket) fail();
    }
  }

  void fail() {
    setState(() => unavailable = true);
    widget.onUnavailable();
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
