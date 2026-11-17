// Source: packages/web/src/store/inboxStore.ts (markAllRead ->
// clearAllMarkedUnreadForRead, markedUnreadStore.ts:48) at v1.24.0-source.1
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show activityFixture, channelRow;

void main() {
  testWidgets(
    '[BP-READ-037] Mark all read clears every marked-unread flag when it goes out',
    (tester) async {
      final (client, w) = activityFixture();
      w.inbox = [channelRow(1, unread: 2)];
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        w.dispose();
        await client.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: ResourceView(
              controller: w,
              section: 'activity',
              onMessage: (_, _) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      w.conversationReads.acceptMark('ch1', 4, true);
      w.conversationReads.acceptMark('ch7', 2, true);
      expect(w.conversationReads.marks.marked, {'ch1', 'ch7'});
      await tester.tap(
        find.widgetWithText(RaftResourceMarkReadButton, 'Mark all read'),
      );
      await tester.pump();
      expect(client.posts, contains('POST /channels/inbox/read-all'));
      expect(
        w.conversationReads.marks.marked,
        isEmpty,
        reason:
            'the read-all going out reads every mark (no frame has arrived)',
      );
      await tester.pumpAndSettle();
    },
  );
}
