import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'primitive_tokens.dart';
import 'theme.dart';
import 'icons.dart';

/// Mounted MessageItem.tsx reactions deliberately override generic RUI chips.
@immutable
class RaftMountedReactionRecipe extends RaftControlRecipe {
  const RaftMountedReactionRecipe(
    super.tokens, {
    this.reacted = false,
    this.failure = false,
  }) : super(variant: RaftControlVariant.ghost, visualHeight: 20);
  final bool reacted, failure;
  @override
  bool get transformsOnInteraction => false;
  @override
  double get focusOutlineWidth => 2;
  @override
  double get focusOutlineOffset => 2;
  @override
  Color get focusRing =>
      tokens.brutal ? Colors.black : tokens.colors['line-strong']!;
  @override
  BorderRadius get radius => BorderRadius.circular(4);
  @override
  EdgeInsets get padding => const EdgeInsets.symmetric(horizontal: 6);
  @override
  Color get foreground =>
      tokens.brutal ? RaftPrimitives.rgbaff000000 : tokens.strong;
  @override
  Color foregroundFor({bool hovered = false}) => foreground;
  @override
  Color get background => backgroundFor();
  @override
  Color backgroundFor({bool hovered = false}) {
    if (hovered)
      return reacted ? tokens.accentSoft : tokens.colors['fill-muted']!;
    if (failure)
      return tokens.colors[tokens.brutal ? 'color-brutal-orange' : 'warning']!
          .withValues(alpha: .3);
    if (reacted)
      return tokens.brutal
          ? tokens.colors['color-brutal-pink']!.withValues(alpha: .2)
          : tokens.accentSoft;
    final fill = tokens.colors['fill-muted']!;
    return fill.withValues(alpha: fill.a * .4);
  }

  @override
  TextStyle get textStyle => TextStyle(
    fontFamily: tokens.headingFont,
    fontSize: 12,
    height: 1,
    fontWeight: FontWeight.w700,
    color: foreground,
  );
  @override
  BorderSide side({bool hovered = false}) =>
      const BorderSide(color: Colors.transparent, width: 0);
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => const [];
}

/// Controlled paint and permission. The adapter supplies current reactor label
/// and glyph asset. Read-only projection is a span, not a dimmed disabled button.
class RaftMountedReaction extends StatelessWidget {
  const RaftMountedReaction({
    super.key,
    required this.label,
    required this.glyph,
    required this.count,
    this.onPressed,
    this.reacted = false,
    this.failure = false,
  });
  final String label;
  final Widget glyph;
  final int count;
  final VoidCallback? onPressed;
  final bool reacted, failure;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftMountedReactionRecipe(
      t,
      reacted: reacted,
      failure: failure,
    );
    final content = ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(dimension: 15, child: glyph),
          const SizedBox(width: 4),
          RaftReactionCount(
            count: count,
            style: recipe.textStyle.copyWith(fontFamily: t.monoFont),
          ),
        ],
      ),
    );
    if (onPressed == null) {
      return Semantics(
        label: label,
        child: Container(
          height: 20,
          padding: recipe.padding,
          decoration: BoxDecoration(
            color: recipe.background,
            borderRadius: recipe.radius,
          ),
          child: content,
        ),
      );
    }
    return RaftControl(
      onPressed: onPressed,
      semanticLabel: label,
      visualHeight: 20,
      // Mounted MessageItem uses the same 20px flow/hit in both pointer modes.
      // Generic controls retain their independent native touch target policy.
      minimumTargetSize: 20,
      shadow: true,
      padding: recipe.padding,
      recipe: recipe,
      child: content,
    );
  }
}

/// Actual source count bump, only on a changed value; reduced motion suppresses it.
class RaftReactionCount extends StatefulWidget {
  const RaftReactionCount({
    super.key,
    required this.count,
    required this.style,
  });
  final int count;
  final TextStyle style;
  @override
  State<RaftReactionCount> createState() => _RaftReactionCountState();
}

class _RaftReactionCountState extends State<RaftReactionCount>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  bool moving = false;
  @override
  void didUpdateWidget(covariant RaftReactionCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count &&
        !MediaQuery.disableAnimationsOf(context)) {
      moving = true;
      controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) && controller.isAnimating) {
      controller.stop();
      moving = false;
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final value = controller.value;
        final first = value < .45;
        final progress = const Cubic(
          .2,
          0,
          .2,
          1,
        ).transform(first ? value / .45 : (value - .45) / .55);
        final offset = !moving
            ? 0.0
            : first
            ? 1 - 2 * progress
            : -1 + progress;
        final scale = !moving
            ? 1.0
            : first
            ? .92 + .24 * progress
            : 1.16 - .16 * progress;
        final opacity = !moving || !first ? 1.0 : .7 + .3 * progress;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, offset),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: Text('${widget.count}', style: widget.style),
    );
  }
}

/// Mounted MessageItem mobile add-reaction button; source md:hidden controls
/// its placement. Paint, hit and flow are 20px, independent of generic buttons.
class RaftMountedReactionAdd extends StatelessWidget {
  const RaftMountedReactionAdd({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => RaftControl(
    semanticLabel: label,
    tooltip: label,
    onPressed: onPressed,
    visualHeight: 20,
    minimumTargetSize: 20,
    recipe: _ReactionAddRecipe(RaftTokens.of(context)),
    child: const ExcludeSemantics(
      child: RaftIcon(RaftGlyph.plus, size: 13, strokeWidth: 2.5),
    ),
  );
}

class _ReactionAddRecipe extends RaftMountedReactionRecipe {
  const _ReactionAddRecipe(super.tokens);
  @override
  Color backgroundFor({bool hovered = false}) => tokens.brutal
      ? Colors.black.withValues(alpha: hovered ? .08 : .03)
      : super.backgroundFor(hovered: hovered);
  @override
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => backgroundFor(hovered: hovered || pressed);
}
