import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/language_settings_previews.dart';

void main() {
  for (final entry in [(raftThemePackId, false), (raftThemePackId, true)]) {
    testWidgets('Language settings type slots ${entry.$1} dark=${entry.$2}', (
      t,
    ) async {
      addTearDown(() => t.pumpWidget(const SizedBox()));
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(entry.$1), dark: entry.$2),
          home: Scaffold(body: languageSettingsReferencePreview()),
        ),
      );
      await t.pumpAndSettle();
      final title = t.widget<Text>(find.text('Display language'));
      // Web v1.24 ListRowTitle: 16/24 semibold; the rows carry no description.
      expect(title.style!.fontSize, 16);
      expect(title.style!.fontWeight, FontWeight.w600);
      expect(title.style!.fontSize! * title.style!.height!, 24);
      expect(
        find.textContaining('Choose the language for the app interface'),
        findsNothing,
      );
      expect(t.takeException(), isNull);
    });
  }
}
