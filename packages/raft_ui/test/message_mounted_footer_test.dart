@Tags(['look-elegant'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/message_row_recipe.dart';
import 'package:raft_ui/raft_ui.dart' show packForThemeId, elegantThemePackId;
import 'package:raft_ui/src/theme.dart';

void main() {
  test('mounted footer overrides generic Elegant desktop ten-pixel margin', () {
    final t = raftTheme(pack: packForThemeId(elegantThemePackId))
        .extension<RaftTokens>()!;
    expect(RaftMessageRowRecipe(t, viewportWidth: 1280).footerGap, 6);
    expect(RaftMessageRowRecipe(t, viewportWidth: 390).footerGap, 6);
  });
  testWidgets('inline reply owns its margin without a duplicate footer gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: packForThemeId(elegantThemePackId)),
        home: const Scaffold(
          body: RaftMessageRow(
            author: 'Public',
            timestamp: '14:30',
            content: SizedBox(key: Key('body-end'), width: 100, height: 80),
            inlineReplies: Padding(
              padding: EdgeInsets.only(top: 6),
              child: SizedBox(key: Key('reply-start'), width: 100, height: 40),
            ),
          ),
        ),
      ),
    );
    final content = tester.getRect(find.byKey(const Key('body-end')));
    final replies = tester.getRect(find.byKey(const Key('reply-start')));
    // The body keeps its 6px bottom margin (it was 0 only in Brutal) and the
    // reply adds its own 6px; no footer gap (also 6) is stacked on top.
    final t = RaftTokens.of(tester.element(find.byKey(const Key('body-end'))));
    final recipe = RaftMessageRowRecipe(t, viewportWidth: 1280);
    expect(recipe.bodyGap, 6);
    expect(replies.top - content.bottom, recipe.bodyGap + 6);
    expect(tester.takeException(), isNull);
  });
}
