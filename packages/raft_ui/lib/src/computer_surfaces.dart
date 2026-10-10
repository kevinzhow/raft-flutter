// Visual pieces of the Web Computers surfaces (raft-source 26f77ef):
// layout/Sidebar.tsx computers mode (section heading + ComputerRow) and the
// small controls MachineDetailPanel / AddMachineDialog compose. Data and
// actions stay in the app; values cite the Web classes they come from.
import 'package:flutter/material.dart';

import 'agent_profile.dart' show raftGray400;
import 'design_primitives.dart' hide RaftPanelHeaderRecipe;
import 'dialog_card.dart';
import 'icons.dart';
import 'indicators.dart' show RaftSkeletonRow;
import 'panel_layout.dart' show raftRecipeTheme, raftPanelInk, RaftCssText;
import 'recipe_surface.dart' show raftCssText, RaftRecipeBox;
import 'recipes/badge.g.dart';
import 'recipes/card.g.dart';
import 'recipes/panel_header.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'sidebar_section.dart' show RaftSidebarSectionActionRecipe;
import 'theme.dart';

/// AppPanelHeader `icon` + `iconBg`: the PanelHeaderIcon cell with the
/// callsite fill (`bg-primary-soft theme-brutal:bg-soft-signal`; elegant
/// `border-0 bg-fill-muted`) around an 18px Lucide icon.
class RaftPanelHeaderIconTile extends StatelessWidget {
  const RaftPanelHeaderIconTile({
    super.key,
    required this.glyph,
    required this.background,
    this.borderless = false,
  });
  final RaftGlyph glyph;
  final Color background;
  final bool borderless;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final s = RaftPanelHeaderRecipe.resolve(
      theme: raftRecipeTheme(t),
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: rt,
    ).headerIcon;
    var decoration = s.decoration(rt).copyWith(color: background);
    if (borderless)
      decoration = decoration.copyWith(
        border: Border.all(width: 0, color: Colors.transparent),
      );
    return Container(
      width: s.width,
      height: s.height,
      alignment: Alignment.center,
      decoration: decoration,
      child: RaftIcon(
        glyph,
        size: 18,
        // `text-foreground-strong theme-brutal:text-black`.
        color: t.brutal ? Colors.black : t.colors['foreground-strong'],
      ),
    );
  }
}

/// MachineDetailPanel "Detected Runtimes" chip: raft-ui Badge (solid,
/// default variant, not uppercase) with the callsite fill — detected
/// `bg-info-soft text-info-strong theme-brutal:bg-brutal-cyan
/// theme-brutal:text-black`, otherwise `bg-fill-muted text-foreground-muted`.
class RaftRuntimeChip extends StatelessWidget {
  const RaftRuntimeChip({
    super.key,
    required this.label,
    required this.detected,
  });
  final String label;
  final bool detected;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final s = RaftBadgeRecipe.resolve(
      theme: raftRecipeTheme(t),
      appearance: RaftBadgeRecipeAppearance.solid,
      variant: RaftBadgeRecipeVariant.default_,
      uppercase: false,
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: rt,
    ).root;
    final fill = detected
        ? (t.brutal ? t.product.brutalCyan : t.colors['info-soft']!)
        : t.colors['fill-muted']!;
    final ink = detected
        ? (t.brutal ? Colors.black : t.colors['info-strong']!)
        : t.colors['foreground-muted']!;
    return Container(
      height: s.height,
      padding: s.padding,
      decoration: s.decoration(rt).copyWith(color: fill),
      child: Center(
        widthFactor: 1,
        child: RaftCssText(
          label,
          maxLines: 1,
          style: raftCssText.merge(
            RaftTypography.body(
              t,
              size: 10,
              line: 10,
            ).merge(s.textStyle(rt)).copyWith(color: ink),
          ),
        ),
      ),
    );
  }
}

/// A bare `<button>` styled as underlined text (`underline
/// underline-offset-2`).
class RaftUnderlineTextButton extends StatelessWidget {
  const RaftUnderlineTextButton({
    super.key,
    required this.label,
    required this.style,
    this.onPressed,
  });
  final String label;
  final TextStyle style;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => RaftInteractive(
    onPressed: onPressed,
    semanticLabel: label,
    builder: (context, state) => RaftCssText(
      label,
      style: style.copyWith(
        decoration: TextDecoration.underline,
        decorationColor: style.color,
      ),
    ),
  );
}

/// `<Card render={<button/>} className="w-full theme-brutal:border-2 p-4
/// text-left">`: an option card whose selected state carries the caller's
/// tint (`bg-*` + `theme-brutal:shadow-brutal-sm`), unselected
/// `border-line-muted theme-brutal:border-black/30 bg-layer-panel
/// theme-brutal:bg-white hover:border-line-strong`.
class RaftOptionCard extends StatelessWidget {
  const RaftOptionCard({
    super.key,
    required this.selected,
    required this.selectedFill,
    required this.child,
    this.onPressed,
  });
  final bool selected;
  final Color selectedFill;
  final Widget child;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => RaftInteractive(
    onPressed: onPressed,
    selected: selected,
    builder: (context, state) {
      final t = RaftTokens.of(context);
      final rt = RaftRecipeTokens(t);
      final root = RaftCardRecipe.resolve(
        theme: raftRecipeTheme(t),
        states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
        tokens: rt,
      ).root;
      // Elegant Card root `border-[0.5px] … dark:border-transparent`: the
      // callsite `border-line-muted` / `hover:border-line-strong` do not
      // override the `dark:` variant.
      final border = !t.brutal && t.dark
          ? Colors.transparent
          : selected
          ? (t.brutal ? Colors.black : t.colors['line-muted']!)
          : state.hovered
          ? (t.brutal ? Colors.black : t.colors['line-strong']!)
          : (t.brutal
                ? Colors.black.withValues(alpha: .3)
                : t.colors['line-muted']!);
      // RaftRecipeBox keeps the recipe's inset layers (elegant dark
      // `shadow-raft-xs` top light, `inset 0 1px 0`) above the fill.
      return RaftRecipeBox(
        style: root,
        tokens: rt,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        applyText: false,
        decorationOverride: (base) => base.copyWith(
          // A translucent tint (`bg-brutal-cyan/20`) composites over the
          // dialog surface.
          color: selected
              ? Color.alphaBlend(
                  selectedFill,
                  t.brutal ? Colors.white : t.colors['layer-panel']!,
                )
              : (t.brutal ? Colors.white : t.colors['layer-panel']),
          border: Border.all(color: border, width: t.brutal ? 2 : 1),
          boxShadow: t.brutal && selected
              ? RaftShadowSet.brutalSm
              : t.brutal
              ? const []
              : base.boxShadow,
        ),
        child: child,
      );
    },
  );
}

/// Sidebar.tsx computers mode heading: `mb-1.5 flex items-center
/// justify-between px-2`, label `text-xs font-bold uppercase
/// text-foreground-strong tracking-widest theme-brutal:text-black` + count
/// `text-foreground-placeholder font-mono normal-case tracking-normal
/// theme-brutal:text-black/40`, and the size-6 "Add computer" icon button.
class RaftComputerSidebarHeading extends StatelessWidget {
  const RaftComputerSidebarHeading({
    super.key,
    required this.label,
    required this.count,
    this.onAdd,
    this.addKey,
    this.addLabel = 'Add computer',
  });
  final String label;
  final int count;
  final VoidCallback? onAdd;
  final Key? addKey;
  final String addLabel;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final strong = t.brutal ? Colors.black : t.colors['foreground-strong']!;
    final style = raftCssText.merge(
      RaftTypography.body(
        t,
        size: 12,
        line: 16,
        weight: FontWeight.w700,
        color: strong,
      ).copyWith(letterSpacing: 1.2),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: SizedBox(
        height: 24,
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: label.toUpperCase()),
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: '$count',
                      style: TextStyle(
                        fontFamily: t.monoFont,
                        letterSpacing: 0,
                        color: t.brutal
                            ? Colors.black.withValues(alpha: .4)
                            : t.colors['foreground-placeholder'],
                      ),
                    ),
                  ],
                ),
                style: style,
                maxLines: 1,
              ),
            ),
            if (onAdd != null)
              RaftControl(
                key: addKey,
                semanticLabel: addLabel,
                tooltip: addLabel,
                visualHeight: 24,
                visualWidth: 24,
                minimumTargetSize: 24,
                recipe: RaftSidebarSectionActionRecipe(t),
                onPressed: onAdd,
                child: const RaftIcon(RaftGlyph.plus, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sidebar.tsx `ComputerRow`: SidebarItem `variant="accent"` +
/// `mb-1.5 gap-2.5 px-2.5 py-2 border theme-brutal:border-2` (the recipe's
/// `md:py-1` / elegant `md:py-1.5` win at desktop width), a size-9 Card with
/// Monitor 18 and a status dot at `-right-1 -top-1`, name (`text-sm
/// font-bold`), optional description (`mt-0.5 text-[11px] leading-tight`),
/// and the mono meta line (run label, `→ vX`, Low disk).
class RaftComputerRow extends StatelessWidget {
  const RaftComputerRow({
    super.key,
    required this.name,
    required this.runLabel,
    required this.offline,
    required this.dot,
    this.description,
    this.availableVersion,
    this.diskLow = false,
    this.selected = false,
    this.onTap,
    this.dotTooltip,
  });
  final String name, runLabel;
  final String? description, availableVersion, dotTooltip;
  final bool offline, diskLow, selected;

  /// Row dot: upgrade (pink), online (lime), offline (gray).
  final RaftComputerDot dot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => RaftInteractive(
    onPressed: onTap,
    semanticLabel: name,
    selected: selected,
    builder: (context, state) {
      final t = RaftTokens.of(context);
      final brutal = t.brutal;
      final hover = state.hovered && !selected;
      // Selected `border-line-strong bg-fill-muted shadow-raft-sm` /
      // brutal `border-black bg-brutal-pink shadow-brutal-sm`; hover the same
      // frame on `bg-white` (brutal). Elegant `data-active` = `bg-layer-panel
      // shadow-raft-sm ring-1 ring-line-muted/45`.
      final Color? fill;
      final Color border;
      List<BoxShadow>? shadow;
      if (brutal) {
        fill = selected
            ? t.product.brutalPink
            : hover
            ? Colors.white
            : null;
        border = selected || hover ? Colors.black : Colors.transparent;
        if (selected || hover) shadow = RaftShadowSet.brutalSm;
      } else {
        // Callsite hover classes win over the recipe's (tailwind-merge):
        // `hover:border-line-strong hover:bg-fill-muted hover:shadow-raft-sm`.
        fill = selected
            ? (t.dark ? t.colors['layer-card'] : t.colors['layer-panel'])
            : hover
            // `dark:hover:bg-ink-6` outranks the callsite hover fill.
            ? (t.dark ? t.colors['ink-6'] : t.colors['fill-muted'])
            : null;
        border = hover ? t.colors['line-strong']! : Colors.transparent;
        if (hover) shadow = t.themeShadows.sm.paintOrder;
        if (selected) {
          shadow = [
            if (!t.dark)
              BoxShadow(
                color: t.colors['line-muted']!.withValues(alpha: .45),
                spreadRadius: 1,
              ),
            ...t.themeShadows.sm.paintOrder,
          ];
        }
      }
      final ink = brutal ? Colors.black : t.colors['foreground-strong']!;
      final muted = raftPanelInk(t, .5, t.colors['foreground-muted']!);
      // Text inherits the item's line box: brutal `text-sm` (20/14),
      // elegant `text-[13px]` (19.5/13 = 1.5).
      final metaLine = brutal ? 11 * 20 / 14 : 11 * 1.5;
      final meta = raftCssText.merge(
        RaftTypography.mono(
          t,
          size: 11,
          line: metaLine,
          color: muted,
        ).copyWith(fontWeight: FontWeight.w500),
      );
      final orange = meta.copyWith(
        color: t.product.brutalOrange,
        fontWeight: FontWeight.w700,
      );
      final cardRoot = RaftCardRecipe.resolve(
        theme: raftRecipeTheme(t),
        states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
        tokens: RaftRecipeTokens(t),
      ).root;
      final cardBorder = cardRoot.borderWidth.top;
      // CSS paints a translucent fill (`dark:bg-ink-6`) over the sidebar,
      // never over the row's own shadow.
      final paint = fill == null || fill.a == 1
          ? fill
          : Color.alphaBlend(fill, t.sidebar);
      return Container(
        // The list owns `mb-1.5` and elegant's 6px bleed.
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: brutal ? 4 : 6),
        decoration: BoxDecoration(
          color: paint,
          borderRadius: brutal ? null : BorderRadius.circular(6),
          border: Border.all(color: border, width: brutal ? 2 : 1),
          boxShadow: shadow,
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 36,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: RaftRecipeCard(
                      child: Center(
                        child: RaftIcon(
                          RaftGlyph.monitor,
                          size: 18,
                          color: ink,
                        ),
                      ),
                    ),
                  ),
                  // `absolute -right-1 -top-1` against the card's padding box.
                  Positioned(
                    right: cardBorder - 4,
                    top: cardBorder - 4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: switch (dot) {
                          RaftComputerDot.upgrade => t.product.brutalPink,
                          RaftComputerDot.online => t.product.brutalLime,
                          RaftComputerDot.offline => raftGray400,
                        },
                        border: Border.all(
                          color: brutal
                              ? Colors.black
                              : t.colors['line-strong']!,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RaftCssText(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: raftCssText.merge(
                      RaftTypography.body(
                        t,
                        size: 14,
                        line: 20,
                        weight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                  if (description != null && description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 13.75,
                      child: RaftCssText(
                        description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: raftCssText.merge(
                          RaftTypography.body(
                            t,
                            size: 11,
                            line: 13.75,
                            weight: FontWeight.w500,
                            color: raftPanelInk(
                              t,
                              .6,
                              t.colors['foreground-muted']!,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  // The CSS line box is fractional (15.71 / 16.5); a
                  // paragraph would round it up and push the row's text.
                  SizedBox(
                    height: metaLine,
                    child: Row(
                      children: [
                        Flexible(
                          child: RaftCssText(
                            runLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: offline
                                ? meta.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: brutal
                                        ? Colors.black.withValues(alpha: .3)
                                        : t.colors['foreground-placeholder'],
                                  )
                                : meta,
                          ),
                        ),
                        if (availableVersion != null) ...[
                          const SizedBox(width: 6),
                          RaftCssText('→ v$availableVersion', style: orange),
                        ],
                        if (diskLow) ...[
                          const SizedBox(width: 6),
                          RaftCssText('Low disk', style: orange),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

enum RaftComputerDot { upgrade, online, offline }

/// AddMachineDialog machine-type option: `flex-1 flex items-center gap-2
/// border p-3 text-left rounded-md theme-brutal:rounded-none
/// theme-brutal:border-2`; selected `border-line-muted theme-brutal:border-black
/// bg-primary-soft text-primary-strong font-bold
/// shadow-[0_0_0_1px_var(--primary-edge)] theme-brutal:bg-soft-signal
/// theme-brutal:text-black theme-brutal:shadow-brutal-sm`; the disabled
/// "coming soon" card is dashed and muted. Title `text-sm font-bold
/// uppercase`, description `text-xs font-normal normal-case`.
class RaftMachineTypeOption extends StatelessWidget {
  const RaftMachineTypeOption({
    super.key,
    required this.glyph,
    required this.title,
    required this.description,
    this.selected = false,
    this.disabled = false,
    this.onPressed,
  });
  final RaftGlyph glyph;
  final String title, description;
  final bool selected, disabled;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => RaftInteractive(
    onPressed: disabled ? null : onPressed,
    selected: selected,
    semanticLabel: title,
    builder: (context, state) {
      final t = RaftTokens.of(context);
      final brutal = t.brutal;
      final Color fill;
      final Color border;
      List<BoxShadow>? shadow;
      Color titleInk, descInk, iconInk;
      if (disabled) {
        fill = brutal ? Colors.white : t.colors['layer-panel']!;
        border = brutal
            ? Colors.black.withValues(alpha: .3)
            : t.colors['line-muted']!;
        titleInk = brutal
            ? Colors.black.withValues(alpha: .3)
            : t.colors['foreground-muted']!;
        descInk = brutal
            ? Colors.black.withValues(alpha: .25)
            : t.colors['foreground-muted']!;
        iconInk = descInk;
      } else if (selected) {
        fill = brutal ? t.product.softSignal : t.colors['primary-soft']!;
        border = brutal ? Colors.black : t.colors['line-muted']!;
        shadow = brutal
            ? RaftShadowSet.brutalSm
            : [BoxShadow(color: t.colors['primary-edge']!, spreadRadius: 1)];
        titleInk = brutal ? Colors.black : t.colors['primary-strong']!;
        descInk = brutal
            ? Colors.black.withValues(alpha: .5)
            : t.colors['primary-strong']!.withValues(alpha: .7);
        iconInk = titleInk;
      } else {
        fill = brutal ? Colors.white : t.colors['layer-panel']!;
        border = state.hovered
            ? (brutal ? Colors.black : t.colors['line-strong']!)
            : (brutal
                  ? Colors.black.withValues(alpha: .3)
                  : t.colors['line-muted']!);
        titleInk = brutal ? Colors.black : t.colors['foreground-strong']!;
        descInk = brutal
            ? Colors.black.withValues(alpha: .5)
            : t.colors['foreground-muted']!;
        iconInk = titleInk;
      }
      // Composite translucent tints (`bg-primary-soft`) over the dialog
      // surface so the ring shadow does not show through them.
      final surface = Color.alphaBlend(
        fill,
        brutal ? Colors.white : t.colors['layer-panel']!,
      );
      return CustomPaint(
        foregroundPainter: disabled
            ? _DashedBorder(
                color: border,
                width: brutal ? 2 : 1,
                radius: brutal ? 0 : 6,
              )
            : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: brutal ? null : BorderRadius.circular(6),
            border: disabled
                ? null
                : Border.all(color: border, width: brutal ? 2 : 1),
            boxShadow: shadow,
          ),
          child: Row(
            children: [
              RaftIcon(glyph, size: 18, color: iconInk),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RaftCssText(
                      title.toUpperCase(),
                      style: raftCssText.merge(
                        RaftTypography.body(
                          t,
                          size: 14,
                          line: 20,
                          weight: FontWeight.w700,
                          color: titleInk,
                        ),
                      ),
                    ),
                    RaftCssText(
                      description,
                      style: raftCssText.merge(
                        RaftTypography.body(
                          t,
                          size: 12,
                          line: 16,
                          color: descInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({
    required this.color,
    required this.width,
    this.radius = 0,
  });
  final Color color;
  final double width, radius;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    // CSS dashed: dash length = 2 * width for borders >= 2px, 3px for 1px.
    final dash = width >= 2 ? width * 2 : 3.0;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash * 2) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.width != width || old.radius != radius;
}

/// Sidebar.tsx computers mode body: `px-2 py-3` scroll column with the
/// heading, [rows] (`mb-1.5` each; Elegant rows shifted by
/// `-mx-(--sidebar-row-inset-x,6px)` under the callsite `w-full`), and the
/// SidebarRowsSkeleton / "No computers yet" states.
class RaftComputerSidebarList extends StatelessWidget {
  const RaftComputerSidebarList({
    super.key,
    required this.label,
    required this.count,
    required this.rows,
    required this.loading,
    required this.emptyText,
    this.errorText,
    this.onAdd,
    this.addKey,
    this.addLabel = 'Add computer',
    this.listKey,
  });
  final String label, emptyText, addLabel;
  final int count;
  final List<Widget> rows;
  final bool loading;
  final String? errorText;
  final VoidCallback? onAdd;
  final Key? addKey, listKey;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final bleed = t.brutal ? 0.0 : 6.0;
    // SidebarSectionDescription: `px-2 text-xs font-mono leading-snug
    // text-foreground-muted theme-brutal:text-black/50`.
    final description = RaftTypography.mono(
      t,
      size: 12,
      line: 16.5,
      color: t.brutal
          ? Colors.black.withValues(alpha: .5)
          : t.colors['foreground-muted'],
    );
    return ListView(
      key: listKey,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      children: [
        RaftComputerSidebarHeading(
          label: label,
          count: count,
          addKey: addKey,
          addLabel: addLabel,
          onAdd: onAdd,
        ),
        if (errorText != null)
          Semantics(liveRegion: true, child: Text(errorText!)),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Transform.translate(offset: Offset(-bleed, 0), child: row),
          ),
        if (rows.isEmpty)
          loading
              ? Column(
                  children: [
                    for (var i = 0; i < 2; i++)
                      // SkeletonRow `gap-1.5 px-2 py-2`, avatar size-[18px].
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: RaftSkeletonRow(
                          avatar: true,
                          gap: 6,
                          lineFractions: [.6],
                        ),
                      ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(emptyText, style: description),
                ),
      ],
    );
  }
}

/// Desktop SidebarRoot edge: `border-r border-line-muted
/// theme-brutal:border-r-2 theme-brutal:border-black` inside the column.
class RaftSidebarColumnEdge extends StatelessWidget {
  const RaftSidebarColumnEdge({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final width = t.brutal ? 2.0 : 1.0;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: t.brutal ? Colors.black : t.colors['line-muted']!,
            width: width,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(right: width),
        child: child,
      ),
    );
  }
}
