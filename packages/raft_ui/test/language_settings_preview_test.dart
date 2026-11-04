import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/language_settings_previews.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final theme in [
    (raftThemePackId, false),
    (raftThemePackId, true),
    (elegantThemePackId, false),
    (elegantThemePackId, true),
    (brutalThemePackId, false),
  ]) {
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
    'Language preview exposes named Save state and keyboard-selects a draft',
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
        expect(view.languageDirty, isTrue);
        final save = find.byKey(const ValueKey('language-save'));
        await t.ensureVisible(save);
        await t.pumpAndSettle();
        final node = t.getSemantics(save);
        expect(node.label, contains('Save'));
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.flagsCollection.isEnabled, Tristate.isTrue);
        await t.tap(save);
        await t.pumpAndSettle();
        expect(
          t
              .widget<RaftLanguageRegionView>(
                find.byType(RaftLanguageRegionView),
              )
              .languageSave,
          RaftLanguageSaveState.saved,
        );
        expect(t.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}
