// List and section primitives from the Web client's components/ui:
// SurfaceListItem (raft-ui Card + product overrides), AvatarListRow,
// SectionEyebrow and SectionHeader. Class lists are cited per widget.

import 'hover_region.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'design_primitives.dart';
import 'form_controls.dart';
import 'icons.dart';
import 'recipes/button_variants.g.dart';

import 'recipe_surface.dart';
import 'recipes/card.g.dart';
import 'recipes/recipe_utilities.g.dart';
import 'recipes/recipe_runtime.dart';
import 'panel_layout.dart';
import 'text_measure.dart';
import 'text_scaling.dart' show RaftScaled;
import 'theme.dart';
import 'tokens/tokens.dart';

/// CSS block box holding one inline-level child (e.g. an `inline-flex`
/// button inside a `<div>`): the child sits on the line box's baseline
/// together with the inherited strut, so the box is as tall as CSS makes it.
class RaftInlineBox extends StatelessWidget {
  const RaftInlineBox({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      // The strut: an empty inline run in the inherited font / line-height.
      Text('​', style: raftCssText.merge(DefaultTextStyle.of(context).style)),
      child,
    ],
  );
}

/// Web `SurfaceListItem`: raft-ui `Card` (variant default) +
/// `min-w-0 w-full px-4 py-3 transition-colors` and, per state,
/// elegant `border-line-muted bg-layer-card` (`hover:border-line-strong
/// hover:shadow-raft-sm` when interactive) or selected `border-info
/// bg-info-muted shadow-raft-sm`; brutal `border-2 border-black bg-white`,
/// selected `bg-brutal-cyan/15 shadow-brutal-sm`, interactive hover
/// `shadow-brutal-sm`.
class RaftSurfaceListItem extends StatefulWidget {
  const RaftSurfaceListItem({
    super.key,
    required this.child,
    this.selected = false,
    this.onTap,
    this.interactive,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.background,
    this.selectedBackground,
  });

  final Widget child;
  final bool selected;

  /// Callsite `bg-*` that also wins over the selected fill (e.g. the
  /// MachineAgentList bulk bar: `SurfaceListItem selected` +
  /// `bg-layer-canvas-muted theme-brutal:bg-gray-100`).
  final Color? selectedBackground;

  /// Callsite `bg-*` override of the unselected, unhovered surface (e.g.
  /// MachineAgentList `bg-layer-canvas-muted theme-brutal:bg-gray-100`).
  final Color? background;
  final VoidCallback? onTap;

  /// Hover affordance; defaults to `onTap != null`.
  final bool? interactive;
  final EdgeInsets padding;

  @override
  State<RaftSurfaceListItem> createState() => _RaftSurfaceListItemState();
}

class _RaftSurfaceListItemState extends State<RaftSurfaceListItem> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final interactive = widget.interactive ?? widget.onTap != null;
    final hover = interactive && hovered;
    var card = RaftCardRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: rt,
    ).root;
    if (!t.brutal) {
      // Source Card + SurfaceListItem caller classes. The mounted Web uses a
      // 1px border; dark:border-transparent remains more specific than the
      // caller's unprefixed border color. Re-resolve the complete shadow so a
      // selected/hovered surface does not retain the default Card inset.
      final classes = [
        ...card.classes.where(
          (name) =>
              name != 'border-[0.5px]' &&
              name != 'border-line-muted' &&
              name != 'bg-layer-panel' &&
              (!(widget.selected || hover) || name != 'shadow-raft-xs'),
        ),
        'border',
        widget.selected ? 'border-info' : 'border-line-muted',
        widget.selected ? 'bg-info-muted' : 'bg-layer-card',
        if (widget.selected) 'shadow-raft-sm',
        if (interactive && !widget.selected) ...[
          'hover:border-line-strong',
          'hover:shadow-raft-sm',
        ],
      ];
      card = raftRecipeEngine.resolveSlot(
        [
          for (final name in classes)
            raftRecipeUtilities.indexWhere((utility) => utility.name == name),
        ],
        t.recipeStates(hovered: hover),
        rt,
      );
    }
    List<BoxShadow> shadow(RaftShadow s) => [
      for (final l in s.layers.reversed)
        if (!l.inset)
          BoxShadow(
            color: l.color,
            offset: l.offset,
            blurRadius: raftCssBlurRadius(l.blur),
            spreadRadius: l.spread,
          ),
    ];
    BoxDecoration brutalDecoration(BoxDecoration decoration) =>
        decoration.copyWith(
          color: widget.selected
              ? widget.selectedBackground ??
                    t.product.brutalCyan.withValues(alpha: .15)
              : hover || widget.background == null
              ? RaftPrimitiveColors.white
              : widget.background,
          border: Border.all(color: RaftPrimitiveColors.black, width: 2),
          boxShadow: widget.selected || hover
              ? shadow(RaftProductShadows.shadowBrutalSm)
              : null,
        );

    Widget item = RaftRecipeBox(
      style: card,
      tokens: rt,
      width: double.infinity,
      padding: widget.padding,
      clip: true,
      decorationOverride: t.brutal
          ? brutalDecoration
          : widget.selected && widget.selectedBackground != null
          ? (d) => d.copyWith(color: widget.selectedBackground)
          : widget.background != null && !widget.selected
          // `hover:bg-layer-panel` replaces the callsite fill on hover.
          ? (d) => d.copyWith(
              color: hover ? t.colors['layer-panel'] : widget.background,
            )
          : null,
      child: widget.child,
    );
    if (interactive) {
      item = RaftHoverRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(onTap: widget.onTap, child: item),
      );
    }
    return Semantics(
      selected: widget.selected,
      button: widget.onTap != null,
      child: item,
    );
  }
}

/// Web ServerSelector option: raft-ui `Card variant="option"` rendered as a
/// `<button class="w-full text-left">`. The raft-ui option recipe itself has
/// no hover, active or focus styles, so a touch client would show no response
/// at all. This is the design-system interactive form of that card: the
/// recipe box plus [RaftInteractive] states, with the same treatment the
/// other interactive cards use (`RaftSurfaceListItem` hover) and a pressed
/// fill. The 48dp hit area comes from [RaftInteractive] on touch density.
///
/// - hover: elegant `border-line-strong shadow-raft-sm`; the idle brutal card
///   already carries `shadow-brutal-sm`.
/// - pressed: filled with the muted canvas (elegant) or the brutal cream;
///   brutal drops its shadow, like a pressed brutal button.
/// - focus-visible: a 2px ring.
class RaftChoiceCard extends StatelessWidget {
  const RaftChoiceCard({
    super.key,
    required this.child,
    this.onPressed,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    return RaftInteractive(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      builder: (context, state) {
        final active = state.enabled && (state.hovered || state.pressed);
        final root = RaftCardRecipe.resolve(
          theme: t.recipeTheme,
          variant: RaftCardRecipeVariant.option,
          states: t.recipeStates(
            hovered: state.hovered,
            pressed: state.pressed,
            focusVisible: state.focusVisible,
            disabled: !state.enabled,
          ),
          tokens: rt,
        ).root;
        return RaftRecipeBox(
          style: root,
          tokens: rt,
          width: double.infinity,
          padding: padding,
          decorationOverride: (base) {
            final pressed = state.enabled && state.pressed;
            return base.copyWith(
              color: pressed
                  ? (t.brutal
                        ? t.product.brutalCream
                        : t.colors['layer-canvas-muted'])
                  : base.color,
              border: active && !t.brutal
                  ? Border.all(color: t.colors['line-strong']!)
                  : base.border,
              boxShadow: [
                if (t.brutal)
                  // The idle brutal card already carries `shadow-brutal-sm`;
                  // pressing it in removes the shadow.
                  ...(pressed
                      ? const <BoxShadow>[]
                      : base.boxShadow ?? const [])
                else ...[
                  ...?base.boxShadow,
                  if (active) ...t.shadows,
                ],
                if (state.focusVisible)
                  BoxShadow(
                    color: (t.brutal ? Colors.black : t.ink).withValues(
                      alpha: .8,
                    ),
                    spreadRadius: 2,
                  ),
              ],
            );
          },
          child: child,
        );
      },
    );
  }
}

/// Web `AvatarListRow` (`align="center"`, v1.21.12): a [RaftSurfaceListItem]
/// with `px-3 py-2`, avatar, name (`truncate text-sm font-semibold
/// text-foreground-muted theme-brutal:font-bold theme-brutal:text-black`) +
/// subtitle (`text-xs font-mono text-foreground-hint
/// theme-brutal:text-black/50`) in a
/// baseline-aligned wrap, and right content (`flex shrink-0 items-center
/// gap-1.5`).
class RaftAvatarListRow extends StatelessWidget {
  const RaftAvatarListRow({
    super.key,
    required this.avatar,
    required this.name,
    this.subtitle,
    this.rightContent = const [],
    this.actionContent = const [],
    this.onTap,
    this.selected = false,
    this.background,
  });

  /// Callsite surface fill (see [RaftSurfaceListItem.background]).
  final Color? background;
  final Widget avatar;
  final String name;
  final String? subtitle;
  final List<Widget> rightContent;

  /// Separate click targets outside the row button.
  final List<Widget> actionContent;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final s = t.semantic;
    final nameStyle = TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: t.brutal ? FontWeight.w700 : FontWeight.w600,
      color: t.brutal ? RaftPrimitiveColors.black : s.foregroundMuted,
    );
    final subtitleStyle = TextStyle(
      fontFamily: t.monoFont,
      fontWeight: FontWeight.w400,
      fontSize: 12,
      height: 16 / 12,
      color: t.brutal
          ? RaftPrimitiveColors.black.withValues(alpha: .5)
          : t.colors['foreground-hint']!,
    );
    List<Widget> gapped(List<Widget> items) => [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        items[i],
      ],
    ];
    // `flex min-w-0 flex-wrap items-baseline gap-x-2`: one baseline-aligned
    // line when name + subtitle fit, otherwise the subtitle wraps below and
    // the name truncates to the line.
    // Above the default text size the name wraps instead of truncating and the
    // right content stacks under the identity.
    final grows = RaftScaled.grows(context);
    Widget nameText() => Text(
      name,
      maxLines: grows ? null : 1,
      softWrap: grows,
      overflow: grows ? TextOverflow.clip : TextOverflow.ellipsis,
      style: nameStyle,
    );
    final text = subtitle == null
        ? nameText()
        : LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context);
              double widthOf(String v, TextStyle st) => raftTextWidth(
                TextSpan(
                  text: v,
                  style: DefaultTextStyle.of(context).style.merge(st),
                ),
                textScaler: scale,
                maxLines: 1,
              );
              final fits =
                  widthOf(name, nameStyle) +
                      8 +
                      widthOf(subtitle!, subtitleStyle) <=
                  constraints.maxWidth;
              final sub = Text(subtitle!, style: subtitleStyle);
              return fits
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [nameText(), const SizedBox(width: 8), sub],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [nameText(), sub],
                    );
            },
          );
    if (grows && (rightContent.isNotEmpty || actionContent.isNotEmpty)) {
      return RaftSurfaceListItem(
        selected: selected,
        onTap: onTap,
        background: background,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                avatar,
                const SizedBox(width: 12),
                Expanded(child: text),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [...rightContent, ...actionContent],
            ),
          ],
        ),
      );
    }
    return RaftSurfaceListItem(
      selected: selected,
      onTap: onTap,
      background: background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(child: text),
          if (rightContent.isNotEmpty) ...[
            const SizedBox(width: 12),
            Row(mainAxisSize: MainAxisSize.min, children: gapped(rightContent)),
          ],
          if (actionContent.isNotEmpty) ...[
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: gapped(actionContent),
            ),
          ],
        ],
      ),
    );
  }
}

/// Web `SectionEyebrow`: `text-xs font-bold uppercase text-foreground-muted
/// tracking-widest` (letter-spacing .1em).
class RaftSectionEyebrow extends StatelessWidget {
  const RaftSectionEyebrow(
    this.label, {
    super.key,
    this.uppercase = true,
    this.color,
    this.trailing,
  });

  final String label;
  final bool uppercase;

  /// Callsite colour override (e.g. `!text-black`).
  final Color? color;

  /// Inline spans after the label (e.g. the SectionHeader count).
  final List<InlineSpan>? trailing;

  static TextStyle style(RaftTokens t, {Color? color}) => TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: color ?? t.semantic.foregroundMuted,
  );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Text.rich(
      TextSpan(
        text: uppercase ? label.toUpperCase() : label,
        children: trailing,
      ),
      style: style(t, color: color),
    );
  }
}

/// Web `SectionHeader`: `flex items-center justify-between gap-2` with
/// optional icon, a [RaftSectionEyebrow] label + count (`ml-2 font-mono
/// text-foreground-placeholder theme-brutal:text-black/40`) and an action
/// in a `shrink-0` block.
class RaftSectionHeader extends StatelessWidget {
  const RaftSectionHeader({
    super.key,
    required this.label,
    this.icon,
    this.count,
    this.action,
    this.wrap = false,
  });

  final String label;
  final Widget? icon;

  final int? count;
  final Widget? action;

  /// Callsite `flex-wrap gap-y-2`: the action drops under the label when the
  /// two do not fit on one line.
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final left = Row(
      mainAxisSize: wrap ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (icon != null) ...[
          IconTheme.merge(
            data: IconThemeData(
              color: t.brutal
                  ? RaftPrimitiveColors.black.withValues(alpha: .6)
                  : t.semantic.foregroundMuted,
            ),
            child: icon!,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: RaftSectionEyebrow(
            label,
            trailing: count == null || count! < 0
                ? null
                : [
                    const WidgetSpan(child: SizedBox(width: 8)),
                    TextSpan(
                      text: '$count',
                      style: TextStyle(
                        fontFamily: t.monoFont,
                        color: t.brutal
                            ? RaftPrimitiveColors.black.withValues(alpha: .4)
                            : t.semantic.foregroundPlaceholder,
                      ),
                    ),
                  ],
          ),
        ),
      ],
    );
    if (wrap) {
      return RaftAutoMarginWrap(
        children: [
          left,
          if (action != null) RaftInlineBox(child: action!),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: left),
        if (action != null) ...[
          const SizedBox(width: 8),
          RaftInlineBox(child: action!),
        ],
      ],
    );
  }
}

/// Section header that opens and closes the content below it.
///
/// Collapsed it is a single [RaftSectionHeader] row (label, optional icon,
/// count and action); expanded the same row stays in place and sits above
/// [children]. The chevron turns a quarter turn, the way the sidebar's
/// sections do, and the row is one button for pointer, keyboard and screen
/// readers (`expanded` state, `label, count` name).
///
/// Opening and closing are animated instead of jumping: the content slides
/// open from under the header while it fades in, and folds back the same way
/// (shortened to zero under `MediaQuery.disableAnimations`). The caller owns
/// [expanded] (see `SidebarDisclosureStore` for the device-local memory
/// pattern) and the content; this widget owns the disclosure affordance and
/// its motion.
class RaftCollapsibleSectionHeader extends StatefulWidget {
  const RaftCollapsibleSectionHeader({
    super.key,
    required this.label,
    required this.expanded,
    required this.onExpandedChanged,
    required this.children,
    this.icon,
    this.count,
    this.action,
    this.disclosureKey,
    this.gap = 8,
  });

  final String label;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final List<Widget> children;
  final Widget? icon;
  final int? count;

  /// Stays outside the disclosure target so it keeps its own action.
  final Widget? action;
  final Key? disclosureKey;

  /// Gap between the header row and [children] while expanded.
  final double gap;

  @override
  State<RaftCollapsibleSectionHeader> createState() =>
      _RaftCollapsibleSectionHeaderState();
}

class _RaftCollapsibleSectionHeaderState
    extends State<RaftCollapsibleSectionHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _openDuration,
    reverseDuration: _closeDuration,
    value: widget.expanded ? 1 : 0,
  );

  // Long enough to read as motion rather than a jump, short enough that the
  // section still feels immediate under the thumb.
  static const Duration _openDuration = Duration(milliseconds: 240);
  static const Duration _closeDuration = Duration(milliseconds: 200);

  /// Height of the body as a fraction of its laid-out size: the disclosure
  /// opens from zero under the header and folds back to it. It decelerates on
  /// the way open and starts gently on the way closed.
  late final CurvedAnimation _size = CurvedAnimation(
    parent: _controller,
    curve: const Cubic(.2, 0, 0, 1),
    reverseCurve: const Cubic(.4, 0, .7, 1),
  );

  /// The content fades a beat behind the height, so rows do not pop while the
  /// gap is still opening, and lingers a beat on the way out.
  late final CurvedAnimation _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(.1, 1, curve: Curves.easeOut),
    reverseCurve: const Interval(0, .8, curve: Curves.easeIn),
  );

  @override
  void didUpdateWidget(RaftCollapsibleSectionHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded == widget.expanded) return;
    // `MediaQuery.disableAnimations` turns the fold into a cut.
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _controller.duration = reducedMotion ? Duration.zero : _openDuration;
    _controller.reverseDuration = reducedMotion
        ? Duration.zero
        : _closeDuration;
    if (widget.expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _size.dispose();
    _fade.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    // The chevron turns over the same beat as the fold it announces.
    final duration = reducedMotion ? Duration.zero : _openDuration;
    final header = Row(
      children: [
        Expanded(
          child: RaftSectionHeader(
            label: widget.label,
            icon: widget.icon,
            count: widget.count,
          ),
        ),
        const SizedBox(width: 8),
        AnimatedRotation(
          turns: widget.expanded ? .25 : 0,
          duration: duration,
          child: RaftIcon(
            RaftGlyph.chevronRight,
            size: 12,
            color: t.brutal
                ? RaftPrimitiveColors.black.withValues(alpha: .6)
                : t.semantic.foregroundMuted,
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                expanded: widget.expanded,
                child: RaftControl(
                  key: widget.disclosureKey,
                  kind: RaftControlKind.textLink,
                  visualHeight: 16,
                  flexibleHeight: true,
                  shadow: false,
                  padding: EdgeInsets.zero,
                  semanticLabel: widget.count == null
                      ? widget.label
                      : '${widget.label}, ${widget.count}',
                  onPressed: () => widget.onExpandedChanged(!widget.expanded),
                  // Only the disclosure's repeated label and decoration are
                  // excluded. An independent action keeps its own semantics.
                  child: ExcludeSemantics(child: header),
                ),
              ),
            ),
            if (widget.action != null) ...[
              const SizedBox(width: 8),
              widget.action!,
            ],
          ],
        ),
        // The body leaves the tree only once it is fully folded, so a closed
        // section stays one row for layout, tests and screen readers.
        ListenableBuilder(
          listenable: _controller,
          child: Padding(
            padding: EdgeInsets.only(top: widget.gap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < widget.children.length; i++) ...[
                  if (i > 0) SizedBox(height: widget.gap),
                  widget.children[i],
                ],
              ],
            ),
          ),
          builder: (context, child) => _controller.isDismissed
              ? const SizedBox.shrink()
              : SizeTransition(
                  sizeFactor: _size,
                  alignment: AlignmentDirectional.topStart,
                  child: FadeTransition(opacity: _fade, child: child),
                ),
        ),
      ],
    );
  }
}

/// Web `ui/MenuItem`: raft-ui `Button` (variant ghost, size sm) with
/// `flex w-full items-center gap-2 px-3 py-2 text-sm text-left
/// font-medium text-foreground-strong hover:bg-fill-muted
/// hover:!border-transparent disabled:text-foreground-muted` and brutal
/// `text-black hover:bg-soft-signal/30 disabled:text-black/30`.
class RaftMenuButtonItem extends StatelessWidget {
  const RaftMenuButtonItem({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailing,
    this.topDivider = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon, trailing;

  /// Callsite `border-t border-black/10` separator.
  final bool topDivider;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final enabled = onPressed != null;
    return Semantics(
      role: SemanticsRole.menuItem,
      child: RaftInteractive(
        onPressed: onPressed,
        button: false,
        builder: (context, st) {
          final s = RaftButtonRecipe.resolve(
            theme: t.recipeTheme,
            variant: RaftButtonRecipeVariant.ghost,
            size: RaftButtonRecipeSize.sm,
            states: t.recipeStates(
              hovered: st.hovered,
              pressed: st.pressed,
              focusVisible: st.focusVisible,
              disabled: !enabled,
            ),
            tokens: rt,
          ).root;
          final hover = st.hovered && enabled;
          final ink = !enabled
              ? (t.brutal
                    ? RaftPrimitiveColors.black.withValues(alpha: .3)
                    : t.semantic.foregroundMuted)
              : (t.brutal
                    ? RaftPrimitiveColors.black
                    : t.semantic.foregroundStrong);
          final side = (s.border(rt) ?? const Border()).top;
          final dividerColor = RaftPrimitiveColors.black.withValues(alpha: .1);
          return RaftRecipeBox(
            style: s,
            tokens: rt,
            overflowCenter: true,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decorationOverride: (d) {
              final color = topDivider ? dividerColor : Colors.transparent;
              BorderSide sideOf(double w) =>
                  w <= 0 ? BorderSide.none : BorderSide(color: color, width: w);
              return d.copyWith(
                color: hover
                    ? (t.brutal
                          ? t.product.softSignal.withValues(alpha: .3)
                          : t.semantic.fillMuted)
                    : d.color,
                border: Border(
                  top: sideOf(topDivider ? 1 : side.width),
                  left: sideOf(side.width),
                  right: sideOf(side.width),
                  bottom: sideOf(side.width),
                ),
              );
            },
            child: Builder(
              builder: (context) {
                final base = DefaultTextStyle.of(context).style.copyWith(
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w500,
                  color: ink,
                );
                return DefaultTextStyle(
                  style: base,
                  child: Row(
                    children: [
                      if (icon != null) ...[icon!, const SizedBox(width: 8)],
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 8),
                        trailing!,
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// One row of [RaftSelectionPopover].
@immutable
class RaftSelectionOption {
  const RaftSelectionOption({
    required this.label,
    required this.checked,
    required this.onTap,
    this.disabled = false,
    this.italic = false,
    this.leading,
    this.reserveLeadingSlot = false,
    this.rowKey,
  });
  final String label;
  final bool checked, disabled, italic, reserveLeadingSlot;

  /// Key of the option row (tests and parity interactions).
  final Key? rowKey;
  final VoidCallback onTap;
  final Widget? leading;
}

/// Web `ui/SelectionPopover`: raft-ui `Card` with the default className
/// (`border border-line-muted bg-layer-panel shadow-raft-sm`, brutal
/// `border-2 border-black bg-white shadow-brutal`), a header (`px-3 py-2
/// border-b`, `text-[10px] font-bold uppercase tracking-wide
/// text-foreground-muted` title + Clear), an optional search `Input`
/// (`w-full px-2 py-1 text-xs font-mono` in a `px-2 py-2 border-b` band) and
/// `h-9` option rows (`px-3 text-xs font-bold border-b`, brutal
/// `border-black/10`) with a 12px check.
class RaftSelectionPopover extends StatelessWidget {
  const RaftSelectionPopover({
    super.key,
    required this.title,
    required this.options,
    this.onClear,
    this.showHeader = true,
    this.clearLabel = 'Clear',
    this.searchController,
    this.searchPlaceholder = 'Search',
    this.onSearchChanged,
    this.searchFocusNode,
    this.emptyLabel = 'No options',
    this.width,
    this.surfaceStyle,
    this.brutalProductShadow = false,
  });

  final String title;
  final List<RaftSelectionOption> options;

  /// A caller surface that names the product `theme-brutal:shadow-brutal`
  /// utility (not a recipe class): brutal paints that shadow instead of the
  /// recipe's.
  final bool brutalProductShadow;

  /// Shows the Clear action when non-null (`showClear && onClear`).
  final VoidCallback? onClear;
  final bool showHeader;
  final String clearLabel, searchPlaceholder, emptyLabel;

  /// Searchable when non-null.
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final FocusNode? searchFocusNode;

  /// Explicit width; null = `min-w-[220px]` content width.
  final double? width;

  /// Final Card surface recipe for a caller's Source `className` composition.
  /// Null uses SelectionPopover's product default. The supplied recipe replaces
  /// that surface only; header, search, options and their interaction stay live.
  final RaftSlotStyle? surfaceStyle;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final s = t.semantic;
    final black = RaftPrimitiveColors.black;
    final divider = BorderSide(color: t.brutal ? black : s.lineMuted);
    final eyebrow = TextStyle(
      fontSize: 10,
      height: 1.5,
      fontWeight: FontWeight.w700,
      letterSpacing: .25,
      color: s.foregroundMuted,
    );
    final card = surfaceStyle ?? _selectionPopoverSurface(t);
    final radius =
        card.borderRadius?.resolve(Directionality.of(context)) ??
        BorderRadius.zero;
    final border = card.borderWidth;
    Radius inner(Radius r, double x, double y) => Radius.elliptical(
      (r.x - x).clamp(0, double.infinity),
      (r.y - y).clamp(0, double.infinity),
    );
    final contentRadius = BorderRadius.only(
      topLeft: inner(radius.topLeft, border.left, border.top),
      topRight: inner(radius.topRight, border.right, border.top),
      bottomLeft: inner(radius.bottomLeft, border.left, border.bottom),
      bottomRight: inner(radius.bottomRight, border.right, border.bottom),
    );
    final inputText = TextStyle(
      fontFamily: t.monoFont,
      fontSize: 12,
      height: 16 / 12,
    );
    Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(border: Border(bottom: divider)),
            child: Row(
              children: [
                Expanded(child: Text(title.toUpperCase(), style: eyebrow)),
                if (onClear != null)
                  _ClearAction(
                    label: clearLabel,
                    style: eyebrow,
                    onTap: onClear!,
                  ),
              ],
            ),
          ),
        if (searchController != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border(bottom: divider)),
            // Source Input is inline in the inherited Card text line. The
            // official caller's Inter 16px/24px line expands by 1px; use the
            // actual ancestor/recipe font metrics rather than a theme offset.
            child: RaftCssInlineBox(
              lineText: card.text(
                t.recipeTokens,
                base: DefaultTextStyle.of(context).style,
              ),
              childText: inputText,
              height: 16 + 8 + (t.brutal ? 4 : 2),
              child: RaftTextInput(
                controller: searchController,
                focusNode: searchFocusNode,
                autofocus: true,
                hintText: searchPlaceholder,
                onChanged: onSearchChanged,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                style: inputText,
              ),
            ),
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 256),
          child: options.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    emptyLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: t.monoFont,
                      fontSize: 11,
                      height: 1.5,
                      color: s.foregroundMuted,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < options.length; i++)
                        _SelectionRow(
                          key: options[i].rowKey,
                          option: options[i],
                          last: i == options.length - 1,
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
    // HTML autoFocus moves focus into a newly mounted popup even when the
    // trigger owns focus. A fresh scope gives Flutter's real TextField the
    // same admission; Tab may still leave into the owner's scope.
    return _SelectionFocusScope(
      child: RaftRecipeBox(
        style: card,
        tokens: t.recipeTokens,
        width: width,
        clip: true,
        padding: EdgeInsets.zero,
        // Source's theme-brutal:shadow-brutal is a product utility. It replaces
        // the default recipe shadow; an explicit caller recipe owns its shadows.
        decorationOverride:
            (surfaceStyle == null || brutalProductShadow) && t.brutal
            ? (decoration) => decoration.copyWith(
                boxShadow: RaftProductShadows.shadowBrutal.paintOrder,
              )
            : null,
        child: ClipRRect(borderRadius: contentRadius, child: body),
      ),
    );
  }
}

// Exact Card/default SelectionPopover composition (SelectionPopover.tsx:117).
// Placement belongs to the popup owner; this recipe owns surface appearance.
RaftSlotStyle _selectionPopoverSurface(RaftTokens tokens) {
  final card = RaftCardRecipe.resolve(
    theme: tokens.recipeTheme,
    states: tokens.recipeStates(),
    tokens: tokens.recipeTokens,
  ).root;
  final classes = [
    ...card.classes.where(
      (name) => !const {
        'min-w-0',
        'border-2',
        'border-[0.5px]',
        'border-line-muted',
        'border-line-strong',
        'border-black',
        'bg-white',
        'bg-layer-panel',
        'shadow-raft-md',
        'shadow-raft-xs',
      }.contains(name),
    ),
    'min-w-[220px]',
    tokens.brutal ? 'border-2' : 'border',
    tokens.brutal ? 'border-black' : 'border-line-muted',
    tokens.brutal ? 'bg-white' : 'bg-layer-panel',
    'shadow-raft-sm',
  ];
  return raftRecipeEngine.resolveSlot(
    [
      for (final name in classes)
        raftRecipeUtilities.indexWhere((utility) => utility.name == name),
    ],
    tokens.recipeStates(),
    tokens.recipeTokens,
  );
}

class _SelectionFocusScope extends StatefulWidget {
  const _SelectionFocusScope({required this.child});
  final Widget child;
  @override
  State<_SelectionFocusScope> createState() => _SelectionFocusScopeState();
}

class _SelectionFocusScopeState extends State<_SelectionFocusScope> {
  final scope = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );
  @override
  void dispose() {
    scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FocusScope(node: scope, child: widget.child);
}

class _ClearAction extends StatelessWidget {
  const _ClearAction({
    required this.label,
    required this.style,
    required this.onTap,
  });
  final String label;
  final TextStyle style;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftInteractive(
      onPressed: onTap,
      builder: (context, state) => CustomPaint(
        foregroundPainter: state.focusVisible
            ? _SelectionFocusOutline(t.semantic.lineStrong)
            : null,
        child: Text(
          label,
          style: style.copyWith(
            color: state.hovered ? t.semantic.foregroundStrong : null,
          ),
        ),
      ),
    );
  }
}

// The product's unstyled buttons inherit index.css *:focus-visible:
// outline 2px line-strong, offset 2px. It affects paint, never row layout.
class _SelectionFocusOutline extends CustomPainter {
  const _SelectionFocusOutline(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(
    (Offset.zero & size).inflate(3),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  @override
  bool shouldRepaint(_SelectionFocusOutline old) => old.color != color;
}

class _SelectionRow extends StatefulWidget {
  const _SelectionRow({super.key, required this.option, required this.last});
  final RaftSelectionOption option;
  final bool last;
  @override
  State<_SelectionRow> createState() => _SelectionRowState();
}

class _SelectionRowState extends State<_SelectionRow> {
  @override
  Widget build(BuildContext context) => RaftInteractive(
    onPressed: widget.option.disabled ? null : widget.option.onTap,
    checked: widget.option.checked,
    builder: (context, state) => buildRow(context, state),
  );

  Widget buildRow(BuildContext context, RaftInteractionState state) {
    final t = RaftTokens.of(context);
    final s = t.semantic;
    final o = widget.option;
    final black = RaftPrimitiveColors.black;
    final ink = o.disabled
        ? (t.brutal ? black.withValues(alpha: .3) : s.foregroundMuted)
        : (t.brutal ? black : s.foregroundStrong);
    final bg = !o.disabled && state.hovered
        ? (t.brutal ? t.product.softSignal.withValues(alpha: .3) : s.fillMuted)
        : (t.brutal ? RaftPrimitiveColors.white : s.layerPanel);
    final leading = o.leading;
    final label = o.italic
        ? Text(
            o.label,
            softWrap: false,
            style: TextStyle(
              height: 2,
              fontStyle: FontStyle.italic,
              color: t.brutal ? black.withValues(alpha: .7) : s.foregroundMuted,
            ),
          )
        : Text(
            o.label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(height: 2),
          );
    return CustomPaint(
      foregroundPainter: state.focusVisible
          ? _SelectionFocusOutline(s.lineStrong)
          : null,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          border: widget.last
              ? null
              : Border(
                  bottom: BorderSide(
                    color: t.brutal ? black.withAlpha(26) : s.lineMuted,
                  ),
                ),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          child: Row(
            children: [
              if (o.reserveLeadingSlot || leading != null) ...[
                SizedBox.square(dimension: 20, child: Center(child: leading)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: label),
              ),
              if (o.checked) ...[
                const SizedBox(width: 8),
                RaftIcon(RaftGlyph.check, size: 12, color: ink),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// CSS `flex flex-wrap gap-x-[spacing] gap-y-[runSpacing] items-center` whose
/// FIRST child carries `mr-auto`: the lead takes the left of the first line,
/// the remaining children sit at its right edge, and children that do not fit
/// wrap onto following lines, left-aligned.
class RaftAutoMarginWrap extends MultiChildRenderObjectWidget {
  const RaftAutoMarginWrap({
    super.key,
    super.children,
    this.spacing = 8,
    this.runSpacing = 8,
  });
  final double spacing, runSpacing;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderAutoMarginWrap(spacing, runSpacing);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderAutoMarginWrap renderObject,
  ) {
    renderObject
      ..spacing = spacing
      ..runSpacing = runSpacing;
  }
}

class _AutoMarginParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderAutoMarginWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _AutoMarginParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _AutoMarginParentData> {
  _RenderAutoMarginWrap(this._spacing, this._runSpacing);
  double _spacing, _runSpacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  set runSpacing(double value) {
    if (_runSpacing == value) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _AutoMarginParentData) {
      child.parentData = _AutoMarginParentData();
    }
  }

  Size _arrange(BoxConstraints constraints, {required bool position}) {
    final maxWidth = constraints.maxWidth;
    final inner = BoxConstraints(maxWidth: maxWidth);
    final lines = <List<RenderBox>>[[]];
    final sizes = <RenderBox, Size>{};
    var used = 0.0;
    for (var c = firstChild; c != null; c = childAfter(c)) {
      final size = position
          ? (c..layout(inner, parentUsesSize: true)).size
          : c.getDryLayout(inner);
      sizes[c] = size;
      final line = lines.last;
      final next = line.isEmpty ? size.width : used + _spacing + size.width;
      if (line.isNotEmpty && next > maxWidth) {
        lines.add([c]);
        used = size.width;
      } else {
        line.add(c);
        used = next;
      }
    }
    var y = 0.0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      final height = line.fold<double>(
        0,
        (h, c) => h > sizes[c]!.height ? h : sizes[c]!.height,
      );
      final lineWidth =
          line.fold<double>(0, (w, c) => w + sizes[c]!.width) +
          _spacing * (line.length - 1);
      // `mr-auto` of the first child pushes the rest to the right edge.
      final margin = i == 0 && line.length > 1 ? maxWidth - lineWidth : 0.0;
      var x = 0.0;
      for (var j = 0; j < line.length; j++) {
        final c = line[j];
        if (position) {
          (c.parentData! as _AutoMarginParentData).offset = Offset(
            x,
            y + (height - sizes[c]!.height) / 2,
          );
        }
        x += sizes[c]!.width + _spacing + (j == 0 ? margin : 0);
      }
      y += height + (i == lines.length - 1 ? 0 : _runSpacing);
    }
    return constraints.constrain(Size(maxWidth, y));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _arrange(constraints, position: false);

  @override
  void performLayout() {
    size = _arrange(constraints, position: true);
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
