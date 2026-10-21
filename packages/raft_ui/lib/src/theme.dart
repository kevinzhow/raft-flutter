import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:raft_theme/raft_theme.dart';

import 'control_typography.dart';
import 'tokens/tokens.dart';

/// The appearance setting: which theme to paint with (Raft, Elegant, Brutal or
/// a user pack) and Light / Dark / System for its two modes.
///
/// The theme and the mode are independent: every theme carries both a light and
/// a dark set of values, so choosing Elegant and Dark is meaningful, and so is
/// Elegant and System.
class RaftAppearance {
  const RaftAppearance({
    this.mode = ThemeMode.system,
    this.themeId = builtInRaftThemeId,
  });
  final ThemeMode mode;

  /// The id of the theme pack to paint with. Must name a loadable pack; an
  /// unknown id is reported by the registry rather than silently ignored.
  final String themeId;

  RaftAppearance copyWith({ThemeMode? mode, String? themeId}) =>
      RaftAppearance(mode: mode ?? this.mode, themeId: themeId ?? this.themeId);

  /// The pack this appearance paints with.
  ///
  /// An id that no longer names a built-in theme falls back to Raft rather than
  /// painting nothing: a stored id can outlive the theme it names (a user pack
  /// removed in a release), and the default look is a better failure than a
  /// blank window. The stored id itself is not rewritten, so the user's choice
  /// survives.
  ///
  /// Lives here rather than at the call site so the app root keeps only a call.
  RaftThemePack get pack => packForThemeId(themeId);
}

/// The id of the built-in Raft pack, the default appearance.
const String builtInRaftThemeId = raftThemePackId;

/// The themes offered in the appearance setting, in the order the picker shows
/// them, with the label each one carries in the UI.
const List<({String id, String en, String zh})> builtInAppearanceThemes = [
  (id: raftThemePackId, en: 'Raft', zh: 'Raft'),
  (id: 'elegant', en: 'Elegant', zh: '雅致'),
  (id: 'brutal', en: 'Brutal', zh: '粗野'),
];

/// The token set of a brightness.
RaftThemeId raftThemeId({bool dark = false}) =>
    dark ? RaftThemeId.dark : RaftThemeId.light;

// No cache keyed by theme id: two themes can both be "light", and a cached map
// would hand the second one the first one's colours.

/// The CJK part of the design stack (raft-ui `fonts.css`): PingFang on Apple platforms, YaHei on Windows,
/// Noto Sans SC elsewhere. Families a platform does not have are skipped by the engine.
const List<String> _raftCjkChain = [
  'PingFang SC',
  'Hiragino Sans GB',
  'Microsoft YaHei',
  'Noto Sans SC',
];

/// String-keyed compatibility view over the generated tokens, keyed by CSS
/// custom-property name without `--`: primitives (`color-brutal-yellow-400`),
/// semantic (`foreground-muted`, `ink-8`), product aliases (`color-brutal-cyan`)
/// and component roles (`button-default-fill`). Prefer the typed tiers.
Map<String, Color> raftColorMap(RaftTokenSet set) => Map.unmodifiable({
  for (final e in RaftPrimitiveColors.byCssName.entries)
    e.key.substring(2): e.value,
  ...set.colors.toCssMap(),
  ...set.product.toCssMap(),
  ...set.components.toCssMap(),
});

@immutable
class RaftFontFamilies {
  const RaftFontFamilies({
    this.body = 'sans-serif',
    this.heading = 'sans-serif',
    this.mono = 'monospace',
    this.fallback = const [],
  });

  final String body, heading, mono;
  final List<String> fallback;
}

/// Offset and thickness of the shared underline (see [RaftUnderlines]).
@immutable
class RaftUnderlineMetrics {
  const RaftUnderlineMetrics({required this.offset, required this.thickness});

  /// Gap between the alphabetic baseline and the stroke's top edge.
  final double offset;
  final double thickness;

  static RaftUnderlineMetrics of(BuildContext context) =>
      RaftTokens.of(context).underline;

  @override
  bool operator ==(Object other) =>
      other is RaftUnderlineMetrics &&
      other.offset == offset &&
      other.thickness == thickness;

  @override
  int get hashCode => Object.hash(offset, thickness);
}

class RaftTokens extends ThemeExtension<RaftTokens> {
  /// [colors] is the string-keyed view; [tokens] defaults to the Raft set for
  /// [dark].
  const RaftTokens(
    this.dark,
    this.colors, {
    RaftTokenSet? tokens,
    RaftModeValues? mode,
    this.systemFonts = false,
    this.systemFontFamilies = const RaftFontFamilies(),
    this.textLocale,
  }) : _tokens = tokens,
       _mode = mode;

  /// The tokens of one mode of [pack] (the built-in Raft theme by default).
  ///
  /// Everything a theme can set is read from the pack: colours, shadows, the
  /// six type metrics and the radii. The value has to equal what the generated
  /// 0.7.1 statics resolve to for the Raft pack — `theme_pack_parity_test.dart`
  /// proves it — so switching the source changes no pixel.
  factory RaftTokens.theme({
    bool dark = false,
    RaftThemePack? pack,
    bool systemFonts = false,
    RaftFontFamilies systemFontFamilies = const RaftFontFamilies(),
    Locale? textLocale,
  }) {
    final themePack = pack ?? builtInRaftTheme;
    // A user pack extends the built-in one; resolve through that chain so the
    // values it does not set come from Raft rather than from nothing.
    final mode = themePack.resolve(
      dark: dark,
      base: themePack.extendsId == builtInRaftTheme.id
          ? builtInRaftTheme
          : null,
    );
    final id = raftThemeId(dark: dark);
    // The built-in theme is the canonical instance the rest of the app compares
    // against; any other pack is resolved fresh from its values.
    final set = pack == null
        ? RaftTokenSet.of(id)
        : RaftTokenSet.fromPack(id, mode: mode);
    return RaftTokens(
      dark,
      // The pack's own names (0.7.1 roles, palette) sit on top of the legacy
      // compatibility view, so a reader of either vocabulary finds its key.
      Map.unmodifiable({...raftColorMap(set), ...mode.colors, ...mode.palette}),
      tokens: set,
      mode: mode,
      systemFonts: systemFonts,
      systemFontFamilies: systemFontFamilies,
      textLocale: textLocale,
    );
  }
  final bool dark;
  final bool systemFonts;
  final RaftFontFamilies systemFontFamilies;

  /// Locale for regional glyphs, independently of the UI translation locale.
  final Locale? textLocale;
  final Map<String, Color> colors;
  final RaftTokenSet? _tokens;

  /// The resolved pack values for this mode; null when the tokens were built
  /// the old way (tests that construct a bare [RaftTokenSet]).
  final RaftModeValues? _mode;

  /// Every generated tier for this theme.
  RaftTokenSet get tokenSet =>
      _tokens ?? RaftTokenSet.of(raftThemeId(dark: dark));
  RaftSemanticColors get semantic => tokenSet.colors;
  RaftProductColors get product => tokenSet.product;
  RaftComponentColors get components => tokenSet.components;
  RaftThemeShadows get themeShadows => tokenSet.shadows;
  RaftThemeMetrics get metrics => tokenSet.metrics;

  Color get ink => colors['foreground']!;
  Color get strong => colors['foreground-strong']!;
  Color get muted => colors['foreground-muted']!;
  Color get canvas => colors['layer-canvas']!;
  Color get sidebar => colors['layer-canvas-muted']!;
  Color get panel => colors['layer-panel']!;
  Color get card => colors['layer-card']!;
  Color get popover => colors['layer-popover']!;
  Color get line => colors['line-muted']!;
  Color get fieldLine => colors['line-field']!;
  Color get accent => colors['accent-strong']!;
  Color get accentSoft => colors['accent-soft']!;
  Color get accentFill => colors['accent']!;
  Color get primaryFill => colors['primary']!;
  String get bodyFont =>
      systemFonts ? systemFontFamilies.body : metrics.sansFont;
  String get headingFont =>
      systemFonts ? systemFontFamilies.heading : metrics.headingFont;
  String get monoFont =>
      systemFonts ? systemFontFamilies.mono : metrics.monoFont;
  List<String> get fontFallback => systemFonts
      ? systemFontFamilies.fallback
      : switch (textLocale?.languageCode) {
          'zh'
              when textLocale?.scriptCode == 'Hant' ||
                  textLocale?.scriptCode != 'Hans' &&
                      const [
                        'TW',
                        'HK',
                        'MO',
                      ].contains(textLocale?.countryCode) =>
            const [
              'Noto Sans CJK TC',
              'Noto Sans CJK SC',
              'Noto Sans CJK JP',
              'sans-serif',
            ],
          'zh' => const [
            ..._raftCjkChain,
            'Noto Sans CJK SC',
            'Noto Sans CJK JP',
            'sans-serif',
          ],
          'ko' => const [
            'Noto Sans CJK KR',
            'Noto Sans CJK JP',
            'Noto Sans CJK SC',
            'sans-serif',
          ],
          'ja' => const ['Noto Sans CJK JP', 'Noto Sans CJK SC', 'sans-serif'],
          _ => const [
            ..._raftCjkChain,
            'Noto Sans CJK JP',
            'Noto Sans CJK SC',
            'sans-serif',
          ],
        };

  /// Radii and stroke widths come from the theme's numeric tokens, so a theme
  /// that squares the corners reaches every control. The fallbacks are the
  /// Raft values for a [RaftTokens] built without a pack (tests).
  double get radius => _mode?.geometry['radius.control'] ?? 8;
  double get fieldRadius => _mode?.geometry['radius.field'] ?? 6;
  double get border => _mode?.geometry['stroke.container'] ?? 1;

  /// Any other numeric token, by contract name. Components read control sizes
  /// and stroke widths through this rather than repeating the Raft number as a
  /// literal, which is what kept two of three themes stuck on Raft's geometry.
  ///
  /// [fallback] is the Raft value, used when a theme does not set the token (a
  /// pack may override only what it cares about).
  double size(String token, {required double fallback}) =>
      _mode?.geometry[token] ?? fallback;

  /// A structural option, by contract name. A component asks how to draw
  /// itself; it must never ask which theme is current.
  ///
  /// The named default is [or] rather than the obvious `fallback` on purpose:
  /// that word is the app's convention for a user-visible string (as in
  /// `userErrorText`), and the zh-catalog scanner treats every literal after it
  /// as translation text. Reusing the name made a theme option value look like
  /// UI copy and failed the catalog test.
  String option(String name, {required String or}) => _mode?.options[name] ?? or;

  /// The hyperlink underline every underlined run shares (Web `underline
  /// decoration-2 underline-offset-2`; no theme overrides it, so Brutal and
  /// Elegant agree and only the colour differs by recipe).
  RaftUnderlineMetrics get underline =>
      const RaftUnderlineMetrics(offset: 2, thickness: 2);
  TextStyle get fieldStyle => TextStyle(
    locale: textLocale,
    fontFamily: headingFont,
    fontFamilyFallback: fontFallback,
    fontSize: metrics.fieldFontSize,
    height: metrics.fieldLineHeight / metrics.fieldFontSize,
    fontWeight: raftFontWeight(metrics.fieldFontWeight),
    letterSpacing: 0,
    color: ink,
  );

  /// The control shadow: `theme-shadow-sm`, which the Raft look maps to nothing
  /// (controls never cast a shadow, so the list is empty). Inset layers are
  /// drawn separately by surfaces.
  List<BoxShadow> get shadows => themeShadows.sm.outer;

  /// The focus lift was Brutal's `--theme-shadow-md`; the Raft focus ring is a
  /// follow-up, so focus adds nothing here.
  List<BoxShadow> get focusShadows => shadows;
  static RaftTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<RaftTokens>() ??
        RaftTokens.theme(dark: theme.brightness == Brightness.dark);
  }

  @override
  RaftTokens copyWith({
    bool? dark,
    Map<String, Color>? colors,
    Locale? textLocale,
  }) => dark == null
      ? RaftTokens(
          this.dark,
          colors ?? this.colors,
          tokens: _tokens,
          mode: _mode,
          systemFonts: systemFonts,
          systemFontFamilies: systemFontFamilies,
          textLocale: textLocale ?? this.textLocale,
        )
      : RaftTokens.theme(
          dark: dark,
          systemFonts: systemFonts,
          systemFontFamilies: systemFontFamilies,
          textLocale: textLocale ?? this.textLocale,
        );
  @override
  RaftTokens lerp(covariant RaftTokens? other, double t) =>
      other == null || t < .5 ? this : other;
}

/// raft-ui 0.7.1 `Input` colours for the Material-hosted text fields (`RaftFieldSurface` + the input decoration
/// theme): `bg-layer-card border-line-strong`, disabled `bg-fill-muted border-line-hairline`.
@immutable
class RaftFieldRecipe {
  const RaftFieldRecipe(this.tokens);
  final RaftTokens tokens;
  Color fill({bool disabled = false}) =>
      tokens.colors[disabled ? 'fill-muted' : 'layer-card']!;
  Color placeholder({bool disabled = false}) =>
      tokens.colors[disabled ? 'foreground-disabled' : 'foreground-hint']!;

  Color border({bool disabled = false, bool hovered = false}) =>
      tokens.colors[disabled ? 'line-hairline' : 'line-strong']!;
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

ThemeData raftTheme({
  bool dark = false,

  /// The theme to paint with. Defaults to the built-in Raft pack, which is
  /// identical to the look the app had before themes became data.
  RaftThemePack? pack,
  bool systemFonts = false,
  RaftFontFamilies systemFontFamilies = const RaftFontFamilies(),

  /// The UI locale. With [platform] it selects [RaftControlTypography] for the
  /// Material control families (buttons, chips, segments, menus, nav labels);
  /// without it the theme keeps the Web line boxes.
  Locale? locale,

  /// Locale for font selection and CJK glyphs; the app supplies the device's
  /// locale without changing [locale], which controls UI copy and line boxes.
  Locale? textLocale,
  TargetPlatform? platform,
}) {
  final t = RaftTokens.theme(
    dark: dark,
    pack: pack,
    systemFonts: systemFonts,
    systemFontFamilies: systemFontFamilies,
    textLocale: textLocale,
  );
  RoundedRectangleBorder shape(
    double radius, {
    BorderSide side = BorderSide.none,
  }) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
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
    // The Raft solid `danger` is a salmon sticker; error text and borders use
    // the readable `danger-strong`.
    error: t.colors['danger-strong']!,
    onError: t.colors['foreground-inverse']!,
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
    locale: t.textLocale,
    fontFamily: heading ? t.headingFont : t.bodyFont,
    fontFamilyFallback: t.fontFallback,
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
    bodyLarge: t.fieldStyle.copyWith(fontFamilyFallback: t.fontFallback),
    bodyMedium: text(16, 24),
    bodySmall: text(12, 16, color: t.muted),
    labelLarge: text(14, 20, heading: false, weight: FontWeight.w500),
    labelMedium: text(12, 16, weight: FontWeight.w500),
    labelSmall: text(11, 16, weight: FontWeight.w500),
  );
  TextStyle? control(TextStyle? style) => style == null || locale == null
      ? style
      : RaftControlTypography.resolve(
          baseStyle: style,
          platform: platform ?? defaultTargetPlatform,
          locale: locale,
        );
  final buttonStyle = ButtonStyle(
    textStyle: WidgetStatePropertyAll(control(textTheme.labelLarge)),
    minimumSize: const WidgetStatePropertyAll(Size(32, 32)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    tapTargetSize: MaterialTapTargetSize.padded,
    shape: WidgetStatePropertyAll(shape(6)),
    side: WidgetStatePropertyAll(BorderSide(color: t.line, width: t.border)),
    elevation: const WidgetStatePropertyAll(0),
    animationDuration: const Duration(milliseconds: 100),
    overlayColor: WidgetStatePropertyAll(
      t.colors['fill-strong']!.withValues(alpha: .3),
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? t.ink.withValues(alpha: .4)
          : t.ink,
    ),
  );
  // `rounded-control border-[1.5px]`: the 0.7.1 input outline, 8px radius.
  OutlineInputBorder fieldBorder(Color color, [double? width]) =>
      RaftFieldBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: width ?? 1.5),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.canvas,
    canvasColor: t.panel,
    fontFamily: t.bodyFont,
    fontFamilyFallback: t.fontFallback,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      focusedBorder: fieldBorder(RaftFieldRecipe(t).border()),
      errorBorder: fieldBorder(t.colors['danger-strong']!),
      focusedErrorBorder: fieldBorder(t.colors['danger-strong']!),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: buttonStyle.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => t.accentFill.withValues(
            alpha: s.contains(WidgetState.disabled) ? .4 : 1,
          ),
        ),
        foregroundColor: WidgetStatePropertyAll(t.colors['accent-950']!),
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
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
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
      selectedTileColor: t.card,
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
      titleTextStyle: text(14, 20, heading: true, weight: FontWeight.w500),
      contentTextStyle: textTheme.bodyMedium,
      elevation: 0,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: t.popover,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: shape(
        6,
        side: BorderSide(color: t.line, width: t.border),
      ),
      textStyle: control(textTheme.bodyMedium),
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
      selectedColor: t.accentSoft,
      labelStyle: control(textTheme.labelMedium),
      side: BorderSide(color: t.line, width: .5),
      shape: shape(4),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      showCheckmark: false,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: shape(2),
      side: BorderSide(color: t.line, width: 1),
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
              ? t.panel
              : t.colors['fill-muted']!,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.canvas,
      surfaceTintColor: Colors.transparent,
      indicatorColor: t.card,
      elevation: 0,
      iconTheme: WidgetStatePropertyAll(IconThemeData(size: 18, color: t.ink)),
      labelTextStyle: WidgetStatePropertyAll(control(textTheme.labelMedium)),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: textTheme.bodySmall!.copyWith(color: scheme.onInverseSurface),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      // LocalizedToastProvider shows a ToastClose unless `hasClose` is false.
      showCloseIcon: true,
      closeIconColor: scheme.onInverseSurface,
      shape: shape(6),
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium!.copyWith(
        color: scheme.onInverseSurface,
      ),
    ),
    dividerTheme: DividerThemeData(color: t.line, thickness: 1, space: 1),
  );
}

/// CSS line-height semantics: half-leading above and below the glyph box
/// (Flutter's default distributes leading proportionally to ascent/descent).
const raftCssTextHeightBehavior = TextHeightBehavior(
  leadingDistribution: TextLeadingDistribution.even,
);
