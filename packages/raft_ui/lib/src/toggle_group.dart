// raft-ui `ToggleGroup` / `ToggleGroupItem` / `ToggleGroupLabel`: a compact row of toggle buttons in a `fill-muted`
// track (`gap-0.5 rounded-[11px] p-[3px]`), each one on or off by itself; a pressed item is the yellow sticker (brand
// fill, ink border, die-cut ring, bold). Painted from the generated `toggleGroup` recipe: the frozen Elegant and Brutal
// recipes have no track, only the gap between plain items.
import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipe_surface.dart';
import 'recipes/toggle_group.g.dart';
import 'theme.dart';
import 'tooltip.dart';

/// One `ToggleGroupItem`: an optional icon and an optional label. An icon-only item is the square `h-8 w-8 p-0` box.
@immutable
class RaftToggleGroupItem<T> {
  const RaftToggleGroupItem({
    required this.value,
    this.label,
    this.glyph,
    this.glyphSize = 16,
    this.tooltip,
    this.semanticLabel,
    this.enabled = true,
    this.itemKey,
  });
  final T value;
  final String? label;
  final RaftGlyph? glyph;
  final double glyphSize;

  /// The tooltip, usually the accessible name of an icon-only item.
  final String? tooltip;
  final String? semanticLabel;
  final bool enabled;

  /// Key of the item (tests, parity interactions).
  final Key? itemKey;
}

/// raft-ui `ToggleGroup`. [value] holds the pressed items; [onChanged] receives the next set (a pressed item pressed
/// again leaves it empty unless [multiple]). A null [onChanged] disables every item.
class RaftToggleGroup<T> extends StatelessWidget {
  const RaftToggleGroup({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.multiple = false,
    this.semanticLabel,
  });

  final List<RaftToggleGroupItem<T>> items;
  final Set<T> value;
  final ValueChanged<Set<T>>? onChanged;

  /// Several items can be pressed at once.
  final bool multiple;
  final String? semanticLabel;

  void _toggle(T item) {
    final pressed = value.contains(item);
    onChanged!(
      multiple
          ? (pressed ? ({...value}..remove(item)) : {...value, item})
          : (pressed ? <T>{} : {item}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final root = RaftToggleGroupRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: rt,
    ).root;
    return Semantics(
      label: semanticLabel == null ? null : raftText(context, semanticLabel!),
      container: true,
      child: RaftRecipeBox(
        style: root,
        tokens: rt,
        child: Wrap(
          spacing: root.columnGap ?? 0,
          runSpacing: root.rowGap ?? 0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [for (final item in items) _item(context, t, item)],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    RaftTokens t,
    RaftToggleGroupItem<T> item,
  ) {
    final pressed = value.contains(item.value);
    final enabled = item.enabled && onChanged != null;
    final rt = t.recipeTokens;
    final iconOnly = item.label == null;
    Widget button = RaftInteractive(
      key: item.itemKey,
      semanticLabel: raftText(
        context,
        item.semanticLabel ?? item.tooltip ?? item.label ?? '',
      ),
      selected: pressed,
      onPressed: enabled ? () => _toggle(item.value) : null,
      builder: (context, st) {
        final style = RaftToggleGroupRecipe.resolve(
          theme: t.recipeTheme,
          states: t.recipeStates(
            hovered: st.hovered,
            pressed: st.pressed,
            focusVisible: st.focusVisible,
            disabled: !enabled,
            extra: [
              pressed ? 'data-pressed' : 'not-data-pressed',
              if (!enabled) 'data-disabled',
            ],
          ),
          tokens: rt,
        ).item;
        return RaftRecipeBox(
          style: style,
          tokens: rt,
          controlLabel: true,
          width: iconOnly ? style.height : null,
          padding: iconOnly ? EdgeInsets.zero : null,
          alignment: Alignment.center,
          child: Builder(
            builder: (context) => Row(
              mainAxisSize: MainAxisSize.min,
              spacing: style.columnGap ?? 0,
              children: [
                if (item.glyph != null)
                  RaftIcon(
                    item.glyph!,
                    size: item.glyphSize,
                    color: DefaultTextStyle.of(context).style.color,
                  ),
                if (item.label != null)
                  Flexible(
                    child: Text(
                      raftText(context, item.label!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (item.tooltip != null) {
      button = RaftTooltip(
        message: raftText(context, item.tooltip!),
        child: button,
      );
    }
    return button;
  }
}
