import 'dart:async';

import 'package:flutter/gestures.dart';
// raft-ui 0.7.0 `SegmentedControl`: a radio group on a `fill-muted` track (`rounded-[11px]`, 3px padding, 2px gap) whose
// items are 32px buttons. The checked item is the yellow sticker (brand fill, ink border, die-cut `sticker-edge` ring,
// bold); the others are `foreground-muted` text that takes the `fill-pressed` wash on hover. An item holds an optional
// 16px icon, a label and a mono count. A disabled group keeps the sticker and greys the ink.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../control_typography.dart';
import '../dialog_card.dart' show raftRecipeThemeOf;
import '../hover_region.dart';
import '../inline_badge_editor.dart' show RaftTouchTargetExpander;
import '../recipe_surface.dart';
import '../recipes/recipe_router.dart' show usesLegacyRecipes;
import '../recipes/recipe_runtime.dart';
import '../recipes/segmented_control.g.dart';
import '../recipes/token_binding.dart';
import '../search_result_surface.dart' show RaftTaskFilterButton;
import 'tabs.dart' show RaftTabButton;
import '../design_primitives.dart';
import '../icons.dart';
import '../localization.dart';
import '../text_scaling.dart' show RaftScaled;
import '../theme.dart';
import '../tokens/tokens.dart';
import 'css_box.dart';
import 'ui_tokens.dart';

part 'segmented_control_frozen.dart';

/// Colours of one segment in one state.
class RaftSegmentColors {
  const RaftSegmentColors({
    required this.fill,
    required this.border,
    required this.foreground,
    this.ringEdge,
  });
  final Color fill, border, foreground;
  final Color? ringEdge;

  static RaftSegmentColors resolve(
    RaftUiColors ui, {
    required bool checked,
    required bool disabled,
    required bool hovered,
    required bool pressed,
  }) {
    const clear = Color(0x00000000);
    if (checked) {
      return RaftSegmentColors(
        fill: !disabled && (pressed || hovered)
            ? Color.alphaBlend(ui.stickerPressed, ui.brand)
            : ui.brand,
        border: ui.stickerInk,
        foreground: disabled ? ui.foregroundDisabled : ui.stickerInk,
        ringEdge: ui.stickerEdge,
      );
    }
    return RaftSegmentColors(
      fill: !disabled && hovered ? ui.fillPressed : clear,
      border: clear,
      foreground: disabled ? ui.foregroundDisabled : ui.foregroundMuted,
    );
  }
}

/// `SegmentedControlItem` with its `SegmentedControlLabel` and `SegmentedControlCount`. [onPressed] null is
/// `data-disabled`; [checked] is `data-checked`.
class RaftSegmentedItem extends StatelessWidget {
  const RaftSegmentedItem({
    super.key,
    required this.label,
    this.glyph,
    this.count,
    this.labelSuffix,
    this.checked = false,
    this.onPressed,
    this.height = 32,
    this.focusNode,
    this.tooltip,
  });

  final String label;
  final RaftGlyph? glyph;

  /// `SegmentedControlCount`: Space Mono 12.
  final String? count;

  /// A small mono note inside the label (`Save 12%`).
  final String? labelSuffix;
  final bool checked;
  final VoidCallback? onPressed;
  final double height;
  final FocusNode? focusNode;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final borderWidth = raftControlBorderPx(context, 1.5);
    final grows = RaftScaled.grows(context);
    final text = raftText(context, label);
    return RaftInteractive(
      onPressed: onPressed,
      focusNode: focusNode,
      button: false,
      checked: checked,
      tooltip: tooltip,
      semanticLabel: text,
      builder: (context, st) {
        if (t.isRaftLook) return _recipeSurface(context, st);
        final disabled = onPressed == null;
        final colors = RaftSegmentColors.resolve(
          ui,
          checked: checked,
          disabled: disabled,
          hovered: st.hovered,
          pressed: st.pressed,
        );
        final fg = colors.foreground;
        final labelStyle = RaftControlTypography.of(
          context,
          t.scale(
            RaftTypeScale.callout,
            weight: checked ? FontWeight.w700 : FontWeight.w600,
            color: fg,
          ),
        );
        final children = <Widget>[
          if (glyph != null) ...[
            RaftIcon(glyph!, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          _Shrink(
            child: Text(
              text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
          if (labelSuffix != null) ...[
            const SizedBox(width: 6),
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
                  color: fg.withValues(alpha: fg.a * .6),
                ),
              ),
            ),
          ],
          if (count != null) ...[
            const SizedBox(width: 6),
            // Chromium rounds Space Mono's ascent and descent at 12px, which seats the line box 1px higher.
            Transform.translate(
              offset: const Offset(0, -1),
              child: Text(
                count!,
                maxLines: 1,
                softWrap: false,
                style: RaftControlTypography.of(
                  context,
                  t.scale(
                    RaftTypeScale.monoMeta,
                    mono: true,
                    weight: FontWeight.w400,
                    color: fg,
                  ),
                ),
              ),
            ),
          ],
        ];
        // LimitedBox bounds an unbounded parent so the label can be Flexible; unlike a LayoutBuilder it keeps the
        // intrinsic sizes (IntrinsicHeight rows host segmented controls).
        Widget row(List<Widget> c) => LimitedBox(
          maxWidth: 4096,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final w in c) w is _Shrink ? Flexible(child: w.child) : w,
            ],
          ),
        );
        Widget box = RaftCssBox(
          // Raft's segment is `rounded-control` (8). The pre-theme app drew the
          // segment with `rounded-sm` (4) for Elegant and square for Brutal, and
          // 4 is what the contract carries as `radius.chip`; `radius.control`
          // would give Elegant 6 and miss the measurement. The chip token is used
          // for both looks because Brutal's chip is 0 and Raft keeps its own 8
          // through `radius.control` in the framed structure below.
          radius: t.option('segmented.frame', or: 'framed') == 'framed'
              ? t.size('radius.control', fallback: 8)
              : t.size('radius.chip', fallback: 4),
          fill: colors.fill,
          borderWidth: borderWidth,
          borderColor: colors.border,
          rings: [
            if (colors.ringEdge != null) RaftRing(1.5, colors.ringEdge!),
            if (st.focusVisible)
              for (final layer in ui.focusRing.layers)
                RaftRing(layer.spread, layer.color),
          ],
          height: grows ? null : height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: row(children),
        );
        if (grows) {
          box = ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: box,
          );
        }
        return box;
      },
    );
  }

  Widget _recipeSurface(BuildContext context, RaftInteractionState state) {
    final t = RaftTokens.of(context);
    final tokens = t.recipeTokens;
    final recipe = RaftSegmentedControlRecipe.resolve(
      theme: t.recipeTheme,
      tokens: tokens,
      states: t.recipeStates(
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
      height: height,
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
          if (glyph != null) RaftIcon(glyph!, size: svg!.width!, color: ink),
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
          if (labelSuffix != null)
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
          if (count != null)
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

  /// `w-full *:flex-1`: the track fills its row and the items share it equally (Raft look only).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final framed = t.option('segmented.frame', or: 'framed') == 'framed';

    // Custom packs can choose the same separate structure as the frozen looks.
    // Keep that explicit option ahead of the current generated track surface.
    if (!framed) {
      final gap = t.size('space.segmentGap', fallback: 4);
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
    }

    if (t.isRaftLook) {
      final tokens = t.recipeTokens;
      final recipe = RaftSegmentedControlRecipe.resolve(
        theme: t.recipeTheme,
        tokens: tokens,
        states: t.recipeStates(),
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

    // The track is the control radius plus its inset: the official source nests
    // `rounded-[11px]` around `p-[3px]` holding a `rounded-control` (8px) segment,
    // so the two corners stay concentric.
    final inset = 3.0;
    final trackRadius = t.size('radius.control', fallback: 8) + inset;
    final trackCorners = BorderRadius.circular(
      trackRadius >= 999 ? 999 : trackRadius,
    );
    if (expand) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: ui.fillMuted,
          borderRadius: trackCorners,
        ),
        child: Padding(
          // ignore: raft_lints/off_grid_spacing -- the track's `p-[3px]` is an explicit arbitrary value in the raft-ui source (3px ink-to-sticker inset), not a spacing step.
          padding: EdgeInsets.all(inset),
          child: Row(
            spacing: 2,
            children: [for (final child in children) Expanded(child: child)],
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ui.fillMuted,
        borderRadius: trackCorners,
      ),
      child: shrinkFrame
          ? _ShrinkingFrame(
              child: Padding(
                // ignore: raft_lints/off_grid_spacing -- the track's `p-[3px]` is an explicit arbitrary value in the raft-ui source (3px ink-to-sticker inset), not a spacing step.
                padding: EdgeInsets.all(inset),
                child: Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: children,
                ),
              ),
            )
          : Padding(
              // ignore: raft_lints/off_grid_spacing -- the track's `p-[3px]` is an explicit arbitrary value in the raft-ui source (3px ink-to-sticker inset), not a spacing step.
              padding: EdgeInsets.all(inset),
              child: Wrap(
                spacing: 2,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: children,
              ),
            ),
    );
  }
}

/// Marks the label a segment lets shrink (`min-w-0 truncate`) when the width is bounded.
class _Shrink extends StatelessWidget {
  const _Shrink({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

// ThreadsInbox v1.21.23: a shrinking flex track paints its full-size items
// outside its own rounded fill. Keep the items' intrinsic box and the track's
// constrained box separate, without clipping their text or reporting overflow.
class _ShrinkingFrame extends SingleChildRenderObjectWidget {
  const _ShrinkingFrame({required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderShrinkingFrame();
}

class _RenderShrinkingFrame extends RenderProxyBox {
  BoxConstraints looseWidth(BoxConstraints c) =>
      c.copyWith(minWidth: 0, maxWidth: double.infinity);
  @override
  void performLayout() {
    child!.layout(looseWidth(constraints), parentUsesSize: true);
    size = constraints.constrain(child!.size);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(child!.getDryLayout(looseWidth(constraints)));
}

/// How the frozen Elegant and Brutal looks draw a [RaftSegmentedControl]: the plain track row, loose tab buttons,
/// task filter buttons, or the row painted from the frozen `segmentedControl` recipe.
enum RaftSegmentedStyle { tabs, buttons, taskViews, recipe }

@immutable
class RaftSegmentedOption<T> {
  const RaftSegmentedOption({
    required this.value,
    required this.label,
    this.glyph,
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
    this.legacyStyle = RaftSegmentedStyle.buttons,
    this.minimumTargetSize,
    this.disabled = false,
    this.shrinkFrame = false,
    this.expand = false,
  });

  /// `className="w-full *:flex-1"`: the track fills its row, the segments share it equally. Raft look only.
  final bool expand;

  /// `SegmentedControl disabled`: every item is inert and its ink greys; the sticker stays.
  final bool disabled;

  /// A flex-shrinking CSS track may be narrower than its non-shrinking items.
  final bool shrinkFrame;

  /// How the frozen Elegant and Brutal looks draw this control. The Raft family
  /// always uses canonical segment items; its pack may choose a separate row.
  final RaftSegmentedStyle legacyStyle;
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
  final scope = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  @override
  void dispose() {
    _scrollController.dispose();
    scope.dispose();
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
    if (delta > 0) {
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
      for (final item in widget.items)
        RaftSegmentedItem(
          key: item.itemKey,
          label: item.label,
          glyph: item.glyph,
          count: item.count,
          labelSuffix: item.labelSuffix,
          tooltip: item.tooltip,
          checked: item.value == widget.value,
          height: widget.visualHeight,
          onPressed: _press(item),
        ),
    ],
  );

  Widget _group(BuildContext context) {
    final raft = RaftTokens.of(context).isRaftLook;
    final style = raft ? RaftSegmentedStyle.buttons : widget.legacyStyle;
    return switch (style) {
      // raft-ui `SegmentedControl` is `inline-flex w-fit`: the track hugs its items instead of stretching in a column.
      // The frozen looks keep the plain row they always drew.
      RaftSegmentedStyle.buttons when raft && widget.expand => _track(),
      RaftSegmentedStyle.buttons when raft => Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        heightFactor: 1,
        child: _track(),
      ),
      RaftSegmentedStyle.buttons => _track(),
      RaftSegmentedStyle.taskViews => _frozenTaskViews(context),
      RaftSegmentedStyle.tabs => _frozenTabs(context),
      RaftSegmentedStyle.recipe => _frozenRecipe(context),
    };
  }
}
