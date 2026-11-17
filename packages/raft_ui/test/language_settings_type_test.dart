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
      final description = t.widget<Text>(
        find.text(
          'Choose the language for the app interface. This is separate from message translation.',
        ),
      );
      // Pinned Web db5e399: subhead 15/20 semibold, footnote 13/18.
      expect(title.style!.fontSize, 15);
      expect(title.style!.fontWeight, FontWeight.w600);
      expect(title.style!.fontSize! * title.style!.height!, 20);
      expect(description.style!.fontSize, 13);
      expect(description.style!.fontSize! * description.style!.height!, 18);
      expect(t.takeException(), isNull);
    });
  }
}
