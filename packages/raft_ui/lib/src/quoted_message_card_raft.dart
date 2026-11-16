// The Raft look's quoted-message card: Web `QuotedMessageCard` on `PreviewShell`
// with raft-ui 0.95.3 `messageQuotedPreview` slots. One flat frame (radius 10,
// hairline, `layer-card`); hover lays `overlay-subtle`, press `overlay-medium`
// (only a tappable, non-muted preview), keyboard focus the focus ring. The
// frozen looks keep the 0.5.52 card in quoted_message_card.dart.
import 'token_geometry.dart';
import 'package:flutter/material.dart';

import 'design_primitives.dart' show RaftInteractive, RaftInteractionState;
import 'flex_shrink_row.dart';
import 'icons.dart';
import 'indicators.dart';
import 'localization.dart';
import 'message_embed_frame.dart' show raftSlotTextStyle;
import 'quoted_message_card.dart';
import 'raft/ui_tokens.dart';
import 'raft_underline.dart';
import 'recipe_surface.dart';
import 'package:raft_theme/recipes/message_quoted_preview.g.dart';
import 'theme.dart';

class RaftQuotedMessageCardRaft extends StatelessWidget {
  const RaftQuotedMessageCardRaft({super.key, required this.card});

  final RaftQuotedMessageCard card;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final slots = RaftMessageQuotedPreviewRecipe.resolve(
      states: t.recipeStates(responsive: true),
      tokens: t.recipeTokens,
    );
    final radius = t.corner('radius.container', fallback: 10);
    final unavailable = card.unavailableText;
    if (unavailable != null) {
      return _Shell(
        key: const Key('quoted-message-card'),
        radius: radius,
        muted: true,
        onTap: card.onTap,
        child: Container(
          key: const ValueKey('quoted-message-unavailable'),
          width: double.infinity,
          child: Text(
            unavailable,
            style: raftSlotTextStyle(t, slots.unavailable),
          ),
        ),
      );
    }
    final hint = t.ui.foregroundHint;
    final channel = raftSlotTextStyle(t, slots.channel);
    final thread = raftSlotTextStyle(t, slots.thread);
    final name = raftSlotTextStyle(t, slots.authorName);
    final meta = raftSlotTextStyle(t, slots.authorMeta);
    final delegated = raftSlotTextStyle(t, slots.authorDelegatedBy);
    final stamp = raftSlotTextStyle(t, slots.timestamp, tabular: true);
    final text = raftSlotTextStyle(t, slots.text);
    final chip = raftSlotTextStyle(t, slots.attachment);
    final dot = Text('·', style: channel.copyWith(color: hint));
    final notice = card.notice;
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: slots.header.columnGap ?? 6,
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  if (!card.isDm)
                    RaftIcon(RaftGlyph.hash, size: 14, color: channel.color),
                  Text(
                    card.isDm ? '@${card.channelName}' : card.channelName,
                    style: channel,
                  ),
                ],
              ),
              dot,
              // `inline-flex min-w-0 items-center gap-1.5`.
              RaftFlexShrinkRow(
                gap: 6,
                truncating: true,
                fixed: const {0},
                children: [
                  card.avatar,
                  Text(
                    card.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: name,
                  ),
                  if (card.authorDelegatedBy != null)
                    Text(
                      card.authorDelegatedBy!,
                      key: const ValueKey('quoted-message-delegated-by'),
                      maxLines: 1,
                      style: delegated,
                    ),
                  if (card.authorSubtitle != null)
                    Text(
                      card.authorSubtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: meta,
                    ),
                ],
              ),
              if (card.isThread) ...[
                dot,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    RaftIcon(RaftGlyph.thread, size: 14, color: thread.color),
                    Text(raftTextZh(context, 'Thread', '消息列'), style: thread),
                  ],
                ),
              ],
              if (card.isArchived) ...[
                dot,
                // A stopped state, not a problem: stone, not orange.
                RaftBadge(
                  label: raftText(context, 'Archived'),
                  appearance: RaftBadgeRecipeAppearance.soft,
                  variant: RaftBadgeRecipeVariant.muted,
                ),
              ],
            ],
          ),
        ),
        Text(card.timestamp, style: stamp),
      ],
    );
    final body = notice != null
        ? DefaultTextStyle.merge(
            style: text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            child: notice,
          )
        : RaftUnderlines(
            child: Text.rich(
              raftInlineMarkdownSpan(
                card.content,
                text,
                linkColor: t.colors['foreground-link'] ?? t.ui.foreground,
                code: text.copyWith(fontFamily: t.monoFont),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          );
    final attachment = card.attachmentLabel;
    final attachmentCorner = slots.attachment.borderRadius?.topLeft.x ?? 6;
    return _Shell(
      key: const Key('quoted-message-card'),
      radius: radius,
      onTap: notice != null ? null : card.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(padding: const EdgeInsets.only(bottom: 4), child: header),
          body,
          if (notice == null && attachment != null)
            Padding(
              padding: EdgeInsets.only(top: slots.attachments.margin.top),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  key: const ValueKey('quoted-message-attachment'),
                  constraints: BoxConstraints(
                    minHeight: slots.attachment.height ?? 22,
                  ),
                  padding: slots.attachment.padding,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.ui.fillMuted,
                    borderRadius: BorderRadius.circular(attachmentCorner),
                  ),
                  child: Text(attachment, style: chip),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `PreviewShell`: the hairline card skin; a tappable one reacts to hover and
/// press, the muted one never does.
class _Shell extends StatelessWidget {
  const _Shell({
    super.key,
    required this.radius,
    required this.child,
    this.onTap,
    this.muted = false,
  });

  final BorderRadius radius;
  final Widget child;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    Widget frame(RaftInteractionState? state) {
      final base = muted ? ui.fillMuted : ui.layerCard;
      final overlay = muted || state == null
          ? null
          : state.pressed
          ? t.colors['fill-medium']!
          : state.hovered
          ? t.colors['fill-subtle']!
          : null;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: overlay == null ? base : Color.alphaBlend(overlay, base),
          borderRadius: radius,
          border: Border.all(color: ui.lineHairline),
          boxShadow: state?.focusVisible == true ? t.focusShadows : null,
        ),
        child: Padding(
          // `px-3 py-2.5` inside the 1px border.
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: child,
        ),
      );
    }

    if (onTap == null) {
      return SizedBox(width: double.infinity, child: frame(null));
    }
    return SizedBox(
      width: double.infinity,
      child: RaftInteractive(
        onPressed: onTap,
        builder: (context, state) => frame(state),
      ),
    );
  }
}
