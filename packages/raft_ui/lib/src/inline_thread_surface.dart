import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';
import 'recipe_surface.dart';

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
  const RaftInlineThreadRecipe(this.tokens);
  final RaftTokens tokens;
  EdgeInsets get padding =>
      const EdgeInsets.symmetric(horizontal: 10, vertical: 8);
  double get topGap => 6;
  double get rowGap => 4;
  double get summaryBottomGap => tokens.brutal ? 0 : 6;
  BorderRadius get radius => BorderRadius.circular(tokens.brutal ? 0 : 6);
  BorderSide get border => tokens.brutal
      ? BorderSide.none
      : BorderSide(
          color: tokens.dark
              ? Colors.transparent
              : tokens.colors['line-muted']!,
          width: .5,
        );
  Color get normal =>
      tokens.brutal ? Colors.black.withValues(alpha: .03) : tokens.card;
  Color get muted => tokens.muted;
  TextStyle get summary => TextStyle(
    fontFamily: tokens.bodyFont,
    fontFamilyFallback: tokens.systemFonts ? tokens.fontFallback : null,
    fontSize: 12.5,
    height: tokens.brutal ? 20 / 14 : 21 / 12.5,
    fontWeight: FontWeight.w700,
    color: muted,
  );
  TextStyle get sender => TextStyle(
    fontFamily: tokens.bodyFont,
    fontFamilyFallback: tokens.systemFonts ? tokens.fontFallback : null,
    fontSize: 12.5,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: muted,
  );
  TextStyle get preview => sender.copyWith(fontWeight: FontWeight.w400);
  TextStyle get clock => TextStyle(
    fontFamily: tokens.brutal ? tokens.bodyFont : tokens.monoFont,
    fontSize: 11.5,
    height: 1.25,
    color: tokens.colors['foreground-placeholder'],
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// One parent-thread button, including every preview. System events never
/// consume the three visible slots and the summary retains the authoritative
/// total. A supplied summary may include localized unread/draft inline content.
///
/// Source Elegant OKLCH hover mix and inset elevation are explicitly controlled
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
    if (widget.replyCount <= 0 || visible.isEmpty)
      return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    final recipe = RaftInlineThreadRecipe(t);
    final enabled = widget.onOpen != null;
    final content = AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 150),
      padding: recipe.padding,
      decoration: RaftCssBoxDecoration(
        color: hovered
            ? t.brutal
                  ? Colors.black.withValues(alpha: .08)
                  : widget.hoverBackground ?? recipe.normal
            : recipe.normal,
        border: Border.fromBorderSide(recipe.border),
        borderRadius: recipe.radius,
        boxShadow: hovered ? widget.hoverShadows : widget.normalShadows,
      ),
      child: DefaultTextStyle(
        style: recipe.summary.copyWith(
          color: hovered ? t.strong : recipe.muted,
        ),
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
          child: MouseRegion(
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

  @override
  Widget build(BuildContext context) => LayoutBuilder(
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
        border: Border.all(
          color: t.brutal ? Colors.black : t.colors['line-muted']!,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(
          t.brutal
              ? 0
              : circular
              ? 10
              : 4,
        ),
      ),
      child: child,
    );
  }
}
