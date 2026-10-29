// raft-ui `Select`: trigger (`Button` outline md merged with the `select`
// recipe `trigger` slot), value / chevron icon, and the popup (`content`,
// `list`, `item`, `itemIndicator` slots) in an overlay anchored below the
// trigger.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart' show SemanticsRole;

import 'design_primitives.dart';
import 'hover_region.dart';
import 'anchored_popup.dart';
import 'dismiss_scope.dart';
import 'icons.dart';
import 'localization.dart';
import 'menu_popup_backend.dart';
import 'panel_layout.dart' show RaftCssText;
import 'recipe_surface.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/select.g.dart';
import 'form_controls.dart' show RaftField;
import 'theme.dart';
import 'tokens/tokens.dart' show RaftCssShadow;
import 'raft/css_box.dart' show raftSnapBorder;

part 'select_field_frozen.dart';

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

/// One option of a [RaftSelectField] (`SelectItem` with its `SelectItemText`): the [value] it selects, the
/// [label] shown in the trigger and in the list, and whether it can be picked.
@immutable
class RaftSelectItem<T> {
  const RaftSelectItem({
    required this.value,
    required this.label,
    this.enabled = true,
    this.cssText = false,
    this.labelKey,
  });

  final T value;

  /// The text, already localised by the caller.
  final String label;
  final bool enabled;

  /// Paint the label with the baseline-snapped [RaftCssText] (the settings forms) instead of a plain [Text].
  final bool cssText;

  /// Key of the label text (tests find a choice by it, in the trigger and in the list).
  final Key? labelKey;

  /// The label widget both the trigger and the list show.
  Widget get child =>
      cssText ? RaftCssText(label, key: labelKey) : Text(label, key: labelKey);
}

/// A [RaftSelectField] under its label (`Field` + `FieldLabel` + `Select`). The Raft look draws the canonical field
/// and select; the Elegant and Brutal looks keep the Material labelled dropdown they always drew.
class RaftLabeledSelect<T> extends StatelessWidget {
  const RaftLabeledSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.fieldKey,
  });
  final String label;
  final T? value;
  final List<RaftSelectItem<T>> items;
  final ValueChanged<T?>? onChanged;

  /// Key of the select (the frozen looks rebuild their dropdown when it changes).
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    if (!RaftTokens.of(context).isRaftLook) {
      return _frozenLabeledSelect<T>(context, this);
    }
    return RaftField(
      label: raftText(context, label),
      child: RaftSelectField<T>(
        key: fieldKey,
        label: raftText(context, label),
        value: value,
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

class RaftSelectField<T> extends StatefulWidget {
  const RaftSelectField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.placeholder = 'Select...',
    this.unmatchedLabel,
    this.chrome = RaftSelectRecipeChrome.default_,
    this.invalid = false,
    this.visualHeight = RaftMetrics.buttonMd,
    this.minimumTargetHeight,
    this.height,
  });

  /// Callsite trigger height (`SelectTrigger className="h-10"`).
  final double? height;
  final T? value;

  final List<RaftSelectItem<T>> items;
  final ValueChanged<T?>? onChanged;

  /// Accessible name (aria-label).
  final String? label;

  /// `SelectValue placeholder`.
  final String placeholder;

  /// Label for a current value absent from the option catalog.
  final String? unmatchedLabel;
  final bool invalid;
  final RaftSelectRecipeChrome chrome;

  /// Kept for source compatibility; the trigger is the Button md box.
  final double visualHeight;
  final double? minimumTargetHeight;

  @override
  State<RaftSelectField<T>> createState() => _RaftSelectFieldState<T>();
}

class _RaftSelectFieldState<T> extends State<RaftSelectField<T>> {
  final portal = OverlayPortalController();
  final link = LayerLink();
  final anchorKey = GlobalKey();
  final triggerFocus = FocusNode();
  Size triggerSize = Size.zero;

  bool get open => portal.isShowing;

  void toggle() {
    if (widget.items.isEmpty) return;
    setState(() => open ? portal.hide() : portal.show());
  }

  void close() {
    if (!open) return;
    setState(portal.hide);
    triggerFocus.requestFocus();
  }

  @override
  void didUpdateWidget(RaftSelectField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The owner can revoke a choice while its menu is open. A disabled
    // trigger must not leave an independently interactive list behind.
    if (open && (widget.onChanged == null || widget.items.isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            open &&
            (widget.onChanged == null || widget.items.isEmpty)) {
          setState(portal.hide);
        }
      });
    }
  }

  @override
  void dispose() {
    triggerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final enabled = widget.onChanged != null;
    final fieldChrome = widget.chrome == RaftSelectRecipeChrome.field;
    final selected = widget.items
        .where((e) => e.value == widget.value && widget.value != null)
        .firstOrNull;
    final hasValue =
        selected != null ||
        (widget.value != null && widget.unmatchedLabel != null);
    final trigger = RaftInteractive(
      onPressed: enabled ? toggle : null,
      focusNode: triggerFocus,
      semanticLabel: widget.label == null
          ? null
          : raftText(context, widget.label!),
      builder: (context, st) => t.isRaftLook
          ? _raftTrigger(
              context,
              t,
              st,
              enabled: enabled,
              selected: selected,
              hasValue: hasValue,
            )
          : _frozenTrigger(
              context,
              t,
              st,
              enabled: enabled,
              fieldChrome: fieldChrome,
              selected: selected,
              hasValue: hasValue,
            ),
    );
    return CompositedTransformTarget(
      key: anchorKey,
      link: link,
      child: OverlayPortal(
        controller: portal,
        overlayChildBuilder: (context) =>
            RaftBackDismiss(onDismiss: close, child: _popup(context, t)),
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

  /// Raft look: `SelectTrigger` is the `Button` outline md box merged with the `select` recipe `trigger` slot; the
  /// value is the `SelectValue` text (`text-foreground-hint` while it shows the placeholder) and the chevron is the
  /// `SelectIcon`.
  Widget _raftTrigger(
    BuildContext context,
    RaftTokens t,
    RaftInteractionState st, {
    required bool enabled,
    required RaftSelectItem<T>? selected,
    required bool hasValue,
  }) {
    final rt = t.recipeTokens;
    final states = t.recipeStates(
      hovered: st.hovered,
      pressed: st.pressed,
      focusVisible: st.focusVisible,
      disabled: !enabled,
      extra: [
        if (open) 'data-popup-open',
        if (widget.invalid) 'data-invalid',
        if (!hasValue) 'data-placeholder',
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
      chrome: widget.chrome,
      states: states,
      tokens: rt,
    );
    final chevron = sel.icon.target('& > svg');
    return RaftRecipeBox(
      style: raftMergeSlots(button, sel.trigger),
      tokens: rt,
      decorationOverride: (decoration) => raftSnapBorder(context, decoration),
      width: double.infinity,
      height: widget.height,
      child: Row(
        children: [
          Expanded(
            child: DefaultTextStyle.merge(
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              child:
                  selected?.child ??
                  Text(hasValue ? widget.unmatchedLabel! : widget.placeholder),
            ),
          ),
          SizedBox(width: sel.trigger.columnGap),
          Opacity(
            opacity: sel.icon.opacity ?? 1,
            child: RaftIcon(
              RaftGlyph.chevronDown,
              size: chevron?.width ?? 16,
              color: sel.icon.color?.resolve(rt),
            ),
          ),
        ],
      ),
    );
  }

  Widget _raftPopup(BuildContext context, RaftTokens t) {
    final rt = t.recipeTokens;
    final base = RaftSelectRecipe.resolve(
      theme: t.recipeTheme,
      chrome: widget.chrome,
      states: t.recipeStates(),
      tokens: rt,
    );
    final preferred = widget.items.indexWhere(
      (item) => item.enabled && item.value == widget.value,
    );
    return Positioned.fill(
      child: TapRegion(
        onTapOutside: (_) => close(),
        child: RaftDismissScope(
          onDismiss: close,
          takeFocus: true,
          child: Stack(
            children: [
              RaftAnchoredPopup(
                anchorKey: anchorKey,
                movement: Scrollable.maybeOf(this.context)?.position,
                child: RaftMenuPopupBackend(
                  key: const ValueKey('raft-select-popup'),
                  anchorWidth: triggerSize.width,
                  triggerFocus: triggerFocus,
                  preferredIndex: preferred < 0 ? null : preferred,
                  semanticRole: SemanticsRole.list,
                  itemSemanticRole: SemanticsRole.listItem,
                  selectionSemantics: true,
                  entries: [
                    for (final item in widget.items)
                      RaftMenuPopupEntry(
                        key: ValueKey(item.value),
                        label: item.label,
                        labelChild: item.child,
                        enabled: item.enabled,
                        selected: item.value == widget.value,
                        indicator: RaftIcon(
                          RaftGlyph.check,
                          size: base.itemIndicator.target('& > svg')!.width!,
                        ),
                      ),
                  ],
                  resolveSlots: (state) {
                    // The backend resolves its surface/list with index -1.
                    // Row state is already a complete recipe input, so no
                    // option lookup (including a sentinel lookup) is needed.
                    final sel = RaftSelectRecipe.resolve(
                      theme: t.recipeTheme,
                      chrome: widget.chrome,
                      states: t.recipeStates(
                        hovered: !state.disabled && state.hovered,
                        focusVisible: !state.disabled && state.focusVisible,
                        extra: [
                          if (state.disabled) 'data-disabled',
                          if (state.selected) 'data-selected',
                          if (!state.disabled && state.highlighted)
                            'data-highlighted',
                          if (state.lastChild) 'last-child',
                        ],
                      ),
                      tokens: rt,
                    );
                    return RaftMenuPopupSlots(
                      content: sel.content,
                      list: sel.list,
                      item: sel.item,
                      itemIndicator: sel.itemIndicator,
                      itemLeading: sel.itemLeading,
                      itemText: sel.itemText,
                    );
                  },
                  onActivate: (index) {
                    // Typed values and current activation authority remain
                    // with Select; the backend only returns an index.
                    if (index < 0 || index >= widget.items.length) return;
                    final item = widget.items[index];
                    if (!item.enabled || widget.onChanged == null) return;
                    widget.onChanged!(item.value);
                    close();
                  },
                  onDismiss: close,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _popup(BuildContext context, RaftTokens t) {
    // Revoke interaction in the current frame; the portal controller is hidden
    // after build, since OverlayPortal forbids hide during persistent callbacks.
    if (widget.onChanged == null || widget.items.isEmpty)
      return const SizedBox.shrink();
    if (t.isRaftLook) return _raftPopup(context, t);
    final rt = t.recipeTokens;
    final sel = RaftSelectRecipe.resolve(
      theme: t.recipeTheme,
      chrome: widget.chrome,
      states: t.recipeStates(),
      tokens: rt,
    );
    final items = [
      for (var i = 0; i < widget.items.length; i++)
        _SelectItem<T>(
          item: widget.items[i],
          selected: widget.items[i].value == widget.value,
          chrome: widget.chrome,
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
        // Escape closes even while focus is still on the trigger.
        child: RaftDismissScope(
          onDismiss: close,
          takeFocus: true,
          child: Stack(
            children: [
              RaftAnchoredPopup(
                anchorKey: anchorKey,
                movement: Scrollable.maybeOf(this.context)?.position,
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
                        key: const ValueKey('raft-select-popup'),
                        child: SingleChildScrollView(
                          padding: sel.list.padding,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < items.length; i++) ...[
                                if (i > 0)
                                  SizedBox(height: sel.list.rowGap ?? 0),
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
    required this.chrome,
    required this.last,
    required this.autofocus,
    required this.onSelect,
  });
  final RaftSelectItem<T> item;
  final bool selected, last, autofocus;
  final RaftSelectRecipeChrome chrome;
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
      chrome: widget.chrome,
      states: t.recipeStates(
        hovered: hovered && enabled && RaftHoverScope.of(context),
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
        onShowHoverHighlight: (v) =>
            setState(() => hovered = v && RaftHoverScope.of(context)),
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

CssValue _selectShadow(RaftCssShadow layer) => CssSeq([
  if (layer.inset) const CssKeyword('inset'),
  CssNum(layer.offset.dx, 'px'),
  CssNum(layer.offset.dy, 'px'),
  CssNum(layer.blur, 'px'),
  CssNum(layer.spread, 'px'),
  CssColor(layer.color.toARGB32(), null, layer.color),
]);
