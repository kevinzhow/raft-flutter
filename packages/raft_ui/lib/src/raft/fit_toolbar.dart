// raft-ui `FitToolbar` (0.95.3), the parts the Computers rack toolbar needs: a
// toolbar whose items give way, in steps and an order they declare, as the
// region it sits in narrows. Declarative: [RaftFitToolbar] takes
// [RaftFitGroup]s and a [RaftFitSearch]; a group takes [RaftFitItem]s
// ([RaftFitButton], [RaftFitPicker], [RaftFitMore], [RaftFitChild]).
//
// How it fits (fit_toolbar_plan.dart is the pure part): every form of every
// item (full, label gone, +) is built once off screen and measured in the same
// layout pass; [raftFit] chooses the steps for the width; only the chosen form
// of each item is built on screen. There is no state to settle, so nothing
// flickers and nothing runs while idle.
//
// Left out on purpose (nothing Flutter mounts needs them): SplitButton,
// `wrapLine`, a collapsing group (`collapseOrder` + `collapsed`).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../design_primitives.dart';
import '../form_controls.dart';
import '../icons.dart';
import '../localization.dart';
import '../picker_trigger_button.dart';
import '../recipe_surface.dart';
import '../tooltip.dart' show RaftTooltip;
import '../recipes/fit_toolbar.g.dart';
import '../input_group_size.dart' show RaftInputGroupRecipeSize;
import '../recipes/recipe_runtime.dart';
import '../theme.dart';
import 'button.dart';
import 'fit_toolbar_plan.dart';

/// `FIT_SEARCH_MAX_LEAST`: the most the search keeps before the other steps
/// are taken, in px (its icon and "Search…", the same at every width).
const double raftFitSearchMaxLeast = 120;

/// The look an item shows: all of it, its label gone (an icon square), or a +.
enum RaftFitForm { full, label, plus }

/// What a group holds. Not a widget: the toolbar builds only the form it
/// chose, and measures the others off screen.
abstract class RaftFitItem {
  const RaftFitItem({
    this.labelOrder,
    this.plusOrder,
    this.moreOrder,
    this.moreItem,
  });

  /// `labelOrder`, `plusOrder`, `moreOrder`: where in the toolbar's one order
  /// the item takes that step. [moreItem] is what it shows in More.
  final int? labelOrder, plusOrder, moreOrder;
  final List<RaftMenuEntry>? moreItem;

  bool get hasLabelForm => false;
  bool get hasPlusForm => false;

  /// The toolbar's More button: shown only while an item is in More.
  bool get isMore => false;

  /// One form of the item. [probe] builds it for measuring only (no keys,
  /// focus nodes, tooltips or menus). [moreEntries] is what More lists.
  Widget buildForm(
    BuildContext context,
    RaftFitForm form, {
    required bool probe,
    List<RaftMenuEntry> moreEntries = const [],
  });
}

RaftFitToolbarRecipeStyle _fitStyle(
  BuildContext context, {
  bool count = false,
  bool scroll = false,
  bool pinned = false,
  List<String> extra = const [],
}) {
  final t = RaftTokens.of(context);
  return RaftFitToolbarRecipe.resolve(
    count: count,
    scroll: scroll,
    pinned: pinned,
    states: t.recipeStates(responsive: true, extra: extra),
    tokens: t.recipeTokens,
  );
}

/// `FitToolbarButton`: a button (ghost unless said) with an icon and a label;
/// from [labelOrder] an icon square (34px with a mouse from 768px, else 32) and
/// from [plusOrder] a + square, its label kept as the accessible name and the
/// tooltip. [collapsedGlyph] shows only once the label has gone.
class RaftFitButton extends RaftFitItem {
  const RaftFitButton({
    this.key,
    required this.label,
    this.glyph,
    this.collapsedGlyph,
    this.variant = RaftButtonVariant.ghost,
    this.onPressed,
    super.labelOrder,
    super.plusOrder,
    super.moreOrder,
    super.moreItem,
  });

  final Key? key;
  final String label;
  final RaftGlyph? glyph, collapsedGlyph;
  final RaftButtonVariant variant;
  final VoidCallback? onPressed;

  @override
  bool get hasLabelForm => glyph != null || collapsedGlyph != null;
  @override
  bool get hasPlusForm => true;

  @override
  Widget buildForm(
    BuildContext context,
    RaftFitForm form, {
    required bool probe,
    List<RaftMenuEntry> moreEntries = const [],
  }) {
    final k = probe ? null : key;
    if (form == RaftFitForm.full) {
      return RaftButton(
        key: k,
        uiVariant: variant,
        uiSize: RaftButtonSize.md,
        glyph: glyph,
        label: label,
        onPressed: onPressed,
      );
    }
    final fit = _fitStyle(
      context,
      extra: [form == RaftFitForm.label ? 'data-fit-label' : 'data-fit-plus'],
    );
    final square = fit.button.length('width');
    final px = fit.button.length('padding-left') ?? 0;
    return RaftButton(
      key: k,
      uiVariant: variant,
      uiSize: RaftButtonSize.md,
      glyph: form == RaftFitForm.plus
          ? RaftGlyph.plus
          : (collapsedGlyph ?? glyph),
      semanticLabel: raftText(context, label),
      tooltip: probe ? null : label,
      visualWidth: square,
      onPressed: onPressed,
      styleBuilder: (context, state, style) => style.copyWith(
        properties: {
          ...style.properties,
          'padding-left': CssNum(px, 'px'),
          'padding-right': CssNum(px, 'px'),
        },
      ),
    );
  }
}

/// `FitToolbarPicker`: a filter trigger with an icon, a label, what is chosen
/// ([value]; a count is mono) and a chevron, filled once a value is chosen.
/// From [labelOrder] its label gives way and stays its accessible name ("Assignee
/// 1") and tooltip. [menuEntries] make it open a dropdown menu; else
/// [onPressed] is called.
class RaftFitPicker extends RaftFitItem {
  const RaftFitPicker({
    this.key,
    required this.label,
    this.glyph,
    this.value,
    this.onPressed,
    this.menuEntries,
    super.labelOrder,
    super.moreOrder,
    super.moreItem,
  });

  final Key? key;
  final String label;
  final RaftGlyph? glyph;
  final String? value;
  final VoidCallback? onPressed;
  final List<RaftMenuEntry>? menuEntries;

  bool get _hasValue => value != null && value!.isNotEmpty;

  @override
  bool get hasLabelForm => glyph != null;

  @override
  Widget buildForm(
    BuildContext context,
    RaftFitForm form, {
    required bool probe,
    List<RaftMenuEntry> moreEntries = const [],
  }) {
    final gone = form != RaftFitForm.full;
    final isCount = _hasValue && RegExp(r'^\d+$').hasMatch(value!.trim());
    final fit = _fitStyle(
      context,
      count: isCount,
      extra: [if (gone) 'data-fit-label'],
    );
    Widget trigger(FocusNode? focusNode, VoidCallback? press) {
      final button = RaftPickerTriggerButton(
        key: probe || menuEntries != null ? null : key,
        label: label,
        glyph: glyph,
        selected: _hasValue,
        value: value,
        valueSlot: fit.pickerValue,
        labelHidden: gone,
        focusNode: focusNode,
        onPressed: press,
        restyle: gone
            ? (style) => style.copyWith(
                properties: {
                  ...style.properties,
                  'column-gap': CssNum(fit.picker.columnGap ?? 4, 'px'),
                  'padding-left': CssNum(
                    fit.picker.length('padding-left') ?? 8,
                    'px',
                  ),
                  'padding-right': CssNum(
                    fit.picker.length('padding-right') ?? 8,
                    'px',
                  ),
                },
              )
            : null,
      );
      return gone && !probe
          ? RaftTooltip(message: raftText(context, label), child: button)
          : button;
    }

    if (probe || menuEntries == null) {
      return trigger(null, onPressed);
    }
    return RaftDropdownMenu(
      key: key,
      label: label,
      entries: menuEntries!,
      triggerBuilder: (context, focusNode, press) => trigger(focusNode, press),
    );
  }
}

/// `FitToolbarMore`: a ghost ellipsis button, shown only while some item took
/// `more`; its menu lists each such item's `moreItem` in order.
class RaftFitMore extends RaftFitItem {
  const RaftFitMore({this.key, this.label = 'More'});
  final Key? key;
  final String label;

  @override
  bool get isMore => true;

  @override
  Widget buildForm(
    BuildContext context,
    RaftFitForm form, {
    required bool probe,
    List<RaftMenuEntry> moreEntries = const [],
  }) {
    Widget trigger(FocusNode? focusNode, VoidCallback? press) => RaftButton(
      uiVariant: RaftButtonVariant.ghost,
      uiSize: RaftButtonSize.iconMd,
      glyph: RaftGlyph.ellipsis,
      semanticLabel: raftText(context, label),
      tooltip: probe ? null : label,
      focusNode: focusNode,
      onPressed: press ?? () {},
    );
    if (probe) return trigger(null, null);
    return RaftDropdownMenu(
      key: key,
      label: label,
      entries: moreEntries,
      align: RaftDropdownAlign.end,
      triggerBuilder: (context, focusNode, press) => trigger(focusNode, press),
    );
  }
}

/// Any other control in a group (a segmented view switch): it has one form.
/// It can go to More with its group's `moreOrder`, or with its own.
class RaftFitChild extends RaftFitItem {
  const RaftFitChild({required this.child, super.moreOrder, super.moreItem});
  final Widget child;

  @override
  Widget buildForm(
    BuildContext context,
    RaftFitForm form, {
    required bool probe,
    List<RaftMenuEntry> moreEntries = const [],
  }) => child;
}

/// What a [RaftFitToolbar] holds: [RaftFitGroup] or [RaftFitSearch].
abstract class RaftFitNode {
  const RaftFitNode();
}

/// `FitToolbarGroup`: a row of items. [firstLine] never wraps; otherwise it
/// takes the `wrap` step at [wrapOrder] (default 0, as in the Web). [moreOrder]
/// puts the whole group in More, showing [moreItem]. [scroll] makes it take
/// the rest of its line and scroll sideways, [end] pinned after the scroll.
class RaftFitGroup extends RaftFitNode {
  const RaftFitGroup({
    required this.items,
    this.firstLine = false,
    this.wrapOrder = 0,
    this.moreOrder,
    this.moreItem,
    this.scroll = false,
    this.end,
  });
  final List<RaftFitItem> items;
  final bool firstLine, scroll;
  final int wrapOrder;
  final int? moreOrder;
  final List<RaftMenuEntry>? moreItem;
  final Widget? end;
}

/// `FitToolbarSearch`: fills the rest of its line (at least
/// [raftFitSearchMaxLeast] px, or [minWidth]). From [collapseOrder] on it is a
/// search icon button that opens the field in place; the field closes when it
/// is empty and loses focus, or on Esc. A search holding text never
/// collapses. Put it first in the toolbar.
class RaftFitSearch extends RaftFitNode {
  const RaftFitSearch({
    required this.semanticLabel,
    this.hintText,
    this.controller,
    this.onChanged,
    this.clearLabel,
    this.collapseOrder,
    this.minWidth,
    this.fieldKey,
  });
  final String semanticLabel;
  final String? hintText, clearLabel;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final int? collapseOrder;
  final double? minWidth;
  final Key? fieldKey;
}

/// `FitToolbar`: one Tab stop, Left/Right (RTL aware) between the controls in
/// reading order, looping. [wrap] lets groups take the `wrap` step; each
/// wrapped group takes a line of its own below. [gap] is the page's `gap-2`.
class RaftFitToolbar extends StatefulWidget {
  const RaftFitToolbar({
    super.key,
    required this.children,
    this.wrap = false,
    this.semanticLabel,
    this.gap = 8,
  });
  final List<RaftFitNode> children;
  final bool wrap;
  final String? semanticLabel;
  final double gap;

  @override
  State<RaftFitToolbar> createState() => _RaftFitToolbarState();
}

class _RaftFitToolbarState extends State<RaftFitToolbar> {
  final _sizes = <String, Size>{};
  final _root = FocusNode(
    debugLabel: 'RaftFitToolbar',
    canRequestFocus: false,
    skipTraversal: true,
  );
  final _scrolls = <String, ScrollController>{};
  final _searches = <String, GlobalKey<_FitSearchSlotState>>{};
  final _controllers = <String, TextEditingController>{};
  final _searchEmpty = <String, bool>{};
  final _searchListeners = <(TextEditingController, VoidCallback)>[];
  FocusNode? _lastInside;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_focusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_focusChanged);
    _root.dispose();
    for (final (c, l) in _searchListeners) {
      c.removeListener(l);
    }
    for (final c in _scrolls.values) {
      c.dispose();
    }
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// When the focused control moves into More (it leaves the tree), focus goes
  /// to the More button.
  void _focusChanged() {
    final primary = FocusManager.instance.primaryFocus;
    final inside =
        primary != null &&
        primary != _root &&
        _root.descendants.contains(primary);
    if (inside) {
      _lastInside = primary;
      return;
    }
    final last = _lastInside;
    if (last == null) return;
    if (!_root.descendants.contains(last)) {
      _lastInside = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final n in _root.traversalDescendants) {
          if (n.context?.findAncestorWidgetOfExactType<_MoreMarker>() != null) {
            n.requestFocus();
            return;
          }
        }
      });
    } else if (primary != null && primary != _root) {
      _lastInside = null;
    }
  }

  TextEditingController _controllerOf(String id, RaftFitSearch search) {
    final given = search.controller;
    if (given != null) return given;
    return _controllers.putIfAbsent(id, TextEditingController.new);
  }

  ScrollController _scrollOf(String id) =>
      _scrolls.putIfAbsent(id, ScrollController.new);

  // -- reading order -------------------------------------------------------

  List<FocusNode> _stops() {
    final scope = _root.nearestScope;
    final nodes = [
      for (final n in _root.traversalDescendants)
        if (n.nearestScope == scope &&
            n.context != null &&
            n.rect.size.height > 0)
          n,
    ];
    if (nodes.isEmpty) return nodes;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    nodes.sort((a, b) => a.rect.top.compareTo(b.rect.top));
    final lines = <List<FocusNode>>[];
    for (final n in nodes) {
      if (lines.isNotEmpty &&
          (n.rect.center.dy - lines.last.first.rect.center.dy).abs() <
              n.rect.height / 2) {
        lines.last.add(n);
      } else {
        lines.add([n]);
      }
    }
    return [
      for (final line in lines)
        ...(line..sort(
          (a, b) => rtl
              ? b.rect.left.compareTo(a.rect.left)
              : a.rect.left.compareTo(b.rect.left),
        )),
    ];
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final kb = HardwareKeyboard.instance;
    if (kb.isAltPressed ||
        kb.isControlPressed ||
        kb.isMetaPressed ||
        kb.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }
    final focused = FocusManager.instance.primaryFocus;
    final ctx = focused?.context;
    if (focused == null || ctx == null) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final forward = (key == LogicalKeyboardKey.arrowRight) != rtl;
    // A text field keeps the arrow while its caret has somewhere to go.
    final field = ctx.findAncestorStateOfType<EditableTextState>();
    if (field != null) {
      final selection = field.widget.controller.selection;
      final text = field.widget.controller.text;
      if (selection.isValid) {
        if (!selection.isCollapsed) return KeyEventResult.ignored;
        if (forward ? selection.start < text.length : selection.start > 0) {
          return KeyEventResult.ignored;
        }
      }
    }
    final stops = _stops();
    final index = stops.indexOf(focused);
    if (index < 0) return KeyEventResult.ignored;
    final next =
        stops[(index + (forward ? 1 : -1) + stops.length) % stops.length];
    if (next != focused) {
      next.requestFocus();
      final c = next.context;
      if (c != null)
        Scrollable.maybeOf(c)?.position
            .ensureVisible(c.findRenderObject()!, alignment: .5);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final nodes = widget.children;
    // Ids by position; the probes list every form of every item.
    final probes = <Widget>[];
    void probe(String key, Widget child) {
      probes.add(
        Offstage(
          child: ExcludeFocus(
            child: ExcludeSemantics(
              child: TickerMode(
                enabled: false,
                child: _MeasureProbe(name: key, sizes: _sizes, child: child),
              ),
            ),
          ),
        ),
      );
    }

    final t = RaftTokens.of(context);
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node is RaftFitSearch) {
        probe('n$i|button', _searchButton(context, node, probe: true));
      } else if (node is RaftFitGroup) {
        for (var j = 0; j < node.items.length; j++) {
          final item = node.items[j];
          final id = 'n$i.$j';
          probe(
            '$id|full',
            item.buildForm(context, RaftFitForm.full, probe: true),
          );
          if (item.hasLabelForm && item.labelOrder != null) {
            probe(
              '$id|label',
              item.buildForm(context, RaftFitForm.label, probe: true),
            );
          }
          if (item.hasPlusForm && item.plusOrder != null) {
            probe(
              '$id|plus',
              item.buildForm(context, RaftFitForm.plus, probe: true),
            );
          }
        }
        if (node.end != null) probe('n$i|end', node.end!);
      }
    }
    // The text each search holds decides whether it may collapse; a field
    // that empties or fills changes the fit, so those rebuild the toolbar.
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node is RaftFitSearch) {
        final id = 'n$i';
        final controller = _controllerOf(id, node);
        if (!_searchEmpty.containsKey(id)) {
          _searchEmpty[id] = controller.text.isEmpty;
          void listener() {
            final empty = controller.text.isEmpty;
            if (_searchEmpty[id] != empty) {
              _searchEmpty[id] = empty;
              if (mounted) setState(() {});
            }
          }

          controller.addListener(listener);
          _searchListeners.add((controller, listener));
        }
      }
    }

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: FocusTraversalGroup(
        policy: _SingleStopPolicy(),
        child: Focus(
          focusNode: _root,
          onKeyEvent: _key,
          child: Stack(
            children: [
              ...probes,
              LayoutBuilder(
                builder: (context, box) => _live(context, box.maxWidth, t),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Size _size(String key) => _sizes[key] ?? Size.zero;

  Widget _searchButton(
    BuildContext context,
    RaftFitSearch node, {
    required bool probe,
    FocusNode? focusNode,
    VoidCallback? onPressed,
  }) {
    return RaftButton(
      uiVariant: RaftButtonVariant.ghost,
      uiSize: RaftButtonSize.iconMd,
      glyph: RaftGlyph.search,
      semanticLabel: raftText(context, node.semanticLabel),
      tooltip: probe ? null : node.semanticLabel,
      focusNode: focusNode,
      onPressed: onPressed ?? () {},
    );
  }

  Widget _live(BuildContext context, double width, RaftTokens t) {
    final nodes = widget.children;
    final gap = widget.gap;
    final specs = <RaftFitNodeSpec>[];
    var hasMore = false;
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final id = 'n$i';
      if (node is RaftFitSearch) {
        final empty = _searchEmpty[id] ?? true;
        specs.add(
          RaftFitSearchSpec(
            id,
            minWidth: node.minWidth ?? raftFitSearchMaxLeast,
            buttonWidth: _size('$id|button').width,
            collapseOrder: empty ? node.collapseOrder : null,
          ),
        );
      } else if (node is RaftFitGroup) {
        final leaves = <RaftFitLeafSpec>[];
        for (var j = 0; j < node.items.length; j++) {
          final item = node.items[j];
          final lid = '$id.$j';
          if (item.isMore) hasMore = true;
          final label = item.hasLabelForm && item.labelOrder != null
              ? _size('$lid|label').width
              : null;
          final plus = item.hasPlusForm && item.plusOrder != null
              ? _size('$lid|plus').width
              : null;
          leaves.add(
            RaftFitLeafSpec(
              lid,
              full: _size('$lid|full').width,
              label: label,
              plus: plus,
              labelOrder: item.labelOrder,
              plusOrder: item.plusOrder,
              moreOrder: item.moreOrder,
              isMore: item.isMore,
            ),
          );
        }
        specs.add(
          RaftFitGroupSpec(
            id,
            leaves: leaves,
            firstLine: node.firstLine,
            scroll: node.scroll,
            wrapOrder: node.wrapOrder,
            moreOrder: node.moreOrder,
            endWidth: node.end == null ? 0 : _size('$id|end').width,
          ),
        );
      }
    }
    final result = raftFit(
      specs,
      width: width,
      gap: gap,
      hasMore: hasMore,
      allowWrap: widget.wrap,
    );
    final plan = result.plan;

    // What More lists: each taken item's moreItem, in DOM order.
    final moreEntries = <RaftMenuEntry>[];
    void addMore(List<RaftMenuEntry>? entries) {
      if (entries == null || entries.isEmpty) return;
      if (moreEntries.isNotEmpty)
        moreEntries.add(const RaftMenuEntry.separator());
      moreEntries.addAll(entries);
    }

    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node is! RaftFitGroup) continue;
      if (plan.has('n$i', RaftFitStep.more)) addMore(node.moreItem);
      for (var j = 0; j < node.items.length; j++) {
        if (plan.has('n$i.$j', RaftFitStep.more))
          addMore(node.items[j].moreItem);
      }
    }

    Widget leafWidget(RaftFitItem item, String lid) {
      final steps = plan.taken[lid];
      final form =
          steps != null && steps.contains(RaftFitStep.plus) && item.hasPlusForm
          ? RaftFitForm.plus
          : steps != null &&
                steps.contains(RaftFitStep.label) &&
                item.hasLabelForm
          ? RaftFitForm.label
          : RaftFitForm.full;
      final built = item.buildForm(
        context,
        form,
        probe: false,
        moreEntries: moreEntries,
      );
      if (item.isMore) {
        return _MoreMarker(
          child: KeyedSubtree(key: ValueKey(lid), child: built),
        );
      }
      return KeyedSubtree(key: ValueKey(lid), child: built);
    }

    Widget slotWidget(RaftFitSlot slot, [double? extra]) {
      final id = slot.id as String;
      final i = int.parse(id.substring(1).split('.').first);
      final node = nodes[i];
      if (node is RaftFitSearch) {
        final controller = _controllerOf(id, node);
        final collapsed = plan.has(id, RaftFitStep.collapse);
        return _FitSearchSlot(
          key: _searches.putIfAbsent(id, GlobalKey.new),
          search: node,
          controller: controller,
          collapsed: collapsed,
          width: slot.width + (extra ?? 0),
          button: (focusNode, press) => _searchButton(
            context,
            node,
            probe: false,
            focusNode: focusNode,
            onPressed: press,
          ),
          inputSize: RaftInputGroupRecipeSize.md,
        );
      }
      final group = node as RaftFitGroup;
      final leaves = <Widget>[
        for (var j = 0; j < group.items.length; j++)
          if (!plan.has('$id.$j', RaftFitStep.more) &&
              (!group.items[j].isMore || plan.more.isNotEmpty))
            leafWidget(group.items[j], '$id.$j'),
      ];
      if (!group.scroll) {
        return KeyedSubtree(
          key: ValueKey(id),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: gap,
            children: leaves,
          ),
        );
      }
      var height = 0.0;
      for (var j = 0; j < group.items.length; j++) {
        final s = _size('$id.$j|full');
        if (s.height > height) height = s.height;
      }
      return _FitScrollGroup(
        key: ValueKey(id),
        controller: _scrollOf(id),
        width: slot.width,
        height: height,
        gap: gap,
        end: group.end,
        children: leaves,
      );
    }

    final lines = <Widget>[];
    for (final line in result.layout.lines) {
      final children = <Widget>[];
      for (var s = 0; s < line.length; s++) {
        final slot = line[s];
        if (slot.kind == RaftFitSlotKind.spacer) continue;
        if (slot.kind == RaftFitSlotKind.searchButton) {
          // The button and the spacer after it are one: the field opens over both.
          final spacer = line.firstWhere(
            (e) => e.id == slot.id && e.kind == RaftFitSlotKind.spacer,
            orElse: () => const RaftFitSlot('', RaftFitSlotKind.spacer, 0),
          );
          children.add(slotWidget(slot, gap + spacer.width));
          continue;
        }
        children.add(slotWidget(slot));
      }
      lines.add(
        SizedBox(
          width: width.isFinite ? width : null,
          child: OverflowBox(
            alignment: AlignmentDirectional.centerStart,
            minWidth: 0,
            maxWidth: double.infinity,
            fit: OverflowBoxFit.deferToChild,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: gap,
              children: children,
            ),
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: gap,
      children: lines,
    );
  }
}

/// Marks the subtree of the More button, so the toolbar can find its focus node.
class _MoreMarker extends StatelessWidget {
  const _MoreMarker({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

/// Tab enters the toolbar at its first control, and the next Tab leaves it:
/// the whole toolbar is one stop; the arrow keys do the rest.
class _SingleStopPolicy extends ReadingOrderTraversalPolicy {
  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) {
    final sorted = super.sortDescendants(descendants, currentNode).toList();
    if (sorted.isEmpty) return sorted;
    if (sorted.contains(currentNode)) return [currentNode];
    return [sorted.first];
  }
}

// ---------------------------------------------------------------------------
// Search

class _FitSearchSlot extends StatefulWidget {
  const _FitSearchSlot({
    super.key,
    required this.search,
    required this.controller,
    required this.collapsed,
    required this.width,
    required this.button,
    required this.inputSize,
  });
  final RaftFitSearch search;
  final TextEditingController controller;
  final bool collapsed;
  final double width;
  final Widget Function(FocusNode, VoidCallback) button;
  final RaftInputGroupRecipeSize inputSize;

  @override
  State<_FitSearchSlot> createState() => _FitSearchSlotState();
}

class _FitSearchSlotState extends State<_FitSearchSlot> {
  final _buttonFocus = FocusNode(debugLabel: 'fit search button');
  final _fieldFocus = FocusNode(debugLabel: 'fit search field');
  bool _opened = false, _focusOnOpen = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(_FitSearchSlot old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _buttonFocus.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  bool get _open =>
      widget.collapsed && (_opened || widget.controller.text.isNotEmpty);

  void _clear() {
    widget.controller.clear();
    widget.search.onChanged?.call('');
    _fieldFocus.requestFocus();
  }

  void _focusChanged(bool focused) {
    if (focused || !widget.collapsed || widget.controller.text.isNotEmpty)
      return;
    if (_opened) setState(() => _opened = false);
  }

  KeyEventResult _escape(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape ||
        !widget.collapsed ||
        widget.controller.text.isNotEmpty ||
        widget.controller.value.composing.isValid) {
      return KeyEventResult.ignored;
    }
    setState(() => _opened = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _buttonFocus.requestFocus();
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final search = widget.search;
    if (widget.collapsed && !_open) {
      return SizedBox(
        width: widget.width,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: widget.button(_buttonFocus, () {
            setState(() {
              _opened = true;
              _focusOnOpen = true;
            });
          }),
        ),
      );
    }
    final autofocus = _focusOnOpen;
    _focusOnOpen = false;
    return SizedBox(
      width: widget.width,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: _focusChanged,
        onKeyEvent: _escape,
        child: RaftInputGroup(
          key: search.fieldKey,
          size: widget.inputSize,
          leading: const RaftInputGroupAddon.icon(RaftGlyph.search),
          controller: widget.controller,
          focusNode: _fieldFocus,
          autofocus: autofocus,
          hintText: search.hintText,
          semanticLabel: search.semanticLabel,
          onChanged: search.onChanged,
          clearLabel: search.clearLabel,
          onClear: search.clearLabel == null ? null : _clear,
          clearOnEscape: search.clearLabel != null,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scroll group

class _FitScrollGroup extends StatefulWidget {
  const _FitScrollGroup({
    super.key,
    required this.controller,
    required this.width,
    required this.height,
    required this.gap,
    required this.end,
    required this.children,
  });
  final ScrollController controller;
  final double width, height, gap;
  final Widget? end;
  final List<Widget> children;

  @override
  State<_FitScrollGroup> createState() => _FitScrollGroupState();
}

class _FitScrollGroupState extends State<_FitScrollGroup> {
  bool _atStart = true, _atEnd = true;

  bool _update(ScrollMetrics m) {
    final start = m.pixels <= 1;
    final end = m.maxScrollExtent <= 1 || m.pixels >= m.maxScrollExtent - 1;
    if (start != _atStart || end != _atEnd) {
      setState(() {
        _atStart = start;
        _atEnd = end;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final fit = _fitStyle(context, scroll: true, pinned: widget.end != null);
    // `scroll-px-6` and the `mask-fade-x` edge: 24px.
    final fade = fit.scroller.length('scroll-padding-left') ?? 24;
    final scroller = NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _update(n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _update(n.metrics),
        child: SingleChildScrollView(
          controller: widget.controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: widget.gap,
            children: widget.children,
          ),
        ),
      ),
    );
    // An alpha mask (dstIn): only the alpha of these stops matters, so any
    // theme colour made opaque / clear will do.
    final shown = RaftTokens.of(context).ink.withValues(alpha: 1);
    final hidden = shown.withValues(alpha: 0);
    final masked = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final f = (fade / (rect.width == 0 ? 1 : rect.width)).clamp(0.0, .5);
        return LinearGradient(
          stops: [0, f, 1 - f, 1],
          colors: [
            _atStart ? shown : hidden,
            shown,
            shown,
            _atEnd ? shown : hidden,
          ],
        ).createShader(rect);
      },
      child: scroller,
    );
    final body = SizedBox(
      height: widget.height,
      child: OverflowBox(
        minHeight: widget.height + 12,
        maxHeight: widget.height + 12,
        child: masked,
      ),
    );
    final end = widget.end;
    // One Row whether or not [end] is shown: when it appears (Clear All after
    // the first filter), the chips keep their elements and the chip that had
    // focus keeps it, instead of the scroller being re-parented.
    return SizedBox(
      width: widget.width,
      child: Row(
        spacing: widget.gap,
        children: [
          Expanded(child: body),
          ?end,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Probes: every form of every item, laid out unconstrained under an Offstage
// (tests and finders skip it, nothing paints) and measured in the same pass.

class _MeasureProbe extends SingleChildRenderObjectWidget {
  const _MeasureProbe({
    required this.name,
    required this.sizes,
    required super.child,
  });
  final String name;
  final Map<String, Size> sizes;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureProbe(name, sizes);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureProbe renderObject,
  ) {
    renderObject
      ..name = name
      ..sizes = sizes;
  }
}

class _RenderMeasureProbe extends RenderProxyBox {
  _RenderMeasureProbe(this.name, this.sizes);
  String name;
  Map<String, Size> sizes;

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(const BoxConstraints(), parentUsesSize: true);
    sizes[name] = c.size;
    size = constraints.constrain(c.size);
  }
}
