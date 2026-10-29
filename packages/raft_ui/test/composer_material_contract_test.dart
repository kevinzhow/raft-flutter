import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      testWidgets(
        '$id/$dark composer follows source material and notice metrics',
        (t) async {
          final theme = raftTheme(pack: packForThemeId(id), dark: dark);
          final tokens = theme.extension<RaftTokens>()!;
          final native = id == raftThemePackId;
          final raised = id == brutalThemePackId && !dark;
          final recipe = RaftComposerRecipe(tokens, desktop: true);
          expect(
            recipe.actionFace,
            native
                ? 32
                : raised
                ? 26
                : 28,
          );
          expect(recipe.submitFace, native ? 32 : 28);
          expect(recipe.glyphSize, native ? 18 : 14);
          expect(recipe.editorMinimum, native ? 24 : 40);
          expect(
            recipe.shellInset,
            native
                ? const EdgeInsets.fromLTRB(12, 12, 12, 8)
                : raised
                ? const EdgeInsets.all(8)
                : EdgeInsets.zero,
          );
          expect(
            recipe.editorInset,
            native
                ? const EdgeInsets.symmetric(horizontal: 2)
                : raised
                ? EdgeInsets.zero
                : const EdgeInsets.fromLTRB(12, 12, 12, 0),
          );
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
          expect(text.style!.fontSize, native ? 13 : 12);
          expect(text.style!.fontSize! * text.style!.height!, native ? 18 : 16);
          expect(
            text.style!.fontWeight,
            native ? FontWeight.w400 : FontWeight.w700,
          );
          expect(
            text.style!.color,
            native
                ? tokens.colors['foreground']
                : raised
                ? const Color(0xff141110)
                : dark
                ? const Color(0xffc4c4c1)
                : const Color(0xff3d3d3a),
          );
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
