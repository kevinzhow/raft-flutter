// Typography policy for single-line control labels (badges, chips, buttons,
// tabs, segments). See docs/android-cjk-control-typography.md.
import 'package:flutter/material.dart';

import 'tokens/typography.g.dart';

/// Static vertical metrics for single-line control labels.
///
/// Flutter centres a font's line box, not the visible glyph outline. The
/// Android system CJK fallback places Chinese ink off the centre of that box,
/// and `leadingDistribution: even` (the CSS half-leading model the recipes use)
/// preserves the font's own offset. A taller line split proportionally to
/// ascent/descent moves the baseline to where the ink is centred. The value is
/// measured on a device and lives in `tool/design-source/control-typography.json`.
///
/// Windows' YaHei fallback has the opposite offset: a shorter proportional
/// line centres its ink. The platform profiles share this entry point.
/// Scope: Android/Windows + Chinese locale + single-line control label.
/// Body text, multi-line text and other platform/locales keep their metrics.
abstract final class RaftControlTypography {
  /// `TextStyle.height` factor of the Android Chinese control profile.
  static double get androidChineseLineHeight =>
      debugAndroidChineseLineHeight ??
      RaftControlTypographyTokens.androidChineseLineHeight;

  /// Measured line-height factor for Windows Chinese control labels.
  static double get windowsChineseLineHeight =>
      RaftControlTypographyTokens.windowsChineseLineHeight;

  /// Measurement hook for the device sweep (tool/cjk-labels); never set in
  /// product code.
  @visibleForTesting
  static double? debugAndroidChineseLineHeight;

  /// Measurement hook: behave as if the profile did not exist.
  @visibleForTesting
  static bool debugDisabled = false;

  static bool appliesTo({
    required TargetPlatform platform,
    required Locale locale,
  }) =>
      !debugDisabled &&
      (platform == TargetPlatform.android ||
          platform == TargetPlatform.windows) &&
      locale.languageCode == 'zh';

  /// [baseStyle] with the control profile when it applies, otherwise
  /// [baseStyle] itself. Only `height` and `leadingDistribution` change; size,
  /// weight, colour and font fallbacks are kept.
  static TextStyle resolve({
    required TextStyle baseStyle,
    required TargetPlatform platform,
    required Locale locale,
  }) {
    if (!appliesTo(platform: platform, locale: locale)) return baseStyle;
    return baseStyle.copyWith(
      height: platform == TargetPlatform.windows
          ? windowsChineseLineHeight
          : androidChineseLineHeight,
      leadingDistribution: TextLeadingDistribution.proportional,
    );
  }

  /// [resolve] for the platform and locale of [context].
  static TextStyle of(BuildContext context, TextStyle baseStyle) => resolve(
    baseStyle: baseStyle,
    platform: Theme.of(context).platform,
    locale: Localizations.maybeLocaleOf(context) ?? const Locale('en'),
  );

  /// Whether the profile applies in [context] (for call sites that need to
  /// skip a CSS line-box snap or similar).
  static bool appliesIn(BuildContext context) => appliesTo(
    platform: Theme.of(context).platform,
    locale: Localizations.maybeLocaleOf(context) ?? const Locale('en'),
  );

  /// Whether [style] already carries the profile.
  static bool isControlStyle(TextStyle style) =>
      style.leadingDistribution == TextLeadingDistribution.proportional &&
      (style.height == androidChineseLineHeight ||
          style.height == windowsChineseLineHeight);
}
