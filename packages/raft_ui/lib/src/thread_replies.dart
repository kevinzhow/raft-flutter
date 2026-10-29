import 'hover_region.dart';

import 'package:flutter/material.dart';

import 'control_typography.dart';
import 'components.dart';
import 'localization.dart';
import 'text_scaling.dart' show RaftScaled;
import 'theme.dart';
import 'icons.dart';
import 'design_primitives.dart';
import 'recipes/badge.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';

@immutable
class RaftThreadReplyPreview {
  const RaftThreadReplyPreview({
    required this.id,
    required this.author,
    required this.preview,
    required this.senderType,
    this.timestamp = '',
  });
  final String id, author, preview, senderType, timestamp;
}

/// A muted conversation preview. Counts are authoritative; system events never
/// consume one of the three visible conversation slots.
class RaftThreadReplies extends StatelessWidget {
  const RaftThreadReplies({
    super.key,
    required this.replies,
    required this.replyCount,
    required this.onOpen,
    required this.onOpenReply,
    this.unreadCount = 0,
    this.hasDraft = false,
  });
  final List<RaftThreadReplyPreview> replies;
  final int replyCount, unreadCount;
  final bool hasDraft;
  final VoidCallback? onOpen;
  final ValueChanged<String>? onOpenReply;

  @override
  Widget build(BuildContext context) {
    final visible = replies
        .where(
          (r) =>
              r.id.isNotEmpty &&
              {'user', 'agent', 'external_projection'}.contains(r.senderType),
        )
        .take(3)
        .toList();
    if (replyCount <= 0 || visible.isEmpty) return const SizedBox.shrink();
    final tokens = RaftTokens.of(context);
    final count = raftFormat(
      context,
      replyCount == 1 ? '{count} reply' : '{count} replies',
      {'count': replyCount},
    );
    final suffix = [
      if (unreadCount > 0)
        raftFormat(context, '{count} new', {'count': unreadCount}),
      if (hasDraft) raftText(context, 'Draft'),
    ];
    final label = [count, ...suffix].join(' · ');
    // Larger text: a reply stacks (author and time above, the preview wrapped
    // below) instead of squeezing the preview out of a single line.
    final grows = RaftScaled.grows(context);
    final style = ButtonStyle(
      alignment: Alignment.centerLeft,
      minimumSize: WidgetStatePropertyAll(const Size(48, 48)),
      padding: WidgetStatePropertyAll(
        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      // Frozen TextButton.styleFrom foreground also supplied these overlays.
      overlayColor: WidgetStateProperty.fromMap({
        WidgetState.pressed: tokens.muted.withValues(alpha: .1),
        WidgetState.hovered: tokens.muted.withValues(alpha: .08),
        WidgetState.focused: tokens.muted.withValues(alpha: .1),
      }),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? null : tokens.muted,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: RaftShapes.field(tokens),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RaftButton.text(
                onPressed: onOpen,
                legacyStyle: style,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const RaftIcon(RaftGlyph.chevronRight, size: 10),
                  ],
                ),
              ),
              for (final reply in visible)
                RaftButton.text(
                  key: ValueKey('thread-preview-${reply.id}'),
                  onPressed: onOpenReply == null
                      ? null
                      : () => onOpenReply!(reply.id),
                  legacyStyle: style,
                  child: Semantics(
                    label: raftFormat(
                      context,
                      'Open reply by {name}: {preview}',
                      {'name': reply.author, 'preview': reply.preview},
                    ),
                    excludeSemantics: true,
                    child: grows
                        ? _stackedReply(reply)
                        : Row(
                            children: [
                              _replyAvatar(reply),
                              const SizedBox(width: 6),
                              Flexible(
                                flex: 3,
                                child: Text(
                                  reply.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _authorStyle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 5,
                                child: Text(
                                  reply.preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _previewStyle,
                                ),
                              ),
                              if (reply.timestamp.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(reply.timestamp, style: _timeStyle),
                              ],
                            ],
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static const _authorStyle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
  );
  static const _previewStyle = TextStyle(fontSize: 12.5);
  static const _timeStyle = TextStyle(fontSize: 11.5);

  Widget _replyAvatar(RaftThreadReplyPreview reply) =>
      reply.senderType == 'user'
      ? RaftAvatar(name: reply.author, size: 20)
      : RaftSymbol(
          reply.senderType == 'agent' ? Icons.smart_toy_outlined : Icons.apps,
          size: 20,
        );

  Widget _stackedReply(RaftThreadReplyPreview reply) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 2,
        children: [
          _replyAvatar(reply),
          Text(reply.author, style: _authorStyle),
          if (reply.timestamp.isNotEmpty)
            Text(reply.timestamp, style: _timeStyle),
        ],
      ),
      const SizedBox(height: 2),
      // `clip`, not ellipsis: an ellipsis without maxLines keeps one line.
      Text(reply.preview, overflow: TextOverflow.clip, style: _previewStyle),
    ],
  );
}

/// Web `ThreadRepliesBadge.tsx`: the message footer "N replies · M new" chip.
/// raft-ui `Badge` — appearance soft/variant information
/// with unread replies, solid/default otherwise; MessageSquare/Pencil 12.
class RaftThreadRepliesBadge extends StatefulWidget {
  const RaftThreadRepliesBadge({
    super.key,
    required this.replyCount,
    this.unreadCount = 0,
    this.hasDraft = false,
    this.onPressed,
  });
  final int replyCount, unreadCount;
  final bool hasDraft;
  final VoidCallback? onPressed;

  @override
  State<RaftThreadRepliesBadge> createState() => _RaftThreadRepliesBadgeState();
}

class _RaftThreadRepliesBadgeState extends State<RaftThreadRepliesBadge> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final hasReplies = widget.replyCount > 0;
    final hasUnread = widget.unreadCount > 0;
    if (!hasReplies && !widget.hasDraft) return const SizedBox.shrink();
    final tokens = RaftTokens.of(context);
    final resolver = RaftRecipeTokens(tokens);
    final s = RaftBadgeRecipe.resolve(
      theme: RaftRecipeTheme.elegant,
      appearance: hasUnread
          ? RaftBadgeRecipeAppearance.soft
          : RaftBadgeRecipeAppearance.solid,
      variant: hasUnread
          ? RaftBadgeRecipeVariant.information
          : RaftBadgeRecipeVariant.default_,
      states: RaftRecipeStates({
        if (hovered && widget.onPressed != null) RaftRecipeStates.hover,
      }),
      tokens: resolver,
    ).root;
    // The badge sets no family: it inherits MessageItem's `font-display`.
    final text = RaftControlTypography.of(
      context,
      s
          .textStyle(resolver)
          .copyWith(
            fontFamily: tokens.headingFont,
            leadingDistribution: TextLeadingDistribution.even,
          ),
    );
    final color = text.color;
    final gap = SizedBox(width: s.columnGap ?? 4);
    Widget dot() => Opacity(opacity: .6, child: Text('·', style: text));
    final children = <Widget>[
      if (hasReplies) ...[
        RaftIcon(RaftGlyph.messageSquare, size: 12, color: color),
        gap,
        Text(
          raftFormat(
            context,
            widget.replyCount == 1 ? '{count} reply' : '{count} replies',
            {'count': widget.replyCount},
          ),
          style: text,
        ),
      ] else
        RaftIcon(RaftGlyph.pencil, size: 12, color: color),
      if (hasUnread) ...[
        gap,
        dot(),
        gap,
        Text(
          raftFormat(context, '{count} new', {'count': widget.unreadCount}),
          style: text,
        ),
      ],
      if (widget.hasDraft) ...[
        if (hasReplies || hasUnread) ...[gap, dot()],
        if (hasReplies) ...[
          gap,
          RaftIcon(RaftGlyph.pencil, size: 12, color: color),
        ],
        gap,
        Opacity(
          opacity: .8,
          child: Text(raftText(context, 'draft'), style: text),
        ),
      ],
    ];
    Widget badge = Container(
      height: s.height,
      padding: s.padding,
      decoration: s.decoration(resolver),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
    // `enabled:hover:brightness-90`.
    if (hovered && widget.onPressed != null) {
      badge = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          .9, 0, 0, 0, 0, //
          0, .9, 0, 0, 0, //
          0, 0, .9, 0, 0, //
          0, 0, 0, 1, 0, //
        ]),
        child: badge,
      );
    }
    return Semantics(
      button: true,
      child: RaftHoverRegion(
        cursor: widget.onPressed == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          key: const ValueKey('message-thread-replies-badge'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: badge,
        ),
      ),
    );
  }
}
