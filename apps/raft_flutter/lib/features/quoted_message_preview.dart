import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'delegated_message.dart';
import 'history_paywall_view.dart' show historyPaywallDays, openHistoryUpgrade;

import '../data/raft_permalink.dart';
import '../data/workspace_controller.dart';
import 'quoted_permalink_cache.dart';

/// Opens a Raft message permalink of this server (Web `handleOpenPermalink` /
/// `handleOpenQuotedPermalink`): a thread link opens its thread focused on the
/// message, any other link jumps to the message in its channel or DM.
Future<void> openRaftPermalink(
  WorkspaceController w,
  RaftPermalink permalink, {
  bool selectChannelRoute = false,
}) async {
  final channel = [
    ...w.channels,
    ...w.dms,
  ].where((c) => c.id == permalink.channelId).firstOrNull;
  final parent = permalink.threadParentMessageId;
  if (parent != null) {
    if (selectChannelRoute) {
      final generation = w.client.generation;
      final selecting = w.jumpToMessage(permalink.channelId, null);
      final revision = w.navigationRevision;
      final resolved = w.location.entityId == permalink.channelId;
      await selecting;
      if (w.client.generation != generation ||
          w.location.entityId != permalink.channelId ||
          w.section != 'chat' ||
          (resolved && w.navigationRevision != revision)) {
        return;
      }
    } else if (channel != null && w.channel?.id != channel.id) {
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

  /// Behind the plan's history window: who sent it and when, not what.
  HiddenHistoryMessage? older;
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
        older = null;
        unavailable = false;
      });
    }
    try {
      final result = await cache.load(link);
      if (result != null && mounted && mine == ticket) show(result);
    } catch (e) {
      if (!mounted || mine != ticket) return;
      // Older than the plan's history window: the quote keeps its header and
      // says so, with the upgrade (Web readHistoryLimitedError).
      final hidden = HiddenTarget.fromError(e)?.target;
      if (hidden == null) {
        show((target: null, archived: false));
        return;
      }
      setState(() {
        target = null;
        older = hidden;
        unavailable = false;
      });
    }
  }

  void show(QuotedPermalinkResult result) {
    final gone = result.target == null;
    if (gone && unavailable) return;
    setState(() {
      target = result.target;
      older = null;
      archived = result.archived;
      unavailable = gone;
    });
    if (gone) widget.onUnavailable();
  }

  @override
  Widget build(BuildContext context) {
    if (unavailable) return const SizedBox.shrink();
    final hidden = older;
    final message =
        target ??
        (hidden == null
            ? null
            : RaftMessage({
                'id': hidden.id,
                'channelId': widget.permalink.channelId,
                'senderId': hidden.senderId,
                'senderType': hidden.senderType,
                'senderName': hidden.senderName ?? '',
                'senderAvatarUrl': hidden.senderAvatarUrl,
                'createdAt': hidden.createdAt,
              }));
    if (message == null) return const QuotedMessageLoadingCard();
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
      authorSubtitle: hidden == null ? widget.subtitle(message) : null,
      authorDelegatedBy: delegatedByLabel(context, message, continuation: true),
      unavailableText: message.retracted
          ? raftText(context, 'This message was retracted.')
          : null,
      content: hidden == null ? message.content : '',
      notice: hidden == null
          ? null
          : RaftOlderMessageNotice(
              label: raftFormat(
                context,
                'This message is older than {days} days.',
                {'days': historyPaywallDays(w)},
              ),
              upgradeLabel: raftText(context, 'Upgrade to Pro'),
              onUpgrade: () => openHistoryUpgrade(context, w),
            ),
      attachmentLabel: attachments == null
          ? null
          : attachments.count == null
          ? raftText(context, attachments.key)
          : raftFormat(context, attachments.key, {'count': attachments.count}),
      onTap: hidden == null ? () => widget.onOpen(link) : null,
    );
  }
}

const double _quotedSkeletonHeaderHeight = 34;
const double _quotedSkeletonAvatarSize = 28;
const double _quotedSkeletonTitleWidth = 128;
const double _quotedSkeletonLastLineFactor = .75;

/// Loading skeleton matching Web v1.24 `QuotedMessagePermalinkPreview.tsx`
/// (`Card` with 34px `line-hairline` header bar, 28px block skeleton, and
/// three line skeletons).
class QuotedMessageLoadingCard extends StatelessWidget {
  const QuotedMessageLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftCard(
      key: const Key('quoted-message-skeleton'),
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: _quotedSkeletonHeaderHeight,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: raftChromeBlend(t.ui.lineHairline, t.ui.layerCard),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: RaftSpace.x3,
              vertical: RaftSpace.x2 + RaftSpace.half,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: RaftSpace.x3,
              children: [
                RaftSkeleton(
                  variant: RaftSkeletonVariant.block,
                  width: _quotedSkeletonAvatarSize,
                  height: _quotedSkeletonAvatarSize,
                  fromRecipe: true,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: RaftSpace.x2,
                    children: [
                      RaftSkeleton(
                        variant: RaftSkeletonVariant.line,
                        width: _quotedSkeletonTitleWidth,
                        fromRecipe: true,
                      ),
                      RaftSkeleton(
                        variant: RaftSkeletonVariant.line,
                        width: double.infinity,
                        fromRecipe: true,
                      ),
                      FractionallySizedBox(
                        widthFactor: _quotedSkeletonLastLineFactor,
                        child: RaftSkeleton(
                          variant: RaftSkeletonVariant.line,
                          width: double.infinity,
                          fromRecipe: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
