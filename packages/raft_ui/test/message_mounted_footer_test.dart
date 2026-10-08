import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/message_row_recipe.dart';
import 'package:raft_ui/src/theme.dart';

void main() {
  test('mounted footer overrides generic Elegant desktop ten-pixel margin', () {
    final t = raftTheme(RaftFamily.elegant).extension<RaftTokens>()!;
    expect(RaftMessageRowRecipe(t, viewportWidth: 1280).footerGap, 6);
    expect(RaftMessageRowRecipe(t, viewportWidth: 390).footerGap, 6);
  });
  testWidgets('inline reply owns its margin without a duplicate footer gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
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
    expect(replies.top - content.bottom, 6);
    expect(tester.takeException(), isNull);
  });
}
