import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_activity_unread_store.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace, activityFixture, skeleton;

void main() {
  late ActivityClient client;
  late ActivityWorkspace w;
  setUp(() => (client, w) = activityFixture());
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  testWidgets(
    'Activity page and attention badge share one inbox request per socket burst',
    (tester) async {
      await tester.runAsync(() => client.login('fixture', 'fixture'));
      client.selectServer('s1');
      final store = SourceActivityUnreadStore(w);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: ResourceView(
              controller: w,
              section: 'activity',
              onMessage: (_, _) async {},
              onActivityWindowAccepted: (window) {
                if (window != null) {
                  store.acceptWindow(window, scope: store.scope);
                }
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Let the badge's offline boot fallback settle first.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(store.totalUnreadCount, 2);
      final before = w.inboxQueries.length;
      w.hold = Completer<void>();
      client.emit('message:new', {
        'id': 'live',
        'channelId': 'ch3',
        'seq': 5000,
        'content': 'Burst',
        'senderId': 'bob',
        'senderType': 'user',
      });
      await tester.pump(const Duration(milliseconds: 150));
      expect(w.inboxQueries, hasLength(before + 1));
      expect(skeleton, findsNothing);
      w.inbox[3] = {
        ...w.inbox[3],
        'unreadCount': 5,
        'latestActivitySeq': '5000',
        'lastMessageId': 'live',
      };
      w.hold!.complete();
      w.hold = null;
      await tester.pumpAndSettle();
      expect(w.inboxQueries, hasLength(before + 1));
      expect(store.totalUnreadCount, 5);
      final dynamic state = tester.state(find.byType(ResourceView));
      expect(state.totalUnreadCount, 5);
    },
  );
}
