import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_context_menu_test.dart' show pendingMention;
import 'activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace, activityFixture, channelRow;

class CountedWorkspace extends ActivityWorkspace {
  CountedWorkspace(super.client);
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    final value = await super.query(path, query: query);
    return path == '/channels/inbox'
        ? {
            ...value as Map,
            'allCount': inbox.length,
            'groups': [
              {'channelId': 'ch1', 'count': inbox.length},
            ],
          }
        : value;
  }
}

Future<dynamic> mount(
  WidgetTester tester,
  ActivityClient client,
  ActivityWorkspace w, {
  void Function(Map? window, {bool firstPage})? onAccepted,
}) async {
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
          activitySidebarEnabled: true,
          onActivityWindowAccepted: onAccepted,
          onMessage: (_, _) async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state(find.byType(ResourceView));
}

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(
    find.byType(RaftConversationCard).first,
    buttons: kSecondaryMouseButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'pending mention Done removes only that item without a channel mutation',
    (tester) async {
      final client = ActivityClient()..user = RaftRecord({'id': 'alice'});
      client.selectServer('s1');
      final w = CountedWorkspace(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'})
        ..channels = [
          RaftChannel({'id': 'ch1', 'name': 'Channel 1', 'joined': true}),
        ];
      w.inbox = [
        pendingMention(),
        {
          ...pendingMention(),
          'id': 'other',
          'messageId': 'other-message',
          'messagePreview': 'Other pending mention',
        },
      ];
      final windows = <Map>[];
      final dynamic state = await mount(
        tester,
        client,
        w,
        onAccepted: (window, {firstPage = false}) {
          if (window != null) windows.add(window);
        },
      );
      expect(state.totalCount, 2);
      final requests = client.posts.length, reads = w.inboxQueries.length;
      await openMenu(tester);
      await tester.tap(find.widgetWithText(RaftMenuButtonItem, 'Done'));
      await tester.pumpAndSettle();
      expect(find.byType(RaftSidebarContextMenu), findsNothing);
      expect((state.rows as List).map((dynamic row) => row['id']), ['other']);
      expect(state.totalCount, 1);
      expect(state.activityAllCount, 1);
      expect(windows.last['totalCount'], 1);
      expect(windows.last['allCount'], 1);
      expect((windows.last['groups'] as List).single['count'], 1);
      expect((windows.last['items'] as List).single['id'], 'other');
      expect(
        client.posts.length,
        requests,
        reason: 'Web removes mention actions locally, never marks their channel done',
      );
      expect(
        w.inboxQueries.length,
        reads,
        reason: 'local dismissal does not refresh the dismissed item back in',
      );
      expect(find.textContaining('Refresh Activity'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending mention Mark as Unread reads the resulting server window',
    (tester) async {
      final (client, w) = activityFixture();
      w.inbox = [pendingMention()];
      final dynamic state = await mount(tester, client, w);
      final reads = w.inboxQueries.length;
      await openMenu(tester);
      // The next server window includes the newly unread conversation. The
      // pending mention remains a separate item with the Web's zero unread count.
      w.inbox = [pendingMention(), channelRow(1, unread: 1)];
      await tester.tap(
        find.widgetWithText(RaftMenuButtonItem, 'Mark as Unread'),
      );
      await tester.pumpAndSettle();
      expect(client.posts, contains('POST /channels/ch1/unread'));
      expect(w.inboxQueries.length, greaterThan(reads));
      expect(
        (state.rows as List)
            .where((dynamic row) => row['kind'] == 'channel')
            .single['unreadCount'],
        1,
      );
      expect(find.byType(RaftSidebarContextMenu), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing servers closes the menu and rejects its retained action',
    (tester) async {
      final (client, w) = activityFixture();
      w.inbox = [pendingMention()];
      await mount(tester, client, w);
      await openMenu(tester);
      final stale = tester
          .widget<RaftMenuButtonItem>(
            find.widgetWithText(RaftMenuButtonItem, 'Mark as Unread'),
          )
          .onPressed!;
      // Reading the new server's rows may ask which are saved; that is not the
      // retained action.
      int actions() =>
          client.posts.where((p) => p != 'POST /channels/saved/check').length;
      final requests = actions();
      client.selectServer('s2');
      w.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byType(RaftSidebarContextMenu), findsNothing);
      stale();
      await tester.pumpAndSettle();
      expect(actions(), requests);
      expect(tester.takeException(), isNull);
    },
  );
}
