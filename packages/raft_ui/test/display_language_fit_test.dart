import 'dart:io';

import 'package:flutter/cupertino.dart'
    show CupertinoLocalizations, DefaultCupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/language_settings_previews.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../../tool/testing/system_fonts.dart';
import '../../../tool/testing/text_scale_audit.dart';

class _TestLocalizations<T> extends LocalizationsDelegate<T> {
  const _TestLocalizations(this.delegate);

  final LocalizationsDelegate<T> delegate;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<T> load(Locale locale) => delegate.load(const Locale('en'));

  @override
  bool shouldReload(_TestLocalizations<T> old) => false;
}

void main() {
  final newLanguages = raftDisplayLanguages.entries.where(
    (entry) => entry.key != 'en' && entry.key != 'zh-cn',
  );
  for (final language in newLanguages) {
    final (locale, endonym) = language.value;
    testWidgets('${language.key} settings fit at all text scales', (
      tester,
    ) async {
      await loadAuditFonts(tester, AuditFonts.real);
      final theme = raftTheme(locale: locale, textLocale: locale);
      final truncation = <String, bool>{};
      for (final scale in [1.0, 1.3, 2.0, 3.1]) {
        final report = await auditSurface(
          tester,
          surface: 'display-language-settings',
          build: languageSettingsReferencePreview,
          theme: theme,
          mode: AuditMode(
            '${language.key}-${scale}x',
            textScale: scale,
            locale: locale,
          ),
          truncationBaseline: truncation,
          screenshotDir: Platform.environment['RAFT_TEXT_SCALE_OUT'],
        );
        expect(report.failures, isEmpty, reason: report.failures.join('\n'));
      }
    });

    if (const ['ja', 'ko', 'ru'].contains(language.key)) {
      testWidgets('${language.key} settings type golden', (tester) async {
        await loadAuditFonts(tester, AuditFonts.real);
        const viewport = Size(390, 600);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: [locale],
            localizationsDelegates: const [
              _TestLocalizations<MaterialLocalizations>(
                DefaultMaterialLocalizations.delegate,
              ),
              _TestLocalizations<CupertinoLocalizations>(
                DefaultCupertinoLocalizations.delegate,
              ),
            ],
            theme: raftTheme(locale: locale, textLocale: locale),
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: RepaintBoundary(
                key: key,
                child: languageSettingsReferencePreview(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(endonym), findsOneWidget);
        await expectLater(
          find.byKey(key),
          matchesGoldenFile('goldens/display-language-${language.key}.png'),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }, skip: missingTestFontReason(cjkTestFonts()) != null);
    }
  }
}
