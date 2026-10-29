import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/recipes/button_variants.g.dart';
import 'package:raft_ui/src/recipes/recipe_runtime.dart';
import 'package:raft_ui/src/recipes/token_binding.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final (dark) in [(false), (true)]) {
    testWidgets(
      '${dark ? 'dark' : 'light'} English UI keeps Chinese glyph locale',
      (tester) async {
        const device = Locale('zh', 'CN');
        final theme = raftTheme(
          dark: dark,
          locale: const Locale('en'),
          textLocale: device,
        );
        final tokens = theme.extension<RaftTokens>()!;
        Locale? uiLocale;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            theme: theme,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  uiLocale = Localizations.localeOf(context);
                  return Column(
                    children: [
                      Text(raftText(context, 'Settings')),
                      Text('骨直令 中文', style: RaftTypography.body(tokens)),
                      TextField(style: tokens.fieldStyle),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        expect(uiLocale!.languageCode, 'en');
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('设置'), findsNothing);
        for (final label in ['Settings', '骨直令 中文']) {
          final richText = find.descendant(
            of: find.text(label),
            matching: find.byType(RichText),
          );
          final paragraph = tester.renderObject<RenderParagraph>(richText);
          expect((paragraph.text as TextSpan).style!.locale, device);
        }
        final editable = tester.widget<EditableText>(find.byType(EditableText));
        expect(editable.style.locale, device);
        // The design stack's CJK chain leads for Simplified Chinese; the Noto face follows it.
        expect(tokens.fontFallback.first, 'PingFang SC');
        expect(tokens.fontFallback, contains('Noto Sans CJK SC'));
        expect(RaftTypography.heading(tokens).locale, device);
        expect(RaftTypography.mono(tokens).locale, device);
        final recipeTokens = RaftRecipeTokens(tokens);
        expect(
          RaftButtonRecipe.resolve(
            theme: RaftRecipeTheme.elegant,
            tokens: recipeTokens,
          ).root.textStyle(recipeTokens).locale,
          device,
        );
        expect(tokens.copyWith(dark: !dark).textLocale, device);
      },
      skip: raftLookSkip(raftLookElegant),
    );
  }

  test('CJK fallback follows device region and explicit script', () {
    for (final (locale, family) in [
      (const Locale('zh', 'CN'), 'SC'),
      (const Locale('zh', 'TW'), 'TC'),
      (const Locale('zh', 'HK'), 'TC'),
      (
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'CN',
        ),
        'TC',
      ),
      (
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
          countryCode: 'TW',
        ),
        'SC',
      ),
      (const Locale('ja', 'JP'), 'JP'),
      (const Locale('ko', 'KR'), 'KR'),
    ]) {
      final tokens = RaftTokens.theme(textLocale: locale);
      expect(tokens.fieldStyle.locale, locale);
      // Simplified Chinese leads with the design stack's CJK chain; Traditional, Korean and Japanese keep their
      // locale-specific Noto face first (the Han glyph variant depends on it).
      expect(
        tokens.fontFallback.first,
        family == 'SC' ? 'PingFang SC' : 'Noto Sans CJK $family',
      );
      expect(tokens.fontFallback, contains('Noto Sans CJK $family'));
    }
  });
}
