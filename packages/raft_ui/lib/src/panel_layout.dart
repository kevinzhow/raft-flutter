// Panel chrome shared by the Web detail panels (AgentDetailPanel,
// HumanDetailPanel, MachineDetailPanel): the canonical PanelHeader row, its
// PanelAction buttons, the scrollable underline Tabs strip and the section
// typography (SectionEyebrow / SectionHeader / InfoRow).
//
// Geometry and colour come from the generated raft-ui recipes (panelHeader,
// panelAction, tabs) and, for classes written directly in Web JSX, from the
// Tailwind classes cited next to each value (packages/web/src paths).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'design_primitives.dart' hide RaftPanelHeaderRecipe;
import 'icons.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/panel_action.g.dart';
import 'recipes/panel_header.g.dart';
import 'recipes/tabs.g.dart';
import 'recipes/token_binding.dart';
import 'recipe_surface.dart' show raftCssText;
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
    RaftTypography.body(
      t,
      size: 14,
      line: 20,
      color: t.brutal ? Colors.black : t.strong,
    ),
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
                      RaftTypography.body(
                        t,
                        size: 12,
                        line: 16,
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
        child: MouseRegion(
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
  });
  final RaftGlyph glyph;
  final String tooltip;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => RaftInteractive(
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

/// raft-ui PanelHeader as composed by Web `components/ui/PanelHeader.tsx`
/// (AppPanelHeader): back action, identity icon slot, title (+ suffix) and
/// subtitle, right-aligned actions.
class RaftPanelHeaderBar extends StatelessWidget {
  const RaftPanelHeaderBar({
    super.key,
    required this.title,
    this.subtitle,
    this.iconSlot,
    this.onBack,
    this.backTooltip = 'Back',
    this.actions = const [],
  });
  final String title;
  final String? subtitle;

  /// Pre-wrapped identity (AvatarSlot context="panel-header"), rendered in
  /// the PanelHeaderIcon cell.
  final Widget? iconSlot;
  final VoidCallback? onBack;
  final String backTooltip;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final width = MediaQuery.sizeOf(context).width;
    final s = RaftPanelHeaderRecipe.resolve(
      theme: raftRecipeTheme(t),
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}, width),
      tokens: rt,
    );
    final base = RaftTypography.body(t, size: 16, line: 20);
    TextStyle text(RaftSlotStyle slot) => raftCssText.merge(
      base
          .merge(slot.textStyle(rt))
          .copyWith(fontFamily: slot.fontFamily == null ? t.bodyFont : null),
    );
    final gap = s.header.columnGap ?? s.header.length('gap') ?? 12;
    return Container(
      height: s.header.height,
      constraints: BoxConstraints(minHeight: s.header.minHeight ?? 0),
      padding: s.header.padding,
      decoration: s.header.decoration(rt),
      child: Row(
        children: [
          if (onBack != null) ...[
            RaftPanelAction(
              glyph: RaftGlyph.arrowLeft,
              tooltip: backTooltip,
              onPressed: onBack,
            ),
            SizedBox(width: gap),
          ],
          if (iconSlot != null) ...[
            SizedBox.square(
              dimension: s.headerIcon.width ?? 36,
              child: iconSlot,
            ),
            SizedBox(width: gap),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RaftCssText(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text(s.title),
                ),
                if (subtitle != null)
                  RaftCssText(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text(s.meta),
                  ),
              ],
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
  }
}

class RaftPanelTab<T> {
  const RaftPanelTab(this.id, this.label, this.glyph);
  final T id;
  final String label;
  final RaftGlyph glyph;
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
    WidgetsBinding.instance.addPostFrameCallback((_) => center());
  }

  @override
  void didUpdateWidget(RaftPanelTabBar<T> old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
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

  @override
  Widget build(BuildContext context) {
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
      child: SingleChildScrollView(
        controller: scroll,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < widget.tabs.length; i++)
              _tab(widget.tabs[i], i, style, base, rt, t),
          ],
        ),
      ),
    );
  }

  Widget _tab(
    RaftPanelTab<T> tab,
    int index,
    RaftTabsRecipeStyle Function(bool, bool) style,
    RaftTabsRecipeStyle base,
    RaftRecipeTokens rt,
    RaftTokens t,
  ) {
    final active = tab.id == widget.value;
    final s = style(active, hovered == tab.id).tab;
    final svg = s.target('& svg:not([class*=\'size-\'])') ?? s.target('& svg');
    final iconSize = svg?.width ?? 14;
    final stroke =
        double.tryParse('${(s.target('& svg') ?? s)['stroke-width'] ?? ''}') ??
        2;
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
    return MouseRegion(
      key: keys.putIfAbsent(tab.id, GlobalKey.new),
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => hovered = tab.id),
      onExit: (_) => setState(() => hovered = null),
      child: Semantics(
        selected: active,
        button: true,
        label: tab.label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onChanged(tab.id),
          child: Container(
            // `h-7` on SortableTabsTab overrides the recipe height.
            height: 28,
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
                RaftIcon(
                  tab.glyph,
                  size: iconSize,
                  strokeWidth: stroke,
                  color: iconColor,
                ),
                SizedBox(width: s.columnGap ?? s.length('gap') ?? 6),
                RaftCssText(tab.label, style: label, maxLines: 1),
              ],
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
class RaftPanelIconButton extends StatefulWidget {
  const RaftPanelIconButton({
    super.key,
    required this.glyph,
    required this.tooltip,
    this.onPressed,
    this.iconSize = 14,
  });
  final RaftGlyph glyph;
  final String tooltip;
  final VoidCallback? onPressed;
  final double iconSize;
  @override
  State<RaftPanelIconButton> createState() => _RaftPanelIconButtonState();
}

class _RaftPanelIconButtonState extends State<RaftPanelIconButton> {
  bool hovered = false, pressed = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final s = RaftButtonRecipe.resolve(
      theme: raftRecipeTheme(t),
      variant: RaftButtonRecipeVariant.outline,
      size: RaftButtonRecipeSize.iconSm,
      states: RaftRecipeStates({
        if (hovered) RaftRecipeStates.hover,
        if (pressed) RaftRecipeStates.active,
        if (widget.onPressed == null) RaftRecipeStates.disabled,
        if (t.dark) RaftRecipeStates.dark,
      }),
      tokens: rt,
    ).root;
    final color = s.color?.resolve(rt) ?? t.strong;
    return RaftTooltip(
      message: widget.tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = false),
          child: GestureDetector(
            onTapDown: (_) => setState(() => pressed = true),
            onTapUp: (_) => setState(() => pressed = false),
            onTapCancel: () => setState(() => pressed = false),
            onTap: widget.onPressed,
            child: Opacity(
              opacity: s.opacity ?? 1,
              child: Transform.translate(
                offset: s.translate ?? Offset.zero,
                child: Container(
                  width: s.width,
                  height: s.height,
                  alignment: Alignment.center,
                  decoration: s.decoration(rt),
                  child: RaftIcon(
                    widget.glyph,
                    size: widget.iconSize,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Distance from the top of a CSS line box to its baseline as Blink lays it
/// out: the font's ascent and descent are rounded to whole pixels and the
/// half-leading `(line-height - (ascent + descent)) / 2` is floored onto the
/// ascent. [style] must carry fontSize and height (line-height / size).
double raftCssBaseline(TextStyle style) {
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
  });
  final TextStyle lineText, childText;
  final double height;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final lineHeight = (lineText.height ?? 1.2) * (lineText.fontSize ?? 14);
    final childLine = (childText.height ?? 1.2) * (childText.fontSize ?? 14);
    final childBaseline = (height - childLine) / 2 + raftCssBaseline(childText);
    final top = raftCssBaseline(lineText) - childBaseline;
    final shift = top < 0 ? -top : 0.0;
    return SizedBox(
      height: [
        lineHeight + shift,
        top + shift + height,
      ].reduce((a, b) => a > b ? a : b),
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.only(top: top + shift),
          child: SizedBox(height: height, child: child),
        ),
      ),
    );
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
  }) : span = null;

  const RaftCssText.rich(
    InlineSpan this.span, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
  }) : data = null;

  final String? data;
  final InlineSpan? span;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final text = span == null
        ? Text(
            data!,
            style: style,
            maxLines: maxLines,
            overflow: overflow,
            textAlign: textAlign,
            softWrap: softWrap,
          )
        : Text.rich(
            span!,
            style: style,
            maxLines: maxLines,
            overflow: overflow,
            textAlign: textAlign,
            softWrap: softWrap,
          );
    return _CssLineBox(
      style: effective,
      textScaler: MediaQuery.textScalerOf(context),
      child: text,
    );
  }
}

class _CssLineBox extends SingleChildRenderObjectWidget {
  const _CssLineBox({
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
  static final _cache = <(TextStyle, TextScaler), _BlinkMetrics>{};
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
    _flutterBaseline = c.getDistanceToBaseline(TextBaseline.alphabetic) ?? 0;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _metrics.baseline;

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => _metrics.baseline;

  double get _shift {
    final flutter = _flutterBaseline;
    final top = localToGlobal(Offset.zero).dy;
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
    final top = localToGlobal(Offset.zero).dy;
    final snapped = (top + .5).floorToDouble();
    context.canvas.drawRect(
      Rect.fromLTWH(offset.dx, offset.dy + snapped - top, size.width, _width),
      Paint()
        ..color = _color
        ..isAntiAlias = false,
    );
  }
}
