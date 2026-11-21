// Panel chrome shared by the Web detail panels (AgentDetailPanel,
// HumanDetailPanel, MachineDetailPanel): the canonical PanelHeader row, its
// PanelAction buttons, the scrollable underline Tabs strip and the section
// typography (SectionEyebrow / SectionHeader / InfoRow).
//
// Geometry and colour come from the generated raft-ui recipes (panelHeader,
// panelAction, tabs) and, for classes written directly in Web JSX, from the
// Tailwind classes cited next to each value (packages/web/src paths).
import 'interaction.dart';
import 'hover_region.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter/rendering.dart';

import 'agent_info_list.dart' show RaftInfoRowBody;
import 'tokens/tokens.dart' show RaftDesktopMetrics, RaftTypeScale;
import 'raft_underline.dart';
import 'control_typography.dart';
import 'design_primitives.dart' hide RaftPanelHeaderRecipe;
import 'icons.dart';
import 'inline_badge_editor.dart' show RaftTouchTargetExpander;
import 'recipes/recipe_runtime.dart';
import 'recipes/panel_action.g.dart';
import 'recipes/panel_header.g.dart';
import 'raft/tabs.dart';
import 'raft/blink_snap.dart';
import 'raft/button.dart';
import 'raft/css_box.dart' show raftSnapBorder;
import 'raft/ui_tokens.dart';
import 'recipes/token_binding.dart';
import 'recipe_surface.dart'
    show RaftRecipeBinding, RaftRecipeBox, RaftSlotPaint, raftCssText;
import 'status_bar.dart';
import 'text_scaling.dart' show RaftChrome, RaftScaled;
import 'large_content_viewer.dart';
import 'theme.dart';
import 'tooltip.dart';

/// The panel ink: the semantic token (the Web `theme-brutal:text-black/<n>`
/// overrides do not apply).
Color raftPanelInk(RaftTokens t, double brutalAlpha, Color elegant) => elegant;

/// raft-ui `PanelTitle` as the profile detail block uses it (Web v1.21.12
/// `<PanelTitle className="min-w-0 text-foreground-muted
/// theme-brutal:text-black theme-brutal:text-lg">`): the panel-header recipe's
/// `title` slot with the muted ink.
TextStyle raftPanelTitleStyle(RaftTokens t) {
  final rt = RaftRecipeTokens(t);
  final slot = RaftPanelHeaderRecipe.resolve(
    states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}, 390),
    tokens: rt,
  ).title;
  final base = RaftTypography.body(t, size: 16, line: 20);
  final style = raftCssText.merge(
    base
        .merge(slot.textStyle(rt))
        .copyWith(fontFamily: slot.fontFamily == null ? t.bodyFont : null),
  );
  return style.copyWith(color: t.colors['foreground-muted']);
}

/// AgentDetailPanel.tsx InfoRow (Web v1.21.12): `grid
/// grid-cols-[7.75rem_minmax(0,1fr)] items-start gap-x-4`; the term is `flex
/// min-h-5 items-center gap-1.5 text-[13px] text-foreground-hint`, the value
/// `text-sm text-foreground-muted`.
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
    ).copyWith(color: t.colors['foreground-muted']),
  );

  /// The term: `text-[13px] text-foreground-hint`.
  /// `text-[13px]` sets no line height, so the body's 1.5 ratio is inherited.
  static TextStyle labelStyle(RaftTokens t) => raftCssText.merge(
    RaftTypography.body(
      t,
      size: 13,
      line: 19.5,
      color: raftPanelInk(t, .5, t.colors['foreground-hint']!),
    ),
  );

  /// The term: the DescriptionList term (footnote, medium, hint).
  static TextStyle termStyleOf(BuildContext context) {
    final t = RaftTokens.of(context);
    return raftCssText.merge(
      t.scale(
        RaftTypeScale.footnote,
        weight: FontWeight.w500,
        color: t.ui.foregroundHint,
      ),
    );
  }

  /// The details: the DescriptionList details (callout, regular, foreground).
  static TextStyle detailsStyleOf(BuildContext context) {
    final t = RaftTokens.of(context);
    return raftCssText.merge(
      t.scale(
        RaftTypeScale.callout,
        weight: FontWeight.w400,
        color: t.ui.foreground,
      ),
    );
  }

  /// [detailsStyleOf] in the mono face (`font-mono`).
  static TextStyle monoStyleOf(BuildContext context) =>
      detailsStyleOf(context)
          .copyWith(fontFamily: RaftTokens.of(context).monoFont);

  /// [detailsStyleOf] in `text-foreground-muted`.
  static TextStyle mutedStyleOf(BuildContext context) {
    final t = RaftTokens.of(context);
    return detailsStyleOf(context).copyWith(color: t.ui.foregroundMuted);
  }

  /// [detailsStyleOf] in `text-foreground-hint`.
  static TextStyle hintStyleOf(BuildContext context) {
    final t = RaftTokens.of(context);
    return detailsStyleOf(context).copyWith(color: t.ui.foregroundHint);
  }

  @override
  Widget build(BuildContext context) {
    return RaftInfoRowBody(row: this);
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
    this.color,
  });
  final RaftGlyph glyph;
  final String tooltip;
  final double size;
  final VoidCallback? onPressed;

  /// Resting colour (hover keeps the strong ink); null is the placeholder ink.
  final Color? color;
  @override
  State<RaftInlineIconButton> createState() => _RaftInlineIconButtonState();
}

class _RaftInlineIconButtonState extends State<RaftInlineIconButton> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final color = hovered
        ? (t.strong)
        : widget.color ??
              raftPanelInk(t, .4, t.colors['foreground-placeholder']!);
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
    this.ghostSize,
    this.desktopBar = false,
    this.focusNode,
  });
  final RaftGlyph glyph;
  final String tooltip;
  final VoidCallback? onPressed;
  final RaftButtonSize? ghostSize;
  final bool desktopBar;
  final FocusNode? focusNode;

  /// Minimum touch target for touch input. Web's boxed action is
  /// 24x28 (Brutal) / 32x32 (Elegant); the visual and layout stay as Web
  /// draws them and the hit area is extended around it.
  final double minHitExtent;
  @override
  Widget build(BuildContext context) {
    final ghost =
        RaftTokens.of(context).option('panelAction.surface', or: 'outline') ==
        'ghost';
    final control = ghost
        ? (desktopBar || ghostSize != null
              ? RaftButton(
                  label: '',
                  glyph: glyph,
                  tooltip: tooltip,
                  semanticLabel: tooltip,
                  uiVariant: RaftButtonVariant.ghost,
                  uiSize:
                      ghostSize ??
                      (MediaQuery.sizeOf(context).width <
                              RaftLayoutMetrics.desktopBreakpoint
                          ? RaftButtonSize.iconLg
                          : RaftButtonSize.iconMd),
                  physicalHeight: desktopBar
                      ? RaftDesktopMetrics.barButtonSize
                      : null,
                  visualWidth: desktopBar
                      ? RaftDesktopMetrics.barButtonSize
                      : null,
                  glyphSize: desktopBar
                      ? RaftDesktopMetrics.controlIconSize
                      : null,
                  focusNode: focusNode,
                  onPressed: onPressed,
                )
              : _currentAction())
        : _interactive(context);
    return RaftTouchTargetExpander(
      minSize: Size.square(
        minHitExtent > 0 && RaftInteraction.of(context).touch
            ? minHitExtent
            : 0,
      ),
      child: desktopBar ? RaftBlinkSnap(child: control) : control,
    );
  }

  Widget _currentAction() => RaftInteractive(
    onPressed: onPressed,
    focusNode: focusNode,
    semanticLabel: tooltip,
    tooltip: tooltip,
    builder: (context, state) {
      final tokens = RaftTokens.of(context);
      final recipe = RaftPanelActionRecipe.resolve(
        tokens: tokens.recipeTokens,
        states: tokens.recipeStates(
          responsive: true,
          hovered: state.hovered,
          pressed: state.pressed,
          focusVisible: state.focusVisible,
          disabled: !state.enabled,
        ),
      ).base;
      final icon = recipe.target('& > svg');
      return RaftRecipeBox(
        style: recipe,
        tokens: tokens.recipeTokens,
        width: recipe.minWidth,
        alignment: Alignment.center,
        decorationOverride: (decoration) => raftSnapBorder(context, decoration),
        child: RaftIcon(
          glyph,
          size: icon?.width ?? RaftDesktopMetrics.controlIconSize,
          color:
              icon?.foreground(tokens.recipeTokens) ??
              recipe.foreground(tokens.recipeTokens),
        ),
      );
    },
  );

  Widget _interactive(BuildContext context) => RaftInteractive(
    onPressed: onPressed,
    focusNode: focusNode,
    semanticLabel: tooltip,
    tooltip: tooltip,
    builder: (context, state) {
      final t = RaftTokens.of(context),
          rt = RaftRecipeTokens(RaftTokens.of(context));
      final s = RaftPanelActionRecipe.resolve(
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

/// Every corner rounded by [radius].
BorderRadius raftRoundedBorder(double radius) => BorderRadius.circular(radius);

// Source global index.css focus-visible outline: 2px, offset 2px.
// Pointer focus keeps the generated resting surface and geometry unchanged.
class RaftCssFocusOutline extends CustomPainter {
  const RaftCssFocusOutline({
    required this.enabled,
    required this.color,
    this.radius = BorderRadius.zero,
    this.width = 2,
    this.offset = 2,
  });

  /// The same ring with every corner [radius] (a circle: half the side, or
  /// any larger value).
  RaftCssFocusOutline.rounded({
    required this.enabled,
    required this.color,
    required double radius,
    this.width = 2,
    this.offset = 2,
  }) : radius = raftRoundedBorder(radius);
  final bool enabled;
  final Color color;
  final BorderRadius radius;
  final double width, offset;
  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled) return;
    canvas.drawRRect(
      radius.toRRect(Offset.zero & size).inflate(offset + width / 2),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(RaftCssFocusOutline old) =>
      old.enabled != enabled ||
      old.color != color ||
      old.radius != radius ||
      old.width != width ||
      old.offset != offset;
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
    this.inline = false,
  });

  /// `flex-row items-baseline gap-2` on the content (a page head that names
  /// the page with its number beside it: Web TasksPage), whatever the recipe.
  final bool inline;
  final RaftSlotStyle style;
  final Widget heading;
  final Widget? meta;

  @override
  Widget build(BuildContext context) {
    final horizontal =
        inline ||
        switch (style['flex-direction']) {
          CssKeyword(value: 'row') => true,
          _ => false,
        };
    final gap = inline
        ? 8.0
        : (horizontal ? style.columnGap : style.rowGap) ??
              style.length('gap') ??
              0;
    final baseline =
        horizontal &&
        meta != null &&
        (inline ||
            switch (style['align-items']) {
              CssKeyword(value: 'baseline') => true,
              _ => false,
            });
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
/// Web panelHeadEdges plus PanelActions' overhang, shared by every native head.
EdgeInsets raftPanelHeaderEdges(
  BuildContext context, {
  bool hasBack = false,
  bool hasActions = false,
  double? leftPadding,
  double? columnMargin,
}) {
  if (columnMargin != null) {
    final t = RaftTokens.of(context);
    final action = RaftPanelActionRecipe.resolve(
      tokens: t.recipeTokens,
      states: t.recipeStates(responsive: true),
    ).base;
    final iconInset =
        ((action.minWidth ?? 0) - (action.target('& > svg')?.width ?? 0)) / 2;
    return EdgeInsets.fromLTRB(
      leftPadding ?? columnMargin - (hasBack ? iconInset : 0),
      0,
      columnMargin - (hasActions ? iconInset : 0),
      0,
    );
  }
  final narrow =
      MediaQuery.sizeOf(context).width < RaftLayoutMetrics.desktopBreakpoint;
  const desktopActionInset =
      RaftLayoutMetrics.panelInset -
      (RaftDesktopMetrics.barButtonSize - RaftDesktopMetrics.controlIconSize) /
          2;
  final trailingInset = narrow
      ? (hasActions ? 3.0 : 6.0)
      : (hasActions ? desktopActionInset : 13.0);
  return EdgeInsets.fromLTRB(
    // ignore: raft_lints/off_grid_spacing -- Web mobile pl-4 plus leading -ml-[13px].
    narrow && hasBack ? 3 : leftPadding ?? (narrow ? 16 : 20),
    0,
    trailingInset,
    0,
  );
}

class RaftPanelHeaderBar extends StatelessWidget {
  const RaftPanelHeaderBar({
    super.key,
    required this.title,
    this.subtitle,
    this.titleSlot,
    this.metaSlot,
    this.iconSlot,
    this.onBack,
    this.backKey,
    this.backTooltip = 'Back',
    this.actions = const [],
    this.iconAlwaysVisible = false,
    this.profileBody = false,
    this.leftPadding,
    this.columnMargin,
    this.bottomRule = false,
    this.bottomBorder,
    this.titleSuffix,
    this.profileHandle = false,
    this.background,
    this.leading,
    this.inlineMeta = false,
    this.desktopBar = false,
  });

  /// Use the v1.24 fine-pointer column margin and bar-button overhang.
  final bool desktopBar;

  /// A control before the title, after Back (a side card's fold chevron).
  final Widget? leading;

  /// The subtitle beside the title on one baseline, in the mono meta hint ink
  /// (Web `PanelHeaderContent className="flex-row items-baseline gap-2"` with
  /// `text-mono-meta text-foreground-hint`: the server Tasks page's head).
  final bool inlineMeta;

  /// The page surface under this header; null keeps the recipe fill.
  final Color? background;
  final String title;
  final String? subtitle;

  /// Web `subtitleClassName={PROFILE_HANDLE_SIZE_CLASS}` (agent / human
  /// profile headers): the `@handle` subtitle reads at 15px mono in elegant;
  /// brutal keeps its own (already mono) meta.
  final bool profileHandle;

  /// AppPanelHeader `titleSuffix`: a node inline after the title (outside the
  /// truncating title), e.g. `Badge.Experimental`.
  final Widget? titleSuffix;

  /// AppPanelHeader `titleSlot`: replaces the title/meta stack (the search
  /// field of MessageSearchPage).
  final Widget? titleSlot;

  /// Content for a header whose metadata includes controls.
  final Widget? metaSlot;

  /// Overrides the recipe's left inset (ActivityInboxPanel's `pl-3`).
  final double? leftPadding;

  /// Content inset of the host column. Frameless edge actions overhang this
  /// margin by the PanelAction recipe's icon inset.
  final double? columnMargin;

  /// A 1px `border-line-muted` rule under the header (the Activity header's
  /// `border-b`; the canonical desktop header has none).
  final bool bottomRule;
  final Border? bottomBorder;

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

  Widget _ghostHeader(BuildContext context, RaftTokens t) {
    final narrow =
        MediaQuery.sizeOf(context).width < RaftLayoutMetrics.desktopBreakpoint;
    final grows = RaftScaled.grows(context);
    final inline = !grows && (inlineMeta || !narrow);
    final height = RaftLayoutMetrics.shellHeaderHeight(
      t,
      MediaQuery.sizeOf(context).height,
    );
    final gap = narrow ? 8.0 : 12.0;
    final titleStyle = t.scale(t.typeSlot('headline'));
    final metaStyle = inlineMeta || profileHandle
        ? t.scale(
            t.typeSlot('mono-meta'),
            mono: true,
            color: t.ui.foregroundHint,
          )
        : t.scale(
            t.typeSlot('caption'),
            weight: FontWeight.w500,
            color: t.ui.foregroundHint,
          );
    final heading = Row(
      mainAxisSize: inline ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Flexible(
          child: Semantics(
            header: true,
            child: RaftCssText(
              title,
              style: titleStyle,
              maxLines: grows ? null : 1,
              overflow: grows ? TextOverflow.visible : TextOverflow.ellipsis,
              softWrap: grows,
            ),
          ),
        ),
        if (titleSuffix != null) ...[const SizedBox(width: 8), titleSuffix!],
      ],
    );
    final fill = background ?? t.colors['layer-panel-header']!;
    const contentInset = RaftDesktopMetrics.pageInset;
    const actionInset =
        (RaftDesktopMetrics.barButtonSize -
            RaftDesktopMetrics.controlIconSize) /
        2;
    final edges = desktopBar
        ? EdgeInsets.only(
            left: leading == null ? contentInset : contentInset - actionInset,
            right: actions.isEmpty ? contentInset : contentInset - actionInset,
          )
        : raftPanelHeaderEdges(
            context,
            hasBack: onBack != null,
            hasActions: actions.isNotEmpty,
            leftPadding: leftPadding,
            columnMargin: columnMargin,
          );
    return RaftStatusBarSource(
      color: fill,
      child: Container(
        height: grows ? null : height,
        constraints: BoxConstraints(minHeight: height),
        padding: edges.copyWith(top: grows ? 8 : 0, bottom: grows ? 8 : 0),
        decoration: BoxDecoration(
          color: fill,
          border:
              bottomBorder ?? Border(bottom: BorderSide(color: t.ui.lineSeam)),
        ),
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
            if (leading != null) ...[leading!, SizedBox(width: gap)],
            if (iconSlot != null && (!narrow || iconAlwaysVisible)) ...[
              // PanelHeaderIcon[icon-kind=avatar] retains a transparent used 1px edge.
              Padding(
                padding: iconAlwaysVisible
                    // ignore: raft_lints/off_grid_spacing -- Actual Web AvatarSlot header outer 37 encloses a 35px avatar with its transparent used edge.
                    ? const EdgeInsets.all(1)
                    : EdgeInsets.zero,
                child: iconSlot!,
              ),
              SizedBox(width: gap),
            ],
            Expanded(
              child:
                  titleSlot ??
                  (inline && subtitle != null
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          spacing: 8,
                          children: [
                            Flexible(child: heading),
                            Flexible(
                              child: RaftCssText(
                                subtitle!,
                                style: metaStyle,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : null) ??
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heading,
                      if (metaSlot != null)
                        metaSlot!
                      else if (subtitle != null)
                        RaftCssText(
                          subtitle!,
                          style: metaStyle,
                          maxLines: grows ? null : 1,
                          overflow: grows
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          softWrap: grows,
                        ),
                    ],
                  ),
            ),
            if (actions.isNotEmpty) ...[
              SizedBox(width: gap),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: narrow ? 2 : 4,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (t.option('panelAction.surface', or: 'outline') == 'ghost')
      return _ghostHeader(context, t);
    final rt = RaftRecipeTokens(t);
    final width = MediaQuery.sizeOf(context).width;
    final s = RaftPanelHeaderRecipe.resolve(
      states: RaftRecipeStates({
        if (t.dark) RaftRecipeStates.dark,
        if (subtitle != null || metaSlot != null) 'has:>data-slot=panel-meta',
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
    final barPadding = columnMargin == null
        ? s.header.padding.copyWith(left: leftPadding)
        : raftPanelHeaderEdges(
            context,
            hasBack: onBack != null,
            hasActions: actions.isNotEmpty,
            leftPadding: leftPadding,
            columnMargin: columnMargin,
          );
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
      decoration: bottomRule || bottomBorder != null
          ? s.header
                .decoration(rt)
                .copyWith(
                  color: background,
                  border:
                      bottomBorder ??
                      Border(
                        // Brutal `border-b-2 border-black` (pure black, not ink).
                        bottom: BorderSide(
                          color: t.colors['line-muted']!,
                          width: 1,
                        ),
                      ),
                )
          : (profileBody)
          // Web v1.21.12 PROFILE_HEADER_SURFACE_CLASS (elegant only):
          // `border-b border-line-muted` on the header; the 1px is inside the
          // header's height. Brutal keeps the recipe's own 2px rule.
          ? s.header
                .decoration(rt)
                .copyWith(
                  color: background,
                  border: Border(
                    bottom: BorderSide(color: t.colors['line-muted']!),
                  ),
                )
          : s.header.decoration(rt).copyWith(color: background),
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
          if (leading != null) ...[leading!, SizedBox(width: gap)],
          // PanelHeaderIcon is `hidden md:flex` unless the surface is an
          // identity panel (`iconAlwaysVisible`).
          if (iconSlot != null && (!narrow || iconAlwaysVisible)) ...[
            SizedBox.square(
              dimension: iconAlwaysVisible
                  ? t.size(
                      'size.avatar.panelHeader',
                      fallback: s.headerIcon.width ?? 36,
                    )
                  : s.headerIcon.width ?? 36,
              child: iconSlot,
            ),
            SizedBox(width: gap),
          ],
          Expanded(
            child:
                titleSlot ??
                RaftPanelHeaderContent(
                  style: s.headerContent,
                  inline: inlineMeta,
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
                  meta:
                      metaSlot ??
                      (subtitle == null
                          ? null
                          : RaftCssText(
                              subtitle!,
                              maxLines: lines,
                              overflow: lines == null
                                  ? TextOverflow.clip
                                  : TextOverflow.ellipsis,
                              style: inlineMeta
                                  ? t
                                        .scale(
                                          RaftTypeScale.monoMeta,
                                          mono: true,
                                          color: t.ui.foregroundHint,
                                        )
                                        .merge(raftCssText)
                                  : (profileHandle)
                                  ? text(s.meta).copyWith(
                                      fontFamily: t.monoFont,
                                      fontSize: 15,
                                    )
                                  : text(s.meta),
                            )),
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
    final fill = background ?? s.header.decoration(rt).color;
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

/// The detail-panel tab strip: raft-ui Tabs `variant="underline"` ([RaftTabButton]) inside a
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
    this.onReorder,
  });
  final List<RaftPanelTab<T>> tabs;
  final T value;
  final ValueChanged<T> onChanged;

  /// `SortableTabsList onReorder`: a tab dragged onto another takes its place;
  /// receives the whole new order. A pointer drags at once, a finger after a
  /// long press (so the strip still scrolls). Null keeps the tabs fixed.
  final ValueChanged<List<T>>? onReorder;
  @override
  State<RaftPanelTabBar<T>> createState() => _RaftPanelTabBarState<T>();
}

class _RaftPanelTabBarState<T> extends State<RaftPanelTabBar<T>> {
  final scroll = ScrollController();
  final keys = <Object?, GlobalKey>{};

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
    // ConversationPanelTabs (0.7.0): the default TabsList variant is the yellow
    // sticker row (`px-5 py-2`, `gap-0.5`, h-8 tabs); the pre-theme looks keep
    // the underline row (panelTabs.style).
    final sticker = t.option('panelTabs.style', or: 'sticker') == 'sticker';
    final narrowStrip =
        MediaQuery.sizeOf(context).width < RaftLayoutMetrics.desktopBreakpoint;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.ui.lineSeam, width: 1)),
      ),
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: _metricsChanged,
        child: NotificationListener<ScrollStartNotification>(
          onNotification: _scrollStarted,
          child: SingleChildScrollView(
            controller: scroll,
            scrollDirection: Axis.horizontal,
            child: Container(
              height: grows ? null : (sticker ? 48 : 47),
              constraints: grows
                  ? BoxConstraints(minHeight: sticker ? 48 : 47)
                  : null,
              padding: sticker
                  ? EdgeInsets.symmetric(
                      horizontal: narrowStrip ? 16 : 20,
                      vertical: 8,
                    )
                  : const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (var i = 0; i < widget.tabs.length; i++) ...[
                    // raft-ui `TabsList variant="underline"`: `gap-5`; the
                    // default (sticker) list is `gap-0.5`.
                    if (i > 0) SizedBox(width: sticker ? 2 : 20),
                    _reorderable(widget.tabs[i], _tab(widget.tabs[i])),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(RaftPanelTab<T> tab) {
    final grows = RaftScaled.grows(context);
    final active = tab.id == widget.value;
    return KeyedSubtree(
      key: keys.putIfAbsent(tab.id, GlobalKey.new),
      child: _largeContent(
        tab,
        child: RaftTabButton(
          key: ValueKey(
            'panel-tab-${tab.id is Enum ? (tab.id as Enum).name : tab.id}',
          ),
          label: tab.label,
          glyph: tab.glyph,
          icon: tab.iconBuilder,
          variant:
              RaftTokens.of(context).option('panelTabs.style', or: 'sticker') ==
                  'sticker'
              ? RaftTabsVariant.standard
              : RaftTabsVariant.underline,
          selected: active,
          height:
              RaftTokens.of(context).option('panelTabs.style', or: 'sticker') ==
                  'sticker'
              ? 32
              : 47,
          growsWithText: grows,
          onPressed: () => widget.onChanged(tab.id),
        ),
      ),
    );
  }

  /// The tab being dragged over (its drop side is marked).
  T? dropTarget;

  List<T> _moved(T moving, T onto) {
    final ids = [for (final tab in widget.tabs) tab.id];
    final from = ids.indexOf(moving), to = ids.indexOf(onto);
    if (from < 0 || to < 0 || from == to) return ids;
    ids.insert(to, ids.removeAt(from));
    return ids;
  }

  Widget _reorderable(RaftPanelTab<T> tab, Widget child) {
    final onReorder = widget.onReorder;
    if (onReorder == null) return child;
    final t = RaftTokens.of(context);
    final touch = RaftInteraction.of(context).touch;
    // The lifted tab: its label on a raised chip (the tab itself stays in
    // place, so its key is never built twice).
    final feedback = Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: t.colors['layer-panel'],
          border: Border.all(color: t.colors['line-strong']!),
          boxShadow: const [BoxShadow(blurRadius: 8, color: Color(0x33000000))],
        ),
        child: RaftCssText(
          tab.label,
          style: raftCssText.merge(
            RaftTypography.heading(
              t,
              size: 13,
              line: 19.5,
              weight: FontWeight.w500,
              color: t.strong,
            ),
          ),
        ),
      ),
    );
    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) => details.data != tab.id,
      onMove: (_) {
        if (dropTarget != tab.id) setState(() => dropTarget = tab.id);
      },
      onLeave: (_) {
        if (dropTarget == tab.id) setState(() => dropTarget = null);
      },
      onAcceptWithDetails: (details) {
        setState(() => dropTarget = null);
        onReorder(_moved(details.data as T, tab.id));
      },
      builder: (context, candidates, _) {
        final marked = dropTarget == tab.id && candidates.isNotEmpty;
        final source = touch
            ? LongPressDraggable<Object>(
                data: tab.id as Object,
                feedback: feedback,
                child: child,
              )
            : Draggable<Object>(
                data: tab.id as Object,
                feedback: feedback,
                child: child,
              );
        return DecoratedBox(
          key: ValueKey(
            'panel-tab-slot-${tab.id is Enum ? (tab.id as Enum).name : tab.id}',
          ),
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: marked
                ? Border(left: BorderSide(color: t.strong, width: 2))
                : null,
          ),
          child: source,
        );
      },
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
}

/// The header/section icon actions of the detail panels (AgentProfileOverflowMenu
/// trigger, ThreadOverflowMenu trigger, CopyableCodeAction, HumanDetailPanel
/// message action, panel close).
///
/// `panelAction.surface` picks the drawing. `ghost` is raft-ui 0.7.0
/// `PanelAction` (`panelActionBase`: `h-11 min-w-11 rounded-control
/// border-[1.5px] border-transparent bg-transparent text-foreground
/// hover:bg-fill-pressed active:bg-fill-pressed focus-visible:shadow-focus`,
/// svg 22px, and `md:h-8 md:min-w-8` with an 18px svg): the shared ghost
/// Button at `icon-lg` below `md` and `icon-md` from it, so size, glyph,
/// radius, colours and focus ring all come from the pack. `outline` is the
/// pre-theme look, `<Button size="icon-sm" variant="outline">` resolved from
/// the generated `buttonVariants` recipe (a57b9dab).
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
    final touch = RaftInteraction.of(context).touch;
    final size = touch ? RaftButtonSize.iconLg : RaftButtonSize.iconMd;
    final source = RaftButtonMetrics.of(size, RaftButtonVariant.ghost, t);
    final extent = t.size(
      'size.control.${touch ? 'lg' : 'md'}',
      fallback: source.height,
    );
    return RaftButton(
      glyph: icon == null ? glyph : null,
      iconBuilder: icon,
      uiVariant: RaftButtonVariant.ghost,
      uiSize: size,
      physicalHeight: extent,
      visualWidth: extent,
      glyphSize: t.size('size.buttonGlyph.${size.name}', fallback: source.icon),
      onPressed: onPressed,
      onKeyboardActivate: onKeyboardActivate,
      focusNode: focusNode,
      semanticLabel: tooltip,
      tooltip: tooltip,
      surfaceBuilder: (context, surface) {
        Widget button = RaftBlinkSnap(child: surface);
        if (anchorLink != null)
          button = CompositedTransformTarget(
            key: anchorKey,
            link: anchorLink!,
            child: button,
          );
        return button;
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

  /// A single-line control label: on Android/Windows + Chinese it takes
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
    this.hasInlineWidgets = false,
    required super.child,
  });
  final TextStyle style;
  final TextScaler textScaler;

  /// Widget spans retain the paragraph's fractional layout baseline.
  final bool hasInlineWidgets;
  bool _windowsChinese(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.windows &&
      RaftControlTypography.appliesIn(context);
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCssLineBox(
    style,
    textScaler,
    _windowsChinese(context),
    hasInlineWidgets,
  );
  @override
  void updateRenderObject(BuildContext context, _RenderCssLineBox r) {
    r
      ..style = style
      ..textScaler = textScaler
      ..windowsChinese = _windowsChinese(context)
      ..hasInlineWidgets = hasInlineWidgets;
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
  _RenderCssLineBox(
    this._style,
    this._textScaler,
    this._windowsChinese,
    this._hasInlineWidgets,
  );
  TextStyle _style;
  TextScaler _textScaler;
  bool _windowsChinese;
  bool _hasInlineWidgets;

  set hasInlineWidgets(bool value) {
    if (value == _hasInlineWidgets) return;
    _hasInlineWidgets = value;
    markNeedsLayout();
  }

  set windowsChinese(bool value) {
    if (value == _windowsChinese) return;
    _windowsChinese = value;
    markNeedsLayout();
  }

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

  /// A control label on a Chinese platform profile keeps Flutter's own
  /// proportional baseline: the Blink even-leading baseline (and its snap)
  /// would move the ink back to where the font draws it too high.
  bool get _optical =>
      RaftControlTypography.isControlStyle(_style) &&
      (_style.height == RaftControlTypography.androidChineseLineHeight ||
          _windowsChinese);

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
    // SkParagraph lays out widget spans against the fractional baseline.
    // Move the attached controls by the same amount as their layout baseline.
    _flutterBaseline = _hasInlineWidgets
        ? reported
        : (reported + 0.5).floorToDouble();
  }

  // Inside a baseline query the child is asked with getDistanceToActualBaseline;
  // getDistanceToBaseline would re-enter the baseline assertion when an ancestor
  // (an inline line box, a baseline Row) is measuring this label.
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => _optical
      ? child?.getDistanceToActualBaseline(baseline)
      : _metrics.baseline;

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
    this.clipBehavior = Clip.none,
    this.paintDevicePixelRatio,
    this.child,
  });
  final BoxDecoration decoration;
  final EdgeInsetsGeometry padding;
  final Clip clipBehavior;
  final double? paintDevicePixelRatio;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    // Like Container: reserve border space and clip only the child.
    final content = Padding(
      padding: padding.add(decoration.padding),
      child: child,
    );
    return _SnappedDecoration(
      decoration: decoration,
      devicePixelRatio:
          paintDevicePixelRatio ?? View.of(context).devicePixelRatio,
      child: clipBehavior == Clip.none
          ? content
          : ClipPath(
              clipper: _SnappedDecorationClipper(
                decoration,
                Directionality.of(context),
              ),
              clipBehavior: clipBehavior,
              child: content,
            ),
    );
  }
}

class _SnappedDecorationClipper extends CustomClipper<Path> {
  const _SnappedDecorationClipper(this.decoration, this.direction);

  final BoxDecoration decoration;
  final TextDirection direction;

  @override
  Path getClip(Size size) =>
      decoration.getClipPath(Offset.zero & size, direction);

  @override
  bool shouldReclip(_SnappedDecorationClipper oldClipper) =>
      oldClipper.decoration != decoration || oldClipper.direction != direction;
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
    final bounds = global.isFinite
        ? Rect.fromLTRB(
            _snap(global.dx),
            _snap(global.dy),
            _snap(global.dx + size.width),
            _snap(global.dy + size.height),
          ).shift(offset - global)
        : offset & size;
    _painter ??= _decoration.createBoxPainter(markNeedsPaint);
    _painter!.paint(
      context.canvas,
      bounds.topLeft,
      ImageConfiguration(size: bounds.size),
    );
    super.paint(context, offset);
  }
}
