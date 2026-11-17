import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final id in raftThemeMatrix([raftThemePackId])) {
    for (final dark in [false, true]) {
      testWidgets(
        '$id/$dark composer follows source material and notice metrics',
        (t) async {
          final theme = raftTheme(pack: packForThemeId(id), dark: dark);
          final tokens = theme.extension<RaftTokens>()!;
          final recipe = RaftComposerRecipe(tokens, desktop: true);
          expect(recipe.actionFace, 32);
          expect(recipe.submitFace, 32);
          expect(recipe.glyphSize, 18);
          expect(recipe.editorMinimum, 24);
          expect(recipe.shellInset, const EdgeInsets.fromLTRB(12, 12, 12, 5));
          expect(recipe.editorInset, const EdgeInsets.symmetric(horizontal: 2));
          await t.pumpWidget(
            MaterialApp(
              theme: theme,
              home: const Scaffold(
                body: RaftComposerNotice(
                  message: 'Notice without a dismiss action',
                ),
              ),
            ),
          );
          final text = t.widget<Text>(
            find.text('Notice without a dismiss action'),
          );
          expect(text.style!.fontSize, 13);
          expect(text.style!.fontSize! * text.style!.height!, 18);
          expect(text.style!.fontWeight, FontWeight.w400);
          expect(text.style!.color, tokens.colors['foreground']);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
