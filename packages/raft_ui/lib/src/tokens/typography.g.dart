// GENERATED — do not edit. Regenerate with `tool/gen-tokens`.
// Source: control-typography.json (authored in-repo; Flutter-only policy, no Web CSS counterpart)
// dart format off

/// Typography policy tokens for single-line control labels.
///
/// Flutter centres a font's line box, not the visible glyphs. Android and Windows
/// CJK fallback faces need different, measured proportional line heights for
/// single-line control labels. See `RaftControlTypography` and
/// docs/android-cjk-control-typography.md.
abstract final class RaftControlTypographyTokens {
  /// `control.androidChineseLineHeight`: `TextStyle.height` factor.
  static const double androidChineseLineHeight = 1.3;
  /// `control.windowsChineseLineHeight`: `TextStyle.height` factor.
  static const double windowsChineseLineHeight = 1.2;
}
