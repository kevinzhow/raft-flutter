// Presentation of the Web AgentDetailPanel "Chat" tab (AgentChatTab,
// features/agent/AgentChatTab.tsx + AgentChatInlineEmpty +
// AgentDMConversationList + ui/cards/ConversationPreviewCard). The app adapter
// owns loading and data.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'card.dart' show RaftCard;
import 'collapsible.dart' show RaftShowMoreToggle;
import 'error_presentation.dart' show RaftErrorBanner;
import 'icons.dart';
import 'list_items.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText;
import 'product_empty_state.dart';
import 'raft/raft.dart';
import 'recipes/badge.g.dart' show RaftBadgeRecipeAppearance;
import 'recipes/empty_state.g.dart';
import 'recipes/recipe_runtime.dart' show RaftRecipeStates;
import 'recipes/token_binding.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;
import 'tooltip.dart';

@immutable
class RaftAgentChannelRow {
  const RaftAgentChannelRow({
    required this.id,
    required this.name,
    this.description,
    this.type = 'channel',
    this.activityMuted = false,
    this.muteFromSeq,
    this.onTap,
  });
  final String id, name, type;
  final String? description;
  final bool activityMuted;
  final Object? muteFromSeq;
  final VoidCallback? onTap;
}

@immutable
class RaftAgentDmRow {
  const RaftAgentDmRow({
    required this.id,
    required this.name,
    required this.handle,
    required this.avatar,
    required this.timestamp,
    required this.preview,
  });
  final String id, name, handle, timestamp;

  /// `AvatarSlot preview-mini` (14px), built by the adapter.
  final Widget avatar;

  /// Last message preview, or null for "No messages yet".
  final String? preview;
}

class RaftAgentChatView extends StatefulWidget {
  const RaftAgentChatView({
    super.key,
    required this.channels,
    required this.dms,
    this.channelsError,
    this.dmsError,
  });
  final List<RaftAgentChannelRow> channels;
  final List<RaftAgentDmRow> dms;

  /// A failed channels / DMs read (English source): the section shows
  /// `<Banner intent="warning" density="sm" className="font-bold">` in
  /// `px-5 pb-4`, like Web.
  final String? channelsError, dmsError;

  /// `AGENT_CHAT_CHANNEL_PREVIEW_LIMIT`.
  static const channelPreviewLimit = 5;

  @override
  State<RaftAgentChatView> createState() => _RaftAgentChatViewState();
}

class _RaftAgentChatViewState extends State<RaftAgentChatView> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final bg = t.ui.layerCanvas;
    final rule = t.ui.lineHairline;
    final empty =
        widget.channels.isEmpty &&
        widget.dms.isEmpty &&
        widget.channelsError == null &&
        widget.dmsError == null;
    return ColoredBox(
      color: bg,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                border: Border(bottom: BorderSide(color: rule)),
              ),
              child: RaftSectionEyebrow(raftText(context, 'Channels & DMs')),
            ),
            if (empty)
              Padding(
                // `EmptyState className="px-(--surface-inset) py-14"`: the call
                // site's padding replaces the recipe root padding.
                padding: EdgeInsets.symmetric(
                  vertical: math.max(
                    0,
                    56 -
                        RaftEmptyStateRecipe.resolve(
                          states: RaftRecipeStates({
                            if (t.dark) RaftRecipeStates.dark,
                          }),
                          tokens: RaftRecipeTokens(t),
                        ).root.padding.top,
                  ),
                ),
                child: RaftProductEmptyState(
                  title: raftText(context, 'No chats yet'),
                  icon: (context, size, color) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RaftIcon(RaftGlyph.hash, size: 34, color: color),
                      const SizedBox(width: 12),
                      RaftChatIcon(size: 34, color: color),
                    ],
                  ),
                ),
              )
            else ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: rule)),
                ),
                child: _channels(context, t),
              ),
              _dms(context, t),
            ],
          ],
        ),
      ),
    );
  }

  /// `px-(--surface-inset) py-3` with the heading alone (v1.24 AgentChatTab).
  Widget _header(String label) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: RaftSectionHeader(label: label),
  );

  Widget _errorRow(String message) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: RaftErrorBanner(message, small: true, bold: true),
  );

  /// `AgentChatInlineEmpty`: `px-(--surface-inset) pb-4`, `IconTile size="sm"` +
  /// callout title + caption description (no border box).
  Widget _inlineEmpty(
    BuildContext context,
    RaftTokens t, {
    required RaftGlyph glyph,
    Widget Function(double size, Color color)? iconBuilder,
    required String title,
    required String description,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: Row(
      children: [
        RaftIconTile(
          glyph: glyph,
          iconBuilder: iconBuilder,
          size: RaftIconTileSize.sm,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RaftCssText(
                title,
                style: t.scale(
                  RaftTypeScale.callout,
                  weight: FontWeight.w600,
                  color: t.ui.foregroundMuted,
                ),
              ),
              RaftCssText(
                description,
                style: t.scale(
                  RaftTypeScale.caption,
                  color: t.ui.foregroundHint,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _channels(BuildContext context, RaftTokens t) {
    final canExpand =
        widget.channels.length > RaftAgentChatView.channelPreviewLimit;
    final shown = expanded
        ? widget.channels
        : widget.channels.take(RaftAgentChatView.channelPreviewLimit).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(raftText(context, 'Channels')),
        if (widget.channelsError != null)
          _errorRow(widget.channelsError!)
        else if (widget.channels.isEmpty)
          _inlineEmpty(
            context,
            t,
            glyph: RaftGlyph.hash,
            title: raftText(context, 'No channels yet'),
            description: raftText(
              context,
              'Channel memberships will appear here.',
            ),
          )
        else
          Padding(
            // `stack-y-2 px-4 pb-4`
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                RaftListRowGroup(
                  children: [for (final c in shown) _channelRow(context, t, c)],
                ),
                if (canExpand)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RaftShowMoreToggle(
                      key: const ValueKey('agent-channels-show-all'),
                      label: expanded
                          ? raftText(context, 'Show Fewer')
                          : raftFormat(context, 'Show All {count} Channels', {
                              'count': widget.channels.length,
                            }),
                      onPressed: () => setState(() => expanded = !expanded),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _channelRow(
    BuildContext context,
    RaftTokens t,
    RaftAgentChannelRow c,
  ) {
    final description = c.description?.trim();
    final glyph = switch (c.type) {
      'private' => RaftGlyph.lock,
      'joint' => RaftGlyph.gitBranch,
      _ => RaftGlyph.hash,
    };
    final muteMessage = c.muteFromSeq != null
        ? raftFormat(context, 'Activity muted from message #{seq}', {
            'seq': c.muteFromSeq,
          })
        : raftText(context, 'Activity muted');
    return RaftListRow(
      tone: c.activityMuted ? RaftListRowTone.muted : RaftListRowTone.normal,
      onPressed: c.onTap,
      children: [
        RaftIconTile(
          glyph: glyph,
          semanticLabel: raftText(
            context,
            c.type == 'private' ? 'Private channel' : 'Channel',
          ),
        ),
        RaftListRowBody(
          children: [
            RaftListRowTop(
              children: [
                RaftListRowTitle(c.name),
                if (c.activityMuted)
                  RaftTooltip(
                    message: muteMessage,
                    child: RaftIcon(
                      RaftGlyph.bellOff,
                      size: 13,
                      color: t.ui.foregroundHint,
                      semanticLabel: muteMessage,
                    ),
                  ),
              ],
            ),
            if (description != null && description.isNotEmpty)
              RaftListRowDescription(description),
          ],
        ),
        if (c.type != 'channel')
          RaftBadge(
            label: raftText(context, c.type == 'private' ? 'Private' : 'Joint'),
            appearance: RaftBadgeRecipeAppearance.outline,
          ),
      ],
    );
  }

  Widget _dms(BuildContext context, RaftTokens t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _header(raftText(context, 'Agent DMs')),
      if (widget.dmsError != null)
        _errorRow(widget.dmsError!)
      else if (widget.dms.isEmpty)
        _inlineEmpty(
          context,
          t,
          glyph: RaftGlyph.messageSquare,
          iconBuilder: (size, color) =>
              RaftDirectMessageIcon(size: size, color: color),
          title: raftText(context, 'No agent-to-agent DMs yet'),
          description: raftText(
            context,
            'Recent agent-to-agent DM activity will appear here.',
          ),
        )
      else
        Padding(
          // `p-4 stack-y-3`
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              for (final d in widget.dms)
                RaftConversationPreviewCard.agentDm(d),
            ],
          ),
        ),
    ],
  );
}

/// `ConversationPreviewCard` (non-interactive): `relative flex w-full items-start
/// gap-3 rounded-container border border-line-hairline bg-layer-card p-3`.
class RaftConversationPreviewCard extends StatelessWidget {
  const RaftConversationPreviewCard({
    super.key,
    required this.channelLabel,
    required this.author,
    required this.authorAvatar,
    required this.authorSubtitle,
    required this.timestamp,
    required this.preview,
    this.footer,
  });

  factory RaftConversationPreviewCard.agentDm(RaftAgentDmRow d) =>
      RaftConversationPreviewCard(
        key: ValueKey('agent-dm-${d.id}'),
        channelLabel: 'Agent DM',
        author: d.name,
        authorAvatar: d.avatar,
        authorSubtitle: d.handle,
        timestamp: d.timestamp,
        preview: d.preview,
        footer: 'Activity only',
      );

  final String channelLabel, author, authorSubtitle, timestamp;
  final Widget authorAvatar;
  final String? preview, footer;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final hint = t.ui.foregroundHint;
    return RaftCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                RaftCssText(
                  raftText(context, channelLabel),
                  style: t.scale(RaftTypeScale.caption, color: hint),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    authorAvatar,
                    const SizedBox(width: 4),
                    Flexible(
                      child: RaftCssText(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.scale(
                          RaftTypeScale.caption,
                          weight: FontWeight.w600,
                          color: t.ui.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    RaftCssText(
                      authorSubtitle,
                      style: t.scale(
                        RaftTypeScale.monoMeta,
                        mono: true,
                        color: hint,
                      ),
                    ),
                  ],
                ),
                if (timestamp.isNotEmpty)
                  RaftCssText(
                    timestamp,
                    style: t.scale(
                      RaftTypeScale.monoMeta,
                      mono: true,
                      color: hint,
                    ),
                  ),
              ],
            ),
          ),
          RaftCssText(
            preview ?? raftText(context, 'No messages yet'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: t.scale(RaftTypeScale.callout, color: t.ui.foregroundMuted),
          ),
          if (footer != null) ...[
            const SizedBox(height: 4),
            RaftCssText(
              raftText(context, footer!),
              style: t.scale(RaftTypeScale.monoMeta, mono: true, color: hint),
            ),
          ],
        ],
      ),
    );
  }
}
