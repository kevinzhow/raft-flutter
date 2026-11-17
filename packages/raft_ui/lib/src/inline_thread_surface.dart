import 'hover_region.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'message_row_recipe.dart' show RaftMessageSizeScope, RaftMessageSizeTier;
import 'theme.dart';
import 'recipe_surface.dart';
import 'text_scaling.dart' show RaftScaled;

/// Plain recipient-projected fields. Avatar resolution and clock formatting are
/// owned by the authorized adapter; this widget never looks up an identity.
@immutable
class RaftInlineReply {
  const RaftInlineReply({
    required this.id,
    required this.author,
    required this.preview,
    required this.senderType,
    this.timestamp = '',
    this.avatar,
  });
  final String id, author, preview, senderType, timestamp;
  final Widget? avatar;
}

/// Product InlineThreadReplies extends messageReplies + messageEmbed +
/// messageBlock. These geometry/type overrides are separate from generic cards.
@immutable
class RaftInlineThreadRecipe {
  const RaftInlineThreadRecipe(
    this.tokens, {
    this.sizeTier = RaftMessageSizeTier.md,
  });
  final RaftTokens tokens;

  /// The reader's message size: the sender, preview and time classes
  /// (`getMessagePreviewSizeClass`, `getMessagePreviewTimeSizeClass`).
  final RaftMessageSizeTier sizeTier;

  /// raft-ui 0.95.3 `messageReplies`: `mt-2 gap-1 px-2.5 py-2 bg-fill-muted`,
  /// no border or radius.
  EdgeInsets get padding =>
      const EdgeInsets.symmetric(horizontal: 10, vertical: 8);
  double get topGap => 8;
  double get rowGap => 4;
  double get summaryBottomGap => 0;
  BorderRadius get radius => BorderRadius.zero;
  Color get normal => tokens.colors['fill-muted']!;

  /// `hover:overlay-subtle`: the subtle fill laid over the block.
  Color get hover => Color.alphaBlend(
    tokens.colors['fill-subtle']!,
    tokens.colors['fill-muted']!,
  );
  Color get muted => tokens.colors['foreground-muted']!;
  Color get hint => tokens.colors['foreground-hint']!;

  /// `text-footnote` / `text-caption` at the reader's size: -1 / 0 / +1
  /// (`getMessagePreviewSizeClass`, `getMessagePreviewTimeSizeClass`).
  double get _tierStep => switch (sizeTier) {
    RaftMessageSizeTier.sm => -1,
    RaftMessageSizeTier.md => 0,
    RaftMessageSizeTier.lg => 1,
  };

  TextStyle _slot(String slot, {double step = 0, FontWeight? weight}) {
    final spec = tokens.typeSlot(slot);
    return TextStyle(
      fontFamily: tokens.bodyFont,
      fontSize: spec.fontSize + step,
      height: spec.lineHeight / (spec.fontSize + step),
      fontWeight: weight,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  /// `messageReplies.summary`: `text-footnote font-bold`.
  TextStyle get summary =>
      _slot('footnote', weight: FontWeight.w700).copyWith(color: muted);
  TextStyle get sender => _slot(
    'footnote',
    step: _tierStep,
    weight: FontWeight.w600,
  ).copyWith(color: muted);
  TextStyle get preview =>
      sender.copyWith(fontWeight: FontWeight.w400, color: hint);

  /// `messageReplies.time`: `font-mono text-mono-meta tabular-nums
  /// text-foreground-hint` at caption -1 / 0 / +1.
  TextStyle get clock {
    final spec = tokens.typeSlot('caption');
    final size = spec.fontSize + _tierStep;
    return TextStyle(
      fontFamily: tokens.monoFont,
      fontSize: size,
      height: spec.lineHeight / size,
      color: hint,
      leadingDistribution: TextLeadingDistribution.even,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}

/// One parent-thread button, including every preview. System events never
/// consume the three visible slots and the summary retains the authoritative
/// total. A supplied summary may include localized unread/draft inline content.
///
/// The source OKLCH hover mix and inset elevation are explicitly controlled
/// paint slots until the shared messageBlock effect recipe is adopted. Null
/// slots preserve the source normal card, never substitute a generic button.
class RaftInlineThreadSurface extends StatefulWidget {
  const RaftInlineThreadSurface({
    super.key,
    required this.replyCount,
    required this.replies,
    required this.summary,
    required this.semanticLabel,
    this.onOpen,
    this.focusNode,
    this.hoverBackground,
    this.normalShadows = const [],
    this.hoverShadows = const [],
  });
  final int replyCount;
  final List<RaftInlineReply> replies;
  final Widget summary;
  final String semanticLabel;
  final VoidCallback? onOpen;
  final FocusNode? focusNode;
  final Color? hoverBackground;
  final List<BoxShadow> normalShadows, hoverShadows;
  @override
  State<RaftInlineThreadSurface> createState() =>
      _RaftInlineThreadSurfaceState();
}

class _RaftInlineThreadSurfaceState extends State<RaftInlineThreadSurface> {
  final ownFocus = FocusNode();
  bool hovered = false, focusVisible = false;
  FocusNode get focus => widget.focusNode ?? ownFocus;
  void invokeOpen() => widget.onOpen?.call();
  @override
  void dispose() {
    ownFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.replies
        .where((r) => r.senderType != 'system')
        .take(3)
        .toList();
    if (widget.replyCount <= 0 || visible.isEmpty) {
      return const SizedBox.shrink();
    }
    final t = RaftTokens.of(context);
    final recipe = RaftInlineThreadRecipe(
      t,
      sizeTier: RaftMessageSizeScope.of(context),
    );
    final enabled = widget.onOpen != null;
    final content = AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 150),
      padding: recipe.padding,
      decoration: RaftCssBoxDecoration(
        color: hovered ? widget.hoverBackground ?? recipe.hover : recipe.normal,
        boxShadow: hovered ? widget.hoverShadows : widget.normalShadows,
      ),
      child: DefaultTextStyle(
        style: recipe.summary.copyWith(color: recipe.summary.color),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.summary,
            SizedBox(height: recipe.summaryBottomGap + recipe.rowGap),
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) SizedBox(height: recipe.rowGap),
              _ReplyRow(
                key: ValueKey('inline-reply-${visible[i].id}'),
                reply: visible[i],
                recipe: recipe,
              ),
            ],
          ],
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(top: recipe.topGap),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.semanticLabel,
        onTap: enabled ? invokeOpen : null,
        excludeSemantics: true,
        child: FocusableActionDetector(
          enabled: enabled,
          focusNode: focus,
          onShowFocusHighlight: (value) => setState(() => focusVisible = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                invokeOpen();
                return null;
              },
            ),
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
              onInvoke: (_) {
                invokeOpen();
                return null;
              },
            ),
          },
          child: RaftHoverRegion(
            cursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            onEnter: enabled ? (_) => setState(() => hovered = true) : null,
            onExit: (_) => setState(() => hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: enabled ? invokeOpen : null,
              child: Stack(
                children: [
                  content,
                  if (focusVisible)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: recipe.radius,
                            border: Border.all(
                              color: t.colors['line-strong']!,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplyRow extends StatelessWidget {
  const _ReplyRow({super.key, required this.reply, required this.recipe});
  final RaftInlineReply reply;
  final RaftInlineThreadRecipe recipe;
  double textWidth(BuildContext context, String value, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  // Larger text: author and time sit on one wrapping line and the preview wraps
  // below them, instead of the preview being squeezed out of a single row.
  Widget stacked() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 2,
        children: [
          ExcludeSemantics(
            child: SizedBox.square(dimension: 20, child: reply.avatar),
          ),
          Text(reply.author, style: recipe.sender),
          if (reply.timestamp.isNotEmpty)
            Text(reply.timestamp, style: recipe.clock),
        ],
      ),
      const SizedBox(height: 2),
      // `clip`: an ellipsis without maxLines keeps a single line in Flutter.
      Text(reply.preview, style: recipe.preview, overflow: TextOverflow.clip),
    ],
  );

  @override
  Widget build(BuildContext context) => RaftScaled.grows(context)
      ? stacked()
      : LayoutBuilder(
          builder: (context, constraints) {
            // Mirrors sender shrink/truncate + content flex:1 + fixed clock. Flexible
            // sender retains intrinsic width whenever space is available, not a 3:5 grid.
            final clockWidth = reply.timestamp.isEmpty
                ? 0.0
                : textWidth(context, reply.timestamp, recipe.clock);
            final budget = math.max(
              0.0,
              constraints.maxWidth -
                  20 -
                  6 -
                  6 -
                  (clockWidth > 0 ? clockWidth + 6 : 0),
            );
            final authorWidth = math.min(
              budget,
              textWidth(context, reply.author, recipe.sender),
            );
            return Row(
              children: [
                ExcludeSemantics(
                  child: SizedBox.square(dimension: 20, child: reply.avatar),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: authorWidth,
                  child: Text(
                    reply.author,
                    style: recipe.sender,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    reply.preview,
                    style: recipe.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (clockWidth > 0) ...[
                  const SizedBox(width: 6),
                  Text(reply.timestamp, style: recipe.clock),
                ],
              ],
            );
          },
        );
}

/// Mounted AvatarSlot compact-list frame: 20px, one-pixel border. The host
/// supplies authorized artwork; this frame performs no identity lookup.
class RaftInlineReplyAvatar extends StatelessWidget {
  const RaftInlineReplyAvatar({
    super.key,
    required this.child,
    this.circular = false,
  });
  final Widget child;
  final bool circular;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      width: 20,
      height: 20,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.colors['fill-muted'],
        border: Border.all(color: t.colors['line-muted']!, width: 1),
        borderRadius: BorderRadius.circular(circular ? 10 : 4),
      ),
      child: child,
    );
  }
}
