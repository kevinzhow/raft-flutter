// List and section primitives from the Web client's components/ui:
// SurfaceListItem (raft-ui Card + product overrides), AvatarListRow,
// SectionEyebrow and SectionHeader. Class lists are cited per widget.
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'form_controls.dart';
import 'icons.dart';
import 'recipes/button_variants.g.dart';

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
              : (t.brutal ? RaftPrimitiveColors.black : t.semantic.foregroundStrong);
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
  });
  final String label;
  final bool checked, disabled, italic, reserveLeadingSlot;
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
  });

  final String title;
  final List<RaftSelectionOption> options;

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
                  _ClearAction(label: clearLabel, style: eyebrow, onTap: onClear!),
              ],
            ),
          ),
        if (searchController != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border(bottom: divider)),
            child: RaftTextInput(
              controller: searchController,
              focusNode: searchFocusNode,
              autofocus: true,
              hintText: searchPlaceholder,
              onChanged: onSearchChanged,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              style: TextStyle(fontFamily: t.monoFont, fontSize: 12, height: 16 / 12),
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
                          option: options[i],
                          last: i == options.length - 1,
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
    // SelectionPopover mounts Card. Its shadow-raft-md utility survives
    // the caller's shadow-brutal/sm class and wins the compiled CSS order.
    // The generic Card theme shadow therefore supplies both tone and layers.
    final shadows = [
      for (final l in t.themeShadows.md.layers.reversed)
        if (!l.inset)
          BoxShadow(
            color: l.color,
            offset: l.offset,
            blurRadius: raftCssBlurRadius(l.blur),
            spreadRadius: l.spread,
          ),
    ];
    return CustomPaint(
      painter: RaftOuterShadowPainter(shadows, BorderRadius.zero),
      child: Container(
        width: width,
        constraints: const BoxConstraints(minWidth: 220),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: t.brutal ? RaftPrimitiveColors.white : s.layerPanel,
          border: t.brutal
              ? Border.all(color: black, width: 2)
              : Border.all(color: s.lineMuted),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: s.foreground),
          child: body,
        ),
      ),
    );
  }
}

class _ClearAction extends StatelessWidget {
  const _ClearAction({required this.label, required this.style, required this.onTap});
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
  const _SelectionRow({required this.option, required this.last});
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
