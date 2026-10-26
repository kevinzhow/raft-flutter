// raft-ui `RadioGroup` / `RadioGroupItem` / `RadioGroupIndicator`: a grid of round options for choosing one of a few
// answers. The item is a 20px circle (`border-line-strong bg-layer-card`, `focus-visible:shadow-focus`) with an 8px dot
// when it is the chosen one; the `<label>` around it makes the whole row the hit area. Arrow keys move the choice.
// The look comes from the generated `radioGroup` recipe (the frozen 0.5.52 set for Elegant and Brutal).
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/services.dart';

import 'design_primitives.dart';
import 'dialog_card.dart' show raftRecipeThemeOf;
import 'recipe_surface.dart';
import 'recipes/radio_group.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart' show RaftRecipeTokens;
import 'space.dart';
import 'theme.dart';

class _RadioScope<T> extends InheritedWidget {
  const _RadioScope({
    required this.group,
    required this.value,
    required super.child,
  });
  final _RaftRadioGroupState<T> group;
  final T? value;

  @override
  bool updateShouldNotify(_RadioScope<T> old) =>
      old.value != value ||
      old.group.widget.onChanged != group.widget.onChanged;
}

/// raft-ui `RadioGroup`: [value] is the chosen item, [onChanged] receives the next one. A null [onChanged] disables
/// the whole group.
class RaftRadioGroup<T> extends StatefulWidget {
  const RaftRadioGroup({
    super.key,
    required this.value,
    required this.onChanged,
    required this.children,
    this.spacing = RaftSpace.x2,
    this.semanticLabel,
  });

  final T? value;
  final ValueChanged<T>? onChanged;

  /// The items, usually [RaftRadioGroupItem]s (`grid w-full gap-2`).
  final List<Widget> children;

  /// The row gap (`gap-2`).
  final double spacing;
  final String? semanticLabel;

  @override
  State<RaftRadioGroup<T>> createState() => _RaftRadioGroupState<T>();
}

class _RaftRadioGroupState<T> extends State<RaftRadioGroup<T>> {
  void move(int delta) {
    if (widget.onChanged == null) return;
    // Read the mounted row order and current widget values at the key event.
    // Mount-time registration becomes stale when rows are replaced or keyed
    // rows move; nested groups must keep their own keyboard selection.
    final enabled = <_RaftRadioGroupItemState<T>>[];
    void visit(Element element) {
      if (element is StatefulElement) {
        final state = element.state;
        if (state is _RaftRadioGroupItemState<T> &&
            state.widget.enabled &&
            state.context
                    .getInheritedWidgetOfExactType<_RadioScope<T>>()
                    ?.group ==
                this) {
          enabled.add(state);
        }
      }
      element.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    if (enabled.isEmpty) return;
    final current = enabled.indexWhere((i) => i.widget.value == widget.value);
    final next =
        ((current < 0 ? (delta > 0 ? -1 : 0) : current) + delta) %
        enabled.length;
    widget.onChanged!(enabled[next].widget.value);
    enabled[next].focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => _RadioScope<T>(
    group: this,
    value: widget.value,
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => move(1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => move(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => move(-1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => move(-1),
      },
      child: Semantics(
        role: SemanticsRole.radioGroup,
        label: widget.semanticLabel,
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: widget.spacing,
          children: widget.children,
        ),
      ),
    ),
  );
}

/// raft-ui `RadioGroupItem` with its `RadioGroupIndicator`, inside the `<label>` row Web wraps it in. [child] is the
/// label content (omit it for the bare circle); the whole row selects [value].
class RaftRadioGroupItem<T> extends StatefulWidget {
  const RaftRadioGroupItem({
    super.key,
    required this.value,
    this.child,
    this.enabled = true,
    this.gap = RaftSpace.x3,
    this.markInset = EdgeInsets.zero,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.padding = EdgeInsets.zero,
    this.minHeight = 0,
    this.semanticLabel,
  });

  final T value;
  final Widget? child;
  final bool enabled;

  /// Space between the circle and the label (`gap-3`).
  final double gap;

  /// Space around the circle (`mt-0.5` when the label has several lines).
  final EdgeInsets markInset;
  final CrossAxisAlignment crossAxisAlignment;

  /// Room around the row, and the least height of its hit area (a 44px choice row).
  final EdgeInsets padding;
  final double minHeight;
  final String? semanticLabel;

  @override
  State<RaftRadioGroupItem<T>> createState() => _RaftRadioGroupItemState<T>();
}

class _RaftRadioGroupItemState<T> extends State<RaftRadioGroupItem<T>> {
  final focus = FocusNode();
  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_RadioScope<T>>();
    final chosen = scope?.value == widget.value;
    final onChanged = scope?.group.widget.onChanged;
    final enabled = widget.enabled && onChanged != null;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      child: RaftInteractive(
        onPressed: enabled ? () => onChanged(widget.value) : null,
        focusNode: focus,
        button: false,
        checked: chosen,
        semanticLabel: widget.semanticLabel,
        builder: (context, st) {
          final mark = Padding(
            padding: widget.markInset,
            child: RaftRadioMark(
              checked: chosen,
              enabled: enabled,
              focusVisible: st.focusVisible,
            ),
          );
          if (widget.child == null) return mark;
          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.minHeight),
            child: Padding(
              padding: widget.padding,
              child: Row(
                crossAxisAlignment: widget.crossAxisAlignment,
                spacing: widget.gap,
                children: [
                  mark,
                  Expanded(child: widget.child!),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The painted circle of a radio item (`radioGroup` recipe `item` + `dot`): the checked one carries the dot.
class RaftRadioMark extends StatelessWidget {
  const RaftRadioMark({
    super.key,
    required this.checked,
    this.enabled = true,
    this.focusVisible = false,
  });
  final bool checked, enabled, focusVisible;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final s = RaftRadioGroupRecipe.resolve(
      theme: raftRecipeThemeOf(t),
      states: t.recipeStates(
        focusVisible: focusVisible,
        disabled: !enabled,
        checked: checked,
        extra: [if (!enabled) 'data-disabled'],
      ),
      tokens: rt,
    );
    final item = s.item, dot = s.dot;
    if (!t.isRaftLook) return _frozenRadioMark(item, dot, checked, rt);
    return ExcludeSemantics(
      child: RaftRecipeBox(
        style: item,
        tokens: rt,
        alignment: Alignment.center,
        child: checked ? RaftRecipeBox(style: dot, tokens: rt) : null,
      ),
    );
  }
}

/// The frozen Elegant and Brutal circle: the recipe decoration of the pre-0.7.0 radio, no focus ring.
Widget _frozenRadioMark(
  RaftSlotStyle item,
  RaftSlotStyle dot,
  bool checked,
  RaftRecipeTokens rt,
) {
  final size = item.width ?? 14.0;
  return Container(
    width: size,
    height: item.height ?? size,
    alignment: Alignment.center,
    decoration: item.decoration(rt),
    child: checked
        ? Container(
            width: dot.width ?? 6,
            height: dot.height ?? 6,
            decoration: dot.decoration(rt),
          )
        : null,
  );
}
