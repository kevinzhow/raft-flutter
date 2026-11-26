import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/display_language_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/features/app_theme.dart';
import 'package:raft_flutter/features/resource_cards.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(DevicePreferences.reset);

  test('display options match Web order and native names', () {
    expect(displayLanguageOptions, [
      ('en', 'English'),
      ('es', 'Español'),
      ('pt-br', 'Português (Brasil)'),
      ('ru', 'Русский'),
      ('ko', '한국어'),
      ('ja', '日本語'),
      ('zh-cn', '简体中文'),
      ('zh-tw', '繁體中文'),
    ]);
  });

  test('device and account select the shipped language and Chinese script', () {
    expect(
      displayLocale(null, device: const Locale('es', 'MX')),
      const Locale('es'),
    );
    expect(displayLocale('pt-PT'), const Locale('pt', 'BR'));
    expect(displayLocale('zh-Hant-CN'), const Locale('zh', 'TW'));
    expect(displayLocale('zh-Hans-TW'), const Locale('zh', 'CN'));
    expect(displayLocale('zh-HK'), const Locale('zh', 'TW'));
    expect(
      displayLocale('fr', device: const Locale('ko', 'KR')),
      const Locale('ko'),
    );
    expect(systemDisplayLanguage(['fr-CA', 'ru-RU', 'en-US']), 'ru');
    expect(systemDisplayLanguage(['en-US', 'es-MX', 'zh-HK']), 'zh-tw');
    expect(systemDisplayLanguage(['en-US', 'ja-JP']), 'en');
  });

  test('Japanese and Korean UI choose their own regional glyphs', () {
    for (final platform in [TargetPlatform.linux, TargetPlatform.android]) {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      for (final (language, family) in [
        ('ja', 'Noto Sans CJK JP'),
        ('ko', 'Noto Sans CJK KR'),
      ]) {
        final locale = Locale(language);
        final theme = raftAppTheme(
          dark: false,
          appearance: const RaftAppearance(),
          locale: locale,
          textLocale: const Locale('zh', 'CN'),
        );
        expect(theme.textTheme.bodyMedium?.locale, locale);
        expect(theme.textTheme.bodyMedium?.fontFamilyFallback?.first, family);
      }
    }
  });

  test('a new display choice survives reload with other preferences', () async {
    SharedPreferences.setMockInitialValues({
      displayLanguagePreferenceKey: 'zh-cn',
      'raft.mode': 'dark',
    });
    await DevicePreferences.load();
    final old = DisplayLanguagePreferences();
    expect(old.value, 'zh-cn');
    await old.save('ja');
    old.dispose();
    await DevicePreferences.load();
    final restored = DisplayLanguagePreferences();
    expect(restored.resolve(null, signedIn: false), const Locale('ja'));
    expect(restored.resolve('ru', signedIn: true), const Locale('ru'));
    expect(DevicePreferences.current?.getString('raft.mode'), 'dark');
    restored.dispose();
  });

  final settings = {
    const Locale('es'): 'Configuración',
    const Locale('pt', 'BR'): 'Configurações',
    const Locale('ru'): 'Настройки',
    const Locale('ko'): '설정',
    const Locale('ja'): '設定',
    const Locale('zh', 'TW'): '設定',
  };

  for (final entry in settings.entries) {
    testWidgets(
      '${entry.key} localizes fixed copy and keeps English fallback',
      (tester) async {
        const nativeCopy = 'Native-only UI fallback for this test';
        await tester.pumpWidget(
          MaterialApp(
            locale: entry.key,
            supportedLocales: settings.keys,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Builder(
              builder: (context) => Column(
                children: [
                  Text(raftText(context, 'Settings')),
                  Text(raftText(context, nativeCopy)),
                ],
              ),
            ),
          ),
        );
        expect(find.text(entry.value), findsOneWidget);
        expect(find.text(nativeCopy), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  test(
    'Web date patterns keep locale punctuation and day period placement',
    () async {
      await initializeSourceTimeFormatting();
      final at = DateTime.utc(2026, 11, 25, 18, 5);
      for (final (locale, shortDate) in [
        ('es', '25 nov, 06:05 p. m.'),
        ('pt-BR', '25 de nov., 06:05 PM'),
        ('ru', '25 нояб., 06:05 PM'),
        ('ko', '11월 25일 오후 06:05'),
        ('ja', '11月25日 午後06:05'),
        ('zh-TW', '11月25日 下午06:05'),
      ]) {
        final format = SourceTimeFormatter(
          locale: locale,
          preferredTimezone: 'UTC',
          preferredTimeFormat: SourceTimeFormat.twelveHour,
        );
        expect(format.shortDateTime(at), shortDate, reason: locale);
      }
    },
  );

  test(
    'relative time uses CLDR plurals, two-day words and number grouping',
    () {
      final now = DateTime.utc(2026, 11, 25, 18, 5);
      String relative(int minutes, String locale) => resourceRelativeTime(
        now.add(Duration(minutes: minutes)).toIso8601String(),
        locale: locale,
        now: now,
      );
      expect(relative(-1, 'ru'), '1 минуту назад');
      expect(relative(-2, 'ru'), '2 минуты назад');
      expect(relative(-5, 'ru'), '5 минут назад');
      expect(relative(-2880, 'es'), 'anteayer');
      expect(relative(5, 'pt-BR'), 'em 5 minutos');
      expect(relative(-120, 'ko'), '2시간 전');
      expect(relative(1440, 'ja'), '明日');
      expect(relative(-5, 'zh-TW'), '5 分鐘前');
      expect(relative(1440 * 1000, 'ru'), 'через 1\u00a0000 дней');
      expect(relative(1440 * 1000, 'es'), 'dentro de 1000 días');
    },
  );
}
