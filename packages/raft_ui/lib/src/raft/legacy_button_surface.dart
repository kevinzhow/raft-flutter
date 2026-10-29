// Frozen pre-migration Button paint for Elegant / Brutal. Interaction belongs
// to RaftButton; this adapter contains no pointer, keyboard or semantics state.
import 'package:flutter/material.dart';

import '../control_typography.dart';
import '../css_opacity.dart';
import '../design_primitives.dart';
import '../icons.dart';
import '../localization.dart';
import '../theme.dart';
import 'button.dart';
import 'button_surface.dart';
import 'ui_tokens.dart';

class RaftLegacyButtonSurface extends StatelessWidget {
  const RaftLegacyButtonSurface({
    super.key,
    required this.button,
    required this.state,
  });
  final RaftButton button;
  final RaftInteractionState state;
  @override
  Widget build(BuildContext context) {
    final label = button.label;
    final icon = button.icon;
    final glyph = button.glyph;
    final busy = button.busy;
    final foreground = button.foreground;
    final iconInlineStart = button.iconInlineStart;
    final iconInlineEnd = button.iconInlineEnd;
    final glyphSize = button.glyphSize;
    final gap = button.gap;
    final leading = button.leading;
    final expand = button.expand;
    final physicalHeight = button.physicalHeight;
    final metricsKey = button.metricsKey;
    final tooltip = button.tooltip;
    final semanticLabel = button.semanticLabel;
    final disabledOpacity = button.disabledOpacity;
    final opacityCompositing = button.opacityCompositing;
    final resolvedVariant = button.resolvedVariant;
    final resolvedSize = button.resolvedSize;
    final st = state;
    final t = RaftTokens.of(context);
    final variantValue = resolvedVariant;
    final sizeValue = resolvedSize;
    final baseMetrics = RaftButtonMetrics.of(
      sizeValue,
      variantValue,
      t,
    ).forComponent(t, metricsKey);
    final metrics = physicalHeight == null
        ? baseMetrics
        : RaftButtonMetrics(
            height: physicalHeight,
            paddingX: baseMetrics.paddingX,
            iconStartPaddingLeft: baseMetrics.iconStartPaddingLeft,
            iconEndPaddingRight: baseMetrics.iconEndPaddingRight,
            text: baseMetrics.text,
            icon: baseMetrics.icon,
            gap: baseMetrics.gap,
            square: baseMetrics.square,
          );
    final text = raftText(context, label);
    final hint = tooltip;
    final accessibleLabel =
        semanticLabel ??
        (text.isEmpty && hint != null
            ? raftText(context, hint)
            : busy
            ? text
            : null);
    final disabled = !state.enabled;
    final colors = RaftButtonColors.themed(
      t,
      variantValue,
      iconSize: sizeValue.isIcon,
      highContrast: MediaQuery.highContrastOf(context),
      disabled: disabled,
      overlay: (st.hovered || st.pressed) && !disabled,
    );
    final fg = foreground ?? colors.foreground;
    final inline = sizeValue == RaftButtonSize.inline;
    final iconSize = glyphSize ?? metrics.icon;
    final gapValue = gap ?? (inline ? 4.0 : metrics.gap);

    Widget? iconWidget;
    if (glyph != null) {
      iconWidget = RaftIcon(glyph, size: iconSize, color: fg);
    } else if (icon != null) {
      iconWidget = RaftSymbol(icon, size: iconSize, color: fg);
    }

    TextStyle labelStyle = t.scale(metrics.text, color: fg);
    if (inline) {
      final inherited = DefaultTextStyle.of(context).style;
      labelStyle = inherited.copyWith(
        color: fg,
        fontFamily: t.bodyFont,
        fontFamilyFallback: t.fontFallback,
        fontWeight: raftFontWeight(t.size('type.button.weight', fallback: 700)),
      );
    } else if ((sizeValue == RaftButtonSize.xs ||
            sizeValue == RaftButtonSize.iconXs) &&
        t.option('button.xsLine', or: 'fixed') == 'inherited') {
      labelStyle = labelStyle.copyWith(
        height: DefaultTextStyle.of(context).style.height ?? kTextHeightNone,
      );
    }
    labelStyle = RaftControlTypography.of(context, labelStyle);
    if (variantValue == RaftButtonVariant.link &&
        t.option('button.linkDecoration', or: 'underline') == 'underline') {
      labelStyle = labelStyle.copyWith(
        decoration: TextDecoration.underline,
        decorationColor: fg,
        decorationThickness: 1.5,
      );
    }

    final children = <Widget>[
      if (leading != null) ...[
        // A leading-only slot can contain the whole workspace label. Pass
        // the button's available width to it instead of laying it out
        // unbounded, including fractional widths at non-integer DPRs.
        if (text.isEmpty) Flexible(child: leading) else leading,
        SizedBox(width: gapValue),
      ],
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
        child:
            button.child ??
            Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
      ),
    );
    if (busy) {
      content = IconTheme.merge(
        data: IconThemeData(color: fg),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Visibility.maintain(visible: false, child: content),
            const RaftSpinner(),
          ],
        ),
      );
    }

    if (accessibleLabel != null) content = ExcludeSemantics(child: content);

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
            left:
                variantValue == RaftButtonVariant.link &&
                    t.option('button.linkPadding', or: 'none') == 'none'
                ? 0
                : start,
            right:
                variantValue == RaftButtonVariant.link &&
                    t.option('button.linkPadding', or: 'none') == 'none'
                ? 0
                : end,
          );

    final box = RaftButtonSurface(
      variant: variantValue,
      size: sizeValue,
      metrics: metrics,
      colors: colors,
      state: st,
      disabled: disabled,
      padding: padding,
      expand: expand,
      child: content,
    );
    final overridden = disabled && !busy && disabledOpacity != null;
    if (t.option('button.disabledSurface', or: 'muted') == 'opacity') {
      final opacity = busy || !disabled
          ? 1.0
          : disabledOpacity ?? t.size('opacity.buttonDisabled', fallback: 1);
      return switch (opacityCompositing) {
        RaftOpacityCompositing.layer => Opacity(opacity: opacity, child: box),
        RaftOpacityCompositing.alphaFilter => RaftCssOpacity(
          opacity: opacity,
          child: box,
        ),
      };
    }
    return overridden
        ? switch (opacityCompositing) {
            RaftOpacityCompositing.layer => Opacity(
              opacity: disabledOpacity,
              child: box,
            ),
            RaftOpacityCompositing.alphaFilter => RaftCssOpacity(
              opacity: disabledOpacity,
              child: box,
            ),
          }
        : box;
  }
}
