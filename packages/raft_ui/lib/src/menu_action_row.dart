import 'package:flutter/material.dart';
import 'package:raft_theme/recipes/web_menu_action.g.dart';

import 'recipe_surface.dart';
import 'raft/ui_tokens.dart' show raftChromeBlend;
import 'surface_background_scope.dart';
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
    return RaftMenuItemSurface(
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

/// The one recipe-painted menu-item surface, also used by rich compositions.
/// Content, input and selection remain owned by each source role adapter.
class RaftMenuItemSurface extends StatelessWidget {
  const RaftMenuItemSurface({
    super.key,
    required this.style,
    required this.tokens,
    required this.child,
    this.width,
    this.applyText = true,
    this.controlLabel = false,
  });

  final RaftSlotStyle style;
  final RaftTokenResolver tokens;
  final Widget child;
  final double? width;
  final bool applyText, controlLabel;

  @override
  Widget build(BuildContext context) {
    final backdrop = RaftSurfaceBackgroundScope.of(context);
    // Only uncalibrated foundation-token fills over a surface that owns its
    // actual opaque paint need Blink's 8-bit composition. Literal paint fits,
    // background images and unknown/faded surfaces keep their existing raster.
    final background = style['background-color'];
    final tokenFill =
        background is CssVar &&
        background.token != null &&
        background.fallback == null;
    final plainFill = switch (style['background-image']) {
      null || CssKeyword(value: 'none') => true,
      _ => false,
    };
    final composite =
        tokens.recipeSet == RaftRecipeSet.raft &&
        tokenFill &&
        plainFill &&
        (style.opacity ?? 1) == 1 &&
        backdrop != null &&
        backdrop.a == 1;
    // Borders may use the same unfitted foundation ink as fills. Only an
    // otherwise unpainted slot can borrow its parent's opaque surface; its own
    // fill or another paint layer would change the colour under that border.
    final current = style
        .text(tokens, base: DefaultTextStyle.of(context).style)
        .color;
    final compositeBorders =
        tokens.recipeSet == RaftRecipeSet.raft &&
        plainFill &&
        (style.opacity ?? 1) == 1 &&
        style.before == null &&
        style.after == null &&
        !style
            .cssShadows(tokens, currentColor: current)
            .any((shadow) => shadow.inset && shadow.color.a > 0) &&
        backdrop != null &&
        backdrop.a == 1;
    return RaftRecipeBox(
      style: style,
      tokens: tokens,
      width: width,
      applyText: applyText,
      controlLabel: controlLabel,
      decorationOverride: !composite && !compositeBorders
          ? null
          : (decoration) {
              var result = decoration;
              final fill = decoration.color;
              if (composite && fill != null && fill.a > 0 && fill.a < 1) {
                result = result.copyWith(
                  color: raftChromeBlend(fill, backdrop),
                );
              }
              final border = decoration.border;
              if (compositeBorders &&
                  (fill == null || fill.a == 0) &&
                  border is Border) {
                BorderSide side(String name, BorderSide original) {
                  final ink = style['border-$name-color'];
                  return ink is CssVar &&
                          ink.token != null &&
                          ink.fallback == null &&
                          original.style != BorderStyle.none &&
                          original.width > 0 &&
                          original.color.a > 0 &&
                          original.color.a < 1
                      ? original.copyWith(
                          color: raftChromeBlend(original.color, backdrop),
                        )
                      : original;
                }

                result = result.copyWith(
                  border: Border(
                    top: side('top', border.top),
                    right: side('right', border.right),
                    bottom: side('bottom', border.bottom),
                    left: side('left', border.left),
                  ),
                );
              }
              return result;
            },
      child: child,
    );
  }
}
