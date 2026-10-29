import 'package:flutter/material.dart' show DividerTheme, Theme;
import 'package:flutter/widgets.dart';

import 'localization.dart';
import 'recipe_surface.dart';
import 'recipes/recipe_runtime.dart' show RaftRecipeSet;
import 'recipes/separator.g.dart';
import 'theme.dart';

/// raft-ui `Separator`: a 1px `line-hairline` between groups of content,
/// horizontal (full width) or vertical (the height of its row), or with a
/// [label] a word between two lines (`text-footnote`, semibold,
/// `foreground-hint`).
///
/// The Raft look reads the `separator` recipe and ignores [color] and
/// [thickness]: raft-ui says a separator is `line-hairline` and nothing else.
/// The frozen Elegant and Brutal looks keep the hairline each call site drew
/// before ([color] null is the ambient divider colour).
class RaftSeparator extends StatelessWidget {
  const RaftSeparator({
    super.key,
    this.axis = Axis.horizontal,
    this.label,
    this.color,
    this.thickness,
  });

  /// [Axis.horizontal] stacks groups; [Axis.vertical] sits between groups in a
  /// row of fixed height.
  final Axis axis;

  /// A word between two lines (horizontal only).
  final String? label;

  /// Frozen looks only: the line colour.
  final Color? color;

  /// Frozen looks only: the line thickness (null is a hairline).
  final double? thickness;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final vertical = axis == Axis.vertical;
    if (t.recipeSet != RaftRecipeSet.raft) {
      final line = _frozenLine(context, vertical);
      return label == null || vertical
          ? line
          : _labeled(context, t, (_) => line);
    }
    final rt = t.recipeTokens;
    final style = RaftSeparatorRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(
        extra: ['data-orientation=${vertical ? 'vertical' : 'horizontal'}'],
      ),
      tokens: rt,
    );
    if (label != null && !vertical) {
      return _labeled(
        context,
        t,
        (_) => RaftRecipeBox(
          style: style.labeledLine,
          tokens: rt,
          height: 1,
          applyText: false,
        ),
        style: style,
      );
    }
    return Semantics(
      container: false,
      child: RaftRecipeBox(
        style: style.root,
        tokens: rt,
        width: vertical ? 1 : null,
        height: vertical ? null : 1,
        applyText: false,
      ),
    );
  }

  /// Material's default thickness: a hairline, one device pixel.
  static const _hairline = 0.0;

  /// What `Divider(height: 1, ...)` / `VerticalDivider(width: 1, ...)` drew: a
  /// 1px box with the line centred in it, the caller's colour or the ambient
  /// divider colour, [thickness] or a hairline.
  Widget _frozenLine(BuildContext context, bool vertical) {
    final theme = DividerTheme.of(context);
    final side = BorderSide(
      color: color ?? theme.color ?? Theme.of(context).dividerColor,
      width: thickness ?? theme.thickness ?? _hairline,
    );
    final line = Container(
      width: vertical ? side.width : null,
      height: vertical ? null : side.width,
      decoration: BoxDecoration(
        border: vertical ? Border(left: side) : Border(bottom: side),
      ),
    );
    return vertical
        ? SizedBox(width: 1, child: Center(child: line))
        : SizedBox(height: 1, child: Center(child: line));
  }

  Widget _labeled(
    BuildContext context,
    RaftTokens t,
    WidgetBuilder line, {
    RaftSeparatorRecipeStyle? style,
  }) {
    final rt = t.recipeTokens;
    final gap = style?.labeledRoot.columnGap ?? 12;
    final padding = style?.labeledRoot.padding;
    final text = style == null
        ? TextStyle(color: t.colors['foreground-hint'])
        : style.labeledContent.text(
            rt,
            base: DefaultTextStyle.of(context).style,
          );
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: line(context)),
          SizedBox(width: gap),
          Flexible(child: Text(raftText(context, label!), style: text)),
          SizedBox(width: gap),
          Expanded(child: line(context)),
        ],
      ),
    );
  }
}
