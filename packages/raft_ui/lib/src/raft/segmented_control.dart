import 'dart:async';

import 'package:flutter/gestures.dart';
// raft-ui 0.7.0 `SegmentedControl`: a radio group on a `fill-muted` track (`rounded-[11px]`, 3px padding, 2px gap) whose
// items are 32px buttons. The checked item is the yellow sticker (brand fill, ink border, die-cut `sticker-edge` ring,
// bold); the others are `foreground-muted` text that takes the `fill-pressed` wash on hover. An item holds an optional
// 16px icon, a label and a mono count. A disabled group keeps the sticker and greys the ink.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/services.dart';

import '../control_typography.dart';
import '../recipe_surface.dart';
import '../recipes/segmented_control.g.dart';
import '../design_primitives.dart';
import '../icons.dart';
import '../localization.dart';
import '../text_scaling.dart' show RaftScaled;
import '../theme.dart';
import '../tokens/tokens.dart';
import 'css_box.dart';
import 'ui_tokens.dart';

/// `SegmentedControlItem` with its `SegmentedControlLabel` and `SegmentedControlCount`. [onPressed] null is
/// `data-disabled`; [checked] is `data-checked`.
class RaftSegmentedItem extends StatelessWidget {
  const RaftSegmentedItem({
    super.key,
    required this.label,
    this.glyph,
    this.iconBuilder,
    this.count,
    this.labelSuffix,
    this.checked = false,
    this.onPressed,
    this.height = 32,
    this.focusNode,
    this.tooltip,
    this.iconsOnly = false,
  });

  final String label;
  final RaftGlyph? glyph;
  final Widget Function(double size, Color color)? iconBuilder;

  /// `SegmentedControlCount`: Space Mono 12.
  final String? count;

  /// A small mono note inside the label (`Save 12%`).
  final String? labelSuffix;
  final bool checked;
  final VoidCallback? onPressed;
  final double height;
  final FocusNode? focusNode;
  final String? tooltip;
  final bool iconsOnly;

  @override
  Widget build(BuildContext context) {
    final text = raftText(context, label);
    return RaftInteractive(
      onPressed: onPressed,
      focusNode: focusNode,
      button: false,
      checked: checked,
      tooltip: tooltip,
      semanticLabel: text,
      builder: (context, st) => _recipeSurface(context, st),
    );
  }

  Widget _recipeSurface(BuildContext context, RaftInteractionState state) {
    final t = RaftTokens.of(context);
    final tokens = t.recipeTokens;
    final recipe = RaftSegmentedControlRecipe.resolve(
      tokens: tokens,
      states: t.recipeStates(
        responsive: true,
        hovered: state.enabled && state.hovered,
        pressed: state.enabled && state.pressed,
        focusVisible: state.focusVisible,
        disabled: !state.enabled,
        extra: [
          checked ? 'data-checked' : 'data-unchecked',
          if (checked) 'group/segmented-control-item:data-checked',
          if (!state.enabled) 'data-disabled',
        ],
      ),
    );
    final item = recipe.item;
    final framed = t.option('segmented.frame', or: 'framed') == 'framed';
    final textStyle = RaftControlTypography.of(
      context,
      item
          .text(tokens)
          .copyWith(fontFamilyFallback: t.fontFallback, locale: t.textLocale),
    );
    final ink = textStyle.color ?? t.ink;
    final gap = item.columnGap ?? 0;
    final svg = item.target("& svg:not([class*='size-'])");
    // Resolve the pack's structural radius before constructing its decoration,
    // just as the generated track resolves its concentric radius below.
    final radius = t.size(
      framed ? 'radius.control' : 'radius.chip',
      fallback: framed ? item.borderRadius?.topLeft.x ?? 0 : 4,
    );
    return RaftRecipeBox(
      style: item,
      tokens: tokens,
      decorationOverride: (decoration) =>
          raftSnapBorder(context, decoration).copyWith(
            // Custom packs retain their structural option and radius binding;
            // the item, label and count still consume the generated recipe.
            borderRadius: BorderRadius.circular(radius),
          ),
      width: iconsOnly ? height : null,
      height: height,
      padding: iconsOnly ? EdgeInsets.zero : null,
      // A separate item's bounded Wrap still hugs its content. Container's
      // alignment would otherwise expand it to the whole available width.
      alignment: framed ? Alignment.center : null,
      applyText: false,
      growWithText: true,
      overflowCenter: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: gap,
        children: [
          if (iconBuilder case final icon?)
            icon(svg!.width!, ink)
          else if (glyph != null)
            RaftIcon(glyph!, size: svg!.width!, color: ink),
          if (!iconsOnly)
            Flexible(
              child: Text(
                raftText(context, label),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: RaftControlTypography.of(
                  context,
                  recipe.label.text(tokens, base: textStyle),
                ),
              ),
            ),
          // Billing's product-owned note is preserved; the shared control's
          // own item, label and count styles come from its generated slots.
          if (!iconsOnly && labelSuffix != null)
            Text(
              raftText(context, labelSuffix!),
              maxLines: 1,
              softWrap: false,
              style: RaftControlTypography.of(
                context,
                t.scale(
                  RaftTypeScale.monoMeta,
                  mono: true,
                  weight: FontWeight.w700,
                  color: ink.withValues(alpha: ink.a * .6),
                ),
              ),
            ),
          if (!iconsOnly && count != null)
            Text(
              count!,
              maxLines: 1,
              softWrap: false,
              style: RaftControlTypography.of(
                context,
                recipe.count.text(tokens, base: textStyle),
              ),
            ),
        ],
      ),
    );
  }
}

/// The `SegmentedControl` track: `bg-fill-muted rounded-[11px] p-[3px] gap-0.5`, as wide as its items. The web
/// control is `flex-nowrap`; native large-text layouts wrap the items to retain access.
class RaftSegmentedTrack extends StatelessWidget {
  const RaftSegmentedTrack({
    super.key,
    required this.children,
    this.shrinkFrame = false,
    this.expand = false,
    this.scrollController,
  });
  final List<Widget> children;

  /// Optional owner for the native narrow-track viewport. The controlled
  /// group uses it to reveal keyboard-focused items in either direction.
  final ScrollController? scrollController;
  final bool shrinkFrame;

  /// `w-full *:flex-1`: the track fills its row and the items share it equally.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final framed = t.option('segmented.frame', or: 'framed') == 'framed';

    // A custom pack can choose a separate (unframed) row; that explicit option
    // goes ahead of the generated track surface.
    if (!framed) {
      final gap = t.size('space.segmentGap', fallback: 4);
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
    }

    final tokens = t.recipeTokens;
    final recipe = RaftSegmentedControlRecipe.resolve(
      tokens: tokens,
      states: t.recipeStates(responsive: true),
    );
    final root = recipe.root;
    final sourceItemRadius = recipe.item.borderRadius?.topLeft.x ?? 0;
    final trackRadius =
        (root.borderRadius?.topLeft.x ?? 0) +
        t.size('radius.control', fallback: sourceItemRadius) -
        sourceItemRadius;
    final gap = root.columnGap ?? 0;
    final scrolls = !expand && !RaftScaled.grows(context);
    final Widget content;
    if (expand) {
      content = Row(
        spacing: gap,
        children: [for (final child in children) Expanded(child: child)],
      );
    } else if (RaftScaled.grows(context)) {
      content = Wrap(
        spacing: gap,
        runSpacing: root.rowGap ?? 0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
    } else {
      // Keep the generated one-row geometry, but make overflow reachable
      // on native screens. Painting outside a smaller hit-test box leaves
      // apparently visible options inert. The viewport clips only overflow;
      // its source padding keeps edge rings inside the scrollable bounds.
      final behavior = ScrollConfiguration.of(context);
      content = ScrollConfiguration(
        behavior: behavior.copyWith(
          scrollbars: false,
          dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse},
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: root.padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: gap,
              children: children,
            ),
          ),
        ),
      );
    }
    return RaftRecipeBox(
      style: root,
      tokens: tokens,
      // The one-row viewport owns this same generated padding so a selected
      // item's ring does not get clipped at the inner content edge.
      padding: scrolls ? EdgeInsets.zero : null,
      applyText: false,
      decorationOverride: (decoration) => decoration.copyWith(
        // Preserve the recipe's concentric track/item radius difference
        // when a custom pack changes the control radius.
        borderRadius: BorderRadius.circular(trackRadius),
      ),
      child: content,
    );
  }
}

@immutable
class RaftSegmentedOption<T> {
  const RaftSegmentedOption({
    required this.value,
    required this.label,
    this.glyph,
    this.iconBuilder,
    this.tooltip,
    this.count,
    this.enabled = true,
    this.labelSuffix,
    this.itemKey,
  });
  final T value;
  final String label;

  /// Key of the segment (tests, parity interactions).
  final Key? itemKey;

  /// A `font-mono text-[10px] font-bold text-black/60` note inside
  /// the label (`gap-1.5`), e.g. BillingIntervalSegmentedControl's "Save 12%".
  final String? labelSuffix;
  final RaftGlyph? glyph;
  final Widget Function(double size, Color color)? iconBuilder;
  final String? tooltip;

  /// `SegmentedControlCount` (buttons style).
  final String? count;
  final bool enabled;
}

/// raft-ui `SegmentedControl`, the one segmented control of the client: 2 to 4 segments in a gray track that switch
/// how the same content is shown, the selected one a yellow sticker. One radio group: arrow keys select and move
/// focus within it.
class RaftSegmentedControl<T> extends StatefulWidget {
  const RaftSegmentedControl({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.visualHeight = 32,
    this.minimumTargetSize,
    this.disabled = false,
    this.shrinkFrame = false,
    this.expand = false,
    this.iconsOnly = false,
    this.inFitToolbar = false,
  });

  /// The fit toolbar's compact form uses square segments and keeps their
  /// labels accessible to assistive technology.
  final bool iconsOnly;
  final bool inFitToolbar;

  /// `className="w-full *:flex-1"`: the track fills its row, the segments share it equally.
  final bool expand;

  /// `SegmentedControl disabled`: every item is inert and its ink greys; the sticker stays.
  final bool disabled;

  /// A flex-shrinking CSS track may be narrower than its non-shrinking items.
  final bool shrinkFrame;

  final T value;
  final List<RaftSegmentedOption<T>> items;
  final ValueChanged<T>? onChanged;
  final String? label;
  final double visualHeight;

  /// Passed to each segment's [RaftControl] (layout follows the Web box when
  /// set to [visualHeight]).
  final double? minimumTargetSize;
  @override
  State<RaftSegmentedControl<T>> createState() =>
      _RaftSegmentedControlState<T>();
}

class _RaftSegmentedControlState<T> extends State<RaftSegmentedControl<T>> {
  final _scrollController = ScrollController();

  /// Tab leaves the group (raft-ui SegmentedControl is one tab stop; the
  /// arrows move within it): a closed loop would trap Tab between segments.
  final scope = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );

  /// One node per segment: only the checked one (else the first enabled) is
  /// a tab stop, the roving tabindex of the Web radio group.
  final _nodes = <FocusNode>[];
  FocusNode _node(int i) {
    while (_nodes.length <= i) {
      _nodes.add(FocusNode());
    }
    return _nodes[i];
  }

  int get _stop {
    final checked = widget.items.indexWhere(
      (e) => e.value == widget.value && e.enabled,
    );
    return checked >= 0 ? checked : widget.items.indexWhere((e) => e.enabled);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    scope.dispose();
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  void move(int delta) {
    if (widget.onChanged == null || widget.disabled) return;
    final enabled = widget.items.where((item) => item.enabled).toList();
    if (enabled.isEmpty) return;
    final current = enabled.indexWhere((e) => e.value == widget.value);
    final next =
        ((current < 0
                ? delta > 0
                      ? -1
                      : 0
                : current) +
            delta) %
        enabled.length;
    widget.onChanged!(enabled[next].value);
    final index = widget.items.indexOf(enabled[next]);
    if (index < _nodes.length) {
      _nodes[index].requestFocus();
    } else if (delta > 0) {
      scope.nextFocus();
    } else {
      scope.previousFocus();
    }
    // Selection changes can resize the bold item. Reveal the final focused
    // box after layout, on this track only (never scroll an outer form).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = scope.focusedChild?.context?.findRenderObject();
      if (target == null || !target.attached) return;
      unawaited(
        _scrollController.position.ensureVisible(target, alignment: .5),
      );
    });
  }

  @override
  Widget build(BuildContext context) => FocusScope(
    node: scope,
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => move(1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => move(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => move(-1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => move(-1),
      },
      child: Semantics(
        label: widget.label,
        container: true,
        child: _group(context),
      ),
    ),
  );

  VoidCallback? _press(RaftSegmentedOption<T> item) =>
      widget.onChanged == null || widget.disabled || !item.enabled
      ? null
      : () => widget.onChanged!(item.value);

  RaftSegmentedTrack _track() => RaftSegmentedTrack(
    scrollController: _scrollController,
    shrinkFrame: widget.shrinkFrame,
    expand: widget.expand,
    children: [
      for (final (i, item) in widget.items.indexed)
        RaftSegmentedItem(
          key: item.itemKey,
          focusNode: _node(i)..skipTraversal = i != _stop,
          label: item.label,
          glyph: item.glyph,
          iconBuilder: item.iconBuilder,
          count: item.count,
          labelSuffix: item.labelSuffix,
          tooltip: item.tooltip,
          iconsOnly: widget.iconsOnly,
          checked: item.value == widget.value,
          height: widget.visualHeight,
          onPressed: _press(item),
        ),
    ],
  );

  Widget _group(BuildContext context) {
    if (widget.inFitToolbar && !RaftScaled.grows(context)) {
      return SizedBox(
        height: widget.visualHeight,
        child: OverflowBox(
          minHeight: 0,
          maxHeight: double.infinity,
          fit: OverflowBoxFit.deferToChild,
          child: _track(),
        ),
      );
    }
    // raft-ui `SegmentedControl` is `inline-flex w-fit`: the track hugs its items instead of stretching in a column.
    if (widget.expand) return _track();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      heightFactor: 1,
      child: _track(),
    );
  }
}
