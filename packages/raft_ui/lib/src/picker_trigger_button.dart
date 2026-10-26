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
  });

  final String label;
  final VoidCallback? onPressed;

  /// The inline-start icon (`data-icon="inline-start"`) and the indicator at the end.
  final RaftGlyph? glyph, trailingGlyph;

  /// `data-has-value`: a filter is applied.
  final bool selected, invalid, enabled;
  final String? tooltip;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (!t.isRaftLook) return _frozen(context, t);
    final rt = t.recipeTokens;
    final button = RaftInteractive(
      onPressed: enabled ? onPressed : null,
      focusNode: focusNode,
      semanticLabel: raftText(context, label),
      builder: (context, st) {
        final style = RaftPickerTriggerButtonRecipe.resolve(
          theme: t.recipeTheme,
          states: t.recipeStates(
            hovered: st.hovered,
            pressed: st.pressed,
            focusVisible: st.focusVisible,
            disabled: !enabled,
            extra: [
              if (selected) 'data-has-value',
              if (invalid) 'data-invalid',
            ],
          ),
          tokens: rt,
        ).base;
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
                    size: 14,
                    color: DefaultTextStyle.of(context).style.color,
                  ),
                Text(raftText(context, label), maxLines: 1),
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

  /// The pre-theme paint: the original PickerTriggerButton recipe on a `RaftControl` (design_primitives.dart).
  Widget _frozen(BuildContext context, RaftTokens t) =>
      raftFrozenPickerTriggerButton(
        context,
        label: label,
        onPressed: enabled ? onPressed : null,
        glyph: glyph,
        trailingGlyph: trailingGlyph,
        selected: selected,
        tooltip: tooltip,
        focusNode: focusNode,
      );
}
