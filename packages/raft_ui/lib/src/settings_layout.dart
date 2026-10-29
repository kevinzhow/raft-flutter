import 'hover_region.dart';
import 'space.dart';
export 'space.dart';
import 'panel_layout.dart'
    show RaftCssText, RaftPanelAction, RaftPanelHeaderBar, raftRecipeTheme;
import 'recipe_surface.dart'
    show
        RaftLayeredDecoration,
        RaftOuterShadowPainter,
        RaftRecipeBinding,
        RaftRecipeBox;
export 'panel_layout.dart' show raftRecipeTheme;

import 'package:flutter/material.dart';

import 'design_primitives.dart' hide RaftPanelHeaderRecipe;
import 'panel_edge.dart';
import 'control_typography.dart';
import 'icons.dart';
import 'indicators.dart';
import 'localization.dart';

import 'package:raft_theme/recipes/sidebar_recipe.g.dart' as raft_sidebar;

import 'recipes/recipe_router.dart' show usesLegacyRecipes;
import 'recipes/recipe_runtime.dart';
import 'recipes/recipes.g.dart';
import 'recipes/token_binding.dart';
import 'status_bar.dart';
import 'text_scaling.dart' show RaftScaled;
import 'theme.dart';

/// Shared Settings page pieces from the Web client:
/// - [RaftSettingsSidebarList]: components/settings/SettingsSidebarList.tsx
///   (group eyebrow + raft-ui `SidebarItem variant="accent"` rows).
/// - [RaftSettingsPanelHeader]: components/ui/PanelHeader.tsx (raft-ui
///   `PanelHeader` + `PanelAction` mobile back).
/// - [RaftSettingsPanelFrame]: SettingsPanel.tsx `Panel edge="attached"` shell
///   with the `px-5 py-4` content surface.
/// - [RaftSettingsSectionHeader]: components/ui/SectionHeader.tsx +
///   SectionEyebrow.tsx.
/// - [RaftSettingsCard]: the bordered settings card class list shared by
///   DangerActionCard / Notifications / Appearance cards.

class RaftSettingsNavEntry {
  const RaftSettingsNavEntry({
    required this.id,
    required this.label,
    required this.glyph,
    required this.onTap,
    this.attention = false,
    this.attentionDanger = false,
  });
  final String id, label;
  final RaftGlyph glyph;
  final VoidCallback onTap;

  /// Paint the [attention] dot in the `--danger` red ("update available").
  final bool attentionDanger;

  /// Trailing `ml-auto` AttentionDot (SettingsSidebarList's
  /// FeedbackUnreadDot on the Feedback row).
  final bool attention;
}

/// `layout.sidebar.settingsGroupServer`: English `Workspace`, Chinese 工作空间
/// (the plain `Workspace` catalog entry is 工作区, the agent's file workspace).
String _groupLabel(BuildContext context, String label) =>
    label == 'Server' || label == 'Workspace'
    ? raftTextZh(context, 'Workspace', '工作空间')
    : raftText(context, label);

class RaftSettingsNavGroup {
  const RaftSettingsNavGroup(this.label, this.items);
  final String label;
  final List<RaftSettingsNavEntry> items;
}

/// SettingsSidebarList.tsx: `space-y-3`; empty groups are dropped.
class RaftSettingsSidebarList extends StatelessWidget {
  const RaftSettingsSidebarList({
    super.key,
    required this.groups,
    this.activeId,
  });
  final List<RaftSettingsNavGroup> groups;
  final String? activeId;

  /// Elegant SidebarItem rows hang `-mx-(--sidebar-row-inset-x,6px)` past
  /// the Sidebar's `px-2` scroll inset (`w-[calc(100%+12px)]`); Brutal rows
  /// sit inside it.
  static double rowOverhang(RaftTokens t) => 6;

  /// The Sidebar scroll surface (`px-2 py-3`) minus the row overhang, so the
  /// rows can span it while the group labels keep their `px-2`.
  static EdgeInsets inset(RaftTokens t) => usesLegacyRecipes(t.recipeTokens)
      ? EdgeInsets.symmetric(horizontal: 8 - rowOverhang(t), vertical: 12)
      // raft-ui 0.7.0 Sidebar content: `px-2`, rows inside it (no overhang).
      : const EdgeInsets.fromLTRB(8, 4, 8, 8);

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final overhang = rowOverhang(t);
    final visible = groups.where((g) => g.items.isNotEmpty).toList();
    if (!usesLegacyRecipes(t.recipeTokens))
      return _buildRaft(context, t, visible);
    // `mb-1 px-2 text-[10px] font-bold
    // text-foreground-muted theme-brutal:text-black/40`; line-height is the
    // inherited preflight 1.5 under Sidebar's `font-display`.
    // Web SidebarGroupLabel is `text-footnote font-bold`; a pack that sets no
    // `type.settingsGroupLabel.*` keeps the a57b9dab 10/15.
    final label = RaftTypography.heading(
      t,
      size: t.size('type.settingsGroupLabel.size', fallback: 10),
      line: t.size('type.settingsGroupLabel.line', fallback: 15),
      weight: FontWeight.w700,
    ).copyWith(color: t.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          // `space-y-3` between group divs; the last row's `mb-*` collapses
          // into it (block margins), so the visible gap stays 12px.
          if (i > 0) SizedBox(height: 12 - (2)),
          Padding(
            padding: EdgeInsets.fromLTRB(8 + overhang, 0, 8 + overhang, 4),
            child: Text(_groupLabel(context, visible[i].label), style: label),
          ),
          for (final item in visible[i].items)
            RaftSettingsSidebarItem(
              rowKey: ValueKey('workspace-settings-nav-${item.id}'),
              entry: item,
              active: item.id == activeId,
            ),
        ],
      ],
    );
  }
}

extension on RaftSettingsSidebarList {
  /// raft-ui 0.7.0 `SidebarGroupLabel` + `SidebarItem` rows (the sidebar and
  /// sidebarItem recipes: `px-2 pt-4 pb-1.5` 13/18 bold hint labels, `h-9` rows
  /// with `my-px` margins that collapse to 1px between rows).
  Widget _buildRaft(
    BuildContext context,
    RaftTokens t,
    List<RaftSettingsNavGroup> visible,
  ) {
    final rt = t.recipeTokens;
    final labelSlot = raft_sidebar.RaftSidebarRecipe.resolve(tokens: rt)
        .sidebarGroupLabel;
    final label = labelSlot.textStyle(rt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in visible) ...[
          Padding(
            // Web paints the 13/18 label glyphs one pixel below Flutter's line box.
            padding: labelSlot.padding.copyWith(
              top: labelSlot.padding.top + 1,
              bottom: labelSlot.padding.bottom - 1,
            ),
            child: RaftCssText(
              // Web v1.21.23 names the group `Workspace`.
              _groupLabel(context, group.label),
              style: label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final item in group.items)
            RaftSettingsSidebarItem(
              rowKey: ValueKey('workspace-settings-nav-${item.id}'),
              entry: item,
              active: item.id == activeId,
            ),
          // The last row's `my-px` margin collapses out of its group.
          // ds-allow: Web SidebarItem `my-px`
          const SizedBox(height: 1),
        ],
      ],
    );
  }
}

/// raft-ui `SidebarItem variant="accent"` with a bare 14px leading icon.
class RaftSettingsSidebarItem extends StatefulWidget {
  const RaftSettingsSidebarItem({
    super.key,
    required this.entry,
    this.active = false,
    this.rowKey,
  });
  final RaftSettingsNavEntry entry;
  final bool active;

  /// Key of the row box itself (the SidebarItem border box, margin
  /// excluded).
  final Key? rowKey;
  @override
  State<RaftSettingsSidebarItem> createState() =>
      _RaftSettingsSidebarItemState();
}

class _RaftSettingsSidebarItemState extends State<RaftSettingsSidebarItem> {
  bool hovered = false;
  Widget _buildRaft(BuildContext context, RaftTokens t) {
    final tokens = RaftRecipeTokens(t);
    final size = MediaQuery.sizeOf(context);
    final recipe = RaftSidebarItemRecipe.resolve(
      theme: raftRecipeTheme(t),
      states: RaftRecipeStates(
        {
          if (hovered) RaftRecipeStates.hover,
          if (widget.active) ...[
            'data-active',
            'group/sidebar-item:data-active',
          ],
          if (t.dark) RaftRecipeStates.dark,
        },
        size.width,
        size.height,
      ),
      tokens: tokens,
    );
    final s = recipe.sidebarItem;
    final icon = recipe.sidebarItemIcon;
    final text = s.textStyle(tokens);
    final line = (text.fontSize ?? 15) * (text.height ?? 1.3);
    final iconBox = icon.width ?? 19;
    // Web v1.21.23: `AI Providers`.
    final title = raftText(
      context,
      widget.entry.label == 'Providers' ? 'AI Providers' : widget.entry.label,
    );
    // `my-px`: the margins of neighbouring rows collapse to one pixel.
    return Padding(
      // ds-allow: Web SidebarItem `my-px`
      padding: const EdgeInsets.only(top: 1),
      child: Semantics(
        button: true,
        selected: widget.active,
        label: widget.entry.label,
        child: RaftHoverRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.entry.onTap,
            child: RaftRecipeBox(
              key: widget.rowKey,
              style: s,
              tokens: tokens,
              applyText: false,
              alignment: AlignmentDirectional.centerStart,
              growWithText: true,
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: iconBox,
                    child: RaftIcon(
                      widget.entry.glyph,
                      size: 16,
                      color: icon.color?.resolve(tokens),
                    ),
                  ),
                  SizedBox(width: s.columnGap ?? 8),
                  Expanded(
                    // Above the default text size the label wraps and the line
                    // box is a minimum, so nothing is clipped.
                    child: RaftScaled.grows(context)
                        ? ConstrainedBox(
                            constraints: BoxConstraints(minHeight: line),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                title,
                                style: RaftControlTypography.of(context, text),
                              ),
                            ),
                          )
                        : SizedBox(
                            height: line,
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: RaftControlTypography.of(context, text),
                              ),
                            ),
                          ),
                  ),
                  if (widget.entry.attention)
                    RaftAttentionDot(danger: widget.entry.attentionDanger),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = RaftRecipeTokens(t);
    if (!usesLegacyRecipes(tokens)) return _buildRaft(context, t);
    final size = MediaQuery.sizeOf(context);
    final s = RaftSidebarItemRecipe.resolve(
      theme: raftRecipeTheme(t),
      variant: RaftSidebarItemRecipeVariant.accent,
      states: RaftRecipeStates(
        {
          if (hovered) RaftRecipeStates.hover,
          if (widget.active) 'data-active',
          if (t.dark) RaftRecipeStates.dark,
        },
        size.width,
        size.height,
      ),
      tokens: tokens,
    ).sidebarItem;
    // Elegant `text-[13px]` sets no line-height: the row inherits the
    // Sidebar's preflight 1.5 (13px -> 19.5px line, 35.5px row pitch).
    // Web SettingsSidebarList rows are raft-ui SidebarItem (`text-subhead
    // font-medium`, `data-active:font-bold`): size and line from
    // `type.settingsSidebarItem.*` and the weights from the existing
    // `type.sidebarItem.weight` / `type.sidebarItemActive.weight`. A pack that
    // sets none keeps the a57b9dab recipe values (Elegant 13 / 1.5, Brutal 14).
    final itemSize = t.size(
      'type.settingsSidebarItem.size',
      fallback: s.fontSize ?? 14,
    );
    final itemLine = t.size(
      'type.settingsSidebarItem.line',
      fallback: (s.fontSize ?? 14) * (s.lineHeight ?? 1.5),
    );
    final recipeWeight = (s.fontWeight ?? FontWeight.w500).value.toDouble();
    final text =
        RaftTypography.heading(
              t,
              size: s.fontSize ?? 14,
              line: (s.fontSize ?? 14) * (s.lineHeight ?? 1.5),
              weight: s.fontWeight ?? FontWeight.w500,
            )
            .merge(s.textStyle(tokens))
            .copyWith(
              fontSize: itemSize,
              height: itemLine / itemSize,
              fontWeight: raftFontWeight(
                t.size(
                  widget.active
                      ? 'type.sidebarItemActive.weight'
                      : 'type.sidebarItem.weight',
                  fallback: recipeWeight,
                ),
              ),
            );
    return Padding(
      padding: s.margin.copyWith(left: 0, right: 0),
      child: Semantics(
        button: true,
        selected: widget.active,
        label: widget.entry.label,
        child: RaftHoverRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.entry.onTap,
            child: Container(
              key: widget.rowKey,
              padding: s.padding,
              decoration: s.decoration(tokens),
              child: Row(
                children: [
                  RaftIcon(widget.entry.glyph, size: 14, color: text.color),
                  SizedBox(width: s.columnGap ?? 6),
                  Expanded(
                    // The CSS line box (19.5px), not Flutter's ceiled
                    // paragraph height, sets the row height.
                    //
                    // Above the default text size the label wraps and the
                    // line box is a minimum height, so nothing is clipped.
                    child: RaftScaled.grows(context)
                        ? ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: text.fontSize! * text.height!,
                            ),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                raftText(context, widget.entry.label),
                                style: RaftControlTypography.of(context, text),
                              ),
                            ),
                          )
                        : SizedBox(
                            height: text.fontSize! * text.height!,
                            // The control profile changes the line height
                            // inside that fixed box; keep the label centred
                            // in it.
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                raftText(context, widget.entry.label),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: RaftControlTypography.of(context, text),
                              ),
                            ),
                          ),
                  ),
                  if (widget.entry.attention)
                    RaftAttentionDot(danger: widget.entry.attentionDanger),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// PanelHeader.tsx on a non-identity surface: the icon is desktop-only and
/// the mobile back is a raft-ui `PanelAction` holding `ArrowLeft size=14`.
class RaftSettingsPanelHeader extends StatelessWidget {
  const RaftSettingsPanelHeader({
    super.key,
    required this.title,
    this.glyph,
    this.onMobileBack,
    this.mobile = true,
    this.backKey,
    this.backTooltip = 'Back',
    this.iconTile = false,
  });
  final String title;
  final RaftGlyph? glyph;

  /// The page passes an icon to its PanelHeader even in the v1.21.23 look
  /// (RaftBench); the settings tabs do not (pageHeader.icon).
  final bool iconTile;
  final VoidCallback? onMobileBack;
  final bool mobile;
  final Key? backKey;
  final String backTooltip;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = RaftRecipeTokens(t);
    if (t.option('panelAction.surface', or: 'outline') == 'ghost') {
      return RaftPanelHeaderBar(
        title: raftText(context, title),
        // v1.21.23 page heads carry no icon tile (pageHeader.icon).
        iconSlot:
            !mobile &&
                glyph != null &&
                (iconTile || t.option('pageHeader.icon', or: 'none') == 'tile')
            ? Container(
                width: 27,
                height: 27,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.colors['fill-muted'],
                  borderRadius: BorderRadius.circular(t.fieldRadius),
                ),
                child: RaftIcon(glyph!, size: 18, color: t.muted),
              )
            : null,
        onBack: mobile ? onMobileBack : null,
        backKey: backKey,
        backTooltip: raftText(context, backTooltip),
      );
    }
    final size = MediaQuery.sizeOf(context);
    final states = RaftRecipeStates(
      {if (t.dark) RaftRecipeStates.dark},
      size.width,
      size.height,
    );
    final s = RaftPanelHeaderRecipe.resolve(
      theme: raftRecipeTheme(t),
      states: states,
      tokens: tokens,
    );
    final header = s.header;
    final titleStyle = RaftTypography.body(
      t,
      size: s.title.fontSize ?? 16,
      line: (s.title.fontSize ?? 16) * (s.title.lineHeight ?? 1.25),
      weight: s.title.fontWeight ?? FontWeight.w700,
    ).merge(s.title.textStyle(tokens));
    final height =
        header.height ?? RaftLayoutMetrics.shellHeaderHeight(t, size.height);
    return RaftStatusBarSource(
      color: header.decoration(tokens).color ?? Colors.transparent,
      child: Container(
        height: height,
        padding: header.padding,
        decoration: header.decoration(tokens),
        child: Row(
          children: [
            if (mobile && onMobileBack != null) ...[
              // AppPanelHeader `onMobileBack`: the raft-ui PanelAction boxed
              // ArrowLeft, touch area extended around the Web-sized visual.
              RaftPanelAction(
                key: backKey,
                glyph: RaftGlyph.arrowLeft,
                tooltip: raftText(context, backTooltip),
                onPressed: onMobileBack,
                minHitExtent: RaftMetrics.touchTarget,
              ),
              SizedBox(width: header.columnGap ?? 12),
            ],
            if (!mobile && glyph != null) ...[
              Container(
                width: s.headerIcon.width,
                height: s.headerIcon.height,
                alignment: Alignment.center,
                decoration: s.headerIcon.decoration(tokens),
                child: RaftIcon(
                  glyph!,
                  size: 18,
                  color: s.headerIcon.textStyle(tokens).color,
                ),
              ),
              SizedBox(width: header.columnGap ?? 12),
            ],
            Expanded(
              child: RaftCssText(
                raftText(context, title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// SettingsPanel.tsx: `Panel edge="attached"` (left edge line) holding the
/// panel header and the `bg-layer-panel px-5 py-4` content surface
/// (`theme-brutal:bg-white`).
class RaftSettingsPanelFrame extends StatelessWidget {
  const RaftSettingsPanelFrame({
    super.key,
    required this.header,
    required this.child,
    this.attached = true,
    this.contentColor,
  });

  /// Web SettingsPanel's content div is `bg-layer-canvas` (v1.21.23
  /// SettingsPanel.tsx); a pack without `layer-settings-content` keeps the
  /// a57b9dab `bg-layer-panel`.
  Color contentSurfaceOf(RaftTokens t) =>
      t.colors['layer-settings-content'] ?? t.panel;

  /// The content surface; defaults to `bg-layer-panel
  /// theme-brutal:bg-white` (see [feedbackSurface]).
  final Color? contentColor;

  /// SettingsPanel's content div for the Feedback tab: `bg-layer-panel
  /// dark:bg-layer-card theme-brutal:bg-white`.
  static Color feedbackSurface(RaftTokens t) =>
      t.colors['layer-settings-feedback-content'] ??
      (t.dark ? t.colors['layer-card']! : t.panel);

  /// Null when the page brings its own header inside the content
  /// (AboutFeedbackPanel's PanelHeader sits in SettingsPanel's content div).
  final Widget? header;
  final Widget child;

  /// `Panel edge="attached"`: the left edge line and the header divider.
  /// False for routes that render outside a Panel (ReleaseNotesPanel's
  /// plain `flex-col` div).
  final bool attached;
  static const contentInset = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 16,
  );
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final edge = t.colors['line-muted']!;
    // `Panel edge="attached"`: the shared rule (RaftPanelEdge) decides, the
    // phone page is the only presentation without the line.
    final edgeBorder = attached ? RaftPanelEdge.left(context) : null;
    return Material(
      // SettingsPanel's Panel supplies bg-layer-canvas-muted to the transparent
      // desktop Elegant header. Its content div owns bg-layer-panel separately.
      color: t.sidebar,
      // Container insets the child by the border width, as CSS does.
      // The left edge continues up under the status bar on wide layouts; the
      // header (when flush) publishes the colour over the panel.
      child: RaftStatusBarSource(
        color: t.sidebar,
        border: edgeBorder,
        child: Container(
          decoration: edgeBorder == null
              ? null
              : BoxDecoration(border: edgeBorder),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Panel edge="attached": `*:data-panel-frame-header:border-b`
              // (Elegant 1px line-muted inside the header box; Brutal's header
              // recipe already draws border-b-2 black).
              if (header != null)
                if (!attached)
                  header!
                else
                  Container(
                    foregroundDecoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: edge)),
                    ),
                    child: header,
                  ),
              Expanded(
                // Without a frame header the content surface is the top one.
                child: RaftStatusBarSource(
                  color: contentColor ?? contentSurfaceOf(t),
                  child: Material(
                    color: contentColor ?? contentSurfaceOf(t),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Settings text that inherits the page's `font-family` (Hanken Grotesk in
/// Brutal, Inter in Elegant) rather than `font-sans`: a thin wrapper over
/// [RaftTypography.inherited] (the mechanism behind [RaftInheritedFont]) that
/// defaults the colour to the strong ink, keeps Inter's optical-size axis and
/// splits CSS half-leading evenly, as Blink lays out a line box.
TextStyle raftSettingsBody(
  RaftTokens t, {
  double size = 16,
  double line = 24,
  FontWeight weight = FontWeight.w400,
  Color? color,
}) => RaftTypography.inherited(
  t,
  size: size,
  line: line,
  weight: weight,
  color: color ?? t.strong,
).copyWith(leadingDistribution: TextLeadingDistribution.even);

/// SectionHeader.tsx: `flex items-center gap-2`, a 16px icon in
/// `text-foreground-muted theme-brutal:text-black/60`, and SectionEyebrow
/// `text-xs font-bold text-foreground-muted`.
class RaftSettingsSectionHeader extends StatelessWidget {
  const RaftSettingsSectionHeader({
    super.key,
    required this.label,
    this.glyph,
    this.action,
    this.bottom = 12,
    this.count,
    this.display = false,
  });
  final String label;
  final RaftGlyph? glyph;
  final Widget? action;

  /// SectionHeader `count`: `ml-2 font-mono text-foreground-placeholder
  /// theme-brutal:text-black/40` after the label.
  final int? count;

  /// Callsite margin (`mb-3` on every SettingsPanel section).
  final double bottom;

  /// The eyebrow inherits the oracle host's `font-display` ancestor and is
  /// laid out as a Blink line box ([RaftCssText]).
  final bool display;
  static TextStyle eyebrow(RaftTokens t, {bool display = false}) =>
      // Web SectionEyebrow (`text-footnote font-bold`): 13/18 in the Raft pack,
      // 12/16 in the a57b9dab packs (type.sectionEyebrow.*).
      (display ? raftSettingsBody : RaftTypography.body)(
        t,
        size: t.size('type.sectionEyebrow.size', fallback: 13),
        line: t.size('type.sectionEyebrow.line', fallback: 18),
        weight: FontWeight.w700,
        color: t.muted,
      );
  Widget rich(InlineSpan span, TextStyle style) => display
      ? RaftCssText.rich(span, style: style)
      : Text.rich(span, style: style);

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Row(
        children: [
          if (glyph != null) ...[
            RaftIcon(glyph!, size: 16, color: t.muted),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: rich(
              TextSpan(
                children: [
                  TextSpan(text: raftText(context, label)),
                  if (count != null && count! >= 0) ...[
                    const WidgetSpan(child: SizedBox(width: 8)),
                    TextSpan(
                      text: '$count',
                      style:
                          RaftTypography.mono(
                            t,
                            size: 12,
                            line: 16,
                            color: t.colors['foreground-placeholder'],
                          ).copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                    ),
                  ],
                ],
              ),
              eyebrow(t, display: display),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// `border border-line-muted bg-layer-panel p-4 shadow-raft-sm
/// theme-brutal:border-2 theme-brutal:border-black theme-brutal:bg-white
/// theme-brutal:shadow-brutal-sm`.
class RaftSettingsCard extends StatelessWidget {
  const RaftSettingsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsets padding;

  /// SurfaceListItem `px-4 py-3`.
  static const listItemInset = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );
  static BoxDecoration decoration(RaftTokens t) {
    final decoration = BoxDecoration(
      // Web's settings Card is `bg-layer-card`; a pack without
      // `layer-settings-card` keeps the a57b9dab `bg-layer-panel`.
      color: t.colors['layer-settings-card'] ?? t.panel,
      borderRadius: BorderRadius.circular(
        t.size('radius.settingsCard', fallback: 0),
      ),
      border: Border.all(color: t.colors['line-muted']!, width: 1),
      boxShadow: t.themeShadows.sm.outer,
    );
    // The Raft look paints CSS geometry (padding-box clip, concentric rings);
    // the frozen looks keep the plain decoration.
    return usesLegacyRecipes(t.recipeTokens)
        ? decoration
        : RaftRecipeDecoration.from(decoration, cssGeometry: true);
  }

  @override
  Widget build(BuildContext context) =>
      box(RaftTokens.of(context), padding: padding, child: child);

  /// The card surface (optionally [color] / [radius] overridden, [height]
  /// fixed): background, the Elegant-dark inset highlights of
  /// `shadow-raft-sm` (Flutter's BoxShadow has none), then the border, all
  /// below the content, with the outer shadow outside the border box.
  static Widget box(
    RaftTokens t, {
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color? color,
    BorderRadius? radius,
    double? height,

    /// A box that grows with its content (a text-bearing control above the
    /// default text size); [height] is the fixed alternative.
    double? minHeight,
  }) {
    final constraints = minHeight == null
        ? null
        : BoxConstraints(minHeight: minHeight);
    final base = decoration(t).copyWith(color: color, borderRadius: radius);
    final effectiveRadius = (base.borderRadius ?? BorderRadius.zero).resolve(
      TextDirection.ltr,
    );
    final inset = t.themeShadows.sm.inset;
    if (inset.isEmpty) {
      return Container(
        height: height,
        constraints: constraints,
        alignment: minHeight == null ? null : AlignmentDirectional.centerStart,
        padding: padding,
        decoration: base,
        // `overflow-hidden` on the Card: a child's fill follows the rounded
        // padding box and never covers the border (the frozen looks do not clip).
        clipBehavior: usesLegacyRecipes(t.recipeTokens)
            ? Clip.none
            : Clip.antiAlias,
        child: child,
      );
    }
    return CustomPaint(
      painter: RaftOuterShadowPainter(
        base.boxShadow ?? const [],
        effectiveRadius,
      ),
      child: Container(
        height: height,
        constraints: constraints,
        alignment: minHeight == null ? null : AlignmentDirectional.centerStart,
        padding: padding,
        decoration: RaftLayeredDecoration(
          BoxDecoration(
            color: base.color,
            border: base.border,
            borderRadius: effectiveRadius,
          ),
          inset,
          effectiveRadius,
          null,
          const EdgeInsets.all(RaftSpace.hairline),
        ),
        child: child,
      ),
    );
  }
}

/// Text colours/styles repeated across SettingsPanel.tsx sections, each the
/// resolved `text-foreground-* theme-brutal:text-black[/NN]` pair.
/// The page's inherited `font-family` for descendants that do not name one:
/// the theme's heading family (Inter in elegant, Hanken Grotesk in brutal),
/// not the `font-sans` utility family ([RaftTokens.bodyFont]).
class RaftInheritedFont extends StatelessWidget {
  const RaftInheritedFont({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftInheritedFontScope(
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontFamily: t.headingFont,
          fontFamilyFallback: t.fontFallback,
        ),
        child: child,
      ),
    );
  }
}

@immutable
class RaftSettingsText {
  const RaftSettingsText(this.t);
  final RaftTokens t;

  /// `text-foreground-strong theme-brutal:text-black`
  Color get strong => t.strong;

  /// `text-foreground-muted theme-brutal:text-black/60`
  Color get muted => t.muted;

  /// `text-foreground-muted theme-brutal:text-black/50`
  Color get faint => t.muted;

  /// `border-black/30` (brutal) / `border-line-muted`.
  Color get softEdge => t.colors['line-muted']!;

  /// `theme-brutal:border-black` / `border-line-muted`.
  Color get edge => t.colors['line-muted']!;

  /// `bg-layer-inset theme-brutal:bg-gray-50` (gray-50 = oklch(98.5% 0.002
  /// 247.839) = #F9FAFB).
  Color get insetFill => t.colors['layer-inset']!;

  /// `bg-layer-panel theme-brutal:bg-white`
  Color get panel => t.panel;

  /// Read-only SlugInput group (`border-line-strong bg-layer-inset
  /// theme-brutal:border-black/30 theme-brutal:bg-gray-50`); in elegant dark
  /// InputGroup's `dark:bg-layer-card` and `dark:not-has-[invalid]:
  /// border-transparent` outrank the callsite classes.
  Color get readonlyGroupBorder =>
      t.dark ? Colors.transparent : t.colors['line-strong']!;
  Color get readonlyGroupFill => t.dark ? t.colors['layer-card']! : insetFill;

  /// `text-sm font-bold`
  TextStyle get title => RaftTypography.inherited(
    t,
    size: 14,
    line: 20,
    weight: FontWeight.w700,
    color: strong,
  );

  /// `text-xs` muted description.
  TextStyle get description =>
      RaftTypography.inherited(t, size: 12, line: 16, color: muted);

  /// `text-sm` muted copy.
  TextStyle get bodyMuted =>
      RaftTypography.inherited(t, size: 14, line: 20, color: muted);

  /// `font-mono text-sm`
  TextStyle get mono =>
      RaftTypography.mono(t, size: 14, line: 20, color: strong);

  /// `font-mono text-sm font-bold`
  TextStyle get monoBold => mono.copyWith(fontWeight: FontWeight.w700);

  /// `text-xs font-bold` alert copy (`text-brutal-red` / danger).
  TextStyle get alert => RaftTypography.inherited(
    t,
    size: 12,
    line: 16,
    weight: FontWeight.w700,
    color: t.colors['color-brutal-red'] ?? t.colors['danger'],
  );
}
