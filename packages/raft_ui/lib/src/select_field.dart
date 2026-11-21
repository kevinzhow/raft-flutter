// raft-ui `Select`: trigger (`Button` outline md merged with the `select`
// recipe `trigger` slot), value / chevron icon, and the popup (`content`,
// `list`, `item`, `itemIndicator` slots) in an overlay anchored below the
// trigger.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:raft_theme/recipes/select.g.dart' as raft_select;

import 'design_primitives.dart';
import 'anchored_popup.dart';
import 'dismiss_scope.dart';
import 'icons.dart';
import 'localization.dart';
import 'menu_popup_backend.dart';
import 'panel_layout.dart' show RaftCssText;
import 'picker_trigger_button.dart';
import 'recipe_surface.dart';
import 'recipes/badge.g.dart' show RaftBadgeRecipeVariant;
import 'recipes/button_variants.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/select.g.dart';
import 'agent_profile.dart' show RaftInlineBadge, RaftRecipeBadge;
import 'form_controls.dart' show RaftField;
import 'theme.dart';
import 'raft/css_box.dart' show raftSnapBorder;

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
///
/// The optional parts are opt-in and change nothing for an item that sets none of them: a [group] heading
/// (`SelectGroup` + `SelectGroupLabel`), a [description] line (`SelectItemDescription`), a [badge] after the
/// label, a [suffix] after the label and badge, and the non-value action row ([RaftSelectItem.action],
/// `SelectActionItem`).
@immutable
class RaftSelectItem<T> {
  const RaftSelectItem({
    required this.value,
    required this.label,
    this.enabled = true,
    this.cssText = false,
    this.labelKey,
    this.group,
    this.description,
    this.badge,
    this.suffix,
    this.suffixInList = true,
    this.listTrailing,
    this.listed = true,
  }) : onAction = null;

  /// A row at the end of the list that changes what the list shows ("Show all supported"). It is reached by
  /// the arrow keys and by typeahead like an option, but it never becomes the value, never reaches
  /// `onChanged` and leaves the list open. [value] only identifies the row (a sentinel the owner never uses
  /// as a real value).
  const RaftSelectItem.action({
    required this.value,
    required this.label,
    required VoidCallback this.onAction,
    this.labelKey,
  }) : enabled = true,
       cssText = false,
       group = null,
       description = null,
       badge = null,
       suffix = null,
       suffixInList = true,
       listTrailing = null,
       listed = true;

  final T value;

  /// False leaves the row out of the open list while the closed field still
  /// resolves its label (Web `getSelectMenuOptions` `hideSelectedOption`: the
  /// chosen language is not offered again; `items` stays the full collection).
  final bool listed;

  /// The text, already localised by the caller.
  final String label;
  final bool enabled;

  /// Paint the label with the baseline-snapped [RaftCssText] (the settings forms) instead of a plain [Text].
  final bool cssText;

  /// Key of the label text (tests find a choice by it, in the trigger and in the list).
  final Key? labelKey;

  /// Heading of the group this row belongs to. Contiguous rows with the same group share one heading; a
  /// hairline separates groups. Null rows list without a heading.
  final String? group;

  /// A second line under the label: what the row means, not its name again.
  final String? description;

  /// Text of an inline badge after the label (Web `Badge.Experimental`), in the list and in the closed field.
  final String? badge;

  /// What follows the label and badge (" · Update required"). Always in the closed field; in the list unless
  /// [suffixInList] is false (the group heading already says it).
  final String? suffix;
  final bool suffixInList;
  final Widget? listTrailing;

  /// Set for the action row ([RaftSelectItem.action]).
  final VoidCallback? onAction;
  bool get isAction => onAction != null;

  bool get _decorated => badge != null || suffix != null;

  Widget _build(bool inList) {
    if (!_decorated) {
      return cssText
          ? RaftCssText(label, key: labelKey)
          : Text(label, key: labelKey);
    }
    final tail = inList && !suffixInList ? null : suffix;
    return Text.rich(
      key: labelKey,
      TextSpan(
        children: [
          TextSpan(text: label),
          if (badge != null) ...[
            const TextSpan(text: ' '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: RaftInlineBadge(
                badge: RaftRecipeBadge(
                  badge!,
                  variant: RaftBadgeRecipeVariant.success,
                ),
              ),
            ),
          ],
          if (tail != null) TextSpan(text: tail),
        ],
      ),
    );
  }

  /// The label widget the closed trigger shows: name, badge and every suffix.
  Widget get child => _build(false);

  /// The label widget the list shows.
  Widget get listChild => _build(true);

  /// The label as announced: name, badge and suffix in the closed field.
  String get semanticLabel =>
      '$label${badge == null ? '' : ' $badge'}${suffix ?? ''}';
}

/// A [RaftSelectField] under its label (`Field` + `FieldLabel` + `Select`): the canonical field and select.
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

  /// Key of the select.
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
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
    this.toolbarPicker = false,
    this.popupMinWidth,
    this.triggerBuilder,
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
  final bool toolbarPicker;
  final double? popupMinWidth;
  final Widget Function(BuildContext, FocusNode, VoidCallback?)? triggerBuilder;

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
    final selected = widget.items
        .where(
          (e) => !e.isAction && e.value == widget.value && widget.value != null,
        )
        .firstOrNull;
    final hasValue =
        selected != null ||
        (widget.value != null && widget.unmatchedLabel != null);
    final onPressed = enabled ? toggle : null;
    final trigger =
        widget.triggerBuilder?.call(context, triggerFocus, onPressed) ??
        (widget.toolbarPicker
            ? RaftPickerTriggerButton(
                label:
                    selected?.label ??
                    (hasValue ? widget.unmatchedLabel! : widget.placeholder),
                semanticLabel: widget.label,
                onPressed: onPressed,
                focusNode: triggerFocus,
                invalid: widget.invalid,
              )
            : RaftInteractive(
                onPressed: onPressed,
                focusNode: triggerFocus,
                semanticLabel: widget.label == null
                    ? null
                    : raftText(context, widget.label!),
                builder: (context, st) => _raftTrigger(
                  context,
                  t,
                  st,
                  enabled: enabled,
                  selected: selected,
                  hasValue: hasValue,
                ),
              ));
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
      responsive: true,
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
      variant: RaftButtonRecipeVariant.outline,
      size: RaftButtonRecipeSize.md,
      states: states,
      tokens: rt,
    ).root;
    final sel = RaftSelectRecipe.resolve(
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
              overflow: TextOverflow.ellipsis,
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
      chrome: widget.chrome,
      states: t.recipeStates(responsive: true),
      tokens: rt,
    );
    final preferredItem = widget.items.indexWhere(
      (item) => !item.isAction && item.enabled && item.value == widget.value,
    );
    // Group headings, separators and the action row come from the items; the
    // backend only sees entries. `itemOf[i]` is the item behind entry i (null
    // for a heading or separator). Plain selects produce one entry per item.
    final entries = <RaftMenuPopupEntry>[];
    final itemOf = <int?>[];
    final structured = widget.items.any(
      (item) => item.group != null || item.isAction,
    );
    String? openGroup;
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      if (!item.listed) continue;
      if (structured) {
        final group = item.isAction ? null : item.group;
        if (i > 0 && (item.isAction || group != openGroup)) {
          entries.add(
            RaftMenuPopupEntry.separator(key: ValueKey('separator:$i')),
          );
          itemOf.add(null);
        }
        if (group != null && group != openGroup) {
          entries.add(
            RaftMenuPopupEntry.heading(
              key: ValueKey('group:$group'),
              label: group,
            ),
          );
          itemOf.add(null);
        }
        openGroup = group;
      }
      entries.add(
        RaftMenuPopupEntry(
          key: ValueKey(item.value),
          label: item.semanticLabel,
          labelChild: item.listChild,
          trailing: item.listTrailing,
          enabled: item.enabled,
          selected: !item.isAction && item.value == widget.value,
          description: item.description,
          action: item.isAction,
          indicator: RaftIcon(
            RaftGlyph.check,
            size: base.itemIndicator.target('& > svg')!.width!,
          ),
        ),
      );
      itemOf.add(i);
    }
    final preferred = itemOf.indexOf(preferredItem < 0 ? null : preferredItem);
    final needsExtras =
        structured || widget.items.any((e) => e.description != null);
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
                  anchorWidth: math.max(
                    triggerSize.width,
                    widget.popupMinWidth ?? 0,
                  ),
                  triggerFocus: triggerFocus,
                  preferredIndex: preferredItem < 0 || preferred < 0
                      ? null
                      : preferred,
                  semanticRole: SemanticsRole.list,
                  itemSemanticRole: SemanticsRole.listItem,
                  selectionSemantics: true,
                  entries: entries,
                  resolveSlots: (state) {
                    final states = t.recipeStates(
                      responsive: true,
                      hovered: !state.disabled && state.hovered,
                      focusVisible: !state.disabled && state.focusVisible,
                      extra: [
                        if (state.disabled) 'data-disabled',
                        if (state.selected) 'data-selected',
                        if (!state.disabled && state.highlighted)
                          'data-highlighted',
                        if (state.lastChild) 'last-child',
                      ],
                    );
                    // The backend resolves its surface/list with index -1.
                    // Row state is already a complete recipe input, so no
                    // option lookup (including a sentinel lookup) is needed.
                    final sel = RaftSelectRecipe.resolve(
                      chrome: widget.chrome,
                      states: states,
                      tokens: rt,
                    );
                    // The slots of the grouped / described / action rows.
                    final more = !needsExtras
                        ? null
                        : raft_select.RaftSelectRecipe.resolve(
                            chrome: raft_select.RaftSelectRecipeChrome.values
                                .where((e) => e.css == widget.chrome.css)
                                .firstOrNull,
                            states: states,
                            tokens: rt,
                          );
                    return RaftMenuPopupSlots(
                      content: sel.content,
                      list: sel.list,
                      item: sel.item,
                      itemIndicator: sel.itemIndicator,
                      itemLeading: sel.itemLeading,
                      itemText: sel.itemText,
                      itemDescription: more?.itemDescription,
                      actionItem: more?.actionItem,
                      groupLabel: more?.groupLabel,
                      separator: more?.separator,
                    );
                  },
                  onActivate: (index) {
                    // Typed values and current activation authority remain
                    // with Select; the backend only returns an index.
                    if (index < 0 || index >= itemOf.length) return;
                    final at = itemOf[index];
                    if (at == null) return;
                    final item = widget.items[at];
                    if (!item.enabled) return;
                    // An action row changes what the list shows and leaves
                    // it open; it is never the value.
                    if (item.onAction case final action?) {
                      action();
                      return;
                    }
                    if (widget.onChanged == null) return;
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
    return _raftPopup(context, t);
  }
}
