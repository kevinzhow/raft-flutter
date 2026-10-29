// Presentation of the Web AgentDetailPanel "Chat" tab (AgentChatTab,
// packages/web/src/components/agent/AgentDetailPanel.tsx + AgentDMConversationList
// + ui/cards/ConversationPreviewCard): a `border-b` eyebrow strip, a Channels
// section of SurfaceListItem cards and an Agent DMs section of conversation
// preview cards. The app adapter owns loading and data.
//
// The insets differ BY DESIGN and are reproduced as such: strip / section
// headers `px-5` (20), channel cards `px-4` (16) + `space-y-3`, DM list `p-4`,
// DM card `p-3` with its own border (1px line-muted, brutal 2px black/30)
// that is not the SurfaceListItem border.
import 'card.dart' show RaftCard;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'agent_profile.dart' show RaftPanelText;
import 'collapsible.dart' show RaftShowMoreToggle;
import 'dialog_card.dart' show RaftTextSteps, raftCssTextStyle;
import 'error_presentation.dart' show RaftErrorBanner;
import 'icons.dart';
import 'list_items.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText;
import 'product_empty_state.dart';
import 'recipe_surface.dart';
import 'recipes/empty_state.g.dart';
import 'theme.dart';

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
    final bg = t.colors['layer-panel']!;
    final rule = t.colors['line-muted']!;
    final sectionRule = t.colors['line-muted']!;
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
              // `border-b theme-brutal:border-b-2 ... px-5 py-3`
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                border: Border(bottom: BorderSide(color: rule, width: 1)),
              ),
              child: RaftSectionEyebrow(raftText(context, 'Channels & DMs')),
            ),
            if (empty)
              Padding(
                // `EmptyState className="px-5 py-14"`: the call site's padding
                // replaces the recipe root padding.
                padding: EdgeInsets.symmetric(
                  vertical: math.max(
                    0,
                    56 -
                        RaftEmptyStateRecipe.resolve(
                          theme: t.recipeTheme,
                          states: t.recipeStates(),
                          tokens: t.recipeTokens,
                        ).root.padding.top,
                  ),
                ),
                child: RaftProductEmptyState(
                  title: raftText(context, 'No chats yet'),
                  description: raftText(
                    context,
                    'When this agent joins channels or has agent-to-agent DM activity, those chat surfaces will appear here.',
                  ),
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
                  border: Border(bottom: BorderSide(color: sectionRule)),
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

  Widget _header(
    BuildContext context,
    RaftTokens t,
    String label,
    String text,
  ) => Padding(
    // `px-5 py-3`
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftSectionHeader(label: label),
        const SizedBox(height: 4),
        RaftCssText(
          text,
          style: RaftPanelText.caption(t)
              .copyWith(color: t.colors['foreground-muted']),
        ),
      ],
    ),
  );

  Widget _errorRow(String message) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: RaftErrorBanner(message, small: true, bold: true),
  );

  /// `flex items-center gap-3 border ... bg-fill-muted px-3 py-2` inside `px-4 pb-4`.
  Widget _inlineEmpty(
    BuildContext context,
    RaftTokens t, {
    required Widget icon,
    required String title,
    required String description,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.colors['fill-muted'],
        border: Border.all(color: t.colors['line-muted']!),
      ),
      child: Row(
        children: [
          IconTheme.merge(
            data: IconThemeData(color: t.colors['foreground-placeholder']),
            child: icon,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RaftCssText(
                  title,
                  style: raftCssTextStyle(
                    family: t.bodyFont,
                    step: RaftTextSteps.sm,
                    weight: FontWeight.w700,
                    color: t.colors['foreground-muted'],
                  ),
                ),
                const SizedBox(height: 2),
                RaftCssText(
                  description,
                  style: raftCssTextStyle(
                    family: t.bodyFont,
                    step: RaftTextSteps.xs,
                    color: t.colors['foreground-placeholder'],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        _header(
          context,
          t,
          raftText(context, 'Channels'),
          raftText(
            context,
            'Channels where this agent can read or participate.',
          ),
        ),
        if (widget.channelsError != null)
          _errorRow(widget.channelsError!)
        else if (widget.channels.isEmpty)
          _inlineEmpty(
            context,
            t,
            icon: const RaftIcon(RaftGlyph.hash, size: 18),
            title: raftText(context, 'No channels yet'),
            description: raftText(
              context,
              'Channel memberships will appear here.',
            ),
          )
        else
          Padding(
            // `space-y-3 px-4 pb-4`
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                for (final c in shown) _channelCard(context, t, c),
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

  Widget _channelCard(
    BuildContext context,
    RaftTokens t,
    RaftAgentChannelRow c,
  ) {
    final placeholder = t.colors['foreground-placeholder']!;
    final muted = t.colors['foreground-muted'];
    final description = c.description?.trim();
    return RaftCard.item(
      onTap: c.onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RaftIcon(
                      c.type == 'private' ? RaftGlyph.lock : RaftGlyph.hash,
                      size: 14,
                      color: placeholder,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: RaftCssText(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: raftCssTextStyle(
                          family: t.bodyFont,
                          step: RaftTextSteps.sm,
                          weight: FontWeight.w700,
                          color: t.strong,
                        ),
                      ),
                    ),
                    if (c.activityMuted) ...[
                      const SizedBox(width: 8),
                      RaftIcon(RaftGlyph.bellOff, size: 13, color: placeholder),
                    ],
                  ],
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  RaftCssText(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: raftCssTextStyle(
                      family: t.bodyFont,
                      step: RaftTextSteps.xs,
                      color: muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (c.type != 'channel') ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: t.colors['line-muted']!),
              ),
              child: RaftCssText(
                raftText(context, c.type == 'private' ? 'Private' : 'Joint'),
                style: raftCssTextStyle(
                  family: t.monoFont,
                  step: (11, 16.5),
                  color: t.colors['foreground-muted'],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dms(BuildContext context, RaftTokens t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _header(
        context,
        t,
        raftText(context, 'Agent DMs'),
        raftText(context, 'Direct conversations involving this agent.'),
      ),
      if (widget.dmsError != null)
        _errorRow(widget.dmsError!)
      else if (widget.dms.isEmpty)
        _inlineEmpty(
          context,
          t,
          icon: const RaftDirectMessageIcon(size: 18),
          title: raftText(context, 'No agent-to-agent DMs yet'),
          description: raftText(
            context,
            'Recent agent-to-agent DM activity will appear here.',
          ),
        )
      else
        Padding(
          // `p-4 space-y-3`
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
/// gap-3 rounded-md border p-3`, border-line-muted bg-layer-panel; brutal
/// `rounded-none border-2 border-black/30 bg-white`.
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
    final hint = t.colors['foreground-hint'] ?? t.colors['foreground-muted']!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.colors['layer-panel'],
        border: Border.all(color: t.colors['line-muted']!, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
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
                  style: raftCssTextStyle(
                    family: t.bodyFont,
                    step: (12, 16),
                    weight: FontWeight.w700,
                    color: hint,
                  ),
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
                        style: raftCssTextStyle(
                          family: t.bodyFont,
                          step: (12, 16),
                          weight: FontWeight.w700,
                          color: t.strong,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    RaftCssText(
                      authorSubtitle,
                      style: raftCssTextStyle(
                        family: t.monoFont,
                        step: (10, 16),
                        color: hint,
                      ),
                    ),
                  ],
                ),
                if (timestamp.isNotEmpty)
                  RaftCssText(
                    timestamp,
                    style: raftCssTextStyle(
                      family: t.monoFont,
                      step: (12, 16),
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
            style: raftCssTextStyle(
              family: t.bodyFont,
              step: RaftTextSteps.sm,
              color: t.strong,
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 4),
            RaftCssText(
              raftText(context, footer!),
              style: raftCssTextStyle(
                family: t.monoFont,
                step: (11, 16.5),
                color: Colors.black.withValues(alpha: .45),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
