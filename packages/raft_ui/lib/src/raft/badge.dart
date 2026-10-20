// raft-ui 0.7.1 `Badge` (dist `badge`): three appearances.
//   solid    a 20px sticker (ink inset ring, die-cut outer ring) for the unread count and the @ marker;
//   soft     a 22px chip on the `*-soft` fill, semibold text (agent state chips hold a Status here);
//   outline  a 22px mono chip with a hairline inset ring.
// Hover lays the pressed overlay over the resting fill; a disabled badge reads `fill-muted`.
import 'package:flutter/material.dart';

import '../control_typography.dart';
import '../design_primitives.dart';
import '../icons.dart';
import '../recipes/badge.g.dart';
import '../text_scaling.dart' show RaftChrome;
import '../theme.dart';
import '../tokens/tokens.dart';
import 'avatar.dart' show raftStickerEdge;
import 'css_box.dart';
import 'text_baseline.dart';
import 'ui_tokens.dart';

/// Resolved paint of one appearance and variant in one state.
@immutable
class RaftBadgeColors {
  const RaftBadgeColors({
    required this.fill,
    required this.foreground,
    this.ink,
    this.edge,
    this.hairline,
  });

  /// Background; transparent for the outline appearance at rest.
  final Color fill;
  final Color foreground;

  /// Solid: the 1.5px ink inset ring, and the die-cut outer ring (`sticker-edge`, clear in light mode).
  final Color? ink, edge;

  /// Outline: the 1px inset ring.
  final Color? hairline;

  static RaftBadgeColors resolve(
    RaftUiColors ui,
    RaftBadgeRecipeAppearance appearance,
    RaftBadgeRecipeVariant variant, {
    bool hovered = false,
    bool disabled = false,
  }) {
    const clear = Color(0x00000000);
    if (disabled) {
      return RaftBadgeColors(
        fill: ui.fillMuted,
        foreground: ui.foregroundDisabled,
      );
    }
    Color over(Color fill, Color pressed) =>
        hovered ? Color.alphaBlend(pressed, fill) : fill;
    // Translucent fills (dark `fill-muted`) composite over the page the way Blink does (see [raftChromeBlend]).
    Color opaque(Color c) => c.a < 1 ? raftChromeBlend(c, ui.layerCanvas) : c;
    switch (appearance) {
      case RaftBadgeRecipeAppearance.solid:
        final fill = switch (variant) {
          RaftBadgeRecipeVariant.default_ => ui.stickerPaper,
          RaftBadgeRecipeVariant.muted => ui.inactive,
          RaftBadgeRecipeVariant.primary => ui.brand,
          RaftBadgeRecipeVariant.information => ui.info,
          RaftBadgeRecipeVariant.accent => ui.attention,
          RaftBadgeRecipeVariant.success => ui.success,
          RaftBadgeRecipeVariant.warning => ui.warning,
          RaftBadgeRecipeVariant.danger => ui.danger,
        };
        return RaftBadgeColors(
          fill: over(fill, ui.stickerPressed),
          foreground: ui.stickerInk,
          ink: ui.stickerInk,
          edge: raftStickerEdge(ui),
        );
      case RaftBadgeRecipeAppearance.soft:
        final fill = switch (variant) {
          RaftBadgeRecipeVariant.default_ => opaque(ui.fillMuted),
          RaftBadgeRecipeVariant.muted => opaque(ui['inactive-soft']),
          RaftBadgeRecipeVariant.primary => opaque(ui['brand-soft']),
          RaftBadgeRecipeVariant.information => opaque(ui['info-soft']),
          RaftBadgeRecipeVariant.accent => opaque(ui['attention-soft']),
          RaftBadgeRecipeVariant.success => opaque(ui['success-soft']),
          RaftBadgeRecipeVariant.warning => opaque(ui['warning-soft']),
          RaftBadgeRecipeVariant.danger => opaque(ui['danger-soft']),
        };
        return RaftBadgeColors(
          fill: over(fill, ui.fillPressed),
          foreground: ui.foreground,
        );
      case RaftBadgeRecipeAppearance.outline:
        final foreground = switch (variant) {
          RaftBadgeRecipeVariant.primary => ui['brand-strong'],
          RaftBadgeRecipeVariant.information => ui['info-strong'],
          RaftBadgeRecipeVariant.accent => ui['attention-strong'],
          RaftBadgeRecipeVariant.success => ui['success-strong'],
          RaftBadgeRecipeVariant.warning => ui['warning-strong'],
          RaftBadgeRecipeVariant.danger => ui['danger-strong'],
          _ => ui.foregroundMuted,
        };
        // Translucent tokens over the page: composite them the way Blink does (see [raftChromeBlend]).
        final backdrop = hovered
            ? Color.alphaBlend(ui.fillPressed, ui.layerCanvas)
            : ui.layerCanvas;
        Color opaqueOver(Color c) => c.a < 1 ? raftChromeBlend(c, backdrop) : c;
        return RaftBadgeColors(
          fill: hovered ? ui.fillPressed : clear,
          foreground: opaqueOver(foreground),
          hairline: opaqueOver(ui.lineHairline),
        );
    }
  }
}

/// raft-ui `Badge`. A count or an @ marker is a solid badge ([label] or [glyph]); [leading] sits before the
/// label with a 4px gap (a [RaftStatus] in an agent state chip).
class RaftBadge extends StatelessWidget {
  const RaftBadge({
    super.key,
    this.label = '',
    this.appearance = RaftBadgeRecipeAppearance.solid,
    this.variant = RaftBadgeRecipeVariant.default_,
    this.leading,
    this.glyph,
    this.onPressed,
    this.disabled = false,
    this.foreground,
    this.radius,
    this.center = false,
    this.fontFamily,
    this.semanticLabel,
  });

  final String label;
  final RaftBadgeRecipeAppearance appearance;
  final RaftBadgeRecipeVariant variant;
  final Widget? leading;

  /// A Lucide glyph before the label (`[&_svg]:size-3.5`, 13px in the solid appearance).
  final RaftGlyph? glyph;

  /// Rendered as a `<button>` (`render={<button/>}`): enables the hover overlay.
  final VoidCallback? onPressed;

  /// `disabled:` styling (`fill-muted`, `foreground-disabled`, no ring); only meaningful for a button.
  final bool disabled;

  /// Callsite overrides (`text-*`, `rounded-[*]`, `justify-center`).
  final Color? foreground;
  final double? radius;
  final bool center;

  /// Inherited face where the host overrides the document font (the hands-feedback root's `system-ui`).
  final String? fontFamily;

  /// `role="img"` + `aria-label` for a badge that means something on its own (`1 unread`).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final interactive = onPressed != null && !disabled;
    if (onPressed == null) return _body(context, hovered: false);
    return RaftInteractive(
      onPressed: disabled ? null : onPressed,
      semanticLabel: semanticLabel,
      builder: (context, st) =>
          _body(context, hovered: (st.hovered || st.pressed) && interactive),
    );
  }

  Widget _body(BuildContext context, {required bool hovered}) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final solid = appearance == RaftBadgeRecipeAppearance.solid;
    final outline = appearance == RaftBadgeRecipeAppearance.outline;
    final colors = RaftBadgeColors.resolve(
      ui,
      appearance,
      variant,
      hovered: hovered,
      disabled: disabled,
    );
    final fg = foreground != null && !disabled
        ? foreground!
        : colors.foreground;
    // `font-mono` for the outline appearance and the solid accent count (`text-mono-meta`).
    final mono = outline || (solid && variant == RaftBadgeRecipeVariant.accent);
    var style = t.scale(
      mono ? RaftTypeScale.monoMeta : RaftTypeScale.caption,
      weight: solid
          ? FontWeight.w700
          : outline
          ? FontWeight.w400
          : FontWeight.w600,
      mono: mono,
      color: fg,
    );
    if (solid) {
      style = style.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );
    }
    if (fontFamily != null) {
      style = style.copyWith(
        fontFamily: fontFamily,
        fontFamilyFallback: const [],
      );
    }
    style = RaftControlTypography.of(context, style);
    final iconSize = solid ? 13.0 : 14.0;
    final baselineShift = raftBaselineShift(
      mono ? RaftFontMetrics.spaceMono : RaftFontMetrics.spaceGrotesk,
      12,
      16,
    );
    final children = <Widget>[
      if (leading != null) leading!,
      if (glyph != null) RaftIcon(glyph!, size: iconSize, color: fg),
      if (label.isNotEmpty)
        Flexible(
          child: RaftBaselineShift(
            dy: baselineShift,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              // Badges are fixed chrome: text growth is bounded.
              textScaler: RaftChrome.boundedScalerOf(context),
              style: style,
            ),
          ),
        ),
    ];
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          children[i],
        ],
      ],
    );
    final ringed = solid && !disabled;
    // `h-5` / `h-[22px]` is a minimum here: at a larger text scale the label keeps its whole line box (a fixed
    // height would clip the descenders); at scale 1 the badge is exactly 20 / 22.
    // Both radii are theme tokens, and the official React specimen confirms the
    // mapping: a solid badge is `rounded-sticker` (4 for Raft) and an outline
    // badge `rounded-chip` (6). Elegant and Brutal then square or soften them.
    final box = RaftCssBox(
      radius: radius ??
          (solid
              ? t.size('radius.sticker', fallback: 4)
              : t.size('radius.chip', fallback: 6)),
      fill: colors.fill,
      insetRingWidth: ringed ? 1.5 : (outline && !disabled ? 1 : 0),
      insetRingColor: ringed ? colors.ink : colors.hairline,
      rings: ringed && colors.edge != null
          ? [RaftRing(1.5, colors.edge!)]
          : const [],
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: DefaultTextStyle.merge(
        style: style,
        // `min-w-5` of the solid badge is the 20px minimum (8 inside the 6px padding); content is centred.
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: solid ? 8 : 0,
            minHeight: solid ? 20 : 22,
          ),
          child: Center(widthFactor: 1, heightFactor: 1, child: row),
        ),
      ),
    );
    return semanticLabel == null
        ? box
        : Semantics(label: semanticLabel, image: onPressed == null, child: box);
  }
}
