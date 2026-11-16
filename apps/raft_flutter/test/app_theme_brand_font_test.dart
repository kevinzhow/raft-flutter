import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/app_theme.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  const brand = 'packages/raft_ui/SpaceGrotesk';
  const mono = 'packages/raft_ui/SpaceMono';

  RaftTokens tokensFor(Locale textLocale, {bool dark = false}) => raftAppTheme(
    dark: dark,
    appearance: const RaftAppearance(),
    locale: const Locale('en'),
    textLocale: textLocale,
  ).extension<RaftTokens>()!;

  for (final dark in [false, true]) {
    test('Android app theme uses the bundled brand faces (dark: $dark)', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final t = tokensFor(const Locale('zh', 'CN'), dark: dark);
      expect(t.bodyFont, brand);
      expect(t.headingFont, brand);
      expect(t.monoFont, mono);
    });
  }

  // Android's fonts.xml registers the CJK faces as unnamed `lang=` fallback
  // families, so the engine cannot find 'Noto Sans CJK SC' by name (emulator
  // probe, API 36): the regional face is chosen by the text style's locale.
  // The theme's text styles must therefore carry the device locale, and the
  // fallback list must end in the generic 'sans-serif'.
  test('Android app theme picks the regional CJK face through the locale', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final locale in const [
      Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
        countryCode: 'CN',
      ),
      Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'TW',
      ),
      Locale('ja', 'JP'),
      Locale('ko', 'KR'),
    ]) {
      final theme = raftAppTheme(
        dark: false,
        appearance: const RaftAppearance(),
        locale: const Locale('zh', 'CN'),
        textLocale: locale,
      );
      for (final style in [
        theme.textTheme.bodyMedium!,
        theme.textTheme.labelLarge!,
        theme.textTheme.titleMedium!,
      ]) {
        expect(style.locale, locale, reason: '$locale');
        expect(style.fontFamily, brand, reason: '$locale');
        expect(style.fontFamilyFallback, contains('sans-serif'));
      }
    }
  });
}
