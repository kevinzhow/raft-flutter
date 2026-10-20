// raft-ui 0.7.1 `Button` (dist `buttonVariants`): stickers (primary / accent / warning / danger), outline paper
// buttons, ghost, on-frame and link. Sizes 32 / 44 / 52 and the icon squares. Press and hover lay one overlay over
// the resting colour; disabled and loading read `fill-muted`; keyboard focus draws the `focus-ring`.
import 'package:flutter/material.dart';

import '../control_typography.dart';
import '../css_opacity.dart';
import '../design_primitives.dart';
import '../icons.dart';
import '../localization.dart';
import '../recipes/button_variants.g.dart';
import '../theme.dart';
import '../tokens/tokens.dart';
import 'css_box.dart';
import 'pixel_spinner.dart';
import 'ui_tokens.dart';

/// `variant` axis of `buttonVariants`. `accent` and `primary` are the same pink sticker.
enum RaftButtonVariant {
  primary,
  accent,
  warning,
  danger,
  standard,
  outline,
  information,
  muted,
  success,
  dangerSecondary,
  dangerOutline,
  ghost,
  onFrame,
  link;

  bool get isSticker =>
      this == primary || this == accent || this == warning || this == danger;
  bool get isOutline => switch (this) {
    standard ||
    outline ||
    information ||
    muted ||
    success ||
    dangerSecondary ||
    dangerOutline => true,
    _ => false,
  };
  bool get isTransparent => this == ghost || this == onFrame || this == link;

  /// The former generated recipe axis.
  static RaftButtonVariant fromRecipe(RaftButtonRecipeVariant v) => switch (v) {
    RaftButtonRecipeVariant.primary => primary,
    RaftButtonRecipeVariant.default_ => standard,
    RaftButtonRecipeVariant.information => information,
    RaftButtonRecipeVariant.muted => muted,
    RaftButtonRecipeVariant.accent => accent,
    RaftButtonRecipeVariant.warning => warning,
    RaftButtonRecipeVariant.success => success,
    RaftButtonRecipeVariant.outline => outline,
    RaftButtonRecipeVariant.ghost => ghost,
    RaftButtonRecipeVariant.link => link,
    RaftButtonRecipeVariant.dangerSecondary => dangerSecondary,
    RaftButtonRecipeVariant.danger => danger,
    RaftButtonRecipeVariant.dangerOutline => dangerOutline,
  };

  static RaftButtonVariant fromControl(RaftControlVariant v) => switch (v) {
    RaftControlVariant.surface => standard,
    RaftControlVariant.primary => primary,
    RaftControlVariant.accent => accent,
    RaftControlVariant.outline => outline,
    RaftControlVariant.ghost => ghost,
    RaftControlVariant.danger => danger,
  };
}

/// `size` axis of `buttonVariants`: `xs`, `sm` and `md` are all 32px; `xl` is the 52px full-width CTA.
enum RaftButtonSize {
  xs,
  sm,
  md,
  lg,
  xl,
  inline,
  iconXs,
  iconSm,
  iconMd,
  iconLg;

  bool get isIcon =>
      this == iconXs || this == iconSm || this == iconMd || this == iconLg;

  static RaftButtonSize fromRecipe(RaftButtonRecipeSize s) => switch (s) {
    RaftButtonRecipeSize.xs => xs,
    RaftButtonRecipeSize.sm => sm,
    RaftButtonRecipeSize.md => md,
    RaftButtonRecipeSize.lg => lg,
    RaftButtonRecipeSize.inline => inline,
    RaftButtonRecipeSize.iconXs => iconXs,
    RaftButtonRecipeSize.iconSm => iconSm,
    RaftButtonRecipeSize.iconMd => iconMd,
    RaftButtonRecipeSize.iconLg => iconLg,
  };
}

/// The geometry of one size (and the on-frame compound that makes xs/sm/md 36px).
class RaftButtonMetrics {
  const RaftButtonMetrics({
    required this.height,
    required this.paddingX,
    required this.iconStartPaddingLeft,
    required this.iconEndPaddingRight,
    required this.text,
    required this.icon,
    this.gap = 8,
    this.square = false,
  });

  final double height,
      paddingX,
      iconStartPaddingLeft,
      iconEndPaddingRight,
      icon,
      gap;
  final RaftTypeStyle text;
  final bool square;

  static const _md = RaftButtonMetrics(
    height: 32,
    paddingX: 12,
    iconStartPaddingLeft: 10,
    iconEndPaddingRight: 10,
    text: RaftTypeScale.footnote,
    icon: 16,
  );
  static const _lg = RaftButtonMetrics(
    height: 44,
    paddingX: 16,
    iconStartPaddingLeft: 14,
    iconEndPaddingRight: 14,
    text: RaftTypeScale.subhead,
    icon: 18,
  );
  static const _xl = RaftButtonMetrics(
    height: 52,
    paddingX: 20,
    iconStartPaddingLeft: 20,
    iconEndPaddingRight: 20,
    text: RaftTypeScale.body,
    icon: 18,
  );
  static const _onFrame = RaftButtonMetrics(
    height: 36,
    paddingX: 10,
    iconStartPaddingLeft: 10,
    iconEndPaddingRight: 10,
    text: RaftTypeScale.subhead,
    icon: 16,
  );
  static const _iconMd = RaftButtonMetrics(
    height: 32,
    paddingX: 0,
    iconStartPaddingLeft: 0,
    iconEndPaddingRight: 0,
    text: RaftTypeScale.footnote,
    icon: 18,
    square: true,
  );
  static const _iconLg = RaftButtonMetrics(
    height: 44,
    paddingX: 0,
    iconStartPaddingLeft: 0,
    iconEndPaddingRight: 0,
    text: RaftTypeScale.subhead,
    icon: 22,
    square: true,
  );
  static const _iconOnFrame = RaftButtonMetrics(
    height: 36,
    paddingX: 0,
    iconStartPaddingLeft: 0,
    iconEndPaddingRight: 0,
    text: RaftTypeScale.subhead,
    icon: 20,
    square: true,
  );

  /// Metrics for [size] under the current theme.
  ///
  /// Heights come from the contract's control tokens, so a theme that sizes its
  /// controls differently reaches the button. The table stays the source of the
  /// parts every look agrees on -- paddings, icon sizes, which type style a size
  /// uses -- because measuring the three looks showed those are equal in all of
  /// them (form, not theme).
  ///
  /// Verified values, from the Raft React specimen's DOM and from resolving the
  /// recipe on a57b9dab:
  ///   sm  Raft 32 / Elegant 28 / Brutal 28
  ///   md  Raft 32 / Elegant 32 / Brutal 32   (form: equal, so no token needed)
  ///   lg  Raft 44 / Elegant 36 / Brutal 40   (theme value)
  static RaftButtonMetrics of(
    RaftButtonSize size,
    RaftButtonVariant variant,
    RaftTokens t,
  ) {
    final onFrame = variant == RaftButtonVariant.onFrame;
    // Each size reads its own token. s/m/l are distinct tokens in the contract
    // even though Raft's xs/sm/md happen to share one box.
    final sm = t.size('size.control.sm', fallback: 32);
    final md = t.size('size.control.md', fallback: 32);
    final lg = t.size('size.control.lg', fallback: 44);
    final frame = t.size('size.control.onFrame', fallback: 36);

    RaftButtonMetrics sized(double height, RaftButtonMetrics base) =>
        height == base.height
            ? base
            : RaftButtonMetrics(
                height: height,
                paddingX: base.paddingX,
                iconStartPaddingLeft: base.iconStartPaddingLeft,
                iconEndPaddingRight: base.iconEndPaddingRight,
                text: base.text,
                icon: base.icon,
                gap: base.gap,
                square: base.square,
              );

    return switch (size) {
      // xs and sm read the small token; md reads the medium one. Raft renders
      // all three at one height, which the Raft pack's equal token values
      // reproduce, while Elegant and Brutal can differ per step.
      RaftButtonSize.xs => sized(sm, _md),
      RaftButtonSize.sm => sized(sm, _md),
      RaftButtonSize.md => onFrame ? sized(frame, _onFrame) : sized(md, _md),
      RaftButtonSize.lg => sized(lg, _lg),
      // xl exists only in raft-ui 0.7.1 (52); the pre-theme looks never had it,
      // so there is no Elegant/Brutal value to read. Keep Raft's box exactly
      // and add the family delta relative to lg, which keeps xl consistent with
      // whatever lg the theme chose instead of silently equalising them.
      RaftButtonSize.xl => sized(lg + (_xl.height - 44), _xl),
      RaftButtonSize.inline => _md,
      RaftButtonSize.iconXs ||
      RaftButtonSize.iconSm ||
      RaftButtonSize.iconMd =>
        onFrame ? sized(frame, _iconOnFrame) : sized(md, _iconMd),
      RaftButtonSize.iconLg => sized(lg, _iconLg),
    };
  }
}

/// Resolved colours of one variant in one state.
class RaftButtonColors {
  const RaftButtonColors({
    required this.fill,
    required this.border,
    required this.foreground,
    this.ringEdge,
  });
  final Color fill, border, foreground;

  /// `ring-sticker-edge`: the die-cut ring outside a sticker.
  final Color? ringEdge;

  static RaftButtonColors resolve(
    RaftUiColors ui,
    RaftButtonVariant variant, {
    required bool disabled,
    required bool overlay,
    bool iconSize = false,
  }) {
    // `disabled:border-transparent disabled:bg-transparent`: on-frame always, ghost only as an icon button.
    if (disabled &&
        (variant == RaftButtonVariant.onFrame ||
            (variant == RaftButtonVariant.ghost && iconSize))) {
      return RaftButtonColors(
        fill: const Color(0x00000000),
        border: const Color(0x00000000),
        foreground: ui.foregroundDisabled,
      );
    }
    if (disabled) {
      if (variant == RaftButtonVariant.link) {
        return RaftButtonColors(
          fill: const Color(0x00000000),
          border: const Color(0x00000000),
          foreground: ui.foregroundDisabled,
        );
      }
      return RaftButtonColors(
        fill: ui.fillMuted,
        border: raftChromeBlend(ui.lineHairline, ui.fillMuted),
        foreground: raftChromeBlend(ui.foregroundDisabled, ui.fillMuted),
      );
    }
    Color over(Color fill, Color pressed) =>
        overlay ? raftChromeBlend(pressed, fill) : fill;
    const clear = Color(0x00000000);
    return switch (variant) {
      RaftButtonVariant.primary || RaftButtonVariant.accent => RaftButtonColors(
        fill: over(ui.attention, ui.stickerPressed),
        border: ui.stickerInk,
        foreground: ui.stickerInk,
        ringEdge: ui.stickerEdge,
      ),
      RaftButtonVariant.warning => RaftButtonColors(
        fill: over(ui.warning, ui.stickerPressed),
        border: ui.stickerInk,
        foreground: ui.stickerInk,
        ringEdge: ui.stickerEdge,
      ),
      RaftButtonVariant.danger => RaftButtonColors(
        fill: over(ui.danger, ui.stickerPressed),
        border: ui.stickerInk,
        foreground: ui.stickerInk,
        ringEdge: ui.stickerEdge,
      ),
      RaftButtonVariant.dangerSecondary ||
      RaftButtonVariant.dangerOutline => RaftButtonColors(
        fill: over(ui.layerCard, ui.fillPressed),
        border: ui.lineStrong,
        foreground: ui.dangerStrong,
      ),
      RaftButtonVariant.ghost => RaftButtonColors(
        fill: overlay ? ui.fillPressed : clear,
        border: clear,
        foreground: ui.foreground,
      ),
      RaftButtonVariant.onFrame => RaftButtonColors(
        fill: overlay ? ui.fillFramePressed : clear,
        border: clear,
        foreground: ui.foregroundOnFrame,
      ),
      RaftButtonVariant.link => RaftButtonColors(
        fill: clear,
        border: clear,
        foreground: ui.foreground,
      ),
      _ => RaftButtonColors(
        fill: over(ui.layerCard, ui.fillPressed),
        border: ui.lineStrong,
        foreground: ui.foreground,
      ),
    };
  }
}

/// raft-ui `Button`. [uiVariant] / [uiSize] are the 0.7.1 axes; the older [variant] / [tone] / [size] /
/// [visualHeight] parameters map onto them for call sites that have not been converted.
class RaftButton extends StatelessWidget {
  const RaftButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.glyph,
    this.busy = false,
    this.secondary = false,
    this.destructive = false,
    this.variant,
    this.tone,
    this.size,
    this.uiVariant,
    this.uiSize,
    this.visualHeight = RaftMetrics.buttonMd,
    this.expand = false,
    this.focusNode,
    this.tooltip,
    this.semanticLabel,
    this.foreground,
    this.iconInlineStart = true,
    this.opacityCompositing = RaftOpacityCompositing.layer,
    this.leading,
    this.gap,
    this.iconInlineEnd = false,
  });

  /// Visible text. Empty with an icon renders the icon square when [uiSize] is an icon size.
  final String label;

  /// A custom leading node (a brand mark) before the label, separated by [gap] (default 8).
  final Widget? leading;
  final double? gap;

  /// Whether the icon is `data-icon="inline-start"` (the smaller start padding).
  final bool iconInlineStart;

  /// The icon follows the label (`data-icon="inline-end"`).
  final bool iconInlineEnd;

  /// Explicit caller text/icon colour; null keeps the variant's.
  final Color? foreground;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Lucide glyph; wins over [icon].
  final RaftGlyph? glyph;
  final bool busy, secondary, destructive;

  /// Legacy variant axis; mapped onto [RaftButtonVariant].
  final RaftControlVariant? variant;

  /// Legacy recipe variant (wins over [variant]).
  final RaftButtonRecipeVariant? tone;

  /// Legacy recipe size; when null it follows [visualHeight].
  final RaftButtonRecipeSize? size;

  /// 0.7.1 variant / size; win over the legacy parameters.
  final RaftButtonVariant? uiVariant;
  final RaftButtonSize? uiSize;
  final double visualHeight;

  /// `w-full` (stretch to the parent width; content stays centered).
  final bool expand;
  final FocusNode? focusNode;
  final String? tooltip;

  /// Explicit authored aria-label.
  final String? semanticLabel;

  /// Kept for call sites; the 0.7.1 disabled style is not an opacity.
  final RaftOpacityCompositing opacityCompositing;

  RaftButtonVariant get resolvedVariant =>
      uiVariant ??
      (tone != null
          ? RaftButtonVariant.fromRecipe(tone!)
          : RaftButtonVariant.fromControl(
              variant ??
                  (destructive
                      ? RaftControlVariant.danger
                      : secondary
                      ? RaftControlVariant.outline
                      : RaftControlVariant.accent),
            ));

  RaftButtonSize get resolvedSize =>
      uiSize ??
      (size != null
          ? RaftButtonSize.fromRecipe(size!)
          : (visualHeight <= 32 ? RaftButtonSize.md : RaftButtonSize.lg));

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final variantValue = resolvedVariant;
    final sizeValue = resolvedSize;
    final metrics = RaftButtonMetrics.of(sizeValue, variantValue, t);
    final text = raftText(context, label);
    return RaftInteractive(
      onPressed: onPressed,
      busy: busy,
      focusNode: focusNode,
      tooltip: tooltip,
      semanticLabel: semanticLabel ?? (busy ? text : null),
      builder: (context, st) {
        final disabled = onPressed == null || busy;
        final colors = RaftButtonColors.resolve(
          ui,
          variantValue,
          iconSize: sizeValue.isIcon,
          disabled: disabled,
          overlay: (st.hovered || st.pressed) && !disabled,
        );
        final fg = foreground ?? colors.foreground;
        final inline = sizeValue == RaftButtonSize.inline;
        final borderWidth = inline ? 0.0 : _borderWidth(context);
        final iconSize = metrics.icon;
        final gapValue = gap ?? (inline ? 4.0 : metrics.gap);

        Widget? iconWidget;
        if (glyph != null) {
          iconWidget = RaftIcon(glyph!, size: iconSize, color: fg);
        } else if (icon != null) {
          iconWidget = RaftSymbol(icon!, size: iconSize, color: fg);
        }

        TextStyle labelStyle = t.scale(
          metrics.text,
          weight: FontWeight.w700,
          color: fg,
        );
        labelStyle = RaftControlTypography.of(context, labelStyle);
        if (variantValue == RaftButtonVariant.link) {
          labelStyle = labelStyle.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: fg,
            decorationThickness: 1.5,
          );
        }

        final children = <Widget>[
          if (leading != null) ...[leading!, SizedBox(width: gapValue)],
          if (iconWidget != null && !iconInlineEnd) iconWidget,
          if (iconWidget != null && !iconInlineEnd && text.isNotEmpty)
            SizedBox(width: gapValue),
          if (text.isNotEmpty)
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          if (iconWidget != null && iconInlineEnd) ...[
            if (text.isNotEmpty) SizedBox(width: gapValue),
            iconWidget,
          ],
        ];
        // The label style and icon colour are inherited, like the Web `content` span: a leading slot (brand
        // mark) and the caller's own text widgets pick them up.
        Widget content = DefaultTextStyle.merge(
          style: labelStyle,
          child: IconTheme.merge(
            data: IconThemeData(color: fg, size: iconSize),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
        );
        if (busy) {
          content = Stack(
            alignment: Alignment.center,
            children: [
              Visibility.maintain(visible: false, child: content),
              RaftPixelSpinner(
                color: fg,
                semanticLabel: raftText(context, 'Loading'),
              ),
            ],
          );
        }

        if (semanticLabel != null) content = ExcludeSemantics(child: content);

        final start =
            iconWidget != null &&
                !iconInlineEnd &&
                iconInlineStart &&
                text.isNotEmpty
            ? metrics.iconStartPaddingLeft
            : metrics.paddingX;
        final end = iconWidget != null && iconInlineEnd && text.isNotEmpty
            ? metrics.iconEndPaddingRight
            : metrics.paddingX;
        final EdgeInsets padding = inline
            ? EdgeInsets.zero
            : metrics.square
            ? EdgeInsets.zero
            : EdgeInsets.only(
                left: variantValue == RaftButtonVariant.link ? 0 : start,
                right: variantValue == RaftButtonVariant.link ? 0 : end,
              );

        final rings = <RaftRing>[
          if (colors.ringEdge != null) RaftRing(1.5, colors.ringEdge!),
          if (st.focusVisible)
            for (final layer in ui.focusRing.layers)
              RaftRing(layer.spread, layer.color),
        ];
        // The focus ring sits outside the sticker ring: the larger layers draw below the 1.5px edge.
        return RaftCssBox(
          radius: inline ? 0 : 8,
          fill: colors.fill,
          borderWidth: borderWidth,
          borderColor: colors.border,
          rings: rings,
          width: metrics.square
              ? metrics.height
              : (expand ? double.infinity : null),
          height: metrics.square && !inline ? metrics.height : null,
          minHeight: metrics.square || inline ? null : metrics.height,
          padding: padding,
          alignment: Alignment.center,
          child: content,
        );
      },
    );
  }

  static double _borderWidth(BuildContext context) =>
      raftControlBorderPx(context, 1.5);
}
