import 'panel_layout.dart' show raftRecipeTheme;
export 'panel_layout.dart' show raftRecipeTheme;

import 'package:flutter/material.dart';

import 'design_primitives.dart' hide RaftPanelHeaderRecipe;
import 'icons.dart';
import 'indicators.dart';
import 'localization.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/recipes.g.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';
import 'tokens/shadows.g.dart';

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
  });
  final String id, label;
  final RaftGlyph glyph;
  final VoidCallback onTap;

  /// Trailing `ml-auto` AttentionDot (SettingsSidebarList's
  /// FeedbackUnreadDot on the Feedback row).
  final bool attention;
}

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
  static double rowOverhang(RaftTokens t) => t.brutal ? 0 : 6;

  /// The Sidebar scroll surface (`px-2 py-3`) minus the row overhang, so the
  /// rows can span it while the group labels keep their `px-2`.
  static EdgeInsets inset(RaftTokens t) =>
      EdgeInsets.symmetric(horizontal: 8 - rowOverhang(t), vertical: 12);

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final overhang = rowOverhang(t);
    final visible = groups.where((g) => g.items.isNotEmpty).toList();
    // `mb-1 px-2 text-[10px] font-bold uppercase tracking-widest
    // text-foreground-muted theme-brutal:text-black/40`; line-height is the
    // inherited preflight 1.5 under Sidebar's `font-display`.
    final label =
        RaftTypography.heading(
          t,
          size: 10,
          line: 15,
          weight: FontWeight.w700,
        ).copyWith(
          letterSpacing: 1,
          color: t.brutal ? Colors.black.withValues(alpha: .4) : t.muted,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          // `space-y-3` between group divs; the last row's `mb-*` collapses
          // into it (block margins), so the visible gap stays 12px.
          if (i > 0) SizedBox(height: 12 - (t.brutal ? 4 : 2)),
          Padding(
            padding: EdgeInsets.fromLTRB(8 + overhang, 0, 8 + overhang, 4),
            child: Text(
              raftText(context, visible[i].label).toUpperCase(),
              style: label,
            ),
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
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = RaftRecipeTokens(t);
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
    final text = RaftTypography.heading(
      t,
      size: s.fontSize ?? 14,
      line: (s.fontSize ?? 14) * (s.lineHeight ?? 1.5),
      weight: s.fontWeight ?? FontWeight.w500,
    ).merge(s.textStyle(tokens));
    return Padding(
      padding: s.margin.copyWith(left: 0, right: 0),
      child: Semantics(
        button: true,
        selected: widget.active,
        label: widget.entry.label,
        child: MouseRegion(
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
                    child: SizedBox(
                      height: text.fontSize! * text.height!,
                      child: Text(
                        raftText(context, widget.entry.label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text,
                      ),
                    ),
                  ),
                  if (widget.entry.attention) const RaftAttentionDot(),
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
  });
  final String title;
  final RaftGlyph? glyph;
  final VoidCallback? onMobileBack;
  final bool mobile;
  final Key? backKey;
  final String backTooltip;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = RaftRecipeTokens(t);
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
    return Container(
      height: height,
      padding: header.padding,
      decoration: header.decoration(tokens),
      child: Row(
        children: [
          if (mobile && onMobileBack != null) ...[
            _PanelBackAction(
              key: backKey,
              tooltip: backTooltip,
              onPressed: onMobileBack!,
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
            child: Text(
              raftText(context, title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelBackAction extends StatefulWidget {
  const _PanelBackAction({
    super.key,
    required this.onPressed,
    required this.tooltip,
  });
  final VoidCallback onPressed;
  final String tooltip;
  @override
  State<_PanelBackAction> createState() => _PanelBackActionState();
}

class _PanelBackActionState extends State<_PanelBackAction> {
  bool hovered = false, pressed = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = RaftRecipeTokens(t);
    final s = RaftPanelActionRecipe.resolve(
      theme: raftRecipeTheme(t),
      states: RaftRecipeStates({
        if (hovered) RaftRecipeStates.hover,
        if (pressed) RaftRecipeStates.active,
        if (t.dark) RaftRecipeStates.dark,
      }),
      tokens: tokens,
    ).base;
    final svg = s.target('& > svg');
    final color = s.textStyle(tokens).color ?? t.strong;
    return Semantics(
      button: true,
      label: raftText(context, widget.tooltip),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: Tooltip(
          message: raftText(context, widget.tooltip),
          child: GestureDetector(
            onTapDown: (_) => setState(() => pressed = true),
            onTapCancel: () => setState(() => pressed = false),
            onTapUp: (_) => setState(() => pressed = false),
            onTap: widget.onPressed,
            child: Transform.translate(
              offset: s.translate ?? Offset.zero,
              child: Container(
                padding: s.padding,
                decoration: s.decoration(tokens),
                child: RaftIcon(
                  RaftGlyph.arrowLeft,
                  size: svg?.width ?? 14,
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

  /// The content surface; defaults to `bg-layer-panel
  /// theme-brutal:bg-white` (see [feedbackSurface]).
  final Color? contentColor;

  /// SettingsPanel's content div for the Feedback tab: `bg-layer-panel
  /// dark:bg-layer-card theme-brutal:bg-white`.
  static Color feedbackSurface(RaftTokens t) => t.brutal
      ? Colors.white
      : t.dark
      ? t.colors['layer-card']!
      : t.panel;

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
    final edge = t.brutal ? Colors.black : t.colors['line-muted']!;
    return Material(
      // SettingsPanel's Panel supplies bg-layer-canvas-muted to the transparent
      // desktop Elegant header. Its content div owns bg-layer-panel separately.
      color: t.brutal ? Colors.white : t.sidebar,
      // Container insets the child by the border width, as CSS does.
      child: Container(
        decoration: attached
            ? BoxDecoration(
                border: Border(
                  left: BorderSide(color: edge, width: t.brutal ? 2 : 1),
                ),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Panel edge="attached": `*:data-panel-frame-header:border-b`
            // (Elegant 1px line-muted inside the header box; Brutal's header
            // recipe already draws border-b-2 black).
            if (header != null)
              if (t.brutal || !attached)
                header!
              else
                Container(
                  foregroundDecoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: edge)),
                  ),
                  child: header,
                ),
            Expanded(
              child: Material(
                color: contentColor ?? (t.brutal ? Colors.white : t.panel),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// SectionHeader.tsx: `flex items-center gap-2`, a 16px icon in
/// `text-foreground-muted theme-brutal:text-black/60`, and SectionEyebrow
/// `text-xs font-bold uppercase text-foreground-muted tracking-widest`.
class RaftSettingsSectionHeader extends StatelessWidget {
  const RaftSettingsSectionHeader({
    super.key,
    required this.label,
    this.glyph,
    this.action,
    this.bottom = 12,
  });
  final String label;
  final RaftGlyph? glyph;
  final Widget? action;

  /// Callsite margin (`mb-3` on every SettingsPanel section).
  final double bottom;
  static TextStyle eyebrow(RaftTokens t) => RaftTypography.body(
    t,
    size: 12,
    line: 16,
    weight: FontWeight.w700,
    color: t.muted,
  ).copyWith(letterSpacing: 1.2);
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Row(
        children: [
          if (glyph != null) ...[
            RaftIcon(
              glyph!,
              size: 16,
              color: t.brutal ? Colors.black.withValues(alpha: .6) : t.muted,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              raftText(context, label).toUpperCase(),
              style: eyebrow(t),
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
  static BoxDecoration decoration(RaftTokens t) => BoxDecoration(
    color: t.brutal ? Colors.white : t.panel,
    border: Border.all(
      color: t.brutal ? Colors.black : t.colors['line-muted']!,
      width: t.brutal ? 2 : 1,
    ),
    boxShadow: t.brutal
        ? RaftProductShadows.shadowBrutalSm.outer
        : t.themeShadows.sm.outer,
  );
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: decoration(RaftTokens.of(context)),
    child: child,
  );
}

/// Tailwind spacing steps (`--spacing: 0.25rem`) used by the settings pages.
abstract final class RaftSpace {
  static const double half = 2, x1 = 4, x1_5 = 6, x2 = 8, x3 = 12, x4 = 16;
  static const double x5 = 20, x6 = 24;

  /// SocialProviderIcon `size-[18px]`.
  static const double providerIcon = 18;
}

/// Text colours/styles repeated across SettingsPanel.tsx sections, each the
/// resolved `text-foreground-* theme-brutal:text-black[/NN]` pair.
@immutable
class RaftSettingsText {
  const RaftSettingsText(this.t);
  final RaftTokens t;

  /// `text-foreground-strong theme-brutal:text-black`
  Color get strong => t.brutal ? Colors.black : t.strong;

  /// `text-foreground-muted theme-brutal:text-black/60`
  Color get muted => t.brutal ? Colors.black.withValues(alpha: .6) : t.muted;

  /// `text-foreground-muted theme-brutal:text-black/50`
  Color get faint => t.brutal ? Colors.black.withValues(alpha: .5) : t.muted;

  /// `border-black/30` (brutal) / `border-line-muted`.
  Color get softEdge =>
      t.brutal ? Colors.black.withValues(alpha: .3) : t.colors['line-muted']!;

  /// `theme-brutal:border-black` / `border-line-muted`.
  Color get edge => t.brutal ? Colors.black : t.colors['line-muted']!;

  /// `bg-layer-inset theme-brutal:bg-gray-50` (gray-50 = oklch(98.5% 0.002
  /// 247.839) = #F9FAFB).
  Color get insetFill =>
      t.brutal ? const Color(0xFFF9FAFB) : t.colors['layer-inset']!;

  /// `bg-layer-panel theme-brutal:bg-white`
  Color get panel => t.brutal ? Colors.white : t.panel;

  /// `text-sm font-bold`
  TextStyle get title => RaftTypography.body(
    t,
    size: 14,
    line: 20,
    weight: FontWeight.w700,
    color: strong,
  );

  /// `text-xs` muted description.
  TextStyle get description =>
      RaftTypography.body(t, size: 12, line: 16, color: muted);

  /// `text-sm` muted copy.
  TextStyle get bodyMuted =>
      RaftTypography.body(t, size: 14, line: 20, color: muted);

  /// `font-mono text-sm`
  TextStyle get mono =>
      RaftTypography.mono(t, size: 14, line: 20, color: strong);

  /// `font-mono text-sm font-bold`
  TextStyle get monoBold => mono.copyWith(fontWeight: FontWeight.w700);

  /// `text-xs font-bold` alert copy (`text-brutal-red` / danger).
  TextStyle get alert => RaftTypography.body(
    t,
    size: 12,
    line: 16,
    weight: FontWeight.w700,
    color: t.colors['color-brutal-red'] ?? t.colors['danger'],
  );
}
