// raft-ui 0.7.1 `Checkbox` / `CheckboxIndicator` (dist `checkboxIndicator` + `checkbox`): a 20px ink-bordered sticker
// square (or circle) with a lucide check / minus; unchecked is a `layer-card` box, checked fills with `foreground`,
// disabled reads `fill-muted` / `foreground-disabled`. Keyboard focus draws the `focus-ring` on the 20px root.
import 'package:flutter/material.dart';

import '../control_typography.dart';
import '../design_primitives.dart';
import '../recipe_surface.dart' show RaftRecipeBinding;
import '../recipes/checkbox.g.dart';
import '../recipes/recipe_runtime.dart' show RaftRecipeTheme;
import '../icons.dart';
import '../theme.dart';
import 'css_box.dart';
import '../space.dart';
import '../tokens/tokens.dart' show RaftTypeScale;
import 'ui_tokens.dart';

part 'checkbox_frozen.dart';

/// `mark` of `CheckboxIndicator`.
enum RaftCheckboxMark { check, minus }

/// `shape` of `Checkbox` / `CheckboxIndicator`.
enum RaftCheckboxShape { square, circle }

/// Authored inline variants of the shared indicator. Null fields keep the
/// standard CheckboxIndicator appearance; this never adds another control.
@immutable
class RaftCheckboxIndicatorStyle {
  const RaftCheckboxIndicatorStyle({
    this.fill,
    this.borderColor,
    this.markColor,
    this.borderWidth,
    this.radius,
    this.markSize,
    this.markStrokeWidth,
  });
  final Color? fill, borderColor, markColor;
  final double? borderWidth, radius, markSize, markStrokeWidth;
}

/// The presentational graphic (`data-slot="checkbox-indicator-graphic"`, aria-hidden).
///
/// [size] is 20 in raft-ui (`size-5`); the lucide mark is 14 (`size-3.5`) at that size and keeps its 0.7 ratio.
class RaftCheckboxIndicator extends StatelessWidget {
  const RaftCheckboxIndicator({
    super.key,
    required this.checked,
    this.mark = RaftCheckboxMark.check,
    this.shape = RaftCheckboxShape.square,
    this.disabled = false,
    this.previewOnHover = false,
    this.hovered = false,
    this.size = 20,
    this.style,
  });

  final bool checked, disabled, previewOnHover;

  /// The parent `group` is hovered (what `group-hover:text-foreground/20` reads).
  final bool hovered;
  final RaftCheckboxMark mark;
  final RaftCheckboxShape shape;
  final double size;

  /// An authored inline variant, without changing the default checkbox.
  final RaftCheckboxIndicatorStyle? style;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final Color fill, border, ink;
    // Translucent tokens are blended the way Blink does, over the box they sit on (the border over its own fill).
    if (checked) {
      final disabledFill = raftChromeBlend(
        ui.foregroundDisabled,
        ui.layerCanvas,
      );
      fill = disabled ? disabledFill : ui.foreground;
      border = disabled
          ? raftChromeBlend(ui.foregroundDisabled, disabledFill)
          : ui.foreground;
      ink = disabled ? ui.layerCard : ui['foreground-inverse'];
    } else {
      fill = disabled ? ui.fillMuted : ui.layerCard;
      border = disabled
          ? raftChromeBlend(ui.foregroundDisabled, ui.fillMuted)
          : ui.lineStrong;
      ink = previewOnHover && hovered
          ? ui.foreground.withValues(alpha: ui.foreground.a * .2)
          : const Color(0x00000000);
    }
    final showMark = checked || previewOnHover;
    return ExcludeSemantics(
      child: RaftCssBox(
        // The square form is the theme's sticker corner; the circle form is a true
        // circle at any size, which is why the official `rounded-full` stays
        // `size / 2` rather than becoming a token.
        radius:
            style?.radius ??
            (shape == RaftCheckboxShape.circle
                ? size / 2
                : t.size('radius.sticker', fallback: 4)),
        fill: style?.fill ?? fill,
        borderWidth: style?.borderWidth ?? raftControlBorderPx(context, 1.5),
        borderColor: style?.borderColor ?? border,
        width: size,
        height: size,
        alignment: Alignment.center,
        child: showMark
            ? RaftIcon(
                mark == RaftCheckboxMark.minus
                    ? RaftGlyph.minus
                    : RaftGlyph.check,
                size: style?.markSize ?? size * .7,
                strokeWidth: style?.markStrokeWidth ?? 2,
                color: style?.markColor ?? ink,
              )
            : null,
      ),
    );
  }
}

/// raft-ui `Checkbox`: controlled, with the `indeterminate` mixed state. A null [onChanged] is `disabled`. The
/// canonical checkbox of the client; [RaftCheckboxIndicator] is its graphic for rows that own the tap.
class RaftCheckbox extends StatelessWidget {
  const RaftCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.indeterminate = false,
    this.shape = RaftCheckboxShape.square,
    this.semanticLabel,
    this.focusNode,
    this.size = 20,
    this.legacyMaterial = false,
  });

  /// The frozen Elegant and Brutal looks drew this one control (the sign-up terms box) as a Material checkbox; this
  /// keeps it so. The Raft look ignores it. Delete with the legacy looks.
  final bool legacyMaterial;

  final bool value, indeterminate;
  final ValueChanged<bool>? onChanged;
  final RaftCheckboxShape shape;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final disabled = onChanged == null;
    if (legacyMaterial && !t.isRaftLook)
      return _frozenMaterialCheckbox(context, this);
    return RaftInteractive(
      onPressed: disabled
          ? null
          : () => onChanged!(indeterminate ? true : !value),
      button: false,
      checked: indeterminate ? null : value,
      focusNode: focusNode,
      semanticLabel: semanticLabel,
      builder: (context, st) => Semantics(
        mixed: indeterminate,
        child: RaftCssBox(
          // `rounded-sticker` on the root, also for the circle shape: the official
          // root keeps the sticker corner and the inner indicator draws the circle.
          radius: t.size('radius.sticker', fallback: 4),
          rings: [
            if (st.focusVisible)
              for (final layer in ui.focusRing.layers)
                RaftRing(layer.spread, layer.color),
          ],
          width: size,
          height: size,
          child: ExcludeSemantics(
            child: RaftCheckboxIndicator(
              checked: value || indeterminate,
              mark: indeterminate
                  ? RaftCheckboxMark.minus
                  : RaftCheckboxMark.check,
              shape: shape,
              disabled: disabled,
              size: size,
            ),
          ),
        ),
      ),
    );
  }
}

/// A checkbox with its title and optional description on one row (`<label><Checkbox /> title <span>description</span>
/// </label>`): the whole row toggles. The frozen Elegant and Brutal looks keep the Material list tile they drew.
class RaftCheckboxRow extends StatelessWidget {
  const RaftCheckboxRow({
    super.key,
    required this.title,
    this.description,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  /// Already localised by the caller (it may be a member's name).
  final String title;
  final String? description;
  final bool value;

  /// Null disables the row.
  final ValueChanged<bool>? onChanged;

  /// The compact row of the action card (`dense` list tile in the frozen looks).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (!t.isRaftLook) return _frozenCheckboxRow(context, this);
    final ui = t.ui;
    final disabled = onChanged == null;
    final titleText = title;
    return RaftInteractive(
      onPressed: disabled ? null : () => onChanged!(!value),
      button: false,
      checked: value,
      semanticLabel: titleText,
      builder: (context, st) => Padding(
        padding: EdgeInsets.symmetric(
          vertical: dense ? RaftSpace.x1 : RaftSpace.x2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: RaftSpace.x3,
          children: [
            // The 20px box centres on the first 20px title line.
            RaftCheckboxIndicator(checked: value, disabled: disabled),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleText,
                    style: RaftControlTypography.of(
                      context,
                      t.scale(
                        RaftTypeScale.callout,
                        weight: FontWeight.w600,
                        color: disabled ? ui.foregroundDisabled : ui.foreground,
                      ),
                    ),
                  ),
                  if (description != null)
                    Text(
                      description!,
                      style: t.scale(
                        RaftTypeScale.footnote,
                        color: disabled
                            ? ui.foregroundDisabled
                            : ui.foregroundMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
