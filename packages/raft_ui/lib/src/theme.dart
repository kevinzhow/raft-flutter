import 'package:flutter/material.dart';

import 'tokens/tokens.dart';

enum RaftFamily { brutal, elegant }

class RaftAppearance {
  const RaftAppearance({
    this.mode = ThemeMode.system,
    this.light = RaftFamily.brutal,
  });
  final ThemeMode mode;
  final RaftFamily light;
  RaftAppearance copyWith({ThemeMode? mode, RaftFamily? light}) =>
      RaftAppearance(mode: mode ?? this.mode, light: light ?? this.light);
}

/// Generated token set for a family/brightness pair (dark is always elegant).
RaftThemeId raftThemeId(RaftFamily family, {bool dark = false}) => dark
    ? RaftThemeId.elegantDark
    : family == RaftFamily.brutal
    ? RaftThemeId.brutal
    : RaftThemeId.elegantLight;

final Map<RaftThemeId, Map<String, Color>> _colorMaps = {};

/// String-keyed compatibility view over the generated tokens, keyed by CSS
/// custom-property name without `--`: primitives (`color-brutal-yellow-400`),
/// semantic (`foreground-muted`, `ink-8`), product aliases (`color-brutal-cyan`)
/// and component roles (`button-default-fill`). Prefer the typed tiers.
Map<String, Color> raftColorMap(RaftTokenSet set) => _colorMaps.putIfAbsent(
  set.id,
  () => Map.unmodifiable({
    for (final e in RaftPrimitiveColors.byCssName.entries)
      e.key.substring(2): e.value,
    ...set.colors.toCssMap(),
    ...set.product.toCssMap(),
    ...set.components.toCssMap(),
  }),
);

@immutable
class RaftTokens extends ThemeExtension<RaftTokens> {
  /// [colors] is the string-keyed view; [tokens] defaults to the generated
  /// set for [family]/[dark].
  const RaftTokens(this.family, this.dark, this.colors, {RaftTokenSet? tokens})
    : _tokens = tokens;

  /// Tokens generated from raft-ui CSS for a theme (dark forces elegant).
  factory RaftTokens.theme(RaftFamily family, {bool dark = false}) {
    final set = RaftTokenSet.of(raftThemeId(family, dark: dark));
    return RaftTokens(
      dark ? RaftFamily.elegant : family,
      dark,
      raftColorMap(set),
      tokens: set,
    );
  }
  final RaftFamily family;
  final bool dark;
  final Map<String, Color> colors;
  final RaftTokenSet? _tokens;

  /// Every generated tier for this theme.
  RaftTokenSet get tokenSet =>
      _tokens ?? RaftTokenSet.of(raftThemeId(family, dark: dark));
  RaftSemanticColors get semantic => tokenSet.colors;
  RaftProductColors get product => tokenSet.product;
  RaftComponentColors get components => tokenSet.components;
  RaftThemeShadows get themeShadows => tokenSet.shadows;
  RaftThemeMetrics get metrics => tokenSet.metrics;

  bool get brutal => family == RaftFamily.brutal;
  Color get ink => colors['foreground']!;
  Color get strong => colors['foreground-strong']!;
  Color get muted => colors['foreground-muted']!;
  Color get canvas => colors['layer-canvas']!;
  Color get sidebar => colors['layer-canvas-muted']!;
  Color get panel => colors['layer-panel']!;
  Color get card => colors['layer-card']!;
  Color get popover => colors['layer-popover']!;
  Color get line => colors[brutal ? 'line-strong' : 'line-muted']!;
  Color get fieldLine => colors[brutal ? 'line-strong' : 'line-field']!;
  Color get accent => colors['accent-strong']!;
  Color get accentSoft => colors['accent-soft']!;
  Color get accentFill => colors['accent']!;
  Color get primaryFill => colors['primary']!;
  String get bodyFont => metrics.sansFont;
  String get headingFont => metrics.headingFont;
  String get monoFont => metrics.monoFont;
  double get radius => brutal ? 0 : 8;
  double get fieldRadius => brutal ? 0 : 6;
  double get border => brutal ? 2 : 1;
  TextStyle get fieldStyle => TextStyle(
    fontFamily: headingFont,
    fontVariations: brutal ? null : const [FontVariation('opsz', 14)],
    fontSize: metrics.fieldFontSize,
    height: metrics.fieldLineHeight / metrics.fieldFontSize,
    fontWeight: raftFontWeight(metrics.fieldFontWeight),
    letterSpacing: 0,
    color: ink,
  );

  /// `--theme-shadow-sm` outer layers (Brutal, Elegant light). Elegant dark
  /// keeps the `--theme-shadow-xs` outer pair the ported surfaces were matched
  /// against. Inset layers are drawn separately by surfaces.
  List<BoxShadow> get shadows =>
      !brutal && dark ? themeShadows.xs.outer : themeShadows.sm.outer;

  /// Brutal focus lift is `--theme-shadow-md` (4px 4px line-strong).
  List<BoxShadow> get focusShadows => brutal ? themeShadows.md.outer : shadows;
  static RaftTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<RaftTokens>() ??
        RaftTokens.theme(
          RaftFamily.elegant,
          dark: theme.brightness == Brightness.dark,
        );
  }

  @override
  RaftTokens copyWith({
    RaftFamily? family,
    bool? dark,
    Map<String, Color>? colors,
  }) => family == null && dark == null
      ? RaftTokens(
          this.family,
          this.dark,
          colors ?? this.colors,
          tokens: _tokens,
        )
      : RaftTokens(
          family ?? this.family,
          dark ?? this.dark,
          colors ??
              raftColorMap(
                RaftTokenSet.of(
                  raftThemeId(family ?? this.family, dark: dark ?? this.dark),
                ),
              ),
        );
  @override
  RaftTokens lerp(covariant RaftTokens? other, double t) =>
      other == null || t < .5 ? this : other;
}

@immutable
class RaftFieldRecipe {
  const RaftFieldRecipe(this.tokens);
  final RaftTokens tokens;
  Color fill({bool disabled = false}) => disabled && !tokens.brutal
      ? tokens.colors['fill-muted']!.withValues(
          alpha: tokens.colors['fill-muted']!.a * .5,
        )
      : tokens.dark && !tokens.brutal
      ? tokens.card
      : tokens.panel;
  Color placeholder({bool disabled = false}) {
    final placeholder = tokens.colors['foreground-placeholder'] ?? tokens.muted;
    if (disabled && !tokens.brutal) {
      return tokens.colors['foreground-disabled'] ?? placeholder;
    }
    return tokens.brutal
        ? placeholder
        : placeholder.withValues(alpha: placeholder.a * .7);
  }

  Color border({bool disabled = false, bool hovered = false}) =>
      disabled && !tokens.brutal
      ? tokens.colors['line-muted']!.withValues(
          alpha: tokens.colors['line-muted']!.a * .6,
        )
      : tokens.dark && !tokens.brutal
      ? Colors.transparent
      : hovered && !tokens.brutal
      ? tokens.colors['line-field-hover']!
      : tokens.fieldLine;
}

/// Original dark Input's two inset shadows and outer bottom shadow.
/// Source: raft-ui 0.5.27 input.recipe, after semantic role resolution.
@immutable
class RaftFieldInsetRecipe {
  const RaftFieldInsetRecipe(this.tokens);
  final RaftTokens tokens;
  Color get line => tokens.colors['field-inset-line']!;
  Color get top => tokens.colors['field-inset-top']!;
  Color get bottom => tokens.colors['field-inset-bottom']!;
  double get lineWidth => 1;
  double get topOffset => 1;
  double get topBlurRadius => 2;
  double get topBlurSigma => topBlurRadius / 2;
  double get bottomOffset => 1;

  /// CSS inset shadows clip to the padding edge, inside even transparent borders.
  RRect paddingBox(Rect rect, BorderRadius radius, double borderWidth) =>
      radius.toRRect(rect).deflate(borderWidth);
}

/// CSS inset shadows use the padding box; the faint bottom shadow is exterior.
class RaftFieldBorder extends OutlineInputBorder {
  const RaftFieldBorder({
    super.borderSide,
    super.borderRadius,
    super.gapPadding,
    this.insets,
  });
  final RaftFieldInsetRecipe? insets;
  @override
  RaftFieldBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
  }) => RaftFieldBorder(
    borderSide: borderSide ?? this.borderSide,
    borderRadius: borderRadius ?? this.borderRadius,
    gapPadding: gapPadding ?? this.gapPadding,
    insets: insets,
  );
  RaftFieldBorder _interpolate(
    OutlineInputBorder a,
    OutlineInputBorder b,
    double t,
  ) => RaftFieldBorder(
    borderSide: BorderSide.lerp(a.borderSide, b.borderSide, t),
    borderRadius: BorderRadius.lerp(a.borderRadius, b.borderRadius, t)!,
    gapPadding: a.gapPadding + (b.gapPadding - a.gapPadding) * t,
    insets: t < .5
        ? (a is RaftFieldBorder ? a.insets : insets)
        : (b is RaftFieldBorder ? b.insets : insets),
  );
  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) =>
      a is OutlineInputBorder ? _interpolate(a, this, t) : super.lerpFrom(a, t);
  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) =>
      b is OutlineInputBorder ? _interpolate(this, b, t) : super.lerpTo(b, t);
  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0,
    double gapPercentage = 0,
    TextDirection? textDirection,
  }) {
    final recipe = insets;
    if (recipe != null) {
      final outer = borderRadius.toRRect(rect);
      final padding = recipe.paddingBox(rect, borderRadius, borderSide.width);
      // The final CSS shadow is not inset. Draw its shifted silhouette outside
      // the border box, before the inset layers and actual border.
      canvas.save();
      canvas.clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(rect.inflate(recipe.bottomOffset)),
          Path()..addRRect(outer),
        ),
      );
      canvas.drawRRect(
        outer.shift(Offset(0, recipe.bottomOffset)),
        Paint()..color = recipe.bottom,
      );
      canvas.restore();
      canvas.save();
      canvas.clipRRect(padding);
      // Keep Material floating-label gaps legible for existing API callers.
      if (gapStart != null && gapPercentage > 0) {
        final gap = Rect.fromLTWH(
          rect.left + gapStart - gapPadding,
          rect.top,
          (gapExtent + gapPadding * 2) * gapPercentage,
          4,
        );
        canvas.clipPath(
          Path.combine(
            PathOperation.difference,
            Path()..addRect(rect),
            Path()..addRect(gap),
          ),
        );
      }
      void shadow(Color color, double offset, double sigma) {
        final path = Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rect.inflate(recipe.topBlurRadius * 2))
          ..addRRect(padding.shift(Offset(0, offset)));
        final paint = Paint()..color = color;
        if (sigma > 0) {
          paint.maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
        }
        canvas.drawPath(path, paint);
      }

      // CSS lists paint first-on-top: the blurred top (first) overlays the
      // 1px spread ring (second), both clipped to the padding edge.
      final ring = Path()
        ..fillType = PathFillType.evenOdd
        ..addRRect(padding)
        ..addRRect(padding.deflate(recipe.lineWidth));
      canvas.drawPath(ring, Paint()..color = recipe.line);
      shadow(recipe.top, recipe.topOffset, recipe.topBlurSigma);
      canvas.restore();
    }
    super.paint(
      canvas,
      rect,
      gapStart: gapStart,
      gapExtent: gapExtent,
      gapPercentage: gapPercentage,
      textDirection: textDirection,
    );
  }
}

/// CSS numeric font-weight → Flutter [FontWeight].
FontWeight raftFontWeight(double weight) =>
    FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)];

ThemeData raftTheme(RaftFamily family, {bool dark = false}) {
  if (dark) family = RaftFamily.elegant;
  final t = RaftTokens.theme(family, dark: dark);
  RoundedRectangleBorder shape(
    double radius, {
    BorderSide side = BorderSide.none,
  }) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(t.brutal ? 0 : radius),
    side: side,
  );
  final scheme = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: t.primaryFill,
    onPrimary: t.colors['primary-950']!,
    primaryContainer: t.colors['primary-soft']!,
    onPrimaryContainer: t.colors['primary-strong']!,
    secondary: t.accentFill,
    onSecondary: t.colors['accent-950']!,
    secondaryContainer: t.accentSoft,
    onSecondaryContainer: t.accent,
    tertiary: t.colors['info']!,
    onTertiary: t.colors['foreground-inverse']!,
    tertiaryContainer: t.colors['info-soft']!,
    onTertiaryContainer: t.colors['info-strong']!,
    error: t.colors['danger']!,
    onError: t.colors['danger-foreground']!,
    errorContainer: t.colors['danger-soft']!,
    onErrorContainer: t.colors['danger-strong']!,
    surface: t.canvas,
    onSurface: t.ink,
    onSurfaceVariant: t.muted,
    surfaceDim: t.sidebar,
    surfaceBright: t.panel,
    surfaceContainerLowest: t.canvas,
    surfaceContainerLow: t.sidebar,
    surfaceContainer: t.panel,
    surfaceContainerHigh: t.card,
    surfaceContainerHighest: t.popover,
    outline: t.line,
    outlineVariant: t.colors['line-hairline']!,
    shadow: Colors.black,
    scrim: Colors.black.withValues(alpha: .65),
    inverseSurface: dark ? const Color(0xfff5f5f3) : const Color(0xff242422),
    onInverseSurface: dark ? const Color(0xff191815) : Colors.white,
    inversePrimary: t.accent,
    surfaceTint: Colors.transparent,
  );
  TextStyle text(
    double size,
    double line, {
    FontWeight weight = FontWeight.w400,
    bool heading = false,
    Color? color,
  }) => TextStyle(
    fontFamily: heading ? t.headingFont : t.bodyFont,
    fontVariations: heading && !t.brutal
        ? [FontVariation('opsz', size.clamp(14.0, 32.0).toDouble())]
        : null,
    fontFamilyFallback: const [
      'Noto Sans CJK JP',
      'Noto Sans CJK SC',
      'sans-serif',
    ],
    fontSize: size,
    height: line / size,
    fontWeight: weight,
    letterSpacing: 0,
    color: color ?? t.ink,
  );
  final textTheme = TextTheme(
    displayLarge: text(
      56,
      64,
      heading: true,
      weight: FontWeight.w500,
    ).copyWith(letterSpacing: -.56),
    displayMedium: text(
      48,
      56,
      heading: true,
      weight: FontWeight.w500,
    ).copyWith(letterSpacing: -.48),
    displaySmall: text(
      40,
      48,
      heading: true,
      weight: FontWeight.w500,
    ).copyWith(letterSpacing: -.4),
    headlineLarge: text(
      32,
      40,
      heading: true,
      weight: FontWeight.w500,
    ).copyWith(letterSpacing: -.16),
    headlineMedium: text(24, 32, heading: true, weight: FontWeight.w500),
    headlineSmall: text(20, 28, heading: true, weight: FontWeight.w500),
    titleLarge: text(18, 28, heading: true, weight: FontWeight.w700),
    titleMedium: text(16, 24, heading: true, weight: FontWeight.w700),
    titleSmall: text(14, 20, heading: true, weight: FontWeight.w600),
    bodyLarge: t.fieldStyle.copyWith(
      fontFamilyFallback: const [
        'Noto Sans CJK JP',
        'Noto Sans CJK SC',
        'sans-serif',
      ],
    ),
    bodyMedium: text(16, 24),
    bodySmall: text(12, 16, color: t.muted),
    labelLarge: text(
      14,
      20,
      heading: t.brutal,
      weight: t.brutal ? FontWeight.w700 : FontWeight.w500,
    ),
    labelMedium: text(12, 16, weight: FontWeight.w500),
    labelSmall: text(11, 16, weight: FontWeight.w500),
  );
  final buttonStyle = ButtonStyle(
    textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
    minimumSize: const WidgetStatePropertyAll(Size(32, 32)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    tapTargetSize: MaterialTapTargetSize.padded,
    shape: WidgetStatePropertyAll(shape(6)),
    side: WidgetStatePropertyAll(BorderSide(color: t.line, width: t.border)),
    elevation: const WidgetStatePropertyAll(0),
    animationDuration: const Duration(milliseconds: 100),
    overlayColor: WidgetStatePropertyAll(
      t.brutal
          ? Colors.transparent
          : t.colors['fill-strong']!.withValues(alpha: .3),
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? t.ink.withValues(alpha: .4)
          : t.ink,
    ),
  );
  OutlineInputBorder fieldBorder(Color color, [double? width]) =>
      RaftFieldBorder(
        insets: t.dark && !t.brutal ? RaftFieldInsetRecipe(t) : null,
        borderRadius: BorderRadius.circular(t.fieldRadius),
        borderSide: BorderSide(color: color, width: width ?? t.border),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.canvas,
    canvasColor: t.panel,
    fontFamily: t.bodyFont,
    fontFamilyFallback: const [
      'Noto Sans CJK JP',
      'Noto Sans CJK SC',
      'sans-serif',
    ],
    textTheme: textTheme,
    extensions: [t],
    dividerColor: t.line,
    visualDensity: VisualDensity.standard,
    splashFactory: NoSplash.splashFactory,
    iconTheme: IconThemeData(color: t.strong, size: 18),
    appBarTheme: AppBarTheme(
      backgroundColor: t.canvas,
      foregroundColor: t.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: t.sidebar,
      shape: shape(0),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: WidgetStateColor.resolveWith(
        (states) =>
            RaftFieldRecipe(t)
                .fill(disabled: states.contains(WidgetState.disabled)),
      ),
      isDense: true,
      // CSS field outer height includes borders; Material outlines paint inside.
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8 + t.border,
      ),
      hintStyle: WidgetStateTextStyle.resolveWith(
        (states) => t.fieldStyle.copyWith(
          color: RaftFieldRecipe(t)
              .placeholder(disabled: states.contains(WidgetState.disabled)),
        ),
      ),
      labelStyle: textTheme.bodySmall,
      floatingLabelStyle: textTheme.bodySmall,
      errorStyle: textTheme.bodySmall!.copyWith(color: scheme.error),
      helperStyle: textTheme.bodySmall,
      border: fieldBorder(RaftFieldRecipe(t).border()),
      enabledBorder: fieldBorder(RaftFieldRecipe(t).border()),
      disabledBorder: fieldBorder(RaftFieldRecipe(t).border(disabled: true)),
      focusedBorder: fieldBorder(
        t.brutal ? t.strong : t.primaryFill,
        t.brutal ? 2 : 1,
      ),
      errorBorder: fieldBorder(scheme.error),
      focusedErrorBorder: fieldBorder(scheme.error),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: buttonStyle.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => t.accentFill.withValues(
            alpha: s.contains(WidgetState.disabled) ? .4 : 1,
          ),
        ),
        foregroundColor: WidgetStatePropertyAll(
          t.brutal ? t.strong : t.colors['accent-950']!,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: buttonStyle.copyWith(
        backgroundColor: WidgetStatePropertyAll(t.panel),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: buttonStyle.copyWith(
        backgroundColor: WidgetStatePropertyAll(
          t.brutal ? t.panel : Colors.transparent,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: buttonStyle.copyWith(
        side: const WidgetStatePropertyAll(BorderSide.none),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStatePropertyAll(t.strong),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: buttonStyle.copyWith(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        iconSize: const WidgetStatePropertyAll(18),
        shape: WidgetStatePropertyAll(shape(6)),
        side: const WidgetStatePropertyAll(BorderSide.none),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: shape(6),
      selectedTileColor: t.brutal ? t.accentFill : t.card,
      textColor: t.ink,
      iconColor: t.colors['foreground-icon']!,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      horizontalTitleGap: 6,
      minLeadingWidth: 18,
      titleTextStyle: textTheme.bodyMedium,
      subtitleTextStyle: textTheme.bodySmall,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.popover,
      surfaceTintColor: Colors.transparent,
      shape: shape(
        8,
        side: BorderSide(color: t.line, width: t.border),
      ),
      titleTextStyle: t.brutal
          ? textTheme.titleLarge
          : text(14, 20, heading: true, weight: FontWeight.w500),
      contentTextStyle: textTheme.bodyMedium,
      elevation: 0,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: t.popover,
      surfaceTintColor: Colors.transparent,
      elevation: t.brutal ? 0 : 3,
      shape: shape(
        6,
        side: BorderSide(color: t.line, width: t.border),
      ),
      textStyle: textTheme.bodyMedium,
      menuPadding: const EdgeInsets.all(4),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(t.popover),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
        shape: WidgetStatePropertyAll(
          shape(
            6,
            side: BorderSide(color: t.line, width: t.border),
          ),
        ),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: buttonStyle.copyWith(
        alignment: Alignment.centerLeft,
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        side: const WidgetStatePropertyAll(BorderSide.none),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: t.fieldStyle,
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(t.popover),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          shape(
            6,
            side: BorderSide(color: t.line, width: t.border),
          ),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: t.panel,
      selectedColor: t.brutal ? t.accentFill : t.accentSoft,
      labelStyle: textTheme.labelMedium,
      side: BorderSide(color: t.line, width: t.brutal ? 1 : .5),
      shape: shape(4),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      showCheckmark: false,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: shape(2),
      side: BorderSide(color: t.line, width: t.brutal ? 2 : 1),
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? t.primaryFill : t.panel,
      ),
      checkColor: WidgetStatePropertyAll(t.strong),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStatePropertyAll(t.strong),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? t.primaryFill
            : t.colors['fill-strong']!,
      ),
      thumbColor: WidgetStatePropertyAll(t.panel),
      trackOutlineColor: WidgetStatePropertyAll(t.line),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: buttonStyle.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? t.brutal
                    ? t.primaryFill
                    : t.panel
              : t.colors['fill-muted']!,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.canvas,
      surfaceTintColor: Colors.transparent,
      indicatorColor: t.brutal ? t.accentFill : t.card,
      elevation: 0,
      iconTheme: WidgetStatePropertyAll(IconThemeData(size: 18, color: t.ink)),
      labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(t.brutal ? 0 : 4),
      ),
      textStyle: textTheme.bodySmall!.copyWith(color: scheme.onInverseSurface),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: shape(6),
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium!.copyWith(
        color: scheme.onInverseSurface,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: t.line,
      thickness: t.brutal ? 2 : 1,
      space: 1,
    ),
  );
}
