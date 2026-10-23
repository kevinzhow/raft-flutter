import 'package:flutter/material.dart';

import 'design_primitives.dart';

/// The a57b9dab small icon surface, expressed through structural theme data.
/// Other interaction structures retain the existing generic control recipe.
class RaftSmallIconRecipe extends RaftControlRecipe {
  const RaftSmallIconRecipe(
    super.tokens, {
    super.variant,
    super.visualHeight,
    super.highContrast,
  });

  bool get _offsetShadow =>
      tokens.option('press.effect', or: 'overlay') == 'offsetShadow';

  // a57b9dab _RaftControlState.build: this structure lifts by 1px on hover
  // and moves by (1,1) on press. Cindy4430babb approved the internal constant;
  // themes using another press structure do not have an offset step.
  @override
  Matrix4 interactionTransform({
    required bool hovered,
    required bool pressed,
    required bool reducedMotion,
  }) => !_offsetShadow
      ? super.interactionTransform(
          hovered: hovered,
          pressed: pressed,
          reducedMotion: reducedMotion,
        )
      : !transformsOnInteraction || reducedMotion
      ? Matrix4.identity()
      : Matrix4.translationValues(
          pressed ? 1 : 0,
          pressed
              ? 1
              : hovered
              ? -1
              : 0,
          0,
        );

  @override
  Color get foreground => _offsetShadow ? tokens.strong : super.foreground;

  @override
  Color get focusRing => _offsetShadow ? Colors.transparent : super.focusRing;

  @override
  Color get background => !_offsetShadow
      ? super.background
      : switch (variant) {
          RaftControlVariant.primary => tokens.primaryFill,
          RaftControlVariant.accent => tokens.accentFill,
          RaftControlVariant.danger => tokens.colors['color-brutal-red']!,
          RaftControlVariant.ghost => Colors.transparent,
          RaftControlVariant.outline ||
          RaftControlVariant.surface => tokens.panel,
        };

  @override
  Color backgroundFor({bool hovered = false}) =>
      _offsetShadow ? background : super.backgroundFor(hovered: hovered);

  @override
  Gradient? get overlayGradient => _offsetShadow ? null : super.overlayGradient;

  @override
  double get insetHighlightAlpha =>
      _offsetShadow ? 0 : super.insetHighlightAlpha;

  @override
  BorderRadius get radius => !_offsetShadow
      ? super.radius
      : BorderRadius.circular(tokens.size('radius.controlSmall', fallback: 0));

  @override
  BorderSide side({bool hovered = false}) =>
      _offsetShadow &&
          tokens.option('control.edge', or: 'inkBorder') == 'inkBorder'
      ? BorderSide(
          color: variant == RaftControlVariant.ghost && !hovered
              ? Colors.transparent
              : tokens.colors['line-strong']!,
          width: tokens.size('stroke.control', fallback: 0),
        )
      : super.side(hovered: hovered);

  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => !_offsetShadow
      ? super.shadows(hovered: hovered, pressed: pressed, focused: focused)
      : variant == RaftControlVariant.ghost
      ? const []
      : (pressed
                ? tokens.themeShadows.xs
                : hovered
                ? tokens.themeShadows.md
                : tokens.themeShadows.sm)
            .outer;
}
