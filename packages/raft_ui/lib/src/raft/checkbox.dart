// raft-ui `Checkbox` / `CheckboxIndicator`, painted in the Raft look from the generated `checkbox` and
// `checkboxIndicator` recipes (raft_theme recipes/checkbox.g.dart, checkbox_indicator.g.dart): box size, border,
// radius, fill, mark colour and size, the focus ring and the disabled colours are whatever the recipe resolves for
// the control's state. The frozen Elegant and Brutal paint lives in checkbox_frozen.dart.
import 'package:flutter/material.dart';

import '../control_typography.dart';
import '../design_primitives.dart';
import '../recipe_surface.dart'
    show RaftRecipeBinding, RaftRecipeBox, RaftSlotPaint;
import '../recipes/checkbox.g.dart';
import '../recipes/checkbox_indicator.g.dart';
import '../recipes/recipe_runtime.dart' show CssNum, RaftRecipeTheme;
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
    if (!t.isRaftLook) return _frozenIndicator(context, this);
    final rt = t.recipeTokens;
    final root = RaftCheckboxIndicatorRecipe.resolve(
      theme: t.recipeTheme,
      shape: shape == RaftCheckboxShape.circle
          ? RaftCheckboxIndicatorRecipeShape.circle
          : RaftCheckboxIndicatorRecipeShape.square,
      checked: checked,
      disabled: disabled,
      previewOnHover: previewOnHover,
      // `group-hover:text-foreground/20`: the parent row is hovered.
      states: t.recipeStates(extra: [if (hovered) 'group:hover']),
      tokens: rt,
    ).root;
    final showMark = checked || previewOnHover;
    final svg = root.target("& svg:not([class*='size-'])");
    final stroke = root.target('& svg')?['stroke-width'];
    // The recipe sizes the mark for its own 20px box; another [size] keeps that ratio.
    final markScale = size / (root.width ?? size);
    final inline = style;
    return ExcludeSemantics(
      child: RaftRecipeBox(
        style: root,
        tokens: rt,
        width: size,
        height: size,
        alignment: Alignment.center,
        applyText: false,
        applyOpacity: false,
        // Blink floors the recipe's `border-[1.5px]` to device pixels.
        decorationOverride: (d) {
          d = raftSnapBorder(context, d);
          if (inline == null) return d;
          final side = (d.border as Border).top;
          return d.copyWith(
            color: inline.fill ?? d.color,
            border: Border.all(
              color: inline.borderColor ?? side.color,
              width: inline.borderWidth ?? side.width,
            ),
            borderRadius: inline.radius == null
                ? d.borderRadius
                : BorderRadius.circular(inline.radius!),
          );
        },
        child: showMark
            ? RaftIcon(
                mark == RaftCheckboxMark.minus
                    ? RaftGlyph.minus
                    : RaftGlyph.check,
                size: inline?.markSize ?? (svg?.width ?? size) * markScale,
                strokeWidth:
                    inline?.markStrokeWidth ??
                    (stroke is CssNum
                        ? stroke.value
                        : const RaftIcon(RaftGlyph.check).strokeWidth),
                color: inline?.markColor ?? root.foreground(rt),
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
    final disabled = onChanged == null;
    if (!t.isRaftLook) {
      return legacyMaterial
          ? _frozenMaterialCheckbox(context, this)
          : _frozenCheckbox(context, this);
    }
    final rt = t.recipeTokens;
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
        child: RaftRecipeBox(
          style: RaftCheckboxRecipe.resolve(
            theme: t.recipeTheme,
            states: t.recipeStates(
              focusVisible: st.focusVisible,
              extra: [if (disabled) 'data-disabled'],
            ),
            tokens: rt,
          ).root,
          tokens: rt,
          width: size,
          height: size,
          applyText: false,
          applyOpacity: false,
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
            RaftRecipeBox(
              style: RaftCheckboxRecipe.resolve(
                theme: t.recipeTheme,
                states: t.recipeStates(
                  focusVisible: st.focusVisible,
                  extra: [if (disabled) 'data-disabled'],
                ),
                tokens: t.recipeTokens,
              ).root,
              tokens: t.recipeTokens,
              applyText: false,
              child: RaftCheckboxIndicator(checked: value, disabled: disabled),
            ),
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
