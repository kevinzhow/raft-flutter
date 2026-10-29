import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_theme/recipes/recipe_utilities.g.dart' as source;

import 'design_primitives.dart' show RaftInteractive;
import 'menu_action_row.dart';
import 'menu_focus_reveal.dart';
import 'recipe_surface.dart';
import 'recipe_background_scope.dart';
import 'recipes/recipe_runtime.dart';
import 'theme.dart';

/// Presentation data for one popup row. Typed values stay with its owner.
@immutable
class RaftMenuPopupEntry {
  const RaftMenuPopupEntry({
    this.key,
    required this.label,
    this.labelChild,
    this.enabled = true,
    this.selected = false,
    this.leading,
    this.trailing,
    this.indicator,
  });

  final Key? key;
  final String label;

  /// An existing label renderer/key; the plain label remains its accessible
  /// name. It inherits the generated text slot and scaling policy.
  final Widget? labelChild;
  final bool enabled, selected;
  final Widget? leading, trailing;

  /// Caller-owned indicator artwork, shown only while [selected]. Its slot
  /// supplies dimensions and colour; the backend does not invent a checkmark.
  final Widget? indicator;
}

/// State supplied to the caller's existing generated recipe resolver.
@immutable
class RaftMenuPopupRowState {
  const RaftMenuPopupRowState({
    required this.index,
    this.selected = false,
    this.disabled = false,
    this.highlighted = false,
    this.hovered = false,
    this.focusVisible = false,
    this.lastChild = false,
  });

  /// The surface/list resolution uses -1 with no row interaction state.
  final int index;
  final bool selected, disabled, highlighted, hovered, focusVisible, lastChild;
}

/// Generated paint/layout slots shared by action and typed choice adapters.
@immutable
class RaftMenuPopupSlots {
  const RaftMenuPopupSlots({
    required this.content,
    required this.list,
    required this.item,
    required this.itemIndicator,
    this.itemLeading,
    this.itemText,
  });

  final RaftSlotStyle content, list, item, itemIndicator;
  final RaftSlotStyle? itemLeading, itemText;
}

typedef RaftMenuPopupSlotResolver = RaftMenuPopupSlots Function(
  RaftMenuPopupRowState state,
);

/// Recipe-painted popup contents with shared keyboard/focus ownership.
///
/// The caller still owns the overlay, placement, outside/back dismissal, typed
/// values and activation authority. [onActivate] only reports the row index;
/// it neither changes [RaftMenuPopupEntry.selected] nor implicitly dismisses.
/// Escape calls [onDismiss], and removal restores the trigger when this popup
/// held focus. Set [autofocus] false for pointer-hover menus that retain editor
/// focus. The frozen Elegant/Brutal adapters do not use this backend.
class RaftMenuPopupBackend extends StatefulWidget {
  const RaftMenuPopupBackend({
    super.key,
    required this.entries,
    required this.resolveSlots,
    required this.onActivate,
    required this.onDismiss,
    this.anchorWidth,
    this.maxHeight,
    this.preferredIndex,
    this.triggerFocus,
    this.autofocus = true,
    this.semanticRole = SemanticsRole.menu,
    this.itemSemanticRole = SemanticsRole.menuItem,
    this.selectionSemantics = false,
  }) : assert(
         anchorWidth == null ||
             (anchorWidth >= 0 && anchorWidth < double.infinity),
       ),
       assert(maxHeight == null || maxHeight >= 0);

  final List<RaftMenuPopupEntry> entries;
  final RaftMenuPopupSlotResolver resolveSlots;
  final ValueChanged<int> onActivate;
  final VoidCallback onDismiss;

  /// A finite anchor width, or null when the source/parent supplies width.
  /// Select callers provide it to bind Base UI's --anchor-width declaration.
  final double? anchorWidth, maxHeight;
  final int? preferredIndex;
  final FocusNode? triggerFocus;
  final bool autofocus;

  /// This SDK has no listBox role. A choice adapter may supply list/listItem
  /// plus [selectionSemantics]; action adapters retain menu/menuItem.
  final SemanticsRole semanticRole, itemSemanticRole;
  final bool selectionSemantics;

  @override
  State<RaftMenuPopupBackend> createState() => _RaftMenuPopupBackendState();
}

class _RaftMenuPopupBackendState extends State<RaftMenuPopupBackend> {
  final _scope = FocusScopeNode(debugLabel: 'RaftMenuPopupBackend');
  final _scroll = ScrollController();
  final _keyboardFocus = FocusNode(debugLabel: 'popup-empty-keyboard');
  bool _heldFocusOnDeactivate = false;
  final _nodes = <FocusNode>[];
  final _rowKeys = <GlobalKey>[];
  int? _activeIndex;
  bool _dismissing = false;

  bool _enabled(int? index) =>
      index != null &&
      index >= 0 &&
      index < widget.entries.length &&
      widget.entries[index].enabled;

  int? _preferred() {
    if (_enabled(widget.preferredIndex)) return widget.preferredIndex;
    for (var i = 0; i < widget.entries.length; i++) {
      if (_enabled(i) && widget.entries[i].selected) return i;
    }
    return _edgeIndex(1);
  }

  int? _edgeIndex(int direction) {
    for (
      var i = direction > 0 ? 0 : widget.entries.length - 1;
      i >= 0 && i < widget.entries.length;
      i += direction
    ) {
      if (_enabled(i)) return i;
    }
    return null;
  }

  void _syncNodes([List<RaftMenuPopupEntry>? previous]) {
    final oldNodes = List<FocusNode>.of(_nodes);
    final oldKeys = List<GlobalKey>.of(_rowKeys);
    final used = <int>{};
    _nodes.clear();
    _rowKeys.clear();
    for (var index = 0; index < widget.entries.length; index++) {
      final key = widget.entries[index].key;
      final oldIndex = previous == null
          ? -1
          : key != null
          ? previous.indexWhere((entry) => entry.key == key)
          : index < previous.length && previous[index].key == null
          ? index
          : -1;
      if (oldIndex >= 0 && oldIndex < oldNodes.length && used.add(oldIndex)) {
        _nodes.add(oldNodes[oldIndex]);
        _rowKeys.add(oldKeys[oldIndex]);
      } else {
        final node = FocusNode(debugLabel: 'popup-row-$index');
        node.addListener(() => _focusChanged(node));
        _nodes.add(node);
        _rowKeys.add(GlobalKey());
      }
    }
    for (var index = 0; index < oldNodes.length; index++) {
      if (!used.contains(index)) oldNodes[index].dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    _syncNodes();
    _activeIndex = _preferred();
    if (widget.autofocus) _initialFocus();
  }

  void _initialFocus({bool keepCurrentFocus = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || (!widget.autofocus && !keepCurrentFocus)) return;
      if (_enabled(_activeIndex)) {
        _focus(_activeIndex!);
      } else {
        // An all-disabled or empty popup still receives Escape.
        _keyboardFocus.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(RaftMenuPopupBackend oldWidget) {
    super.didUpdateWidget(oldWidget);
    final heldFocus = _scope.hasFocus;
    final activeNode = _activeIndex != null && _activeIndex! < _nodes.length
        ? _nodes[_activeIndex!]
        : null;
    _syncNodes(oldWidget.entries);
    final retainedIndex = activeNode == null ? -1 : _nodes.indexOf(activeNode);
    _activeIndex = retainedIndex < 0 ? null : retainedIndex;
    if (widget.preferredIndex != oldWidget.preferredIndex ||
        !_enabled(_activeIndex)) {
      _activeIndex = _preferred();
      if (heldFocus || widget.autofocus) {
        _initialFocus(keepCurrentFocus: heldFocus);
      }
    } else if (widget.autofocus && !oldWidget.autofocus) {
      _initialFocus();
    } else if (heldFocus && _activeIndex != null) {
      _reveal(_activeIndex!);
    }
  }

  void _focusChanged(FocusNode node) {
    final index = _nodes.indexOf(node);
    if (!mounted || index < 0) return;
    if (node.hasFocus) {
      _activeIndex = index;
      _reveal(index);
    }
  }

  void _reveal(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index >= _rowKeys.length || !_scroll.hasClients) return;
      final target = _rowKeys[index].currentContext?.findRenderObject();
      if (target == null || !target.attached) return;
      // Reveal only in this popup, never an outer page or form scrollable.
      final list = widget
          .resolveSlots(const RaftMenuPopupRowState(index: -1))
          .list;
      revealRaftMenuRow(
        target: target,
        position: _scroll.position,
        paddingStart: list.length('scroll-padding-top') ?? 0,
        paddingEnd: list.length('scroll-padding-bottom') ?? 0,
      );
    });
  }

  void _focus(int index) {
    if (!_enabled(index)) return;
    _activeIndex = index;
    _nodes[index].requestFocus();
    _reveal(index);
  }

  void _move(int direction) {
    if (widget.entries.isEmpty) return;
    var index = _enabled(_activeIndex)
        ? _activeIndex!
        : direction > 0
        ? -1
        : 0;
    for (var visited = 0; visited < widget.entries.length; visited++) {
      index = (index + direction) % widget.entries.length;
      if (_enabled(index)) {
        _focus(index);
        return;
      }
    }
  }

  void _edge(int direction) {
    final next = _edgeIndex(direction);
    if (next != null) _focus(next);
  }

  void _activate(int? index) {
    if (_dismissing || !_enabled(index)) return;
    widget.onActivate(index!);
  }

  void _dismiss() {
    if (_dismissing) return;
    _dismissing = true;
    try {
      widget.onDismiss();
    } finally {
      // Dismissal authority stays with the owner. A guard that keeps the popup
      // mounted must not leave its rows permanently inert.
      _dismissing = false;
    }
  }

  @override
  void deactivate() {
    // Descendant Focus widgets detach before dispose; remember ownership while
    // the subtree is still active, without stealing focus on a reparent.
    _heldFocusOnDeactivate = _scope.hasFocus;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _heldFocusOnDeactivate = false;
  }

  @override
  void dispose() {
    if (_heldFocusOnDeactivate || _scope.hasFocus) {
      final trigger = widget.triggerFocus;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final current = FocusManager.instance.primaryFocus;
        final lostOwner =
            current == null ||
            current == FocusManager.instance.rootScope ||
            current.context?.mounted != true;
        // A newer destination's explicit focus claim wins over this fallback.
        if (lostOwner &&
            trigger?.context?.mounted == true &&
            trigger!.canRequestFocus) {
          trigger.requestFocus();
        }
      });
    }
    for (final node in _nodes) {
      node.dispose();
    }
    _scope.dispose();
    _keyboardFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rt = RaftTokens.of(context).recipeTokens;
    final surface = widget.resolveSlots(const RaftMenuPopupRowState(index: -1));
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = math.min(
          constraints.maxHeight,
          widget.maxHeight ?? double.infinity,
        );
        final content = _withPopupLengths(surface.content, availableHeight);
        final list = _withPopupLengths(surface.list, availableHeight);
        final width =
            content.width ??
            (widget.anchorWidth == null
                ? null
                : math.max(widget.anchorWidth!, content.minWidth ?? 0));
        return FocusScope(
          node: _scope,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  _move(1),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  _move(-1),
              const SingleActivator(LogicalKeyboardKey.home): () => _edge(1),
              const SingleActivator(LogicalKeyboardKey.end): () => _edge(-1),
              const SingleActivator(LogicalKeyboardKey.escape): _dismiss,
              const SingleActivator(LogicalKeyboardKey.enter): () =>
                  _activate(_activeIndex),
              const SingleActivator(LogicalKeyboardKey.space): () =>
                  _activate(_activeIndex),
            },
            child: Focus(
              focusNode: _keyboardFocus,
              skipTraversal: true,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: availableHeight),
                child: RaftRecipeBox(
                  style: content,
                  tokens: content.tokens ?? rt,
                  width: width,
                  clip: true,
                  child: RaftRecipeBackgroundScope(
                    style: content,
                    tokens: content.tokens ?? rt,
                    child: RaftRecipeBox(
                      style: list,
                      tokens: list.tokens ?? rt,
                      applyText: false,
                      child: RaftRecipeBackgroundScope(
                        style: list,
                        tokens: list.tokens ?? rt,
                        inheritUnpainted: true,
                        child: SingleChildScrollView(
                          controller: _scroll,
                          primary: false,
                          child: Semantics(
                            container: true,
                            explicitChildNodes: true,
                            role: widget.semanticRole,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: list.rowGap ?? 0,
                              children: [
                                for (var i = 0; i < widget.entries.length; i++)
                                  _row(i, rt),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _row(int index, RaftTokenResolver tokens) {
    final entry = widget.entries[index];
    return KeyedSubtree(
      key: entry.key,
      child: KeyedSubtree(
        key: _rowKeys[index],
        child: RaftInteractive(
          focusNode: _nodes[index],
          onPressed: entry.enabled ? () => _activate(index) : null,
          semanticLabel: entry.label,
          semanticRole: widget.itemSemanticRole,
          selected: widget.selectionSemantics ? entry.selected : null,
          button: false,
          builder: (context, state) {
            final slots = widget.resolveSlots(
              RaftMenuPopupRowState(
                index: index,
                selected: entry.selected,
                disabled: !entry.enabled,
                highlighted:
                    entry.enabled && (state.hovered || _nodes[index].hasFocus),
                hovered: state.hovered,
                focusVisible: state.focusVisible,
                lastChild: index == widget.entries.length - 1,
              ),
            );
            return ExcludeSemantics(
              child: RaftMenuSlotRow(
                label: entry.label,
                labelChild: entry.labelChild,
                leading: entry.leading,
                trailing: entry.trailing,
                indicator: entry.selected ? entry.indicator : null,
                root: slots.item,
                itemLeading: slots.itemLeading,
                itemText: slots.itemText,
                itemIndicator: slots.itemIndicator,
                tokens: slots.item.tokens ?? tokens,
              ),
            );
          },
        ),
      ),
    );
  }

  static final _sourceIndices = {
    for (var i = 0; i < source.raftRecipeUtilities.length; i++)
      source.raftRecipeUtilities[i].name: i,
  };

  RaftSlotStyle _withPopupLengths(RaftSlotStyle slot, double availableHeight) {
    // The first recipe pass correctly unsets declarations with unbound Base UI
    // variables. Reuse that same generated cascade with popup layout values;
    // only unresolved lengths are filled, preserving caller/theme overrides.
    final indices = [for (final name in slot.classes) _sourceIndices[name]];
    final projected = slot.context == null || indices.any((i) => i == null)
        ? null
        : RaftRecipeEngine(
            source.raftRecipeUtilities,
            {
              ...source.raftRecipeEngine.registered,
              if (widget.anchorWidth case final width?)
                '--anchor-width': CssNum(width, 'px'),
              if (availableHeight.isFinite)
                '--available-height': CssNum(availableHeight, 'px'),
            },
          ).resolveSlot(indices.cast<int>(), slot.context!.states, slot.tokens);
    double? resolve(String property) =>
        _length(slot[property], slot.tokens, availableHeight) ??
        (_hasUnboundValue(slot.properties[property])
            ? _length(
                projected == null ? null : projected[property],
                slot.tokens,
                availableHeight,
              )
            : null);
    return slot.copyWith(
      properties: {
        ...slot.properties,
        for (final property in const [
          'width',
          'min-width',
          'max-width',
          'height',
          'min-height',
          'max-height',
        ])
          if (resolve(property) case final length? when length.isFinite)
            property: CssNum(math.max(0, length), 'px'),
      },
    );
  }

  bool _hasUnboundValue(CssValue? value) => switch (value) {
    CssUnset() => true,
    CssCalc(:final expr) => _hasUnboundValue(expr),
    CssFunction(:final args) => args.any(_hasUnboundValue),
    CssOp(:final a, :final b) => _hasUnboundValue(a) || _hasUnboundValue(b),
    CssSeq(:final items) ||
    CssList(:final items) => items.any(_hasUnboundValue),
    _ => false,
  };

  /// Resolve layout-owned CSS variables from the existing generated AST. In
  /// particular Select's max(var(--anchor-width), 220px) stays recipe-owned.
  double? _length(
    CssValue? value,
    RaftTokenResolver? tokens,
    double available,
  ) {
    switch (value) {
      case CssNum(unit: 'px', :final value):
      case CssNum(unit: '', :final value):
        return value;
      case CssVar(:final name, :final fallback, :final token):
        return switch (name) {
          '--anchor-width' => widget.anchorWidth,
          '--available-height' => available,
          _ =>
            token == null
                ? _length(fallback, tokens, available)
                : tokens?.number(token) ?? _length(fallback, tokens, available),
        };
      case CssCalc(:final expr):
        return _length(expr, tokens, available);
      case CssFunction(:final name, :final args):
        final values = [
          for (final arg in args) _length(arg, tokens, available),
        ];
        if (values.isEmpty || values.any((value) => value == null)) return null;
        final lengths = values.cast<double>();
        return switch (name) {
          'max' => lengths.reduce(math.max),
          'min' => lengths.reduce(math.min),
          'clamp' when lengths.length == 3 => lengths[1].clamp(
            lengths[0],
            lengths[2],
          ),
          _ => null,
        };
      default:
        return null;
    }
  }
}
