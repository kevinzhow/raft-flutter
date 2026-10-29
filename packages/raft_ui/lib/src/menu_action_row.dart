import 'package:flutter/material.dart';
import 'package:raft_theme/recipes/web_menu_action.g.dart';

import 'recipe_surface.dart';
import 'recipes/recipe_router.dart';
import 'recipes/recipe_runtime.dart';
import 'text_scaling.dart' show RaftScaled;
import 'theme.dart';

/// Paint part for the current Web product `MenuItem` action row.
///
/// The compatibility widgets own activation, focus, semantics and touch targets.
/// This part only consumes the generated product recipe; it has no selection
/// state, since SelectionPopover rows are a separate contract.
class RaftMenuActionRow extends StatelessWidget {
  const RaftMenuActionRow({
    super.key,
    required this.label,
    this.leading,
    this.trailing,
    this.enabled = true,
    this.hovered = false,
    this.focusVisible = false,
    this.topDivider = false,
  });

  final String label;
  final Widget? leading, trailing;
  final bool enabled, hovered, focusVisible, topDivider;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final viewport = MediaQuery.sizeOf(context);
    final states = t
        .recipeStates(
          hovered: enabled && hovered,
          focusVisible: enabled && focusVisible,
          disabled: !enabled,
          extra: [if (enabled) 'enabled'],
        )
        .copyWith(
          viewportWidth: viewport.width,
          viewportHeight: viewport.height,
        );
    final action = RaftWebMenuActionRecipe.resolve(
      states: states,
      tokens: rt,
    ).root;
    // Preserve the compatibility API's product separator without copying the
    // action recipe's class list or drawing a second action-row surface.
    final root = topDivider
        ? resolveRecipeClasses(
            [...action.classes, 'border-t', 'border-line-hairline'],
            states,
            rt,
          )
        : action;
    return RaftMenuSlotRow(
      label: label,
      leading: leading,
      trailing: trailing,
      root: root,
      tokens: rt,
    );
  }
}

/// The shared slot-painted row for action menus and choice popup backends.
///
/// Recipe callers supply their own resolved slots and indicator contents. This
/// renderer owns neither input nor selection; the root's minimum height and
/// padding, including compact viewport rules, remain the generated geometry.
class RaftMenuSlotRow extends StatelessWidget {
  const RaftMenuSlotRow({
    super.key,
    required this.label,
    required this.root,
    required this.tokens,
    this.labelChild,
    this.leading,
    this.trailing,
    this.indicator,
    this.itemLeading,
    this.itemText,
    this.itemIndicator,
  });

  final String label;
  final RaftSlotStyle root;
  final RaftTokenResolver tokens;
  final Widget? labelChild, leading, trailing, indicator;
  final RaftSlotStyle? itemLeading, itemText, itemIndicator;

  @override
  Widget build(BuildContext context) {
    final grows = RaftScaled.grows(context);
    final foreground = root.foreground(tokens);
    final leadingTarget =
        root.target('& > svg:first-child') ?? root.target('& > svg');

    Widget iconSlot(Widget child, RaftSlotStyle? slot, {bool first = false}) {
      final target = slot?.target('& > svg') ?? (first ? leadingTarget : null);
      final slotInk =
          slot?.foreground(tokens, inherited: foreground) ?? foreground;
      final ink = target?.foreground(tokens, inherited: slotInk) ?? slotInk;
      Widget content = IconTheme.merge(
        data: IconThemeData(color: ink),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: ink),
          child: target?.width != null || target?.height != null
              ? SizedBox(
                  width: target?.width,
                  height: target?.height,
                  child: child,
                )
              : child,
        ),
      );
      if (slot != null) {
        content = RaftRecipeBox(
          style: slot,
          tokens: tokens,
          alignment: switch (slot['justify-content']) {
            CssKeyword(value: 'center') => Alignment.center,
            _ => null,
          },
          child: content,
        );
      }
      return content;
    }

    Widget text = DefaultTextStyle.merge(
      maxLines: grows ? null : 1,
      softWrap: grows,
      overflow: TextOverflow.ellipsis,
      child: labelChild ?? Text(label),
    );
    if (itemText case final slot?) {
      text = RaftRecipeBox(style: slot, tokens: tokens, child: text);
    }
    return RaftRecipeBox(
      style: root,
      tokens: tokens,
      width: double.infinity,
      controlLabel: true,
      child: Row(
        spacing: root.columnGap ?? 0,
        children: [
          if (leading != null) iconSlot(leading!, itemLeading, first: true),
          Expanded(child: text),
          if (trailing != null) trailing!,
          if (indicator != null) iconSlot(indicator!, itemIndicator),
        ],
      ),
    );
  }
}
