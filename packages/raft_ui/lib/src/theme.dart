import 'package:flutter/material.dart';

import 'generated_tokens.dart';

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

@immutable
class RaftTokens extends ThemeExtension<RaftTokens> {
  const RaftTokens(this.family, this.dark, this.colors);
  final RaftFamily family;
  final bool dark;
  final Map<String, Color> colors;
  bool get brutal => family == RaftFamily.brutal;
  Color get ink => colors['foreground']!;
  Color get muted => colors['foreground-muted']!;
  Color get canvas => colors['layer-canvas']!;
  Color get sidebar => colors['layer-canvas-muted']!;
  Color get panel => colors['layer-panel']!;
  Color get line => colors[brutal ? 'line-strong' : 'line-muted']!;
  Color get accent => colors['accent-strong']!;
  Color get accentSoft => colors['accent-soft']!;
  double get radius => brutal ? 0 : 8;
  double get border => brutal ? 2 : 1;
  List<BoxShadow> get shadows => brutal
      ? [BoxShadow(color: ink, offset: const Offset(2, 2))]
      : [
          BoxShadow(
            color: ink.withValues(alpha: .05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ];
  static RaftTokens of(BuildContext context) =>
      Theme.of(context).extension<RaftTokens>()!;
  @override
  RaftTokens copyWith({
    RaftFamily? family,
    bool? dark,
    Map<String, Color>? colors,
  }) => RaftTokens(
    family ?? this.family,
    dark ?? this.dark,
    colors ?? this.colors,
  );
  @override
  RaftTokens lerp(covariant RaftTokens? other, double t) =>
      other == null || t < .5 ? this : other;
}

ThemeData raftTheme(RaftFamily family, {bool dark = false}) {
  if (dark) family = RaftFamily.elegant;
  final t = RaftTokens(
    family,
    dark,
    dark
        ? elegant_dark
        : family == RaftFamily.brutal
        ? brutal_light
        : elegant_light,
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(t.radius),
  );
  final scheme =
      ColorScheme.fromSeed(
        seedColor: t.accent,
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: t.accent,
        onPrimary: dark ? Colors.black : Colors.white,
        surface: t.canvas,
        onSurface: t.ink,
        outline: t.line,
        secondaryContainer: t.accentSoft,
        onSecondaryContainer: t.ink,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.canvas,
    fontFamily: family == RaftFamily.brutal
        ? 'packages/raft_ui/HankenGrotesk'
        : 'packages/raft_ui/Geist',
    fontFamilyFallback: const [
      'Noto Sans CJK JP',
      'Noto Sans CJK SC',
      'sans-serif',
    ],
    extensions: [t],
    dividerColor: t.line,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: t.canvas,
      foregroundColor: t.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: t.ink,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    drawerTheme: DrawerThemeData(backgroundColor: t.sidebar, shape: shape),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.panel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(t.radius),
        borderSide: BorderSide(color: t.line, width: t.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(t.radius),
        borderSide: BorderSide(color: t.line, width: t.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        minimumSize: const Size(48, 48),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: shape,
        side: BorderSide(color: t.line, width: t.border),
        minimumSize: const Size(48, 48),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: shape,
      selectedTileColor: t.accentSoft,
      textColor: t.ink,
      iconColor: t.muted,
    ),
    dialogTheme: DialogThemeData(backgroundColor: t.panel, shape: shape),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: shape,
    ),
  );
}
