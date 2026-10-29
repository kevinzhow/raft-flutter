import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:raft_theme/raft_theme.dart'
    show RaftModeValues, RaftShadowSpec, RaftFontSpec, builtInRaftTheme;

import 'component_colors.g.dart';
import 'metrics.g.dart';
import 'product_colors.g.dart';
import 'raft_token_mapping.dart';
import 'raft_tokens.g.dart';
import 'semantic_colors.g.dart';
import 'shadows.g.dart';

/// Bundled design faces (`packages/raft_ui/assets/fonts`, pubspec families).
const String raftSansFontFamily = 'packages/raft_ui/SpaceGrotesk';
const String raftMonoFontFamily = 'packages/raft_ui/SpaceMono';

// Theme packs carry CSS family names. Flutter assets are registered under
// package-qualified names; unrecognised user families remain platform names.
String _bundledFamily(String family) => switch (family) {
  'Space Grotesk' || 'SpaceGrotesk' => raftSansFontFamily,
  'Space Mono' || 'SpaceMono' => raftMonoFontFamily,
  'Geist Mono' || 'GeistMono' => 'packages/raft_ui/GeistMono',
  'Geist' => 'packages/raft_ui/Geist',
  'Inter' => 'packages/raft_ui/Inter',
  'Hanken Grotesk' || 'HankenGrotesk' => 'packages/raft_ui/HankenGrotesk',
  _ => family,
};

/// raft-ui 0.7.1 `fonts.css`: `--heading-font` and `--sans-font` are the same stack.
const List<String> raftSansFontStack = [
  'Space Grotesk',
  'PingFang SC',
  'Hiragino Sans GB',
  'Microsoft YaHei',
  'Noto Sans SC',
  'system-ui',
  'sans-serif',
];

/// `--mono-font`.
const List<String> raftMonoFontStack = [
  'Space Mono',
  'ui-monospace',
  'SF Mono',
  'Menlo',
  'monospace',
];

/// The Raft Design System has one look in two modes.
enum RaftThemeId { light, dark }

/// Everything one mode resolves to: semantic, product and component colours,
/// shadows and metrics, filled from [RaftLight] / [RaftDark] through the tables
/// in raft_token_mapping.dart.
@immutable
class RaftTokenSet {
  const RaftTokenSet._(
    this.id,
    this.colors,
    this.product,
    this.components,
    this.shadows,
    this.metrics,
  );
  final RaftThemeId id;
  final RaftSemanticColors colors;
  final RaftProductColors product;
  final RaftComponentColors components;
  final RaftThemeShadows shadows;
  final RaftThemeMetrics metrics;

  static final RaftTokenSet light = of(RaftThemeId.light);
  static final RaftTokenSet dark = of(RaftThemeId.dark);

  static final Map<RaftThemeId, RaftTokenSet> _builtIn = {};

  /// The token set the app paints with: one mode of the built-in Raft theme,
  /// resolved once per mode. [fromStatics] is the generated reference these
  /// were checked against (`theme_pack_parity_test.dart`).
  static RaftTokenSet of(RaftThemeId id) => _builtIn.putIfAbsent(
    id,
    () => RaftTokenSet.fromPack(
      id,
      mode: builtInRaftTheme.resolve(dark: id == RaftThemeId.dark),
    ),
  );

  /// Every tier read from one mode of a theme pack instead of the generated
  /// statics.
  /// [fonts] are the pack's own family/stack declarations. Without them every
  /// theme would paint the built-in Raft typeface, which is what happened before
  /// this parameter existed: Elegant's Geist/Inter never reached a single glyph.
  factory RaftTokenSet.fromPack(
    RaftThemeId id, {
    required RaftModeValues mode,
    Map<String, RaftFontSpec> fonts = const {},
  }) {
    // A pack may declare only some families; the Raft stacks remain the fallback.
    RaftFontSpec? spec(String role) => fonts[role];
    final headingStack = spec('heading')?.stack.isNotEmpty == true
        ? spec('heading')!.stack
        : raftSansFontStack;
    final sansStack = spec('sans')?.stack.isNotEmpty == true
        ? spec('sans')!.stack
        : raftSansFontStack;
    final monoStack = spec('mono')?.stack.isNotEmpty == true
        ? spec('mono')!.stack
        : raftMonoFontStack;
    final headingFamily = _bundledFamily(
      spec('heading')?.family ?? raftSansFontFamily,
    );
    final sansFamily = _bundledFamily(
      spec('sans')?.family ?? raftSansFontFamily,
    );
    final monoFamily = _bundledFamily(
      spec('mono')?.family ?? raftMonoFontFamily,
    );
    final colors = {...mode.colors, ...mode.palette};
    RaftShadow shadow(String role) => RaftShadow([
      for (final layer in mode.shadows[role] ?? const <RaftShadowSpec>[])
        RaftCssShadow(
          inset: layer.inset,
          offset: layer.offset,
          blur: layer.blur,
          spread: layer.spread,
          color: layer.color,
        ),
    ]);
    double token(String name, double fallback) =>
        mode.geometry[name] ?? fallback;
    return RaftTokenSet._(
      id,
      RaftSemanticColors.fromCssMap(colors),
      RaftProductColors.fromCssMap(colors),
      RaftComponentColors.fromCssMap(colors),
      RaftThemeShadows(
        xs: shadow('xs'),
        sm: shadow('sm'),
        md: shadow('md'),
        lg: shadow('lg'),
        xl: shadow('xl'),
      ),
      RaftThemeMetrics(
        fieldFontSize: token('type.field.size', 16),
        fieldFontWeight: token('type.field.weight', 400),
        fieldLineHeight: token('type.field.line', 24),
        cardTitleFontSize: token('type.cardTitle.size', 16),
        cardTitleFontWeight: token('type.cardTitle.weight', 500),
        cardTitleLineHeight: token('type.cardTitle.line', 22),
        headingFontStack: headingStack,
        sansFontStack: sansStack,
        monoFontStack: monoStack,
        headingFont: headingFamily,
        sansFont: sansFamily,
        monoFont: monoFamily,
      ),
    );
  }

  /// The same tiers read from the generated raft-ui 0.7.1 statics. Kept as the
  /// independent oracle the packs are compared against.
  static RaftTokenSet fromStatics(RaftThemeId id) {
    final dark = id == RaftThemeId.dark;
    final tokens = dark ? RaftDark.colors : RaftLight.colors;
    final shadows = dark ? RaftDark.shadows : RaftLight.shadows;
    Map<String, Color> colors(Map<String, String> table) => {
      for (final e in table.entries)
        e.key: e.value == raftTransparentToken
            ? const Color(0x00000000)
            : tokens[e.value] ??
                  (throw StateError('${e.key}: no 0.7.1 token ${e.value}')),
    };
    RaftShadow shadow(String name) {
      final token = raftShadowMapping[name]!;
      return token == raftNoShadowToken
          ? const RaftShadow([])
          : shadows[token]!;
    }

    double metric(String field) => raftCarriedMetrics[field]!;
    return RaftTokenSet._(
      id,
      RaftSemanticColors.fromCssMap(colors(raftSemanticMapping)),
      RaftProductColors.fromCssMap(colors(raftProductMapping)),
      RaftComponentColors.fromCssMap(colors(raftComponentMapping)),
      RaftThemeShadows(
        xs: shadow('theme-shadow-xs'),
        sm: shadow('theme-shadow-sm'),
        md: shadow('theme-shadow-md'),
        lg: shadow('theme-shadow-lg'),
        xl: shadow('theme-shadow-xl'),
      ),
      RaftThemeMetrics(
        fieldFontSize: metric('fieldFontSize'),
        fieldFontWeight: metric('fieldFontWeight'),
        fieldLineHeight: metric('fieldLineHeight'),
        cardTitleFontSize: metric('cardTitleFontSize'),
        cardTitleFontWeight: metric('cardTitleFontWeight'),
        cardTitleLineHeight: metric('cardTitleLineHeight'),
        // raft-ui 0.7.1 fonts.css `--heading-font` / `--sans-font` / `--mono-font`.
        headingFontStack: raftSansFontStack,
        sansFontStack: raftSansFontStack,
        monoFontStack: raftMonoFontStack,
        headingFont: raftSansFontFamily,
        sansFont: raftSansFontFamily,
        monoFont: raftMonoFontFamily,
      ),
    );
  }
}
