// Source: packages/web/src/components/thread/inboxRowActions.ts
// (`onNothingUnread`) at v1.24.0-source.1
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityWorkspace, activityFixture, channelRow;

const _toast = 'Nothing new from others here to mark unread.';

Future<void> _mount(
  WidgetTester tester,
  ActivityWorkspace w,
  RaftClient client,
) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 30));
    w.dispose();
    await client.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      builder: (context, child) => RaftToastHost(child: child!),
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
}

Future<void> _markUnread(WidgetTester tester) async {
  await tester.tap(
    find.byType(RaftInboxItem).first,
    buttons: kSecondaryMouseButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(RaftMenuButtonItem, 'Mark as unread'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets(
    '[BP-READ-036] a nothing answer to Mark as unread shows the "nothing new" toast',
    (tester) async {
      final (client, w) = activityFixture();
      w.inbox = [channelRow(1)];
      client.responses['POST /channels/ch1/unread'] = {
        'outcome': 'nothing',
        'unreadCount': 0,
        'readStateVersion': 2,
        'maxReadSeq': '5',
      };
      await _mount(tester, w, client);
      await _markUnread(tester);
      expect(find.text(_toast), findsOneWidget);
    },
  );

  testWidgets('[BP-READ-036] a counted answer shows no toast', (tester) async {
    final (client, w) = activityFixture();
    w.inbox = [channelRow(1)];
    client.responses['POST /channels/ch1/unread'] = {
      'outcome': 'counted',
      'unreadCount': 1,
      'readStateVersion': 2,
      'maxReadSeq': '4',
    };
    await _mount(tester, w, client);
    await _markUnread(tester);
    expect(find.text(_toast), findsNothing);
  });
}
