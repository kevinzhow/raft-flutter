import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/language_settings_previews.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final theme in [(raftThemePackId, false), (raftThemePackId, true)]) {
    for (final entry in [
      (const Size(390, 844), TargetPlatform.linux),
      (const Size(856, 944), TargetPlatform.android),
      (const Size(944, 856), TargetPlatform.android),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'Language preview ${theme.$1}/${theme.$2} ${entry.$1} ${scale}x',
          (t) async {
            t.view.physicalSize = entry.$1;
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.reset);
            addTearDown(() => t.pumpWidget(const SizedBox()));
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(
                  pack: packForThemeId(theme.$1),
                  dark: theme.$2,
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(body: languageSettingsReferencePreview()),
              ),
            );
            await t.pumpAndSettle();
            expect(find.byType(RaftLanguageRegionView), findsOneWidget);
            final selector = find.byKey(
              const ValueKey('display-language-select'),
            );
            await t.ensureVisible(selector);
            await t.pumpAndSettle();
            expect(selector.hitTestable(), findsOneWidget);
            expect(t.takeException(), isNull);
          },
          variant: TargetPlatformVariant({entry.$2}),
        );
      }
    }
  }
  testWidgets(
    'Language preview applies a keyboard choice at once and names a failure',
    (t) async {
      final semantics = t.ensureSemantics();
      try {
        addTearDown(() => t.pumpWidget(const SizedBox()));
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(body: languageSettingsReferencePreview()),
          ),
        );
        await t.pumpAndSettle();
        expect(find.byType(RaftSaveStatus), findsNothing);
        final selector = find.byKey(const ValueKey('display-language-select'));
        await t.tap(selector);
        await t.pumpAndSettle();
        await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        final view = t.widget<RaftLanguageRegionView>(
          find.byType(RaftLanguageRegionView),
        );
        expect(view.displayLanguage, 'zh-cn');
        expect(find.byKey(const ValueKey('language-save')), findsNothing);
        // The preview's timezone choice fails: the line is an alert under it.
        final timezone = find.byKey(const ValueKey('timezone-select'));
        await t.ensureVisible(timezone);
        await t.tap(timezone);
        await t.pumpAndSettle();
        await t.tap(find.text('UTC+00:00 UTC').last);
        await t.pumpAndSettle();
        final failure = find.text('Failed to update date and time preferences');
        expect(failure, findsOneWidget);
        final node = t.getSemantics(failure);
        expect(node.label, contains('Failed to update date and time'));
        expect(node.flagsCollection.isLiveRegion, isTrue);
        expect(t.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}
