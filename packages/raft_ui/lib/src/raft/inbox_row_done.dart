// Web `InboxRowDone`: an Activity row's Mark as Done, in `RaftInboxItem.actions`.
// With a mouse it is a ghost `icon-md` button (a 28px, radius 6 bar button from
// 768) with the "Mark as Done" tooltip; with touch it is the outline 32px
// button that rests in the row, without a tooltip. A phone with touch does not
// mount it: Done is the swipe, the hold menu, and `RaftInboxItem.semanticActions`.
import 'package:flutter/material.dart';

import '../icons.dart';
import '../interaction.dart';
import '../recipes/button_variants.g.dart';
import '../recipes/recipe_runtime.dart';
import '../theme.dart';
import '../tokens/tokens.dart' show RaftDesktopMetrics;
import 'button.dart' show RaftButton;

class RaftInboxRowDone extends StatelessWidget {
  const RaftInboxRowDone({
    super.key,
    required this.semanticLabel,
    required this.tooltip,
    required this.onPressed,
  });

  /// The row's own name for the action ("Mark #launch-week as Done"), so a
  /// list read aloud does not repeat one name.
  final String semanticLabel;

  /// The action's name, the same on every row ("Mark as Done"). Mouse only.
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (RaftInteraction.of(context).touch) {
      return RaftButton(
        key: const ValueKey('inbox-row-done-touch'),
        tone: RaftButtonRecipeVariant.outline,
        size: RaftButtonRecipeSize.iconMd,
        glyph: RaftGlyph.check,
        glyphSize: 18,
        semanticLabel: semanticLabel,
        onPressed: onPressed,
      );
    }
    final bar = RaftTokens.of(context).desktop;
    return RaftButton(
      key: const ValueKey('inbox-row-done'),
      tone: RaftButtonRecipeVariant.ghost,
      size: RaftButtonRecipeSize.iconMd,
      glyph: RaftGlyph.check,
      glyphSize: 18,
      tooltip: tooltip,
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      physicalHeight: bar ? RaftDesktopMetrics.barButtonSize : null,
      visualWidth: bar ? RaftDesktopMetrics.barButtonSize : null,
      styleBuilder: !bar
          ? null
          : (context, state, style) => style.copyWith(
              properties: {
                ...style.properties,
                for (final corner in [
                  'top-left',
                  'top-right',
                  'bottom-left',
                  'bottom-right',
                ])
                  'border-$corner-radius': const CssNum(
                    RaftDesktopMetrics.barButtonRadius,
                    'px',
                  ),
              },
            ),
    );
  }
}
