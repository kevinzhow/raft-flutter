import 'package:flutter/material.dart';

import 'dialog_card.dart' show raftRecipeThemeOf;
import 'recipe_surface.dart';
import 'recipes/card.g.dart';
import 'recipes/recipe_runtime.dart' show RaftRecipeStates;
import 'recipes/token_binding.dart';
import 'system_inset.dart';
import 'theme.dart';

/// ui/BottomSheet.tsx: a `fixed inset-x-0 bottom-0 p-3` root holding a raft-ui
/// Card (`mx-auto max-w-md`, Elegant `shadow-raft-xl`, Brutal `border-2
/// border-black bg-white shadow-brutal-lg`) with no dim backdrop. The caller
/// positions the sheet at the bottom of the page; [safeBottom] is
/// `max(12px, env(safe-area-inset-bottom))`.
class RaftBottomSheet extends StatelessWidget {
  const RaftBottomSheet({
    super.key,
    required this.child,
    this.maxWidth = 448,
    this.contentPadding = EdgeInsets.zero,
    this.safeBottom,
  });
  final Widget child;
  final double maxWidth;

  /// `sheetClassName` padding (e.g. `p-4`).
  final EdgeInsets contentPadding;

  /// Defaults to [raftBottomInset].
  final double? safeBottom;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final root = RaftCardRecipe.resolve(
      theme: raftRecipeThemeOf(t),
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: rt,
    ).root;
    final inset = safeBottom ?? raftBottomInset(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, inset > 12 ? inset : 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: RaftRecipeBox(
            style: root.withCssUsedBorderWidths(),
            tokens: rt,
            width: double.infinity,
            padding: contentPadding,
            applyText: false,
            decorationOverride: (d) => d.copyWith(
              color: d.color,
              boxShadow: t.themeShadows.xl.paintOrder,
            ),
            child: DefaultTextStyle.merge(
              style: root.textStyle(rt),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
