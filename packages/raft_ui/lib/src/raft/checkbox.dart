// raft-ui 0.7.1 `Checkbox` / `CheckboxIndicator` (dist `checkboxIndicator` + `checkbox`): a 20px ink-bordered sticker
// square (or circle) with a lucide check / minus; unchecked is a `layer-card` box, checked fills with `foreground`,
// disabled reads `fill-muted` / `foreground-disabled`. Keyboard focus draws the `focus-ring` on the 20px root.
import 'package:flutter/material.dart';

import '../design_primitives.dart';
import '../icons.dart';
import '../theme.dart';
import 'css_box.dart';
import 'ui_tokens.dart';

/// `mark` of `CheckboxIndicator`.
enum RaftCheckboxMark { check, minus }

/// `shape` of `Checkbox` / `CheckboxIndicator`.
enum RaftCheckboxShape { square, circle }

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
  });

  final bool checked, disabled, previewOnHover;

  /// The parent `group` is hovered (what `group-hover:text-foreground/20` reads).
  final bool hovered;
  final RaftCheckboxMark mark;
  final RaftCheckboxShape shape;
  final double size;

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
    return RaftCssBox(
      // The square form is the theme's sticker corner; the circle form is a true
      // circle at any size, which is why the official `rounded-full` stays
      // `size / 2` rather than becoming a token.
      radius: shape == RaftCheckboxShape.circle
          ? size / 2
          : t.size('radius.sticker', fallback: 4),
      fill: fill,
      borderWidth: raftControlBorderPx(context, 1.5),
      borderColor: border,
      width: size,
      height: size,
      alignment: Alignment.center,
      child: showMark
          ? RaftIcon(
              mark == RaftCheckboxMark.minus
                  ? RaftGlyph.minus
                  : RaftGlyph.check,
              size: size * .7,
              color: ink,
            )
          : null,
    );
  }
}

/// raft-ui `Checkbox`: controlled, with the `indeterminate` mixed state. A null [onChanged] is `disabled`.
class RaftCheckboxControl extends StatelessWidget {
  const RaftCheckboxControl({
    super.key,
    required this.value,
    this.onChanged,
    this.indeterminate = false,
    this.shape = RaftCheckboxShape.square,
    this.semanticLabel,
    this.focusNode,
    this.size = 20,
  });

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
