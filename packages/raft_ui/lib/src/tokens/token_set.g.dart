// GENERATED — do not edit. Regenerate with `tool/gen-tokens`.
// Source: the generated tier files in this directory
// dart format off
// ignore_for_file: constant_identifier_names, lines_longer_than_80_chars

import 'package:flutter/foundation.dart';

import 'component_colors.g.dart';
import 'metrics.g.dart';
import 'product_colors.g.dart';
import 'semantic_colors.g.dart';
import 'shadows.g.dart';

/// The three Web theme presets.
enum RaftThemeId { brutal, elegantLight, elegantDark }

/// Everything one theme resolves to: semantic, product and component colours,
/// shadows and metrics.
@immutable
class RaftTokenSet {
  const RaftTokenSet._(this.id, this.colors, this.product, this.components, this.shadows, this.metrics);
  final RaftThemeId id;
  final RaftSemanticColors colors;
  final RaftProductColors product;
  final RaftComponentColors components;
  final RaftThemeShadows shadows;
  final RaftThemeMetrics metrics;

  static const brutal = RaftTokenSet._(RaftThemeId.brutal, RaftSemanticColors.brutal, RaftProductColors.brutal, RaftComponentColors.brutal, RaftThemeShadows.brutal, RaftThemeMetrics.brutal);
  static const elegantLight = RaftTokenSet._(RaftThemeId.elegantLight, RaftSemanticColors.elegantLight, RaftProductColors.elegantLight, RaftComponentColors.elegantLight, RaftThemeShadows.elegantLight, RaftThemeMetrics.elegantLight);
  static const elegantDark = RaftTokenSet._(RaftThemeId.elegantDark, RaftSemanticColors.elegantDark, RaftProductColors.elegantDark, RaftComponentColors.elegantDark, RaftThemeShadows.elegantDark, RaftThemeMetrics.elegantDark);

  static RaftTokenSet of(RaftThemeId id) => switch (id) {
    RaftThemeId.brutal => brutal,
    RaftThemeId.elegantLight => elegantLight,
    RaftThemeId.elegantDark => elegantDark,
  };
}
