import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'indicators.dart';
import 'message_content_tokens.dart';
import 'recipe_surface.dart';
import 'recipes/markdown.g.dart';
import 'recipes/message_translation.g.dart';
import 'recipes/recipe_runtime.dart';
import 'theme.dart';
import 'tooltip.dart';

/// Web MessageItem `TranslationIndicator` tones.
enum RaftMessageTranslationTone {
  /// A translation is shown (or its original): a Show original / Show
  /// translation toggle.
  normal,

  /// `Translating…` with a pulsing icon and no action.
  pending,

  /// `Translation unavailable · Retry`.
  failed,
}

/// Web MessageItem `TranslationIndicator` (`MessageItemTranslationStatus` /
/// `MessageItemTranslationFailedStatus` with `MessageItemTranslationAction` /
/// `MessageItemTranslationRetryAction`): a 12px Languages (or alert) icon,
/// an optional status text and an optional underlined action.
class RaftMessageTranslationStatus extends StatelessWidget {
  const RaftMessageTranslationStatus({
    super.key,
    required this.tone,
    required this.tooltip,
    this.message,
    this.actionLabel,
    this.onAction,
  });
  final RaftMessageTranslationTone tone;

  /// Web `title`: the action's tooltip, or the whole indicator's when there
  /// is no action.
  final String tooltip;
  final String? message, actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = t.recipeTokens;
    final recipe = RaftMessageTranslationRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: tokens,
    );
    final failed = tone == RaftMessageTranslationTone.failed;
    final slot = failed
        ? recipe.translationFailedStatus
        : recipe.translationStatus;
    final style = slot.text(tokens, base: DefaultTextStyle.of(context).style);
    final gap = slot.columnGap ?? 6;
    Widget icon = RaftIcon(
      failed ? RaftGlyph.triangleAlert : RaftGlyph.languages,
      size: 12,
      color: style.color,
    );
    if (tone == RaftMessageTranslationTone.pending) {
      icon = RaftPulse(child: icon);
    }
    final label = actionLabel;
    final action = label == null || label.isEmpty
        ? null
        : _RaftTranslationAction(
            key: const ValueKey('message-translation-action'),
            label: label,
            tooltip: tooltip,
            retry: failed,
            base: style,
            onPressed: onAction,
          );
    final text = message;
    final indicator = DefaultTextStyle.merge(
      style: style,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          if (text != null && text.isNotEmpty) ...[
            SizedBox(width: gap),
            Flexible(child: Text(text)),
          ],
          if (text != null && text.isNotEmpty && action != null) ...[
            SizedBox(width: gap),
            const ExcludeSemantics(child: Text('·')),
          ],
          if (action != null) ...[SizedBox(width: gap), action],
        ],
      ),
    );
    return action == null
        ? RaftTooltip(message: tooltip, child: indicator)
        : indicator;
  }
}

class _RaftTranslationAction extends StatefulWidget {
  const _RaftTranslationAction({
    super.key,
    required this.label,
    required this.tooltip,
    required this.retry,
    required this.base,
    required this.onPressed,
  });
  final String label, tooltip;
  final bool retry;
  final TextStyle base;
  final VoidCallback? onPressed;
  @override
  State<_RaftTranslationAction> createState() => _RaftTranslationActionState();
}

class _RaftTranslationActionState extends State<_RaftTranslationAction> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = t.recipeTokens;
    final recipe = RaftMessageTranslationRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(hovered: hovered),
      tokens: tokens,
    );
    final slot = widget.retry
        ? recipe.translationRetryAction
        : recipe.translationAction;
    final style = slot.text(tokens, base: widget.base);
    final decoration = slot['text-decoration-line'];
    final underline =
        decoration is CssKeyword && decoration.value == 'underline';
    final decorationColor = RaftColorRef.fromCss(slot['text-decoration-color'])
        ?.resolve(tokens, currentColor: style.color);
    final background = slot.backgroundColor?.resolve(
      tokens,
      currentColor: style.color,
    );
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: RaftControl(
        kind: RaftControlKind.textLink,
        shadow: true,
        visualHeight: 16,
        minimumTargetSize: 16,
        padding: EdgeInsets.zero,
        semanticLabel: widget.label,
        tooltip: widget.tooltip,
        onPressed: widget.onPressed,
        child: AnimatedContainer(
          duration: slot.transitionDuration ?? Duration.zero,
          curve: slot.transitionCurve ?? Curves.linear,
          padding: slot.padding,
          decoration: BoxDecoration(
            color: background ?? Colors.transparent,
            borderRadius: slot.borderRadius,
          ),
          child: ExcludeSemantics(
            child: Text(
              widget.label,
              style: style.copyWith(
                decoration: underline ? TextDecoration.underline : null,
                decorationColor: decorationColor ?? style.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Web `animate-pulse` (opacity 1 → .5 → 1 over 2 s); still under reduced
/// motion.
class RaftPulse extends StatefulWidget {
  const RaftPulse({super.key, required this.child});
  final Widget child;
  @override
  State<RaftPulse> createState() => _RaftPulseState();
}

class _RaftPulseState extends State<RaftPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  static const _curve = Cubic(.4, 0, .6, 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      pulse
        ..stop()
        ..value = 0;
    } else if (!pulse.isAnimating) {
      pulse.repeat();
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: pulse,
    builder: (context, child) {
      final v = pulse.value, half = v < .5 ? v * 2 : (1 - v) * 2;
      return Opacity(opacity: 1 - .5 * _curve.transform(half), child: child);
    },
    child: widget.child,
  );
}

/// Web MessageItem's pending-translation body: `Skeleton variant="line"
/// className="inline-block w-44 max-w-full align-middle"` on the body's
/// first line box, so the row keeps one body line while it waits.
class RaftMessageTranslationSkeleton extends StatelessWidget {
  const RaftMessageTranslationSkeleton({super.key, this.fontSize = 14});

  /// Message body font size (the line box follows the body's line height).
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final line =
        MessageContentRecipe(
          t,
          fontSize: fontSize,
          mountedMessage: true,
        ).body.height! *
        fontSize;
    return SizedBox(
      key: const ValueKey('message-translation-skeleton'),
      height: line,
      child: const Align(
        alignment: Alignment.centerLeft,
        child: _SkeletonLine(),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => RaftSkeleton(
      variant: RaftSkeletonVariant.line,
      // `w-44 max-w-full`.
      width: constraints.maxWidth.isFinite
          ? constraints.maxWidth.clamp(0, 176).toDouble()
          : 176,
    ),
  );
}

/// Web `MessageItemTranslationOriginal` (a `MarkdownBlockquote`, `not-italic`
/// and `mt-1.5`) with its `MessageItemTranslationOriginalLabel`: the
/// bilingual view's original text below the translation.
class RaftMessageTranslationOriginal extends StatelessWidget {
  const RaftMessageTranslationOriginal({
    super.key,
    required this.label,
    required this.child,
  });
  final String label;
  final Widget child;

  /// The quote's text colour, which Web markdown prose inside it inherits.
  static Color? foreground(BuildContext context) {
    final t = RaftTokens.of(context), tokens = t.recipeTokens;
    return RaftMarkdownRecipe.resolve(
      theme: t.recipeTheme,
      tokens: tokens,
    ).blockquote.foreground(tokens);
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = t.recipeTokens;
    final quote = RaftMarkdownRecipe.resolve(
      theme: t.recipeTheme,
      tokens: tokens,
    ).blockquote;
    final recipe = RaftMessageTranslationRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: tokens,
    );
    final base = DefaultTextStyle.of(context).style;
    final labelSlot = recipe.translationOriginalLabel;
    var labelText = label;
    if (labelSlot.textTransform == 'uppercase') {
      labelText = labelText.toUpperCase();
    }
    final quoteText = quote
        .text(tokens, base: base)
        .copyWith(fontStyle: FontStyle.normal);
    final margin = quote.margin;
    return Padding(
      // `mt-1.5` replaces the blockquote's top margin.
      padding: EdgeInsets.only(top: 6, bottom: margin.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: quote.maxWidth ?? double.infinity,
        ),
        child: RaftRecipeBox(
          style: quote,
          tokens: tokens,
          applyText: false,
          child: DefaultTextStyle(
            style: quoteText,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: labelSlot.margin,
                  child: Text(
                    labelText,
                    style: labelSlot.text(tokens, base: quoteText),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
