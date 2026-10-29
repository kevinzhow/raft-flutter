// The single Button entry point. All visual states of the Raft look resolve
// the complete raft-ui 0.7.0 Button recipe; compatibility wrappers retain only
// frozen legacy paint and delegate their interaction to this component.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsRole;

import '../css_opacity.dart';
import '../design_primitives.dart';
import '../icons.dart';
import '../localization.dart';
import '../recipes/button_variants.g.dart';
import '../recipes/recipe_router.dart';
import '../recipes/recipe_runtime.dart';
import '../recipe_surface.dart';
import '../text_scaling.dart' show RaftScaled;
import '../raft_underline.dart';
import 'legacy_button_surface.dart';
import 'button_color_transition.dart';
import 'button_colors.dart';
import 'css_box.dart' show raftControlBorderPx;
import 'legacy_material_button_surface.dart';
import '../theme.dart';
import '../control_typography.dart';
import '../tokens/tokens.dart';
export 'button_colors.dart';

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

  String get css => switch (this) {
    standard => 'default',
    dangerSecondary => 'danger-secondary',
    dangerOutline => 'danger-outline',
    onFrame => 'on-frame',
    _ => name,
  };

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

  String get css =>
      name.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '-${m[0]!.toLowerCase()}');

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

  /// Component-specific values refine a size without selecting another size
  /// axis. A caller chooses its semantic component; the pack supplies numbers.
  RaftButtonMetrics forComponent(RaftTokens t, String? component) {
    if (component == null) return this;
    final padding = t.size('space.${component}Inline', fallback: paddingX);
    return RaftButtonMetrics(
      height: t.size('size.$component', fallback: height),
      paddingX: padding,
      iconStartPaddingLeft: padding - (paddingX - iconStartPaddingLeft),
      iconEndPaddingRight: padding - (paddingX - iconEndPaddingRight),
      text: RaftTypeStyle(
        t.size('type.$component.size', fallback: text.fontSize),
        t.size('type.$component.line', fallback: text.lineHeight),
        fontWeight: text.fontWeight,
        letterSpacingEm: text.letterSpacingEm,
      ),
      icon: t.size('size.${component}Glyph', fallback: icon),
      gap: t.size('space.${component}Gap', fallback: gap),
      square: square,
    );
  }

  /// Size axes from current Web and actual a57b9dab recipe probes.
  /// Physical height overrides never choose a different typography axis.
  static RaftButtonMetrics of(
    RaftButtonSize size,
    RaftButtonVariant variant,
    RaftTokens t,
  ) {
    final tokens = t.recipeTokens;
    if (!usesLegacyRecipes(tokens)) {
      Map<String, RaftSlotStyle> resolve([Iterable<String> extra = const []]) =>
          RaftButtonRecipe.resolveProps(
            {'variant': variant.css, 'size': size.css},
            states: t.recipeStates(extra: extra),
            tokens: tokens,
          );
      final root = resolve()['root']!;
      final start = resolve([RaftRecipeStates.iconInlineStart])['root']!;
      final end = resolve([RaftRecipeStates.iconInlineEnd])['root']!;
      final text = root.text(tokens);
      final fontSize = text.fontSize ?? RaftTypeScale.body.fontSize;
      return RaftButtonMetrics(
        height: root.height ?? 0,
        paddingX: root.padding.left,
        iconStartPaddingLeft: start.padding.left,
        iconEndPaddingRight: end.padding.right,
        text: RaftTypeStyle(
          fontSize,
          fontSize * (text.height ?? 1),
          fontWeight: text.fontWeight?.value.toInt() ?? 700,
        ),
        icon: root.target("& svg:not([class*='size-'])")?.width ?? fontSize,
        gap: root.columnGap ?? 0,
        square: size.isIcon,
      );
    }
    // Pre-0.7 geometry remains frozen with the legacy paint adapters.
    final frame =
        variant == RaftButtonVariant.onFrame &&
        (size == RaftButtonSize.xs ||
            size == RaftButtonSize.sm ||
            size == RaftButtonSize.md ||
            size == RaftButtonSize.iconXs ||
            size == RaftButtonSize.iconSm ||
            size == RaftButtonSize.iconMd);
    final axis = switch (size) {
      RaftButtonSize.xs || RaftButtonSize.iconXs => 'xs',
      RaftButtonSize.sm || RaftButtonSize.iconSm => 'sm',
      RaftButtonSize.lg || RaftButtonSize.iconLg => 'lg',
      _ => 'md',
    };
    final large = axis == 'lg';
    final height = frame
        ? t.size('size.control.onFrame', fallback: 36)
        : size == RaftButtonSize.xl
        ? 52.0
        : t.size('size.control.$axis', fallback: large ? 44 : 32);
    final nativeType = large ? RaftTypeScale.subhead : RaftTypeScale.footnote;
    final fontSize = size == RaftButtonSize.xl
        ? RaftTypeScale.body.fontSize
        : frame
        ? RaftTypeScale.subhead.fontSize
        : t.size('type.button.$axis.size', fallback: nativeType.fontSize);
    final line = size == RaftButtonSize.xl
        ? RaftTypeScale.body.lineHeight
        : frame
        ? RaftTypeScale.subhead.lineHeight
        : axis == 'xs'
        ? 18.0
        : t.size('type.button.$axis.line', fallback: nativeType.lineHeight);
    final padding = size == RaftButtonSize.xl
        ? 20.0
        : frame
        ? 10.0
        : axis == 'md'
        ? 12.0
        : t.size('space.buttonInline.$axis', fallback: large ? 16 : 12);
    final glyph = size == RaftButtonSize.xl
        ? 18.0
        : frame
        ? (size.isIcon ? 20.0 : 16.0)
        : size.isIcon
        ? t.size('size.buttonGlyph.${size.name}', fallback: large ? 22 : 18)
        : axis == 'md'
        ? 16.0
        : t.size('size.buttonGlyph.$axis', fallback: large ? 18 : 16);
    return RaftButtonMetrics(
      height: height,
      paddingX: size.isIcon ? 0 : padding,
      iconStartPaddingLeft: size.isIcon ? 0 : padding - 2,
      iconEndPaddingRight: size.isIcon ? 0 : padding - 2,
      text: RaftTypeStyle(
        fontSize,
        line,
        fontWeight: t.size('type.button.weight', fallback: 700).round(),
      ),
      icon: glyph,
      gap: frame || size == RaftButtonSize.xl
          ? 8
          : t.size('space.buttonGap.$axis', fallback: 8),
      square: size.isIcon,
    );
  }
}

/// raft-ui Button, shared by text, icon, composer and dialog actions.
/// [uiVariant] and [uiSize] select the source axes. The earlier parameters are
/// compatibility aliases; new callers can pass [child] for composed content.
class RaftButton extends StatelessWidget {
  const RaftButton({
    super.key,
    this.label = '',
    this.child,
    this.onPressed,
    this.onKeyboardActivate,
    this.icon,
    this.glyph,
    this.trailingGlyph,
    this.iconBuilder,
    this.busy = false,
    this.disabled = false,
    this.loadingLabel = 'Loading',
    this.secondary = false,
    this.destructive = false,
    this.variant,
    this.tone,
    this.size,
    this.uiVariant,
    this.uiSize,
    this.visualHeight = RaftMetrics.buttonMd,
    this.physicalHeight,
    this.visualWidth,
    this.minimumTargetSize,
    this.layoutTouchTarget = false,
    this.expandTouchTarget = true,
    this.semanticContainer,
    this.metricsKey,
    this.expand = false,
    this.focusNode,
    this.focusOnPointer = true,
    this.focusRing = false,
    this.tooltip,
    this.semanticLabel,
    this.button = true,
    this.semanticRole,
    this.selected,
    this.checked,
    this.toggled,
    this.inMutuallyExclusiveGroup = false,
    this.inertWhenDisabled = false,
    this.foreground,
    this.padding,
    this.textStep,
    this.fontWeight,
    this.underline = false,
    this.autoHeight = false,
    this.iconInlineStart = true,
    this.opacityCompositing = RaftOpacityCompositing.layer,
    this.leading,
    this.gap,
    this.iconInlineEnd = false,
    this.glyphSize,
    this.disabledOpacity,
    this.legacyBuilder,
    this.surfaceBuilder,
    this.styleBuilder,
    this.legacyKind,
    this.legacyStyle,
    this.legacyConstraints,
    this.legacyPadding,
  });

  /// Migration constructors: current Button variants with frozen pre-0.7
  /// style data for the legacy looks. No Material input implementation remains.
  const RaftButton.text({
    Key? key,
    Widget? child,
    Widget? label,
    Widget? icon,
    VoidCallback? onPressed,
    FocusNode? focusNode,
    ButtonStyle? legacyStyle,
    EdgeInsets? padding,
    RaftSlotStyle Function(BuildContext, RaftInteractionState, RaftSlotStyle)?
    styleBuilder,
    bool focusOnPointer = true,
  }) : this(
         key: key,
         child: child ?? label,
         leading: icon,
         onPressed: onPressed,
         focusNode: focusNode,
         focusOnPointer: focusOnPointer,
         uiVariant: RaftButtonVariant.ghost,
         legacyKind: RaftLegacyButtonKind.text,
         layoutTouchTarget: true,
         expandTouchTarget: false,
         semanticContainer: false,
         legacyStyle: legacyStyle,
         padding: padding,
         styleBuilder: styleBuilder,
         autoHeight: true,
       );

  const RaftButton.outlined({
    Key? key,
    Widget? child,
    Widget? label,
    Widget? icon,
    VoidCallback? onPressed,
    FocusNode? focusNode,
    ButtonStyle? legacyStyle,
  }) : this(
         key: key,
         child: child ?? label,
         leading: icon,
         onPressed: onPressed,
         focusNode: focusNode,
         uiVariant: RaftButtonVariant.outline,
         legacyKind: RaftLegacyButtonKind.outlined,
         layoutTouchTarget: true,
         expandTouchTarget: false,
         semanticContainer: false,
         legacyStyle: legacyStyle,
       );

  const RaftButton.iconAction({
    Key? key,
    required Widget icon,
    VoidCallback? onPressed,
    String? tooltip,
    ButtonStyle? legacyStyle,
    BoxConstraints? constraints,
    EdgeInsetsGeometry? padding,
  }) : this(
         key: key,
         child: icon,
         onPressed: onPressed,
         tooltip: tooltip,
         uiVariant: RaftButtonVariant.ghost,
         uiSize: RaftButtonSize.iconMd,
         legacyKind: RaftLegacyButtonKind.icon,
         layoutTouchTarget: true,
         expandTouchTarget: false,
         semanticContainer: false,
         legacyStyle: legacyStyle,
         legacyConstraints: constraints,
         legacyPadding: padding,
       );

  final RaftLegacyButtonKind? legacyKind;
  final ButtonStyle? legacyStyle;
  final BoxConstraints? legacyConstraints;
  final EdgeInsetsGeometry? legacyPadding;
  final String label;
  final Widget? child, leading;
  final VoidCallback? onPressed, onKeyboardActivate;
  final IconData? icon;
  final RaftGlyph? glyph, trailingGlyph;
  final Widget Function(double size, Color color)? iconBuilder;
  final bool busy, disabled, secondary, destructive, expand;
  final String loadingLabel;
  final RaftControlVariant? variant;
  final RaftButtonRecipeVariant? tone;
  final RaftButtonRecipeSize? size;
  final RaftButtonVariant? uiVariant;
  final RaftButtonSize? uiSize;
  final double visualHeight;
  final double? physicalHeight, visualWidth, minimumTargetSize;
  final String? metricsKey;
  final bool layoutTouchTarget, expandTouchTarget;
  final bool? semanticContainer;
  final FocusNode? focusNode;
  final bool focusOnPointer, focusRing;
  final String? tooltip, semanticLabel;
  final bool button, inMutuallyExclusiveGroup, inertWhenDisabled;
  final SemanticsRole? semanticRole;
  final bool? selected, checked, toggled;
  final Color? foreground;
  final EdgeInsets? padding;
  final (double, double)? textStep;
  final FontWeight? fontWeight;
  final bool underline, autoHeight;
  final bool iconInlineStart, iconInlineEnd;
  final double? gap, glyphSize, disabledOpacity;
  final RaftOpacityCompositing opacityCompositing;

  /// Frozen paint adapter used only by the pre-0.7 compatibility wrappers.
  /// New compositions use the recipe and its normal class overrides above.
  final Widget Function(BuildContext, RaftInteractionState)? legacyBuilder;

  /// Product positioning around the painted border box, e.g. a popup anchor.
  /// Runs inside interaction so hit testing/semantics track the same surface.
  final Widget Function(BuildContext, Widget)? surfaceBuilder;

  /// Explicit product class overrides for composed controls (reaction chips,
  /// picker triggers). Their input and rendering still belong to Button.
  final RaftSlotStyle Function(
    BuildContext,
    RaftInteractionState,
    RaftSlotStyle,
  )?
  styleBuilder;

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
          : visualHeight <= 24
          ? RaftButtonSize.xs
          : visualHeight <= 28
          ? RaftButtonSize.sm
          : visualHeight <= 32
          ? RaftButtonSize.md
          : RaftButtonSize.lg);

  @override
  Widget build(BuildContext context) {
    final text = raftText(context, label);
    final childText = child is Text ? (child as Text).data : null;
    final accessibleLabel =
        semanticLabel ??
        (text.isEmpty && tooltip != null
            ? raftText(context, tooltip!)
            : busy
            ? (text.isNotEmpty
                  ? text
                  : childText ?? raftText(context, loadingLabel))
            : null);
    return RaftInteractive(
      onPressed: disabled ? null : onPressed,
      onKeyboardActivate: onKeyboardActivate,
      busy: busy,
      focusNode: focusNode,
      focusOnPointer: focusOnPointer,
      cancelOutsideRelease: true,
      tooltip: tooltip,
      semanticLabel: accessibleLabel,
      semanticValue: busy && accessibleLabel != raftText(context, loadingLabel)
          ? raftText(context, loadingLabel)
          : null,
      liveRegion: busy,
      button: button,
      semanticRole: semanticRole,
      semanticContainer: semanticContainer,
      expandTouchTarget: expandTouchTarget,
      selected: selected,
      checked: checked,
      toggled: toggled,
      inMutuallyExclusiveGroup: inMutuallyExclusiveGroup,
      inertWhenDisabled: inertWhenDisabled,
      builder: (context, state) {
        final t = RaftTokens.of(context);
        Widget surface = usesLegacyRecipes(t.recipeTokens)
            ? legacyBuilder?.call(context, state) ??
                  (legacyKind != null
                      ? RaftLegacyMaterialButtonSurface(
                          button: this,
                          state: state,
                        )
                      : RaftLegacyButtonSurface(button: this, state: state))
            : _recipeSurface(context, state, accessibleLabel);
        if (surfaceBuilder != null) surface = surfaceBuilder!(context, surface);
        return surface;
      },
    );
  }

  Widget _recipeSurface(
    BuildContext context,
    RaftInteractionState state,
    String? accessibleLabel,
  ) {
    final t = RaftTokens.of(context);
    final tokens = t.recipeTokens;
    final inactive = disabled || !state.enabled;
    final inert = inactive && inertWhenDisabled;
    final hasIcon =
        glyph != null || icon != null || iconBuilder != null || leading != null;
    final hasLabel = label.isNotEmpty || child != null;
    final inlineStart =
        hasIcon && iconInlineStart && !iconInlineEnd && hasLabel;
    final inlineEnd =
        (hasIcon && iconInlineEnd || trailingGlyph != null) && hasLabel;
    final states = t.recipeStates(
      hovered: state.hovered && !inactive,
      pressed: state.pressed && !inactive,
      focusVisible:
          state.focusVisible || focusRing && (focusNode?.hasFocus ?? false),
      disabled: inactive && !inert,
      ariaDisabled: busy,
      extra: [
        if (busy) RaftRecipeStates.loading,
        if (inlineStart) RaftRecipeStates.iconInlineStart,
        if (inlineEnd) RaftRecipeStates.iconInlineEnd,
        if (MediaQuery.disableAnimationsOf(context))
          RaftRecipeStates.motionReduce,
      ],
    );
    final slots = RaftButtonRecipe.resolveProps(
      {'variant': resolvedVariant.css, 'size': resolvedSize.css},
      states: states,
      tokens: tokens,
    );
    var recipeRoot = slots['root'] ?? absentSlot(tokens);
    // Theme-authored structural roles refine the source shape without selecting
    // another Button variant. Every rounded source size uses rounded-control.
    final shapeRadius = recipeRoot.borderRadius;
    final radius = t.themeValues?.geometry['radius.control'];
    final stroke = t.themeValues?.geometry['stroke.control'];
    recipeRoot = recipeRoot.copyWith(
      properties: {
        ...recipeRoot.properties,
        if (radius != null && shapeRadius != null && shapeRadius.topLeft.x > 0)
          for (final corner in [
            'top-left',
            'top-right',
            'bottom-left',
            'bottom-right',
          ])
            'border-$corner-radius': CssNum(radius, 'px'),
        if (stroke != null && recipeRoot.borderWidth != EdgeInsets.zero)
          for (final side in ['top', 'right', 'bottom', 'left'])
            'border-$side-width': CssNum(stroke, 'px'),
      },
    );
    // Blink floors fractional CSS border widths to device pixels. Keep that
    // projection in Button for every variant, including the social outline;
    // generated recipes retain the specified 1.5px value.
    final widths = recipeRoot.borderWidth;
    recipeRoot = recipeRoot.copyWith(
      properties: {
        ...recipeRoot.properties,
        for (final (side, width) in [
          ('top', widths.top),
          ('right', widths.right),
          ('bottom', widths.bottom),
          ('left', widths.left),
        ])
          if (width > 0)
            'border-$side-width': CssNum(
              raftControlBorderPx(context, width),
              'px',
            ),
      },
    );
    var root = styleBuilder?.call(context, state, recipeRoot) ?? recipeRoot;
    // Theme-authored variant colour roles remain independent of the source's
    // motion and edge axes. The built-in look uses the generated overlay.
    if (t.option('button.hoverSurface', or: 'overlay') == 'variant') {
      final colors = RaftButtonColors.themed(
        t,
        resolvedVariant,
        disabled: inactive,
        overlay: state.hovered || state.pressed,
        iconSize: resolvedSize.isIcon,
        highContrast: MediaQuery.highContrastOf(context),
      );
      CssColor value(Color c) => CssColor(c.toARGB32(), null, c);
      root = root.copyWith(
        properties: {
          ...root.properties,
          'background-color': value(colors.fill),
          'background-image': const CssKeyword('none'),
          'color': value(colors.foreground),
          for (final side in ['top', 'right', 'bottom', 'left'])
            'border-$side-color': value(colors.border),
        },
      );
    }
    final profile = metricsKey == null
        ? null
        : RaftButtonMetrics.of(
            resolvedSize,
            resolvedVariant,
            t,
          ).forComponent(t, metricsKey);
    // Migrated icon actions keep the product's explicit box overrides (for
    // example an avatar trigger); the Button size still supplies its recipe.
    final fixedHeight =
        physicalHeight ??
        (legacyConstraints?.hasBoundedHeight == true
            ? legacyConstraints!.maxHeight
            : null);
    final fixedWidth =
        visualWidth ??
        (legacyConstraints?.hasBoundedWidth == true
            ? legacyConstraints!.maxWidth
            : null);
    final overrides = <String, CssValue>{
      if (autoHeight) ...{
        'height': const CssKeyword('auto'),
        'min-height': CssNum(root.height ?? 0, 'px'),
      },
      if (resolvedSize != RaftButtonSize.inline &&
          (fixedHeight != null || profile != null))
        'height': CssNum(fixedHeight ?? profile!.height, 'px'),
      if (fixedWidth != null) 'width': CssNum(fixedWidth, 'px'),
      if (profile != null) ...{
        'padding-left': CssNum(profile.paddingX, 'px'),
        'padding-right': CssNum(profile.paddingX, 'px'),
        'font-size': CssNum(profile.text.fontSize, 'px'),
        'line-height': CssNum(profile.text.lineHeight, 'px'),
      },
      if (foreground != null)
        'color': CssColor(foreground!.toARGB32(), null, foreground!),
      if (fontWeight != null)
        'font-weight': CssNum(fontWeight!.value.toDouble()),
      if (textStep != null) ...{
        'font-size': CssNum(textStep!.$1, 'px'),
        'line-height': CssNum(textStep!.$2, 'px'),
      },
      if (underline) 'text-decoration-line': const CssKeyword('underline'),
    };
    root = root.copyWith(properties: {...root.properties, ...overrides});
    return RaftButtonColorTransition(
      style: root,
      tokens: tokens,
      builder: (context, animated) => _paintRecipeContent(
        context,
        state,
        accessibleLabel,
        animated,
        profile,
      ),
    );
  }

  Widget _paintRecipeContent(
    BuildContext context,
    RaftInteractionState state,
    String? accessibleLabel,
    RaftSlotStyle root,
    RaftButtonMetrics? profile,
  ) {
    final t = RaftTokens.of(context);
    final tokens = t.recipeTokens;
    final inactive = disabled || !state.enabled;
    final inherited = DefaultTextStyle.of(context).style;
    var style = root
        .text(tokens, base: inherited)
        .copyWith(fontFamilyFallback: t.fontFallback, locale: t.textLocale);
    style = RaftControlTypography.of(context, style);
    final ink = style.color ?? t.ink;
    final svg = root.target("& svg:not([class*='size-'])");
    final extent =
        glyphSize ?? profile?.icon ?? svg?.width ?? style.fontSize ?? 16;
    final spacing = gap ?? profile?.gap ?? root.columnGap ?? 0;
    final wraps = autoHeight || RaftScaled.grows(context);
    final iconWidget = iconBuilder != null
        ? iconBuilder!(extent, ink)
        : glyph != null
        ? RaftIcon(glyph!, size: extent, color: ink)
        : icon != null
        ? RaftSymbol(icon!, size: extent, color: ink)
        : null;
    final line = root['text-decoration-line']?.toString() ?? '';
    final labelNode =
        child ??
        (label.isEmpty
            ? null
            : line.contains('underline')
            ? RaftUnderlinedText(
                raftText(context, label),
                underlineColor:
                    RaftColorRef.fromCss(root['text-decoration-color'])
                        ?.resolve(tokens) ??
                    ink,
                underlineOffset: root.length('text-underline-offset'),
                underlineThickness: root.length('text-decoration-thickness'),
                maxLines: wraps ? null : 1,
                softWrap: wraps,
                textAlign: TextAlign.center,
                overflow: wraps ? TextOverflow.clip : TextOverflow.ellipsis,
              )
            : Text(
                raftText(context, label),
                maxLines: wraps ? null : 1,
                softWrap: wraps,
                textAlign: TextAlign.center,
                overflow: wraps ? TextOverflow.clip : TextOverflow.ellipsis,
              ));
    Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[
          if (labelNode == null) Flexible(child: leading!) else leading!,
          if (labelNode != null || iconWidget != null) SizedBox(width: spacing),
        ],
        if (iconWidget != null && !iconInlineEnd) ...[
          iconWidget,
          if (labelNode != null) SizedBox(width: spacing),
        ],
        if (labelNode != null) Flexible(child: labelNode),
        if (iconWidget != null && iconInlineEnd) ...[
          if (labelNode != null) SizedBox(width: spacing),
          iconWidget,
        ],
        if (trailingGlyph != null) ...[
          if (labelNode != null || iconWidget != null) SizedBox(width: spacing),
          RaftIcon(trailingGlyph!, size: extent, color: ink),
        ],
      ],
    );
    // The source content slot stays in layout while its loading indicator
    // overlays it; no state-dependent width/height or live duplicate label.
    // The source content slot only provides inline-flex, inherited gap and
    // loading visibility. Row + Visibility implement those declarations
    // without another text/opacity/transform layer overriding the control.
    content = Visibility.maintain(visible: !busy, child: content);
    content = Stack(
      alignment: Alignment.center,
      children: [
        content,
        if (busy)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Semantics(
                  label: raftText(context, loadingLabel),
                  liveRegion: true,
                  child: const ExcludeSemantics(child: RaftSpinner()),
                ),
              ),
            ),
          ),
      ],
    );
    if (accessibleLabel != null) content = ExcludeSemantics(child: content);
    Widget surface = RaftRecipeBox(
      style: root,
      tokens: tokens,
      applyText: false,
      applyOpacity: root.opacity != null && root.opacity != 1,
      overflowCenter: true,
      growWithText: true,
      opacityCompositing: opacityCompositing,
      width: expand ? double.infinity : null,
      padding: padding ?? legacyPadding?.resolve(Directionality.of(context)),
      child: DefaultTextStyle(
        style: style,
        child: IconTheme.merge(
          data: IconThemeData(size: extent, color: ink),
          child: content,
        ),
      ),
    );
    if (inactive && !busy && disabledOpacity != null) {
      surface = Opacity(opacity: disabledOpacity!, child: surface);
    }
    final target =
        minimumTargetSize ??
        (layoutTouchTarget && RaftDensityScope.of(context) == RaftDensity.touch
            ? RaftMetrics.touchTarget
            : null);
    if (target != null)
      surface = ConstrainedBox(
        constraints: BoxConstraints(minWidth: target, minHeight: target),
        child: Center(widthFactor: 1, heightFactor: 1, child: surface),
      );
    return surface;
  }
}
