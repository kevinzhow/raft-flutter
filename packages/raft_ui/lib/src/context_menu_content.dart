import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_primitives.dart' show RaftInteractive;
import 'icons.dart';
import 'menu_action_row.dart';
import 'popover_surface.dart';
import 'recipe_surface.dart';
import 'recipes/context_menu.g.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';

/// One entry of a raft-ui `ContextMenuContent`: a `ContextMenuItem` row or a
/// `ContextMenuSeparator`.
@immutable
sealed class RaftContextMenuContentEntry {
  const RaftContextMenuContentEntry();
}

class RaftContextMenuContentItem extends RaftContextMenuContentEntry {
  const RaftContextMenuContentItem({
    required this.label,
    this.glyph,
    this.onPressed,
    this.itemKey,
  });
  final String label;

  /// `<Icon size={14} />` before the label.
  final RaftGlyph? glyph;
  final VoidCallback? onPressed;
  final Key? itemKey;
}

class RaftContextMenuContentSeparator extends RaftContextMenuContentEntry {
  const RaftContextMenuContentSeparator();
}

/// raft-ui `ContextMenuContent` / `ContextMenuItem` / `ContextMenuSeparator`
/// (the base-ui context menu recipe: brutal `border-2 border-black` popup with
/// `py-2 px-3` rows and a `border-t-2` rule, elegant `rounded-md p-1`). The
/// width is the recipe's `min-w-48` or the widest row.
class RaftContextMenuContent extends StatelessWidget {
  const RaftContextMenuContent({
    super.key,
    required this.entries,
    this.onDismiss,
  });
  final List<RaftContextMenuContentEntry> entries;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final resolver = RaftRecipeTokens(t);
    final content = RaftContextMenuRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: resolver,
    ).content;
    final gap = content.rowGap ?? 0;
    final children = [
      for (final entry in entries)
        switch (entry) {
          RaftContextMenuContentSeparator() => const _Separator(),
          RaftContextMenuContentItem() => _Item(entry),
        },
    ];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            onDismiss?.call(),
      },
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Semantics(
          role: SemanticsRole.menu,
          child: DefaultTextStyle.merge(
            style: const TextStyle(decoration: TextDecoration.none),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: content.minWidth ?? 192),
              child: IntrinsicWidth(
                child: t.isRaftLook
                    ? RaftPopoverSurface(
                        surfaceStyle: content,
                        child: _ContentList(children: children, gap: gap),
                      )
                    : RaftRecipeBox(
                        style: content,
                        tokens: resolver,
                        clip: true,
                        applyText: false,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < children.length; i++) ...[
                                if (i > 0 && gap > 0) SizedBox(height: gap),
                                children[i],
                              ],
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContentList extends StatelessWidget {
  const _ContentList({required this.children, required this.gap});
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    primary: false,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0 && gap > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    ),
  );
}

class _Separator extends StatelessWidget {
  const _Separator();
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final resolver = RaftRecipeTokens(t);
    final style = RaftContextMenuRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: resolver,
    ).separator;
    return RaftRecipeBox(style: style, tokens: resolver, applyText: false);
  }
}

class _Item extends StatelessWidget {
  const _Item(this.item);
  final RaftContextMenuContentItem item;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final resolver = RaftRecipeTokens(t);
    final enabled = item.onPressed != null;
    return Semantics(
      role: SemanticsRole.menuItem,
      child: RaftInteractive(
        key: item.itemKey,
        onPressed: item.onPressed,
        button: false,
        builder: (context, st) {
          final slot = RaftContextMenuRecipe.resolve(
            theme: t.recipeTheme,
            states: t.recipeStates(
              hovered: st.hovered && enabled,
              pressed: st.pressed,
              focusVisible: st.focusVisible,
              disabled: !enabled,
              extra: [
                if (t.isRaftLook && !enabled) 'data-disabled',
                if (t.isRaftLook && enabled && (st.hovered || st.focusVisible))
                  'data-highlighted',
              ],
            ),
            tokens: resolver,
          );
          final style = slot.item;
          if (t.isRaftLook) {
            return RaftMenuSlotRow(
              label: item.label,
              root: style,
              tokens: resolver,
              leading: item.glyph == null
                  ? null
                  : RaftIcon(item.glyph!, size: 14),
            );
          }
          final color =
              style.textStyle(resolver).color ??
              DefaultTextStyle.of(context).style.color;
          return RaftRecipeBox(
            style: style,
            tokens: resolver,
            width: double.infinity,
            child: Row(
              children: [
                if (item.glyph != null) ...[
                  SizedBox.square(
                    dimension: 14,
                    child: RaftIcon(item.glyph!, size: 14, color: color),
                  ),
                  SizedBox(width: style.columnGap ?? 8),
                ],
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
