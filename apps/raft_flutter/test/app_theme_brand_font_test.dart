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

  test('Android app theme falls back to the locale CJK face by name', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    void leads(Locale locale, String face) {
      final list = tokensFor(locale).fontFallback;
      expect(list, contains(face), reason: '$locale');
      expect(list.indexOf(face), lessThan(list.indexOf('sans-serif')));
    }

    leads(const Locale('zh', 'CN'), 'Noto Sans CJK SC');
    leads(const Locale('zh', 'TW'), 'Noto Sans CJK TC');
    leads(const Locale('ja'), 'Noto Sans CJK JP');
    leads(const Locale('ko'), 'Noto Sans CJK KR');
    expect(
      tokensFor(const Locale('ja')).fontFallback.first,
      'Noto Sans CJK JP',
    );
    expect(
      tokensFor(const Locale('ko')).fontFallback.first,
      'Noto Sans CJK KR',
    );
    expect(
      tokensFor(const Locale('zh', 'TW')).fontFallback.first,
      'Noto Sans CJK TC',
    );
  });
}
