import 'package:flutter/material.dart';

import 'design_primitives.dart' show RaftInteractive;
import 'icons.dart';
import 'localization.dart';
import 'recipe_surface.dart';
import 'recipes/message_footer.g.dart';
import 'theme.dart';

/// Web `MessageItemSavedIndicator`: the "Saved" badge in a saved message's
/// footer row. Pressing it removes the message from Saved.
class RaftMessageSavedIndicator extends StatelessWidget {
  const RaftMessageSavedIndicator({super.key, this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final label = raftText(context, 'Saved');
    final slot = RaftMessageFooterRecipe.resolve(
      theme: t.recipeTheme,
      tokens: t.recipeTokens,
    ).savedIndicator;
    final svgKey = slot.targets.keys
        .where((k) => k.contains('svg'))
        .firstOrNull;
    final svg = svgKey == null ? null : slot.target(svgKey);
    // `[&_svg]:size-3.5`.
    final iconSize = svg?.length('width') ?? 14;
    return RaftInteractive(
      key: const Key('message-saved-badge'),
      onPressed: onPressed,
      semanticLabel: raftText(context, 'Remove from Saved'),
      builder: (_, state) => RaftRecipeBox(
        style: RaftMessageFooterRecipe.resolve(
          theme: t.recipeTheme,
          states: t.recipeStates(
            hovered: state.hovered,
            pressed: state.pressed,
          ),
          tokens: t.recipeTokens,
        ).savedIndicator,
        tokens: t.recipeTokens,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RaftIcon(RaftGlyph.bookmark, size: iconSize, filled: true),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
