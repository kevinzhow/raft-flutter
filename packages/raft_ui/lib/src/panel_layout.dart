// Panel chrome shared by the Web detail panels (AgentDetailPanel,
// HumanDetailPanel, MachineDetailPanel): the canonical PanelHeader row, its
// PanelAction buttons, the scrollable underline Tabs strip and the section
// typography (SectionEyebrow / SectionHeader / InfoRow).
//
// Geometry and colour come from the generated raft-ui recipes (panelHeader,
// panelAction, tabs) and, for classes written directly in Web JSX, from the
// Tailwind classes cited next to each value (packages/web/src paths).
import 'hover_region.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter/rendering.dart';

import 'raft_underline.dart';
import 'control_typography.dart';
import 'design_primitives.dart' hide RaftPanelHeaderRecipe;
import 'icons.dart';
import 'inline_badge_editor.dart' show RaftTouchTargetExpander;
import 'recipes/recipe_runtime.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/panel_action.g.dart';
import 'recipes/panel_header.g.dart';
import 'recipes/tabs.g.dart';
import 'recipes/token_binding.dart';
import 'recipe_surface.dart' show raftCssText;
import 'status_bar.dart';
import 'text_scaling.dart' show RaftChrome, RaftScaled;
import 'large_content_viewer.dart';
import 'theme.dart';
import 'tooltip.dart';

RaftRecipeTheme raftRecipeTheme(RaftTokens t) =>
    t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant;

/// `theme-brutal:text-black/<n>` overrides used across the Web panels; other
/// themes keep the semantic token.
Color raftPanelInk(RaftTokens t, double brutalAlpha, Color elegant) =>
    t.brutal ? Colors.black.withValues(alpha: brutalAlpha) : elegant;

/// AgentDetailPanel.tsx InfoRow: `grid grid-cols-[6.5rem_minmax(0,1fr)]
/// items-start gap-x-4`; the term is `flex min-h-5 items-center gap-1.5
/// text-xs text-foreground-muted theme-brutal:text-black/50`, the value
/// `text-sm text-foreground-strong theme-brutal:text-black`.
class RaftInfoRow extends StatelessWidget {
  const RaftInfoRow({
    super.key,
    required this.label,
    required this.child,
    this.actions = const [],
  });
  final String label;
  final Widget child;
  final List<Widget> actions;

  static TextStyle valueStyle(RaftTokens t) => raftCssText.merge(
    RaftTypography.heading(
      t,
      size: 14,
      line: 20,
      weight: FontWeight.w400,
    ).copyWith(color: t.brutal ? Colors.black : t.strong),
  );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 20),
            child: Row(
              children: [
                Flexible(
                  child: RaftCssText(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: raftCssText.merge(
                      RaftTypography.heading(
                        t,
                        size: 12,
                        line: 16,
                        weight: FontWeight.w400,
                        color: raftPanelInk(
                          t,
                          .5,
                          t.colors['foreground-muted']!,
                        ),
                      ),
                    ),
                  ),
                ),
                for (final a in actions) ...[const SizedBox(width: 6), a],
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DefaultTextStyle.merge(style: valueStyle(t), child: child),
        ),
      ],
    );
  }
}

/// Bare inline icon button: `text-foreground-placeholder
/// theme-brutal:text-black/40 hover:text-foreground-strong
/// theme-brutal:hover:text-black` (pencil / help affordances).
class RaftInlineIconButton extends StatefulWidget {
  const RaftInlineIconButton({
    super.key,
    required this.glyph,
    required this.tooltip,
    this.size = 12,
    this.onPressed,
  });
  final RaftGlyph glyph;
  final String tooltip;
  final double size;
  final VoidCallback? onPressed;
  @override
  State<RaftInlineIconButton> createState() => _RaftInlineIconButtonState();
}

class _RaftInlineIconButtonState extends State<RaftInlineIconButton> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final color = hovered
        ? (t.brutal ? Colors.black : t.strong)
        : raftPanelInk(t, .4, t.colors['foreground-placeholder']!);
    return RaftTooltip(
      message: widget.tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: RaftHoverRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: RaftIcon(widget.glyph, size: widget.size, color: color),
          ),
        ),
      ),
    );
  }
}

/// raft-ui PanelAction (panelAction recipe): bordered square icon action of
/// the panel header (`& > svg` 14px in brutal).
class RaftPanelAction extends StatelessWidget {
  const RaftPanelAction({
    super.key,
    required this.glyph,
    required this.tooltip,
    this.onPressed,
    this.minHitExtent = 0,
  });
  final RaftGlyph glyph;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Minimum touch target below the md breakpoint. Web's boxed action is
  /// 24x28 (Brutal) / 32x32 (Elegant); the visual and layout stay as Web
  /// draws them and the hit area is extended around it.
  final double minHitExtent;
  @override
  Widget build(BuildContext context) => RaftTouchTargetExpander(
    minSize: Size.square(
      minHitExtent > 0 &&
              MediaQuery.sizeOf(context).width <
                  RaftLayoutMetrics.desktopBreakpoint
          ? minHitExtent
          : 0,
    ),
    child: _interactive(context),
  );

  Widget _interactive(BuildContext context) => RaftInteractive(
    onPressed: onPressed,
    semanticLabel: tooltip,
    tooltip: tooltip,
    builder: (context, state) {
      final t = RaftTokens.of(context),
          rt = RaftRecipeTokens(RaftTokens.of(context));
      final s = RaftPanelActionRecipe.resolve(
        theme: raftRecipeTheme(t),
        states: RaftRecipeStates({
          if (state.hovered) RaftRecipeStates.hover,
          if (state.pressed) RaftRecipeStates.active,
          if (state.focusVisible) RaftRecipeStates.focusVisible,
          if (!state.enabled) RaftRecipeStates.disabled,
          if (t.dark) RaftRecipeStates.dark,
        }),
        tokens: rt,
      ).base;
      final svg = s.target('& > svg');
      return CustomPaint(
        foregroundPainter: RaftCssFocusOutline(
          enabled: state.focusVisible,
          color: t.colors['line-strong']!,
          radius: s.borderRadius ?? BorderRadius.zero,
        ),
        child: Opacity(
          opacity: s.opacity ?? 1,
          child: Transform.translate(
            offset: s.translate ?? Offset.zero,
            child: Container(
              padding: s.padding,
              decoration: s.decoration(rt),
              child: RaftIcon(
                glyph,
                size: svg?.width ?? 14,
                color: s.color?.resolve(rt) ?? t.strong,
              ),
            ),
          ),
        ),
      );
    },
  );
}

// Source global index.css focus-visible outline: 2px, offset 2px.
// Pointer focus keeps the generated resting surface and geometry unchanged.
class RaftCssFocusOutline extends CustomPainter {
  const RaftCssFocusOutline({
    required this.enabled,
    required this.color,
    this.radius = BorderRadius.zero,
  });
  final bool enabled;
  final Color color;
  final BorderRadius radius;
  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled) return;
    canvas.drawRRect(
      radius.toRRect(Offset.zero & size).inflate(3),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(RaftCssFocusOutline old) =>
      old.enabled != enabled || old.color != color || old.radius != radius;
}

/// Title/meta flow of the real raft-ui PanelHeaderContent slot.
///
/// The generated recipe supplies its column/row direction and spacing. Callers
/// resolve `has:>data-slot=panel-meta` when [meta] is present so desktop Elegant
/// aligns the two CSS line boxes on their alphabetic baseline. One Flex owner
/// remains mounted when the theme or viewport changes.
class RaftPanelHeaderContent extends StatelessWidget {
  const RaftPanelHeaderContent({
    super.key,
    required this.style,
    required this.heading,
    this.meta,
  });
  final RaftSlotStyle style;
  final Widget heading;
  final Widget? meta;

  @override
  Widget build(BuildContext context) {
    final horizontal = switch (style['flex-direction']) {
      CssKeyword(value: 'row') => true,
      _ => false,
    };
    final gap =
        (horizontal ? style.columnGap : style.rowGap) ??
        style.length('gap') ??
        0;
    final baseline =
        horizontal &&
        meta != null &&
        switch (style['align-items']) {
          CssKeyword(value: 'baseline') => true,
          _ => false,
        };
    return LayoutBuilder(
      builder: (context, constraints) => Flex(
        direction: horizontal ? Axis.horizontal : Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: horizontal
            ? baseline
                  ? CrossAxisAlignment.baseline
                  : CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        textBaseline: TextBaseline.alphabetic,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: horizontal && meta != null
                  ? (constraints.maxWidth - gap).clamp(0, double.infinity)
                  : constraints.maxWidth,
            ),
            child: heading,
          ),
          if (meta != null) ...[
            SizedBox(width: horizontal ? gap : 0, height: horizontal ? 0 : gap),
            Flexible(
              fit: horizontal ? FlexFit.tight : FlexFit.loose,
              child: meta!,
            ),
          ],
        ],
      ),
    );
  }
}

/// raft-ui PanelHeader as composed by Web `components/ui/PanelHeader.tsx`
/// (AppPanelHeader): back action, identity icon slot, title (+ suffix) and
/// subtitle, right-aligned actions.
class RaftPanelHeaderBar extends StatelessWidget {
  const RaftPanelHeaderBar({
    super.key,
    required this.title,
    this.subtitle,
    this.titleSlot,
    this.iconSlot,
    this.onBack,
    this.backKey,
    this.backTooltip = 'Back',
    this.actions = const [],
    this.iconAlwaysVisible = false,
    this.profileBody = false,
    this.leftPadding,
    this.bottomRule = false,
    this.titleSuffix,
  });
  final String title;
  final String? subtitle;

  /// AppPanelHeader `titleSuffix`: a node inline after the title (outside the
  /// truncating title), e.g. `Badge.Experimental`.
  final Widget? titleSuffix;

  /// AppPanelHeader `titleSlot`: replaces the title/meta stack (the search
  /// field of MessageSearchPage).
  final Widget? titleSlot;

  /// Overrides the recipe's left inset (ActivityInboxPanel's `pl-3`).
  final double? leftPadding;

  /// A 1px `border-line-muted` rule under the header (the Activity header's
  /// `border-b`; the canonical desktop header has none).
  final bool bottomRule;

  /// The header sits on raft-ui `ProfilePanelBody` (`dark:bg-layer-card`), whose
  /// own fill the transparent header shows through in Elegant dark.
  final bool profileBody;

  /// Pre-wrapped identity (AvatarSlot context="panel-header"), rendered in
  /// the PanelHeaderIcon cell.
  final Widget? iconSlot;

  /// AppPanelHeader `iconAlwaysVisible`: identity panels (Agent / Human /
  /// Machine detail) keep the icon below md; other surfaces hide it.
  final bool iconAlwaysVisible;
  final VoidCallback? onBack;
  final Key? backKey;
  final String backTooltip;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final width = MediaQuery.sizeOf(context).width;
    final s = RaftPanelHeaderRecipe.resolve(
      theme: raftRecipeTheme(t),
      states: RaftRecipeStates({
        if (t.dark) RaftRecipeStates.dark,
        if (subtitle != null) 'has:>data-slot=panel-meta',
      }, width),
      tokens: rt,
    );
    final base = RaftTypography.body(t, size: 16, line: 20);
    TextStyle text(RaftSlotStyle slot) => raftCssText.merge(
      base
          .merge(slot.textStyle(rt))
          .copyWith(fontFamily: slot.fontFamily == null ? t.bodyFont : null),
    );
    final gap = s.header.columnGap ?? s.header.length('gap') ?? 12;
    final narrow = width < RaftLayoutMetrics.desktopBreakpoint;
    // Above the default text size the header height is a minimum and the
    // title / subtitle wrap, so the bar grows with its text.
    final grows = RaftScaled.grows(context);
    final lines = grows ? null : 1;
    final barPadding = leftPadding == null
        ? s.header.padding
        : s.header.padding.copyWith(left: leftPadding);
    final header = Container(
      height: grows ? null : s.header.height,
      constraints: BoxConstraints(
        minHeight: math.max(
          s.header.minHeight ?? 0,
          grows ? s.header.height ?? 0 : 0,
        ),
      ),
      padding: grows
          ? barPadding.copyWith(
              top: math.max(barPadding.top, 8),
              bottom: math.max(barPadding.bottom, 8),
            )
          : barPadding,
      decoration: bottomRule
          ? s.header
                .decoration(rt)
                .copyWith(
                  border: Border(
                    // Brutal `border-b-2 border-black` (pure black, not ink).
                    bottom: BorderSide(
                      color: t.brutal ? Colors.black : t.colors['line-muted']!,
                      width: t.brutal ? 2 : 1,
                    ),
                  ),
                )
          : s.header.decoration(rt),
      child: Row(
        children: [
          if (onBack != null) ...[
            RaftPanelAction(
              key: backKey,
              glyph: RaftGlyph.arrowLeft,
              tooltip: backTooltip,
              onPressed: onBack,
              minHitExtent: RaftMetrics.touchTarget,
            ),
            SizedBox(width: gap),
          ],
          // PanelHeaderIcon is `hidden md:flex` unless the surface is an
          // identity panel (`iconAlwaysVisible`).
          if (iconSlot != null && (!narrow || iconAlwaysVisible)) ...[
            SizedBox.square(
              dimension: s.headerIcon.width ?? 36,
              child: iconSlot,
            ),
            SizedBox(width: gap),
          ],
          Expanded(
            child:
                titleSlot ??
                RaftPanelHeaderContent(
                  style: s.headerContent,
                  heading: titleSuffix == null
                      ? Semantics(
                          header: true,
                          child: RaftCssText(
                            title,
                            maxLines: lines,
                            overflow: lines == null
                                ? TextOverflow.clip
                                : TextOverflow.ellipsis,
                            style: text(s.title),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing:
                              s.heading.columnGap ??
                              s.heading.length('gap') ??
                              8,
                          children: [
                            Flexible(
                              child: Semantics(
                                header: true,
                                child: RaftCssText(
                                  title,
                                  maxLines: lines,
                                  overflow: lines == null
                                      ? TextOverflow.clip
                                      : TextOverflow.ellipsis,
                                  style: text(s.title),
                                ),
                              ),
                            ),
                            titleSuffix!,
                          ],
                        ),
                  meta: subtitle == null
                      ? null
                      : RaftCssText(
                          subtitle!,
                          maxLines: lines,
                          overflow: lines == null
                              ? TextOverflow.clip
                              : TextOverflow.ellipsis,
                          style: text(s.meta),
                        ),
                ),
          ),
          if (actions.isNotEmpty) ...[
            SizedBox(width: gap),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0)
                SizedBox(
                  width: s.actions.columnGap ?? s.actions.length('gap') ?? 6,
                ),
              actions[i],
            ],
          ],
        ],
      ),
    );
    // The surface the user sees: the recipe's own fill, else (transparent
    // header) the profile body it sits on.
    final fill = s.header.decoration(rt).color;
    final shown = fill != null && fill.a != 0
        ? fill
        : profileBody && t.dark
        ? t.card
        : Colors.transparent;
    return RaftStatusBarSource(
      color: shown,
      child: profileBody && t.dark
          ? ColoredBox(color: t.card, child: header)
          : header,
    );
  }
}

class RaftPanelTab<T> {
  const RaftPanelTab(this.id, this.label, RaftGlyph this.glyph)
    : iconBuilder = null;
  const RaftPanelTab.custom(this.id, this.label, {required this.iconBuilder})
    : glyph = null;
  final T id;
  final String label;
  final RaftGlyph? glyph;

  /// Product SVG artwork (for example raft-ui ChatIcon), resolved with the
  /// tab recipe's SVG dimensions, colour and stroke width.
  final Widget Function(double size, Color color, double strokeWidth)?
  iconBuilder;
}

/// The detail-panel tab strip: raft-ui Tabs `variant="underline"` inside a
/// horizontally scrollable row (AgentDetailPanel.tsx ~3070: Tabs root
/// `border-b theme-brutal:border-b-2 border-line-muted theme-brutal:border-black
/// bg-layer-panel`, list `max-w-full theme-brutal:border-0
/// theme-brutal:bg-layer-panel`, tab `h-7`, icon size 12). The active tab is
/// scrolled to the centre like the Web layout effect.
class RaftPanelTabBar<T> extends StatefulWidget {
  const RaftPanelTabBar({
    super.key,
    required this.tabs,
    required this.value,
    required this.onChanged,
  });
  final List<RaftPanelTab<T>> tabs;
  final T value;
  final ValueChanged<T> onChanged;
  @override
  State<RaftPanelTabBar<T>> createState() => _RaftPanelTabBarState<T>();
}

class _RaftPanelTabBarState<T> extends State<RaftPanelTabBar<T>> {
  final scroll = ScrollController();
  final keys = <Object?, GlobalKey>{};
  T? hovered;

  @override
  void initState() {
    super.initState();
    // Web scrolls the active tab into view on mount and again a frame later
    // (`scrollActiveTabIntoView` + requestAnimationFrame): a route page that
    // mounts on a non-default tab has no extent on its first frame, so it also
    // re-centres while the strip's extent settles (until the user scrolls).
    WidgetsBinding.instance.addPostFrameCallback((_) => center());
  }

  bool userScrolled = false;

  bool _metricsChanged(ScrollMetricsNotification n) {
    if (!userScrolled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => center());
    }
    return false;
  }

  bool _scrollStarted(ScrollStartNotification n) {
    if (n.dragDetails != null) userScrolled = true;
    return false;
  }

  @override
  void didUpdateWidget(RaftPanelTabBar<T> old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      userScrolled = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => center());
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void center() {
    if (!mounted || !scroll.hasClients) return;
    final box =
        keys[widget.value]?.currentContext?.findRenderObject() as RenderBox?;
    final list = context.findRenderObject() as RenderBox?;
    if (box == null || list == null || !box.attached) return;
    final left =
        box.localToGlobal(Offset.zero, ancestor: list).dx + scroll.offset;
    final target = left - (list.size.width - box.size.width) / 2;
    scroll.jumpTo(target.clamp(0, scroll.position.maxScrollExtent));
  }

  // Fixed chrome: label text is bounded (RaftChrome) and a long press shows the
  // tab large (Large Content Viewer) once the bound hides growth.
  @override
  Widget build(BuildContext context) =>
      RaftChrome(child: RaftLargeContentScope(child: _strip(context)));

  Widget _strip(BuildContext context) {
    final grows = RaftScaled.grows(context);
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    RaftTabsRecipeStyle style(bool active, bool hover) =>
        RaftTabsRecipe.resolve(
          theme: raftRecipeTheme(t),
          variant: RaftTabsRecipeVariant.underline,
          states: RaftRecipeStates({
            if (active) 'data-active',
            if (hover) RaftRecipeStates.hover,
            if (t.dark) RaftRecipeStates.dark,
          }),
          tokens: rt,
        );
    final base = style(false, false);
    final listBg = t.colors['layer-panel']!;
    return Container(
      decoration: BoxDecoration(
        color: listBg,
        border: Border(
          bottom: BorderSide(
            color: t.brutal ? Colors.black : t.colors['line-muted']!,
            width: t.brutal ? 2 : 1,
          ),
        ),
      ),
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: _metricsChanged,
        child: NotificationListener<ScrollStartNotification>(
          onNotification: _scrollStarted,
          child: SingleChildScrollView(
            controller: scroll,
            scrollDirection: Axis.horizontal,
            child: t.brutal
                ? Row(
                    children: [
                      for (var i = 0; i < widget.tabs.length; i++)
                        _tab(widget.tabs[i], i, style, base, rt, t),
                    ],
                  )
                // Elegant `tabs-list`: `h-12 gap-1 px-4` with a hairline rule; the
                // `h-7` tabs sit centred and the 2px indicator on the list floor.
                : Container(
                    height: grows ? null : 48,
                    constraints: grows
                        ? const BoxConstraints(minHeight: 48)
                        : null,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color:
                              t.colors['line-hairline'] ??
                              t.colors['line-muted']!,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < widget.tabs.length; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          _elegantTab(widget.tabs[i], style, rt, t),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _elegantTab(
    RaftPanelTab<T> tab,
    RaftTabsRecipeStyle Function(bool, bool) style,
    RaftRecipeTokens rt,
    RaftTokens t,
  ) {
    final grows = RaftScaled.grows(context);
    final active = tab.id == widget.value;
    final recipe = style(active, hovered == tab.id);
    final s = recipe.tab;
    final svg = s.target('& svg:not([class*=\'size-\'])') ?? s.target('& svg');
    final iconSize = svg?.width ?? 14;
    final strokeValue = (s.target('& svg') ?? s)['stroke-width'];
    final stroke = strokeValue is CssNum ? strokeValue.value : 2.0;
    final fg = s.color?.resolve(rt) ?? t.strong;
    final iconColor = s.target('& svg')?.color?.resolve(rt) ?? fg;
    final label = raftCssText.merge(
      RaftTypography.heading(
        t,
        size: 13,
        line: 19.5,
        weight: FontWeight.w500,
      ).copyWith(color: fg, letterSpacing: -0.065),
    );
    return RaftHoverRegion(
      key: keys.putIfAbsent(tab.id, GlobalKey.new),
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => hovered = tab.id),
      onExit: (_) => setState(() => hovered = null),
      child: Semantics(
        selected: active,
        button: true,
        label: tab.label,
        excludeSemantics: true,
        child: _largeContent(
          tab,
          child: GestureDetector(
            key: ValueKey(
              'panel-tab-${tab.id is Enum ? (tab.id as Enum).name : tab.id}',
            ),
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onChanged(tab.id),
            child: Stack(
              children: [
                Padding(
                  // ds-allow: Web AgentDetailPanel.tsx tabs-list `h-12` centring the `h-7` tab: (48 - 1 - 28) / 2
                  padding: const EdgeInsets.symmetric(vertical: 9.5),
                  child: Container(
                    height: grows ? null : 28,
                    constraints: grows
                        ? const BoxConstraints(minHeight: 28)
                        : null,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        tab.iconBuilder?.call(iconSize, iconColor, stroke) ??
                            RaftIcon(
                              tab.glyph!,
                              size: iconSize,
                              strokeWidth: stroke,
                              color: iconColor,
                            ),
                        const SizedBox(width: 6),
                        RaftCssText(
                          tab.label,
                          style: label,
                          maxLines: 1,
                          controlLabel: true,
                        ),
                      ],
                    ),
                  ),
                ),
                if (active)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 2,
                    child: ColoredBox(
                      color:
                          recipe.indicator.backgroundColor?.resolve(rt) ?? fg,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _largeContent(RaftPanelTab<T> tab, {required Widget child}) =>
      RaftLargeContentViewer(
        label: tab.label,
        onActivate: () => widget.onChanged(tab.id),
        iconBuilder: (context, size) =>
            tab.iconBuilder?.call(
              size,
              IconTheme.of(context).color ?? RaftTokens.of(context).strong,
              2,
            ) ??
            RaftIcon(tab.glyph!, size: size),
        child: child,
      );

  Widget _tab(
    RaftPanelTab<T> tab,
    int index,
    RaftTabsRecipeStyle Function(bool, bool) style,
    RaftTabsRecipeStyle base,
    RaftRecipeTokens rt,
    RaftTokens t,
  ) {
    final grows = RaftScaled.grows(context);
    final active = tab.id == widget.value;
    final s = style(active, hovered == tab.id).tab;
    final svg = s.target('& svg:not([class*=\'size-\'])') ?? s.target('& svg');
    final iconSize = svg?.width ?? 14;
    // CSS resolves this dimension as `2.5px`; parsing its printed text as
    // a bare number used to fall back to 2 and thin every Brutal tab icon.
    final strokeValue = (s.target('& svg') ?? s)['stroke-width'];
    final stroke = strokeValue is CssNum ? strokeValue.value : 2.0;
    final fg = s.color?.resolve(rt) ?? (t.brutal ? Colors.black : t.strong);
    final iconColor = s.target('& svg')?.color?.resolve(rt) ?? fg;
    final label = raftCssText.merge(
      RaftTypography.body(
        t,
        size: 12,
        line: 16,
      ).merge(s.textStyle(rt).copyWith(color: fg)),
    );
    // `[&+&]:before:absolute before:inset-y-0 before:left-0 before:w-0.5
    // before:bg-line-strong` (brutal): a 2px divider inside every tab that
    // follows another tab.
    final divider = index > 0 && t.brutal;
    return RaftHoverRegion(
      key: keys.putIfAbsent(tab.id, GlobalKey.new),
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => hovered = tab.id),
      onExit: (_) => setState(() => hovered = null),
      child: Semantics(
        selected: active,
        button: true,
        label: tab.label,
        excludeSemantics: true,
        child: _largeContent(
          tab,
          child: GestureDetector(
            key: ValueKey(
              'panel-tab-${tab.id is Enum ? (tab.id as Enum).name : tab.id}',
            ),
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onChanged(tab.id),
            child: Container(
              // `h-7` on SortableTabsTab overrides the recipe height.
              height: grows ? null : 28,
              constraints: grows ? const BoxConstraints(minHeight: 28) : null,
              padding: EdgeInsets.only(
                left: s.padding.left,
                right: s.padding.right,
              ),
              color: s.backgroundColor?.resolve(rt),
              foregroundDecoration: BoxDecoration(
                border: divider
                    ? Border(
                        left: BorderSide(
                          color: t.colors['line-strong']!,
                          width: 2,
                        ),
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  tab.iconBuilder?.call(iconSize, iconColor, stroke) ??
                      RaftIcon(
                        tab.glyph!,
                        size: iconSize,
                        strokeWidth: stroke,
                        color: iconColor,
                      ),
                  SizedBox(width: s.columnGap ?? s.length('gap') ?? 6),
                  RaftCssText(
                    tab.label,
                    style: label,
                    maxLines: 1,
                    controlLabel: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `<Button size="icon-sm" variant="outline">` as the detail panels use it
/// for header/section icon actions (AgentProfileOverflowMenu trigger,
/// CopyableCodeAction, HumanDetailPanel message action). Resolved from the
/// generated `buttonVariants` recipe.
class RaftPanelIconButton extends StatelessWidget {
  const RaftPanelIconButton({
    super.key,
    this.glyph = RaftGlyph.x,
    this.icon,
    required this.tooltip,
    this.onPressed,
    this.iconSize = 14,
    this.anchorLink,
    this.anchorKey,
    this.focusNode,
    this.onKeyboardActivate,
  });
  final RaftGlyph glyph;

  /// Product artwork instead of [glyph], built with the icon size and the
  /// recipe colour (`DirectMessageIcon`).
  final Widget Function(double size, Color color)? icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double iconSize;

  /// Overlay anchor at the painted button, including recipe hover/press
  /// translation. CSS menus use the trigger's transformed border box.
  final LayerLink? anchorLink;
  final GlobalKey? anchorKey;
  final FocusNode? focusNode;
  final VoidCallback? onKeyboardActivate;
  @override
  Widget build(BuildContext context) {
    // Fixed chrome: at large text sizes a long press shows the icon and label
    // large (Large Content Viewer).
    return RaftChrome(
      child: RaftLargeContentViewer(
        label: tooltip,
        enabled: onPressed != null,
        onActivate: onPressed,
        iconBuilder: (context, size) => icon != null
            ? icon!(size, RaftTokens.of(context).strong)
            : RaftIcon(glyph, size: size),
        child: _button(context),
      ),
    );
  }

  Widget _button(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    return RaftInteractive(
      onPressed: onPressed,
      focusNode: focusNode,
      onKeyboardActivate: onKeyboardActivate,
      semanticLabel: tooltip,
      tooltip: tooltip,
      builder: (context, state) {
        final s = RaftButtonRecipe.resolve(
          theme: raftRecipeTheme(t),
          variant: RaftButtonRecipeVariant.outline,
          size: RaftButtonRecipeSize.iconSm,
          states: RaftRecipeStates({
            if (state.hovered) RaftRecipeStates.hover,
            if (state.pressed) RaftRecipeStates.active,
            if (state.focusVisible) RaftRecipeStates.focusVisible,
            if (onPressed == null) RaftRecipeStates.disabled,
            if (t.dark) RaftRecipeStates.dark,
          }),
          tokens: rt,
        ).root;
        Widget button = Container(
          width: s.width,
          height: s.height,
          alignment: Alignment.center,
          decoration: s.decoration(rt),
          child: icon != null
              ? icon!(iconSize, s.color?.resolve(rt) ?? t.strong)
              : RaftIcon(
                  glyph,
                  size: iconSize,
                  color: s.color?.resolve(rt) ?? t.strong,
                ),
        );
        if (anchorLink != null) {
          button = CompositedTransformTarget(
            key: anchorKey,
            link: anchorLink!,
            child: button,
          );
        }
        return Opacity(
          opacity: s.opacity ?? 1,
          child: Transform.translate(
            offset: s.translate ?? Offset.zero,
            child: button,
          ),
        );
      },
    );
  }
}

/// Distance from the top of a CSS line box to its baseline as Blink lays it
/// out: the font's ascent and descent are rounded to whole pixels and the
/// half-leading `(line-height - (ascent + descent)) / 2` is floored onto the
/// ascent. [style] must carry fontSize and height (line-height / size).
double raftCssBaseline(TextStyle style) =>
    _cssBaselineCache.putIfAbsent(style, () => _measureCssBaseline(style));

// Measured once per text style; message rows ask on every build/layout.
final _cssBaselineCache = raftTextMetricsCache<TextStyle, double>();

/// A text-metrics memo cleared whenever the engine's fonts change, so a
/// measurement taken before a font loaded is never reused afterwards.
Map<K, V> raftTextMetricsCache<K, V>() {
  final cache = <K, V>{};
  PaintingBinding.instance.systemFonts.addListener(cache.clear);
  return cache;
}

double _measureCssBaseline(TextStyle style) {
  final size = style.fontSize ?? 14;
  final lineHeight = (style.height ?? 1.2) * size;
  final probe = TextPainter(
    text: TextSpan(
      text: 'Hg',
      style: style.copyWith(height: kTextHeightNone),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final ascent = probe.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  final descent = probe.height - ascent;
  probe.dispose();
  final a = ascent.roundToDouble(), d = descent.roundToDouble();
  return a + ((lineHeight - (a + d)) / 2).floorToDouble();
}

/// An `inline-flex` box of [height] whose text (style [childText], centred
/// by `items-center`) is baseline-aligned in a line of [lineText]: the line
/// box grows below/above exactly as Blink's inline layout does.
class RaftCssInlineBox extends StatelessWidget {
  const RaftCssInlineBox({
    super.key,
    required this.lineText,
    required this.childText,
    required this.height,
    required this.child,
    this.minHeight = false,
  });
  final TextStyle lineText, childText;
  final double height;
  final Widget child;

  /// [height] is the child's minimum (CSS `min-height` / `height: auto`): a
  /// taller child (a larger text scale, a taller control line box) grows the
  /// box instead of being squeezed into it.
  final bool minHeight;
  @override
  Widget build(BuildContext context) {
    final lineHeight = (lineText.height ?? 1.2) * (lineText.fontSize ?? 14);
    final childLine = (childText.height ?? 1.2) * (childText.fontSize ?? 14);
    final childBaseline = (height - childLine) / 2 + raftCssBaseline(childText);
    final top = raftCssBaseline(lineText) - childBaseline;
    final shift = top < 0 ? -top : 0.0;
    final boxHeight = [
      lineHeight + shift,
      top + shift + height,
    ].reduce((a, b) => a > b ? a : b);
    final inner = Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: EdgeInsets.only(top: top + shift),
        child: minHeight
            ? ConstrainedBox(
                constraints: BoxConstraints(minHeight: height),
                child: child,
              )
            : SizedBox(height: height, child: child),
      ),
    );
    return minHeight
        ? ConstrainedBox(
            constraints: BoxConstraints(minHeight: boxHeight),
            child: inner,
          )
        : SizedBox(height: boxHeight, child: inner);
  }
}

/// Text laid out and painted like a Blink line box (measured with
/// tool/parity-baseline-probe.cjs on the parity Chromium):
///
/// * each line box is exactly `font-size * line-height` tall (Flutter rounds
///   a paragraph's line heights to whole pixels);
/// * the baseline sits at `round(ascent) + floor((lineHeight - (round(ascent)
///   + round(descent))) / 2)` inside the line box (font hhea metrics);
/// * the painted baseline is snapped to a whole CSS pixel of the page
///   (round half up), as Blink snaps the text paint origin.
///
/// Flutter draws the paragraph at its own (unrounded) baseline; this widget
/// shifts the paint by the difference. Layout of the surrounding boxes is
/// unchanged apart from the exact line-box height.
class RaftCssText extends StatelessWidget {
  const RaftCssText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
    this.strutStyle,
    this.controlLabel = false,
    this.underline = false,
    this.underlineColor,
  }) : span = null;

  const RaftCssText.rich(
    InlineSpan this.span, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
    this.strutStyle,
    this.controlLabel = false,
    this.underline = false,
    this.underlineColor,
  }) : data = null;

  final String? data;
  final InlineSpan? span;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;
  final StrutStyle? strutStyle;

  /// A single-line control label: on Android + Chinese it takes
  /// [RaftControlTypography], and its optical line box replaces the CSS
  /// baseline snap (which would undo the correction).
  final bool controlLabel;

  /// Paints the shared hyperlink underline ([RaftUnderlines]). With a plain
  /// string the whole label is underlined in [underlineColor] (default: the
  /// text colour); with [RaftCssText.rich] it only enables painting of the
  /// [RaftUnderlineSpan]s the caller put in [span].
  final bool underline;
  final Color? underlineColor;

  @override
  Widget build(BuildContext context) {
    var style = this.style;
    if (controlLabel && RaftControlTypography.appliesIn(context)) {
      style = RaftControlTypography.of(
        context,
        DefaultTextStyle.of(context).style.merge(style),
      );
    }
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final text = span == null
        ? (underline
              ? Text.rich(
                  RaftUnderlineSpan(text: data!, color: underlineColor),
                  style: style,
                  maxLines: maxLines,
                  overflow: overflow,
                  textAlign: textAlign,
                  softWrap: softWrap,
                  strutStyle: strutStyle,
                )
              : Text(
                  data!,
                  style: style,
                  maxLines: maxLines,
                  overflow: overflow,
                  textAlign: textAlign,
                  softWrap: softWrap,
                  strutStyle: strutStyle,
                ))
        : Text.rich(
            span!,
            style: style,
            maxLines: maxLines,
            overflow: overflow,
            textAlign: textAlign,
            softWrap: softWrap,
            strutStyle: strutStyle,
          );
    return RaftCssLineBox(
      style: effective,
      textScaler: MediaQuery.textScalerOf(context),
      // Inside the line box, so the stroke shares the baseline snap shift.
      child: underline ? RaftUnderlines(child: text) : text,
    );
  }
}

/// CSS line-box geometry and paint-baseline alignment for a text-bearing child.
///
/// This keeps the real editable child, including its selection, caret, input
/// connection and hit coordinates, while sharing [RaftCssText]'s baseline
/// calculation. The child must use [style]'s line height.
class RaftCssLineBox extends SingleChildRenderObjectWidget {
  const RaftCssLineBox({
    super.key,
    required this.style,
    required this.textScaler,
    required super.child,
  });
  final TextStyle style;
  final TextScaler textScaler;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCssLineBox(style, textScaler);
  @override
  void updateRenderObject(BuildContext context, _RenderCssLineBox r) {
    r
      ..style = style
      ..textScaler = textScaler;
  }
}

class _BlinkMetrics {
  const _BlinkMetrics(this.lineHeight, this.baseline);
  final double lineHeight, baseline;
  static final _cache =
      raftTextMetricsCache<(TextStyle, TextScaler), _BlinkMetrics>();
  static _BlinkMetrics of(TextStyle style, TextScaler scaler) =>
      _cache.putIfAbsent((style, scaler), () {
        final size = scaler.scale(style.fontSize ?? 14);
        final probe = TextPainter(
          text: TextSpan(
            text: 'Hg',
            style: style.copyWith(height: kTextHeightNone),
          ),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        final m = probe.computeLineMetrics().first;
        probe.dispose();
        final line = style.height == null
            ? m.ascent + m.descent
            : style.height! * size;
        final a = m.ascent.roundToDouble(), d = m.descent.roundToDouble();
        return _BlinkMetrics(line, a + ((line - (a + d)) / 2).floorToDouble());
      });
}

// A retained repaint boundary may paint before an offscreen route ancestor
// has completed layout. Its transform can depend on a size that is not ready.
double _laidOutGlobalTop(RenderBox box) {
  for (
    RenderObject? ancestor = box.parent;
    ancestor != null;
    ancestor = ancestor.parent
  ) {
    if (ancestor is RenderBox && !ancestor.hasSize) return double.nan;
  }
  return box.localToGlobal(Offset.zero).dy;
}

class _RenderCssLineBox extends RenderProxyBox {
  _RenderCssLineBox(this._style, this._textScaler);
  TextStyle _style;
  TextScaler _textScaler;
  double _flutterBaseline = 0;
  set style(TextStyle v) {
    if (v == _style) return;
    _style = v;
    markNeedsLayout();
  }

  set textScaler(TextScaler v) {
    if (v == _textScaler) return;
    _textScaler = v;
    markNeedsLayout();
  }

  _BlinkMetrics get _metrics => _BlinkMetrics.of(_style, _textScaler);

  /// A control label on the Android Chinese profile keeps Flutter's own
  /// proportional baseline: the Blink even-leading baseline (and its snap)
  /// would move the ink back to where the font draws it too high.
  bool get _optical => RaftControlTypography.isControlStyle(_style);

  int get _lines {
    final c = child;
    if (c == null || !c.hasSize) return 1;
    final m = _metrics;
    return (c.size.height / m.lineHeight).round().clamp(1, 1 << 20);
  }

  @override
  void performLayout() {
    final c = child!;
    c.layout(constraints.loosen().copyWith(minHeight: 0), parentUsesSize: true);
    size = constraints.constrain(
      Size(c.size.width, _lines * _metrics.lineHeight),
    );
    // SkParagraph reports the fractional even-leading baseline but draws the
    // glyphs at that baseline rounded to a whole logical pixel (measured: a
    // 12/20 Hanken line reports 14.182 and paints at 14, a 14/20 line reports
    // 14.879 and paints at 15). Align the painted baseline, not the reported
    // one, or every snapped line lands up to half a pixel off Chromium's.
    final reported = c.getDistanceToBaseline(TextBaseline.alphabetic) ?? 0;
    _flutterBaseline = (reported + 0.5).floorToDouble();
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _optical ? child?.getDistanceToBaseline(baseline) : _metrics.baseline;

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => _optical
      ? child?.getDryBaseline(constraints.loosen(), baseline)
      : _metrics.baseline;

  double get _shift {
    if (_optical) return 0;
    final flutter = _flutterBaseline;
    final top = _laidOutGlobalTop(this);
    // Kept-alive sliver children can paint their own repaint boundary while
    // their ancestor has no screen transform. Align locally until attached.
    if (!top.isFinite) return _metrics.baseline - flutter;
    final chrome = (top + _metrics.baseline + 0.5).floorToDouble();
    return chrome - (top + flutter);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    context.paintChild(child!, offset + Offset(0, _shift));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintOffset(
        offset: Offset(0, _shift),
        position: position,
        hitTest: (result, transformed) =>
            child?.hitTest(result, position: transformed) ?? false,
      );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(0, _shift, 0, 1);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final measured = child!.getDryLayout(
      constraints.loosen().copyWith(minHeight: 0),
    );
    final line = _metrics.lineHeight;
    final count = (measured.height / line).round().clamp(1, 1 << 20);
    return constraints.constrain(Size(measured.width, count * line));
  }
}

/// A horizontal CSS border retains its fractional layout position, while
/// Chromium snaps the border's paint edge to a whole CSS pixel. This is the
/// same distinction as [RaftCssText]'s line-box geometry versus paint origin.
/// The caller reserves [width] in its layout; this wrapper only paints it.
class RaftCssTopBorder extends SingleChildRenderObjectWidget {
  const RaftCssTopBorder({
    super.key,
    required this.color,
    this.width = 1,
    required super.child,
  });
  final Color color;
  final double width;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCssTopBorder(color, width);
  @override
  void updateRenderObject(BuildContext context, _RenderCssTopBorder object) {
    object
      ..color = color
      ..width = width;
  }
}

class _RenderCssTopBorder extends RenderProxyBox {
  _RenderCssTopBorder(this._color, this._width);
  Color _color;
  double _width;
  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  set width(double value) {
    if (_width == value) return;
    _width = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final top = _laidOutGlobalTop(this);
    final shift = top.isFinite ? (top + .5).floorToDouble() - top : 0.0;
    context.canvas.drawRect(
      Rect.fromLTWH(offset.dx, offset.dy + shift, size.width, _width),
      Paint()
        ..color = _color
        ..isAntiAlias = false,
    );
  }
}

/// A decorated box painted like Chromium's pixel-snapped border box: layout
/// keeps its fractional geometry (a `leading-relaxed` line is 19.5px) while
/// the background, border and shadow land on whole device pixels (each edge
/// rounds half up). Children are not moved.
class RaftSnappedDecoratedBox extends StatelessWidget {
  const RaftSnappedDecoratedBox({
    super.key,
    required this.decoration,
    this.padding = EdgeInsets.zero,
    this.child,
  });
  final BoxDecoration decoration;
  final EdgeInsetsGeometry padding;
  final Widget? child;
  @override
  Widget build(BuildContext context) => _SnappedDecoration(
    decoration: decoration,
    devicePixelRatio: View.of(context).devicePixelRatio,
    // Like Container: the border width is part of the content inset.
    child: Padding(padding: padding.add(decoration.padding), child: child),
  );
}

class _SnappedDecoration extends SingleChildRenderObjectWidget {
  const _SnappedDecoration({
    required this.decoration,
    required this.devicePixelRatio,
    super.child,
  });
  final BoxDecoration decoration;
  final double devicePixelRatio;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSnappedDecoration(decoration, devicePixelRatio);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSnappedDecoration object,
  ) {
    object
      ..decoration = decoration
      ..devicePixelRatio = devicePixelRatio;
  }
}

class _RenderSnappedDecoration extends RenderProxyBox {
  _RenderSnappedDecoration(this._decoration, this._dpr);
  BoxDecoration _decoration;
  double _dpr;
  BoxPainter? _painter;
  set decoration(BoxDecoration value) {
    if (_decoration == value) return;
    _decoration = value;
    _painter?.dispose();
    _painter = null;
    markNeedsPaint();
  }

  set devicePixelRatio(double value) {
    if (_dpr == value) return;
    _dpr = value;
    markNeedsPaint();
  }

  @override
  void detach() {
    _painter?.dispose();
    _painter = null;
    super.detach();
  }

  double _snap(double v) => (v * _dpr + .5).floorToDouble() / _dpr;

  @override
  void paint(PaintingContext context, Offset offset) {
    final global = localToGlobal(Offset.zero);
    final left = _snap(global.dx), top = _snap(global.dy);
    final right = _snap(global.dx + size.width);
    final bottom = _snap(global.dy + size.height);
    _painter ??= _decoration.createBoxPainter(markNeedsPaint);
    _painter!.paint(
      context.canvas,
      offset + Offset(left - global.dx, top - global.dy),
      ImageConfiguration(size: Size(right - left, bottom - top)),
    );
    super.paint(context, offset);
  }
}
