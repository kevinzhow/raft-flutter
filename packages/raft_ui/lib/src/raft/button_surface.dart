import 'package:flutter/material.dart';

import '../design_primitives.dart' show RaftInteractionState;
import '../recipe_surface.dart';
import '../recipes/button_variants.g.dart';
import '../recipes/recipe_runtime.dart';
import '../theme.dart';
import '../tokens/tokens.dart';
import 'button.dart' show RaftButtonMetrics, RaftButtonSize, RaftButtonVariant;
import 'button_colors.dart';
import 'css_box.dart' show raftControlBorderPx;

/// One button surface: geometry, edge, sheen, elevation and motion are separate.
class RaftButtonSurface extends StatelessWidget {
  const RaftButtonSurface({
    super.key,
    required this.variant,
    required this.size,
    required this.metrics,
    required this.colors,
    required this.state,
    required this.disabled,
    required this.padding,
    required this.expand,
    required this.child,
  });
  final RaftButtonVariant variant;
  final RaftButtonSize size;
  final RaftButtonMetrics metrics;
  final RaftButtonColors colors;
  final RaftInteractionState state;
  final bool disabled, expand;
  final EdgeInsets padding;
  final Widget child;

  static CssValue _color(Color value) =>
      CssColor(value.toARGB32(), null, value);

  static CssValue _shadow(RaftCssShadow layer) => CssSeq([
    if (layer.inset) const CssKeyword('inset'),
    CssNum(layer.offset.dx, 'px'),
    CssNum(layer.offset.dy, 'px'),
    CssNum(layer.blur, 'px'),
    CssNum(layer.spread, 'px'),
    _color(layer.color),
  ]);

  RaftButtonRecipeVariant get _recipeVariant => switch (variant) {
    RaftButtonVariant.standard => RaftButtonRecipeVariant.default_,
    RaftButtonVariant.dangerSecondary =>
      RaftButtonRecipeVariant.dangerSecondary,
    RaftButtonVariant.dangerOutline => RaftButtonRecipeVariant.dangerOutline,
    RaftButtonVariant.onFrame => RaftButtonRecipeVariant.ghost,
    _ => RaftButtonRecipeVariant.values.byName(variant.name),
  };

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final inline = size == RaftButtonSize.inline;
    final edge = t.option('control.edge', or: 'inkBorder');
    final sheen = t.option('control.sheen', or: 'none') == 'gradient';
    final width = t.size('stroke.control', fallback: 1.5);
    final border = !inline && edge == 'inkBorder' && width > 0
        ? raftControlBorderPx(context, width)
        : 0.0;
    final radius = inline
        ? 0.0
        : t.size(
            metrics.height < 32 ? 'radius.controlSmall' : 'radius.control',
            fallback: 8,
          );
    final shadows = <CssValue>[];
    Map<String, Map<String, CssValue>> targets = {};
    // The generated recipe supplies the original ring/sheens only. Its fill,
    // geometry, elevation and transforms never select the button's renderer.
    if (edge == 'ring' || sheen) {
      final reference = RaftButtonRecipe.resolve(
        theme: RaftRecipeTheme.elegant,
        variant: _recipeVariant,
        size: size == RaftButtonSize.xl
            ? RaftButtonRecipeSize.lg
            : RaftButtonRecipeSize.values.byName(size.name),
        states: t.recipeStates(
          hovered: state.hovered && !disabled,
          pressed: state.pressed && !disabled,
          focusVisible: state.focusVisible && !disabled,
        ),
        tokens: rt,
      ).root;
      for (final layer in reference.boxShadow) {
        // Foundation shadow tokens are read independently from the pack below.
        if (layer is! RaftLiteralShadow) continue;
        if (layer.inset ? sheen : edge == 'ring') {
          shadows.add(
            _shadow(
              RaftCssShadow(
                inset: layer.inset,
                offset: layer.offset,
                blur: layer.blur,
                spread: layer.spread,
                color: layer.color.resolve(rt, currentColor: colors.foreground),
              ),
            ),
          );
        }
      }
      if (sheen && reference.before != null) {
        targets = {'::before': reference.before!.properties};
      }
    }
    if (colors.ringEdge != null) {
      shadows.add(
        _shadow(
          RaftCssShadow(
            inset: false,
            offset: Offset.zero,
            blur: 0,
            spread: t.size('stroke.control', fallback: 1.5),
            color: colors.ringEdge!,
          ),
        ),
      );
    }
    if (state.focusVisible && !disabled && edge != 'ring') {
      shadows.addAll(t.shadowLayers('shadow.focusRing').map(_shadow));
    }
    final shadowRole = variant == RaftButtonVariant.dangerOutline
        ? 'shadow.buttonDangerOutline'
        : variant == RaftButtonVariant.success
        ? 'shadow.buttonSuccess'
        : state.pressed && !disabled
        ? 'shadow.buttonPressed'
        : state.hovered && !disabled
        ? 'shadow.buttonHover'
        : 'shadow.control';
    if (!variant.isTransparent) {
      shadows.addAll(t.shadowLayers(shadowRole).map(_shadow));
    }
    final props = <String, CssValue>{
      'background-color': _color(colors.fill),
      if (!inline) 'height': CssNum(metrics.height, 'px'),
      for (final side in ['top', 'right', 'bottom', 'left']) ...{
        'border-$side-width': CssNum(border, 'px'),
        'border-$side-style': const CssKeyword('solid'),
        'border-$side-color': _color(colors.border),
        'padding-$side': CssNum(switch (side) {
          'top' => padding.top,
          'right' => padding.right,
          'bottom' => padding.bottom,
          _ => padding.left,
        }, 'px'),
      },
      for (final corner in [
        'top-left',
        'top-right',
        'bottom-left',
        'bottom-right',
      ])
        'border-$corner-radius': CssNum(radius, 'px'),
      'box-shadow': CssList(shadows),
    };
    if (!disabled && !MediaQuery.disableAnimationsOf(context)) {
      final motion = t.option('press.effect', or: 'overlay');
      if (motion == 'scale' && state.pressed) {
        props['scale'] = const CssNum(.985);
      } else if (motion == 'offsetShadow' &&
          variant != RaftButtonVariant.success &&
          variant != RaftButtonVariant.ghost &&
          variant != RaftButtonVariant.link &&
          variant != RaftButtonVariant.onFrame) {
        props['translate'] = CssSeq([
          CssNum(state.pressed ? 1 : 0, 'px'),
          CssNum(
            state.pressed
                ? 1
                : state.hovered
                ? -1
                : 0,
            'px',
          ),
        ]);
      }
    }
    return RaftRecipeBox(
      style: RaftSlotStyle(props, targets, const [], rt),
      tokens: rt,
      overflowCenter: true,
      applyOpacity: false,
      width: metrics.square
          ? metrics.height
          : expand
          ? double.infinity
          : null,
      child: child,
    );
  }
}
