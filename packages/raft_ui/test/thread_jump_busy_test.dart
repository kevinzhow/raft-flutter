import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('An unread-thread jump gives feedback and ignores a second tap', (
    tester,
  ) async {
    var jumps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Align(
            child: RaftThreadUnreadJumpPill(
              up: true,
              label: 'Loading thread…',
              busy: true,
              dismissLabel: 'Dismiss',
              onJump: () => jumps++,
              onDismiss: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.byType(RaftSpinner), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('thread-unread-jump')));
    expect(jumps, 0);
  });

  testWidgets('A reply badge uses the Raft thread glyph', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: const Scaffold(
          body: RaftThreadRepliesBadge(replyCount: 2, unreadCount: 0),
        ),
      ),
    );
    expect(find.byType(RaftThreadIcon), findsOneWidget);
    expect(find.text('2 replies'), findsOneWidget);
  });
}
