// List and section primitives from the Web client's components/ui:
// SurfaceListItem (raft-ui Card + product overrides), AvatarListRow,
// SectionEyebrow and SectionHeader. Class lists are cited per widget.
import 'package:flutter/material.dart';

import 'recipe_surface.dart';
import 'recipes/card.g.dart';
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
  });

  final Widget child;
  final bool selected;
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
    final card = RaftCardRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: rt,
    ).root;
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
    BoxDecoration override(BoxDecoration d) {
      final s = t.semantic;
      if (t.brutal) {
        return d.copyWith(
          color: widget.selected
              ? t.product.brutalCyan.withValues(alpha: .15)
              : RaftPrimitiveColors.white,
          border: Border.all(color: RaftPrimitiveColors.black, width: 2),
          boxShadow: widget.selected || hover
              ? shadow(RaftProductShadows.shadowBrutalSm)
              : null,
        );
      }
      final width = (d.border as Border?)?.top.width ?? 1;
      return d.copyWith(
        color: widget.selected ? s.infoMuted : s.layerCard,
        border: Border.all(
          width: width,
          color: widget.selected
              ? s.info
              : hover
              ? s.lineStrong
              : s.lineMuted,
        ),
        boxShadow: widget.selected || hover ? shadow(t.themeShadows.sm) : null,
      );
    }

    Widget item = RaftRecipeBox(
      style: card,
      tokens: rt,
      width: double.infinity,
      padding: widget.padding,
      clip: true,
      decorationOverride: override,
      child: widget.child,
    );
    if (interactive) {
      item = MouseRegion(
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

/// Web `AvatarListRow` (`align="center"`): a [RaftSurfaceListItem] with
/// `px-3 py-2`, avatar, name (`truncate text-sm font-bold
/// text-foreground-strong theme-brutal:text-black`) + subtitle (`text-xs
/// font-mono text-foreground-muted theme-brutal:text-black/50`) in a
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
  });

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
      fontWeight: FontWeight.w700,
      color: t.brutal ? RaftPrimitiveColors.black : s.foregroundStrong,
    );
    final subtitleStyle = TextStyle(
      fontFamily: t.monoFont,
      fontWeight: FontWeight.w400,
      fontSize: 12,
      height: 16 / 12,
      color: t.brutal
          ? RaftPrimitiveColors.black.withValues(alpha: .5)
          : s.foregroundMuted,
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
    Widget nameText() => Text(
      name,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: nameStyle,
    );
    final text = subtitle == null
        ? nameText()
        : LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context);
              double widthOf(String v, TextStyle st) => (TextPainter(
                text: TextSpan(
                  text: v,
                  style: DefaultTextStyle.of(context).style.merge(st),
                ),
                textDirection: TextDirection.ltr,
                textScaler: scale,
                maxLines: 1,
              )..layout()).width;
              final fits =
                  widthOf(name, nameStyle) + 8 + widthOf(subtitle!, subtitleStyle) <=
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
    return RaftSurfaceListItem(
      selected: selected,
      onTap: onTap,
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
            Row(mainAxisSize: MainAxisSize.min, children: gapped(actionContent)),
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
  });

  final String label;
  final Widget? icon;
  final int? count;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Row(
      children: [
        Expanded(
          child: Row(
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
                                  ? RaftPrimitiveColors.black.withValues(
                                      alpha: .4,
                                    )
                                  : t.semantic.foregroundPlaceholder,
                            ),
                          ),
                        ],
                ),
              ),
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 8),
          RaftInlineBox(child: action!),
        ],
      ],
    );
  }
}
