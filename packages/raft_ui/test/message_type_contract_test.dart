import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/message_content_tokens.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      test('$id/$dark message typography follows its source tiers', () {
        final tokens = raftTheme(
          pack: packForThemeId(id),
          dark: dark,
        ).extension<RaftTokens>()!;
        final native = id == raftThemePackId;
        final raised = id == brutalThemePackId && !dark;
        final defaultBody = MessageContentRecipe(tokens, mountedMessage: true);
        expect(defaultBody.fontSize, native ? 16 : 14);
        for (var i = 0; i < RaftMessageSizeTier.values.length; i++) {
          final tier = RaftMessageSizeTier.values[i];
          final row = RaftMessageRowRecipe(
            tokens,
            viewportWidth: 390,
            sizeTier: tier,
          );
          expect(
            row.author.fontSize,
            (native ? [13, 15, 17] : [12, 14, 16])[i],
          );
          expect(
            row.author.height! * row.author.fontSize!,
            native || raised ? 20 : [12, 14, 16][i],
          );
          expect(
            row.author.fontWeight,
            native || raised ? FontWeight.w700 : FontWeight.w500,
          );
          final size = (native ? [14.0, 16.0, 18.0] : [12.0, 14.0, 16.0])[i];
          final recipe = MessageContentRecipe(
            tokens,
            fontSize: size,
            mountedMessage: true,
          );
          expect(recipe.body.fontSize, size);
          expect(
            recipe.body.height! * size,
            (native ? [20, 24, 28] : [16, 20, 24])[i],
          );
          expect(recipe.body.letterSpacing, native || raised ? 0 : -size * .01);
          expect(
            recipe.body.color,
            tokens.colors[native
                ? 'foreground'
                : raised
                ? 'ink'
                : 'foreground-muted'],
          );
        }
        // An explicit physical size and caller leading remain authoritative;
        // document typography is separate from a message preference.
        expect(
          MessageContentRecipe(
                tokens,
                fontSize: 14,
                lineHeight: 30,
                mountedMessage: true,
              ).body.height! *
              14,
          30,
        );
        expect(MessageContentRecipe(tokens, document: true).fontSize, 14);
        expect(
          MessageContentRecipe(
            tokens,
            fontSize: 15,
            mountedMessage: true,
          ).body.fontSize,
          15,
        );
      });
    }
  }
}
