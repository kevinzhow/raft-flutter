import 'package:flutter/material.dart';

import 'recipe_surface.dart';
import 'recipes/kbd.g.dart';
import 'theme.dart';

/// raft-ui `Kbd`: a key cap such as `Esc`, an arrow or Return, painted from the `kbd` recipe
/// (`min-w-4 rounded-[3px] px-1 font-mono text-mono-meta text-foreground-hint inset-ring-line-hairline`).
/// A decoration of the keyboard hint, not a control: it carries no semantics.
class RaftKbd extends StatelessWidget {
  const RaftKbd(this.keys, {super.key});

  /// The key's glyph or name (`↑`, `↵`, `Esc`).
  final String keys;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = t.recipeTokens;
    final root = RaftKbdRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: rt,
    ).root;
    return ExcludeSemantics(
      child: RaftRecipeBox(
        style: root,
        tokens: rt,
        child: Text(keys, style: root.textStyle(rt)),
      ),
    );
  }
}

/// raft-ui `KbdGroup`: keys shown together (`inline-flex items-center gap-1`).
class RaftKbdGroup extends StatelessWidget {
  const RaftKbdGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = t.recipeTokens;
    final group = RaftKbdRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: rt,
    ).group;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: group.columnGap ?? 0,
      children: children,
    );
  }
}
