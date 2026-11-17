// raft-ui `PickerTriggerButton`: the compact 32px button that opens a Select or Combobox as a filter above a list. It
// rests as a seam-ringed ghost (`inset-ring-line-seam`, muted footnote text), turns `info-soft` once a value is chosen
// (`data-has-value`), shows a `danger-strong` ring when invalid, and ends in a 16px indicator slot with the hint-coloured
// chevron. Painted from the generated `pickerTriggerButton` recipe; the frozen Elegant and Brutal looks keep the
// original `RaftControl` paint of the 0.5.52 build.
import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'tooltip.dart' show RaftTooltip;
import 'raft/ui_tokens.dart';
import 'recipe_surface.dart';
import 'recipes/picker_trigger_button.g.dart';
import 'recipes/recipe_runtime.dart' show RaftSlotStyle;
import 'theme.dart';

class RaftPickerTriggerButton extends StatelessWidget {
  const RaftPickerTriggerButton({
    super.key,
    required this.label,
    this.onPressed,
    this.glyph,
    this.trailingGlyph = RaftGlyph.chevronDown,
    this.selected = false,
    this.invalid = false,
    this.enabled = true,
    this.tooltip,
    this.focusNode,
    this.value,
    this.valueSlot,
    this.labelHidden = false,
    this.restyle,
  });

  final String label;
  final VoidCallback? onPressed;

  /// The inline-start icon (`data-icon="inline-start"`) and the indicator at the end.
  final RaftGlyph? glyph, trailingGlyph;

  /// `data-has-value`: a filter is applied.
  final bool selected, invalid, enabled;
  final String? tooltip;
  final FocusNode? focusNode;

  /// What is chosen, after the label (FitToolbarPicker's `value`): [valueSlot] gives its text style (a count is
  /// mono). [labelHidden] drops the label's text but keeps it, then the value, as the accessible name ("Assignee 1").
  final String? value;
  final RaftSlotStyle? valueSlot;
  final bool labelHidden;

  /// A caller's class overrides on the resolved trigger slot (`data-fit-label:gap-1 data-fit-label:px-2`).
  final RaftSlotStyle Function(RaftSlotStyle style)? restyle;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final canActivate = enabled && onPressed != null;
    final button = RaftInteractive(
      onPressed: canActivate ? onPressed : null,
      focusNode: focusNode,
      semanticLabel: [
        raftText(context, label),
        if (value != null && value!.isNotEmpty) value!,
      ].join(' '),
      builder: (context, st) {
        var style = RaftPickerTriggerButtonRecipe.resolve(
          states: t.recipeStates(
            responsive: true,
            hovered: st.hovered,
            pressed: st.pressed,
            focusVisible: st.focusVisible,
            disabled: !canActivate,
            extra: [
              if (selected) 'data-has-value',
              if (invalid) 'data-invalid',
            ],
          ),
          tokens: rt,
        ).base;
        if (restyle != null) style = restyle!(style);
        return RaftRecipeBox(
          style: style,
          tokens: rt,
          controlLabel: true,
          child: Builder(
            builder: (context) => Row(
              mainAxisSize: MainAxisSize.min,
              spacing: style.columnGap ?? 0,
              children: [
                if (glyph != null)
                  RaftIcon(
                    glyph!,
                    size: style.target("& svg:not([class*='size-'])")!.width!,
                    color: DefaultTextStyle.of(context).style.color,
                  ),
                if (!labelHidden) Text(raftText(context, label), maxLines: 1),
                if (value != null && value!.isNotEmpty)
                  Text(
                    value!,
                    maxLines: 1,
                    style: valueSlot?.text(
                      rt,
                      base: DefaultTextStyle.of(context).style,
                    ),
                  ),
                if (trailingGlyph != null)
                  SizedBox.square(
                    dimension: 16,
                    child: Center(
                      child: RaftIcon(
                        trailingGlyph!,
                        size: 14,
                        color: t.ui.foregroundHint,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    return tooltip == null
        ? button
        : RaftTooltip(message: raftText(context, tooltip!), child: button);
  }
}
