import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:raft_theme/recipes/web_selection_row.g.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'menu_action_row.dart';
import 'overlays/dialog.dart';
import 'recipe_surface.dart';
import 'theme.dart';

/// Typed data and actions for a native chooser presented as a dialog.
@immutable
class RaftChoiceDialogOption<T> {
  const RaftChoiceDialogOption({
    this.key,
    required this.value,
    required this.label,
    this.enabled = true,
    this.selected = false,
    this.leading,
    this.trailing,
    this.onAuxiliary,
  });

  final Key? key;
  final T value;
  final String label;
  final bool enabled, selected;
  final Widget? leading, trailing;

  /// The owner decides whether a middle press is applicable and what it opens.
  /// It never selects [value] or invokes [RaftChoiceDialog.onSelected].
  final VoidCallback? onAuxiliary;
}

/// Native chooser role adapter using the existing Dialog and selection row.
///
/// Web uses anchored ServerSwitcherMenu / SelectionPopover for these actions.
/// Native entry points that already present a chooser dialog keep that route
/// and cancellation behavior. Only its canonical Dialog paints a surface; rows
/// use the generated WebSelectionRow slots through the shared menu paint part.
/// Account/permission checks and route result authority stay with the caller.
/// Frozen looks retain their original caller-owned SimpleDialog branches.
class RaftChoiceDialog<T> extends StatefulWidget {
  const RaftChoiceDialog({
    super.key,
    required this.title,
    required this.options,
    required this.onSelected,
    required this.onClose,
  });

  final String title;
  final List<RaftChoiceDialogOption<T>> options;
  final ValueChanged<T> onSelected;
  final VoidCallback onClose;

  @override
  State<RaftChoiceDialog<T>> createState() => _RaftChoiceDialogState<T>();
}

class _RaftChoiceDialogState<T> extends State<RaftChoiceDialog<T>> {
  final _nodes = <FocusNode>[];
  final _rowKeys = <GlobalKey>[];
  final _optionKeys = <Key?>[];

  @override
  void initState() {
    super.initState();
    _syncNodes();
    _focusInitial();
  }

  void _syncNodes() {
    final oldNodes = List<FocusNode>.of(_nodes);
    final oldRows = List<GlobalKey>.of(_rowKeys);
    final oldKeys = List<Key?>.of(_optionKeys);
    final used = <int>{};
    _nodes.clear();
    _rowKeys.clear();
    _optionKeys.clear();
    for (var index = 0; index < widget.options.length; index++) {
      final key = widget.options[index].key;
      final oldIndex = key != null
          ? oldKeys.indexOf(key)
          : index < oldKeys.length && oldKeys[index] == null
          ? index
          : -1;
      if (oldIndex >= 0 && used.add(oldIndex)) {
        _nodes.add(oldNodes[oldIndex]);
        _rowKeys.add(oldRows[oldIndex]);
      } else {
        final node = FocusNode();
        node.addListener(() => _reveal(node));
        _nodes.add(node);
        _rowKeys.add(GlobalKey());
      }
      _optionKeys.add(key);
    }
    for (var index = 0; index < oldNodes.length; index++) {
      if (!used.contains(index)) oldNodes[index].dispose();
    }
  }

  @override
  void didUpdateWidget(RaftChoiceDialog<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focused = _nodes.where((node) => node.hasFocus).firstOrNull;
    _syncNodes();
    final retained = focused == null ? -1 : _nodes.indexOf(focused);
    if (focused != null &&
        (retained < 0 || !widget.options[retained].enabled)) {
      _focusInitial();
    } else if (retained >= 0) {
      _reveal(focused!);
    }
  }

  void _focusInitial() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      final preferred = widget.options.indexWhere(
        (option) => option.enabled && option.selected,
      );
      final first = preferred >= 0
          ? preferred
          : widget.options.indexWhere((option) => option.enabled);
      if (first >= 0) _nodes[first].requestFocus();
    });
  }

  void _move(int step, {bool edge = false}) {
    final choices = [
      for (var i = 0; i < widget.options.length; i++)
        if (widget.options[i].enabled) i,
    ];
    if (choices.isEmpty) return;
    final current = choices.indexWhere((index) => _nodes[index].hasFocus);
    final next = edge || current < 0
        ? step > 0
              ? 0
              : choices.length - 1
        : (current + step) % choices.length;
    _nodes[choices[next]].requestFocus();
  }

  void _reveal(FocusNode node) {
    if (!mounted || !node.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !node.hasFocus) return;
      final index = _nodes.indexOf(node);
      if (index < 0) return;
      final row = _rowKeys[index].currentContext;
      final target = row?.findRenderObject();
      final scrollable = row == null ? null : Scrollable.maybeOf(row);
      final viewport = target == null
          ? null
          : RenderAbstractViewport.maybeOf(target);
      if (target == null || scrollable == null || viewport == null) return;
      // Move only the nearest dialog body, by the minimum distance in either
      // direction. Revealing the end alone leaves Home/ArrowUp above its clip.
      final position = scrollable.position;
      final start = viewport.getOffsetToReveal(target, 0).offset;
      final end = viewport.getOffsetToReveal(target, 1).offset;
      final next = position.pixels > start
          ? start
          : position.pixels < end
          ? end
          : position.pixels;
      final bounded = next.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (bounded != position.pixels) position.jumpTo(bounded);
    });
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final rt = tokens.recipeTokens;
    return RaftDialog(
      title: widget.title,
      onClose: widget.onClose,
      content: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
          const SingleActivator(LogicalKeyboardKey.home): () =>
              _move(1, edge: true),
          const SingleActivator(LogicalKeyboardKey.end): () =>
              _move(-1, edge: true),
        },
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < widget.options.length; i++)
                Builder(
                  key: _rowKeys[i],
                  builder: (context) {
                    final option = widget.options[i];
                    return Listener(
                      onPointerDown:
                          option.enabled && option.onAuxiliary != null
                          ? (event) {
                              if (event.buttons == kMiddleMouseButton) {
                                option.onAuxiliary!();
                              }
                            }
                          : null,
                      child: RaftInteractive(
                        key: option.key,
                        focusNode: _nodes[i],
                        semanticLabel: option.label,
                        checked: option.selected,
                        onPressed: option.enabled
                            ? () => widget.onSelected(option.value)
                            : null,
                        builder: (context, state) {
                          final recipe = RaftWebSelectionRowRecipe.resolve(
                            checked: option.selected,
                            disabled: !option.enabled,
                            tokens: rt,
                            states: tokens.recipeStates(
                              hovered: state.hovered,
                              focusVisible: state.focusVisible,
                              disabled: !option.enabled,
                            ),
                          );
                          return RaftMenuSlotRow(
                            label: option.label,
                            labelChild: ExcludeSemantics(
                              child: Text(option.label),
                            ),
                            leading: option.leading,
                            trailing: option.trailing,
                            indicator: option.selected
                                ? RaftIcon(
                                    RaftGlyph.check,
                                    size: recipe.indicator.width!,
                                  )
                                : null,
                            root: recipe.root,
                            itemLeading: recipe.leading,
                            itemText: recipe.label,
                            itemIndicator: recipe.indicator,
                            tokens: rt,
                          );
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
