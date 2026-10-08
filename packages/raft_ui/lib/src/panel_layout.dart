// Panel chrome shared by the Web detail panels (AgentDetailPanel,
// HumanDetailPanel, MachineDetailPanel): the canonical PanelHeader row, its
// PanelAction buttons, the scrollable underline Tabs strip and the section
// typography (SectionEyebrow / SectionHeader / InfoRow).
//
// Geometry and colour come from the generated raft-ui recipes (panelHeader,
// panelAction, tabs) and, for classes written directly in Web JSX, from the
// Tailwind classes cited next to each value (packages/web/src paths).
import 'package:flutter/material.dart';

import 'design_primitives.dart' hide RaftPanelHeaderRecipe;
import 'icons.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/panel_action.g.dart';
import 'recipes/panel_header.g.dart';
import 'recipes/tabs.g.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';

RaftRecipeTheme raftRecipeTheme(RaftTokens t) =>
    t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant;

/// CSS line boxes put half the leading above and half below the glyphs.
TextStyle raftCssText(TextStyle style) =>
    style.copyWith(leadingDistribution: TextLeadingDistribution.even);

/// `theme-brutal:text-black/<n>` overrides used across the Web panels; other
/// themes keep the semantic token.
Color raftPanelInk(RaftTokens t, double brutalAlpha, Color elegant) =>
    t.brutal ? Colors.black.withValues(alpha: brutalAlpha) : elegant;

/// SectionEyebrow.tsx: `text-xs font-bold uppercase text-foreground-muted
/// tracking-widest`.
class RaftSectionEyebrow extends StatelessWidget {
  const RaftSectionEyebrow(this.label, {super.key, this.trailing});
  final String label;

  /// Inline `<span class="ml-2 font-mono text-foreground-placeholder
  /// theme-brutal:text-black/40">` (SectionHeader count).
  final String? trailing;

  static TextStyle style(RaftTokens t) => raftCssText(
    RaftTypography.body(
      t,
      size: 12,
      line: 16,
      weight: FontWeight.w700,
      color: t.colors['foreground-muted'],
    ).copyWith(letterSpacing: 12 * .1),
  );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Text.rich(
      TextSpan(
        text: label.toUpperCase(),
        children: [
          if (trailing != null) ...[
            const WidgetSpan(child: SizedBox(width: 8)),
            TextSpan(
              text: trailing,
              style: raftCssText(
                RaftTypography.mono(
                  t,
                  size: 12,
                  line: 16,
                  color: raftPanelInk(
                    t,
                    .4,
                    t.colors['foreground-placeholder']!,
                  ),
                ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
              ),
            ),
          ],
        ],
      ),
      style: style(t),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// SectionHeader.tsx: `flex items-center justify-between gap-2`, optional
/// leading icon, eyebrow + count and a trailing action.
class RaftSectionHeader extends StatelessWidget {
  const RaftSectionHeader({
    super.key,
    required this.label,
    this.count,
    this.action,
    this.icon,
  });
  final String label;
  final int? count;
  final Widget? action;
  final Widget? icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Row(
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 8)],
            Flexible(
              child: RaftSectionEyebrow(
                label,
                trailing: count != null && count! >= 0 ? '$count' : null,
              ),
            ),
          ],
        ),
      ),
      if (action != null) ...[const SizedBox(width: 8), action!],
    ],
  );
}

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

  static TextStyle valueStyle(RaftTokens t) => raftCssText(
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
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: raftCssText(
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
    return Semantics(
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
    );
  }
}

/// raft-ui PanelAction (panelAction recipe): bordered square icon action of
/// the panel header (`& > svg` 14px in brutal).
class RaftPanelAction extends StatefulWidget {
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
  State<RaftPanelAction> createState() => _RaftPanelActionState();
}

class _RaftPanelActionState extends State<RaftPanelAction> {
  bool hovered = false, pressed = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final s = RaftPanelActionRecipe.resolve(
      theme: raftRecipeTheme(t),
      states: RaftRecipeStates({
        if (hovered) RaftRecipeStates.hover,
        if (pressed) RaftRecipeStates.active,
        if (widget.onPressed == null) RaftRecipeStates.disabled,
        if (t.dark) RaftRecipeStates.dark,
      }),
      tokens: rt,
    ).base;
    final svg = s.target('& > svg');
    final iconSize = svg?.width ?? 14;
    final color = s.color?.resolve(rt) ?? t.strong;
    final translate = s.translate ?? Offset.zero;
    return Semantics(
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
              offset: translate,
              child: Container(
                padding: s.padding,
                decoration: s.decoration(rt),
                child: RaftIcon(widget.glyph, size: iconSize, color: color),
              ),
            ),
          ),
        ),
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
    TextStyle text(RaftSlotStyle slot) => raftCssText(
      base.merge(slot.textStyle(rt)).copyWith(
        fontFamily: slot.fontFamily == null ? t.bodyFont : null,
      ),
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
            SizedBox.square(dimension: s.headerIcon.width ?? 36, child: iconSlot),
            SizedBox(width: gap),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text(s.title),
                ),
                if (subtitle != null)
                  Text(
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
              if (i > 0) SizedBox(width: s.actions.columnGap ?? s.actions.length('gap') ?? 6),
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
    RaftTabsRecipeStyle style(bool active, bool hover) => RaftTabsRecipe.resolve(
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
    final label = raftCssText(
      RaftTypography.body(t, size: 12, line: 16).merge(
        s.textStyle(rt).copyWith(color: fg),
      ),
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
            padding: EdgeInsets.only(left: s.padding.left, right: s.padding.right),
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
                Text(tab.label, style: label, maxLines: 1),
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
    return Semantics(
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
    text: TextSpan(text: 'Hg', style: style.copyWith(height: null)),
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
class RaftInlineBox extends StatelessWidget {
  const RaftInlineBox({
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
      height: [lineHeight + shift, top + shift + height].reduce(
        (a, b) => a > b ? a : b,
      ),
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
