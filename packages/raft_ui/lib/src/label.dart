import 'package:flutter/material.dart';

import 'localization.dart' show raftText;
import 'recipe_surface.dart';
import 'recipes/label.g.dart';
import 'recipes/recipe_runtime.dart';
import 'theme.dart';

/// Tailwind `ml-1`: the markers sit one spacing step after the label text.
const double _ml1 = 4;

/// The label text of a `Label` / `FieldLabel` (set it in [style] on the `Text.rich`): [text], then the `LabelAsterisk` (required) or the
/// `LabelOptional` marker, each after `ml-1`, in the `label` recipe's `asterisk` / `sub` slots.
TextSpan raftLabelSpan(
  BuildContext context, {
  required String text,
  required TextStyle style,
  required RaftLabelRecipeStyle recipe,
  required RaftTokenResolver tokens,
  bool required = false,
  bool optional = false,
  String optionalLabel = '(optional)',
  bool disabled = false,
}) {
  return TextSpan(
    children: [
      TextSpan(text: raftText(context, text)),
      if (required) ...[
        WidgetSpan(child: SizedBox(width: _ml1)),
        TextSpan(
          text: '*',
          style: recipe.asterisk.text(tokens, base: style),
        ),
      ],
      if (optional) ...[
        WidgetSpan(child: SizedBox(width: _ml1)),
        TextSpan(
          text: raftText(context, optionalLabel),
          style: recipe.sub.text(tokens, base: style),
        ),
      ],
    ],
  );
}

/// raft-ui `Label`: a standalone form label in the field-label style (`font-sans font-semibold
/// text-foreground-muted`, `text-footnote` for `md`, `text-caption` for `sm`), with the optional `*` / `(optional)`
/// marker. A form control's own label goes through [RaftField] instead.
class RaftLabel extends StatelessWidget {
  const RaftLabel(
    this.text, {
    super.key,
    this.size = RaftLabelRecipeSize.md,
    this.required = false,
    this.optional = false,
    this.optionalLabel = '(optional)',
    this.disabled = false,
  });

  final String text;
  final RaftLabelRecipeSize size;
  final bool required, optional, disabled;
  final String optionalLabel;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = t.recipeTokens;
    final recipe = RaftLabelRecipe.resolve(
      theme: t.recipeTheme,
      size: size,
      states: t.recipeStates(extra: [if (disabled) 'data-disabled']),
      tokens: rt,
    );
    final style = recipe.root.text(
      rt,
      base: DefaultTextStyle.of(context).style,
    );
    return Text.rich(
      style: style,
      raftLabelSpan(
        context,
        text: text,
        style: style,
        recipe: recipe,
        tokens: rt,
        required: required,
        optional: optional,
        optionalLabel: optionalLabel,
        disabled: disabled,
      ),
    );
  }
}
