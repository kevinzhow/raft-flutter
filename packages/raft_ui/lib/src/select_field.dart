// raft-ui `Select`: trigger (`Button` outline md merged with the `select`
// recipe `trigger` slot), value / chevron icon, and the popup (`content`,
// `list`, `item`, `itemIndicator` slots) in an overlay anchored below the
// trigger.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipe_surface.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/select.g.dart';
import 'theme.dart';

/// `cn(a, b)` for two resolved slots: later declarations win (the class
/// list order raft-ui passes to tailwind-merge).
RaftSlotStyle raftMergeSlots(RaftSlotStyle a, RaftSlotStyle b) {
  final targets = <String, Map<String, CssValue>>{
    for (final e in a.targets.entries) e.key: {...e.value},
  };
  for (final e in b.targets.entries) {
    (targets[e.key] ??= {}).addAll(e.value);
  }
  return RaftSlotStyle(
    {...a.properties, ...b.properties},
    targets,
    [...a.classes, ...b.classes],
    b.tokens ?? a.tokens,
  );
}

class RaftSelectField<T> extends StatefulWidget {
  const RaftSelectField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.placeholder = 'Select...',
    this.invalid = false,
    this.visualHeight = RaftMetrics.buttonMd,
    this.minimumTargetHeight,
  });
  final T? value;

  /// Items: `value`, `child` (the item text) and `enabled`.
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  /// Accessible name (aria-label).
  final String? label;

  /// `SelectValue placeholder`.
  final String placeholder;
  final bool invalid;

  /// Kept for source compatibility; the trigger is the Button md box.
  final double visualHeight;
  final double? minimumTargetHeight;

  @override
  State<RaftSelectField<T>> createState() => _RaftSelectFieldState<T>();
}

class _RaftSelectFieldState<T> extends State<RaftSelectField<T>> {
  final portal = OverlayPortalController();
  final link = LayerLink();
  final triggerFocus = FocusNode();
  Size triggerSize = Size.zero;

  bool get open => portal.isShowing;

  void toggle() => setState(() => open ? portal.hide() : portal.show());

  void close() {
    if (!open) return;
    setState(portal.hide);
    triggerFocus.requestFocus();
  }

  @override
  void dispose() {
    triggerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final enabled = widget.onChanged != null;
    final selected = widget.items
        .where((e) => e.value == widget.value && widget.value != null)
        .firstOrNull;
    final trigger = RaftInteractive(
      onPressed: enabled ? toggle : null,
      focusNode: triggerFocus,
      semanticLabel: widget.label == null ? null : raftText(context, widget.label!),
      builder: (context, st) {
        final states = t.recipeStates(
          hovered: st.hovered,
          pressed: st.pressed,
          focusVisible: st.focusVisible,
          disabled: !enabled,
          extra: [
            if (open) 'data-popup-open',
            if (widget.invalid) 'data-invalid',
          ],
        );
        final button = RaftButtonRecipe.resolve(
          theme: t.recipeTheme,
          variant: RaftButtonRecipeVariant.outline,
          size: RaftButtonRecipeSize.md,
          states: states,
          tokens: rt,
        ).root;
        final sel = RaftSelectRecipe.resolve(
          theme: t.recipeTheme,
          states: states,
          tokens: rt,
        );
        final s = raftMergeSlots(button, sel.trigger);
        final svg = s.target(
          "& [data-slot='select-trigger-content'] svg:not([class*='size-'])",
        );
        final stroke = s.target(
          "& [data-slot='select-trigger-content'] svg:not([class*='stroke-'])",
        );
        return RaftRecipeBox(
          style: s,
          tokens: rt,
          // `w-full` (brutal trigger slot); elegant stays content-sized but
          // these callers stretch it in a column.
          width: double.infinity,
          child: Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (context) => DefaultTextStyle.merge(
                    style: s.target(":is(& *)[data-slot='select-value']")?.fontWeight == null
                        ? null
                        : TextStyle(
                            fontWeight: s
                                .target(":is(& *)[data-slot='select-value']")!
                                .fontWeight,
                          ),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    child: selected?.child ?? Text(widget.placeholder),
                  ),
                ),
              ),
              SizedBox(width: sel.trigger.columnGap ?? 6),
              Opacity(
                opacity: sel.icon.opacity ?? 1,
                child: Builder(
                  builder: (context) => RaftIcon(
                    RaftGlyph.chevronDown,
                    size: svg?.width ?? 14,
                    strokeWidth: (stroke?['stroke-width'] is CssNum)
                        ? (stroke!['stroke-width'] as CssNum).value
                        : 1.5,
                    color: DefaultTextStyle.of(context).style.color,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    return CompositedTransformTarget(
      link: link,
      child: OverlayPortal(
        controller: portal,
        overlayChildBuilder: (context) => _popup(context, t),
        child: LayoutBuilder(
          builder: (context, constraints) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final box = context.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize) triggerSize = box.size;
            });
            return trigger;
          },
        ),
      ),
    );
  }

  Widget _popup(BuildContext context, RaftTokens t) {
    final rt = t.recipeTokens;
    final sel = RaftSelectRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: rt,
    );
    final items = [
      for (var i = 0; i < widget.items.length; i++)
        _SelectItem<T>(
          item: widget.items[i],
          selected: widget.items[i].value == widget.value,
          last: i == widget.items.length - 1,
          autofocus:
              widget.items[i].value == widget.value ||
              (widget.value == null && i == 0),
          onSelect: () {
            widget.onChanged?.call(widget.items[i].value);
            close();
          },
        ),
    ];
    return Positioned.fill(
      child: TapRegion(
        onTapOutside: (_) => close(),
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): close,
          },
          child: Stack(
            children: [
              CompositedTransformFollower(
                link: link,
                targetAnchor: Alignment.bottomLeft,
                // side offset 4px (raft-ui SelectContent sideOffset).
                offset: const Offset(0, 4),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: triggerSize.width,
                    maxWidth: triggerSize.width,
                  ),
                  child: RaftRecipeBox(
                    style: sel.content,
                    tokens: rt,
                    clip: true,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: sel.list.maxHeight ?? 256,
                      ),
                      child: FocusTraversalGroup(
                        child: SingleChildScrollView(
                          padding: sel.list.padding,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < items.length; i++) ...[
                                if (i > 0) SizedBox(height: sel.list.rowGap ?? 0),
                                items[i],
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectItem<T> extends StatefulWidget {
  const _SelectItem({
    super.key,
    required this.item,
    required this.selected,
    required this.last,
    required this.autofocus,
    required this.onSelect,
  });
  final DropdownMenuItem<T> item;
  final bool selected, last, autofocus;
  final VoidCallback onSelect;
  @override
  State<_SelectItem<T>> createState() => _SelectItemState<T>();
}

class _SelectItemState<T> extends State<_SelectItem<T>> {
  bool hovered = false, highlighted = false;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final enabled = widget.item.enabled;
    final sel = RaftSelectRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(
        hovered: hovered && enabled,
        extra: [
          if (!enabled) 'data-disabled',
          if (widget.selected) 'data-selected',
          if (highlighted && enabled) 'data-highlighted',
          if (widget.last) 'last-child',
        ],
      ),
      tokens: rt,
    );
    return Semantics(
      selected: widget.selected,
      enabled: enabled,
      button: true,
      child: FocusableActionDetector(
        enabled: enabled,
        autofocus: widget.autofocus && enabled,
        onShowFocusHighlight: (v) => setState(() => highlighted = v),
        onShowHoverHighlight: (v) => setState(() => hovered = v),
        mouseCursor: SystemMouseCursors.basic,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
          SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onSelect();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? widget.onSelect : null,
          child: RaftRecipeBox(
            style: sel.item,
            tokens: rt,
            child: Row(
              children: [
                Expanded(
                  child: DefaultTextStyle.merge(
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    child: widget.item.child,
                  ),
                ),
                if (widget.selected) ...[
                  SizedBox(width: sel.item.columnGap ?? 8),
                  RaftIcon(
                    RaftGlyph.check,
                    size: 14,
                    color: sel.itemIndicator.color?.resolve(rt),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
