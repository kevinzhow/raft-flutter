import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show activityFixture, activityScroll;

void main() {
  testWidgets('a live Activity update preserves a held bottom bounce', (
    tester,
  ) async {
    final (client, workspace) = activityFixture();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      workspace.dispose();
      await client.dispose();
    });
    client.responses['POST /feature-flags/evaluate'] = {
      'evaluations': [
        {'key': 'activity_conversation_list_v0', 'enabled': true},
      ],
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: ResourceView(
            controller: workspace,
            section: 'activity',
            activitySidebarEnabled: true,
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final dynamic page = tester.state(find.byType(ResourceView));
    final scroll = activityScroll(tester);
    expect(page.rows, hasLength(30));
    scroll.position.jumpTo(scroll.position.maxScrollExtent - 20);
    await tester.pumpAndSettle();
    // Nearing the first page's end accepts the automatic next page. Reach the
    // bottom of that loaded window before beginning the held bounce.
    expect(workspace.inboxQueries.map((query) => query['offset']), [0, 30]);
    expect(page.rows, hasLength(60));
    expect(page.hasMore, isFalse);
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(
      scroll.position.pixels,
      closeTo(scroll.position.maxScrollExtent, .01),
    );
    expect(scroll.position.outOfRange, isFalse);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ListView).last),
    );
    try {
      await gesture.moveBy(const Offset(0, -100));
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(scroll.position.outOfRange, isTrue);
      final before = scroll.position.pixels;
      client.emit('message:new', {
        'id': 'bounce-update',
        'channelId': 'ch5',
        'seq': 2000,
        'content': 'Live update while the reader holds the bottom edge',
        'senderId': 'carol',
        'senderType': 'user',
        'senderName': 'Carol',
        'createdAt': '2026-10-10T01:00:00Z',
      });
      await tester.pump();
      expect(page.rows.first['channelId'], 'ch5');
      expect(scroll.position.pixels, closeTo(before, .01));
      expect(scroll.position.outOfRange, isTrue);
      expect(find.byType(RaftNewUpdatesButton), findsOneWidget);
    } finally {
      await gesture.up();
      await tester.pumpAndSettle();
    }
    expect(scroll.position.outOfRange, isFalse);
    expect(tester.takeException(), isNull);
  });
}
