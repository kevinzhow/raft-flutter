// raft-ui `Meter` (`meter.recipe.ts`): a labelled quantity against its limit,
// the header (label and value) over a track whose indicator fills to the
// share used. Geometry, type and colours come from the generated `meter`
// recipe; the indicator takes the recipe's `--meter-indicator` (info, or
// warning past the limit).
import 'package:flutter/material.dart';

import 'panel_layout.dart' show RaftCssText;
import 'recipe_surface.dart';
import 'recipes/meter.g.dart';
import 'raft/ui_tokens.dart';
import 'theme.dart';

export 'recipes/meter.g.dart' show RaftMeterRecipeSize;

class RaftMeter extends StatelessWidget {
  const RaftMeter({
    super.key,
    required this.label,
    required this.used,
    required this.max,
    required this.valueText,
    this.warning = false,
    this.size = RaftMeterRecipeSize.md,
    this.labelChild,
  });

  /// A stand-in for the label's text (a loading bar of the same line).
  final Widget? labelChild;

  /// `MeterLabel`.
  final String label;

  /// What is used, and the most there is. The filled share is `used / max`
  /// held to 0..1 (a limit of 0 or less shows an empty track).
  final num used, max;

  /// `MeterValue`, and what assistive technology reads as the value.
  final String valueText;

  /// The warning axis: the indicator in the warning colour.
  final bool warning;
  final RaftMeterRecipeSize size;

  double get _fraction {
    if (!max.isFinite || max <= 0 || !used.isFinite) return 0;
    return (used / max).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = t.recipeTokens;
    final r = RaftMeterRecipe.resolve(
      warning: warning,
      size: size,
      states: t.recipeStates(responsive: true),
      tokens: tokens,
    );
    final base = DefaultTextStyle.of(context).style;
    final labelStyle = r.label.text(tokens, base: base);
    final valueStyle = r.value
        .text(tokens, base: base)
        .copyWith(
          color: t.ui.foregroundMuted,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final gap = r.root.length('row-gap') ?? 6;
    final trackHeight = r.track.length('height') ?? 8;
    // Web paints a full meter (used up) in the warning colour.
    final indicator = warning || (max > 0 && used >= max)
        ? t.ui.warning
        : t.ui.info;
    return Semantics(
      container: true,
      label: label,
      value: valueText,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // `flex-wrap justify-between`: the value drops under the label
            // when both cannot share a line (large text).
            LayoutBuilder(
              builder: (context, box) => Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: r.header.length('column-gap') ?? 12,
                runSpacing: r.header.length('row-gap') ?? 2,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth),
                    child:
                        labelChild ??
                        RaftCssText(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle,
                        ),
                  ),
                  RaftCssText(valueText, style: valueStyle),
                ],
              ),
            ),
            SizedBox(height: gap),
            RaftRecipeBox(
              key: const ValueKey('meter-track'),
              style: r.track,
              tokens: tokens,
              width: double.infinity,
              height: trackHeight,
              clip: true,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: _fraction,
                  child: RaftRecipeBox(
                    key: const ValueKey('meter-indicator'),
                    style: r.indicator,
                    tokens: tokens,
                    height: trackHeight,
                    applyText: false,
                    decorationOverride: (decoration) => decoration.copyWith(
                      color: indicator,
                      borderRadius: r.track.borderRadius,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
