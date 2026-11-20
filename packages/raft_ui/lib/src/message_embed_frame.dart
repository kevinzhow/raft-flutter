// The Raft look's `messageEmbed` frame (raft-ui 0.95.3
// `message-embed.recipe.mjs`): one frame, read from the generated recipe root.
// The forwarded bundle, the action card and every other embed use it; the
// frozen looks keep their 0.5.52 frames (`RaftMessageEmbedRecipe` in
// design_primitives.dart) and never reach this file.
import 'package:flutter/widgets.dart';
import 'package:raft_theme/recipes/recipe_runtime.dart';

import 'design_primitives.dart' show RaftInteractive, RaftInteractionState;
import 'panel_layout.dart' show RaftSnappedDecoratedBox;
import 'raft/css_box.dart' show RaftBorderSnap;
import 'raft/ui_tokens.dart' show raftChromeBlend;
import 'recipe_surface.dart';
import 'recipes/message_embed.g.dart' as embed;
import 'surface_background_scope.dart';
import 'theme.dart';

/// The `size` axis of `messageEmbed`: `item` is 400 wide (the whole width
/// below 768), `content` 560.
enum RaftMessageEmbedSize { item, content }

/// A text style read from a generated recipe slot (`font-*`, `line-height`,
/// colour), with the family and fallbacks the Web document would inherit.
TextStyle raftSlotTextStyle(
  RaftTokens t,
  RaftSlotStyle slot, {
  bool tabular = false,
}) {
  final base = slot.textStyle(t.recipeTokens);
  return raftCssText
      .merge(base)
      .copyWith(
        fontFamily: base.fontFamily ?? t.bodyFont,
        fontFamilyFallback: base.fontFamilyFallback ?? t.fontFallback,
        fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
      );
}

/// The slots of `messageEmbed` for [context]: root, header, content, footer.
embed.RaftMessageEmbedRecipeStyle raftMessageEmbedSlots(
  BuildContext context, {
  RaftMessageEmbedSize? size,
  bool hovered = false,
  bool pressed = false,
  bool focusVisible = false,
  bool interactive = false,
}) {
  final t = RaftTokens.of(context);
  final states = RaftRecipeStates({
    if (t.dark) RaftRecipeStates.dark,
    if (hovered) RaftRecipeStates.hover,
    if (pressed) RaftRecipeStates.active,
    if (focusVisible) RaftRecipeStates.focusVisible,
    if (interactive) 'data-interactive=true',
  }, MediaQuery.sizeOf(context).width);
  final slots = embed.RaftMessageEmbedRecipe.resolveProps(
    {'size': size?.name},
    states: states,
    tokens: t.recipeTokens,
  );
  return embed.RaftMessageEmbedRecipeStyle(
    root: slots['root']!,
    header: slots['header']!,
    content: slots['content']!,
    footer: slots['footer']!,
  );
}

/// The padding of the embed's header or footer (`px-3 py-2`).
EdgeInsets raftMessageEmbedHeaderPadding(BuildContext context) =>
    raftMessageEmbedSlots(context).header.padding;

/// `MessageEmbed`: radius 10, a 1px hairline, `layer-card`, and, when it has
/// [onPressed], the subtle overlay on hover, the medium one on press and the
/// focus ring from the keyboard. No second frame inside it.
class RaftMessageEmbedFrame extends StatelessWidget {
  const RaftMessageEmbedFrame({
    super.key,
    required this.child,
    this.size,
    this.onPressed,
    this.semanticLabel,
  });

  final Widget child;
  final RaftMessageEmbedSize? size;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  Widget _frame(
    BuildContext context, {
    bool hovered = false,
    bool pressed = false,
    bool focusVisible = false,
  }) {
    final t = RaftTokens.of(context);
    final root = raftMessageEmbedSlots(
      context,
      size: size,
      hovered: hovered,
      pressed: pressed,
      focusVisible: focusVisible,
      interactive: onPressed != null,
    ).root;
    final max = root.maxWidth;
    // The border is outside the child's box, so the child clips to the inner
    // radius (`container-1`) by itself.
    var decoration = root.decoration(t.recipeTokens);
    // `data-[interactive=true]:hover:overlay-subtle` / `:active:overlay-medium`
    // is a uniform gradient over the card fill: one blended fill here.
    final tier = onPressed == null
        ? null
        : pressed
        ? 'fill-medium'
        : hovered
        ? 'fill-subtle'
        : null;
    final base = decoration.color;
    final overlay = tier == null ? null : t.colors[tier];
    if (base != null && overlay != null) {
      decoration = decoration.copyWith(color: Color.alphaBlend(overlay, base));
    }
    final fill = decoration.color;
    final border = decoration.border;
    if (fill != null && fill.a == 1 && border is Border && border.isUniform) {
      final edge = border.top;
      if (edge.style == BorderStyle.solid &&
          edge.color.a > 0 &&
          edge.color.a < 1) {
        decoration = decoration.copyWith(
          border: Border.fromBorderSide(
            edge.copyWith(color: raftChromeBlend(edge.color, fill)),
          ),
        );
      }
    }
    final frame = RaftSnappedDecoratedBox(
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      paintDevicePixelRatio: RaftBorderSnap.emulatedDeviceScaleFactor
          ? 1
          : null,
      child: RaftSurfaceBackgroundScope(
        color: fill?.a == 1 ? fill : null,
        child: child,
      ),
    );
    // `width: 100%; max-width: ...`, left-aligned in its row.
    return Align(
      alignment: Alignment.topLeft,
      widthFactor: 1,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: max == null || max.isInfinite ? double.infinity : max,
        ),
        child: SizedBox(width: double.infinity, child: frame),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (onPressed == null) return _frame(context);
    return RaftInteractive(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      builder: (context, RaftInteractionState state) => _frame(
        context,
        hovered: state.hovered,
        pressed: state.pressed,
        focusVisible: state.focusVisible,
      ),
    );
  }
}
