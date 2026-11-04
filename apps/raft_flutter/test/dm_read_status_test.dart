import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/message_timeline.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture, MessageAdapter;

const statusKey = ValueKey('dm-read-status');

Map<String, dynamic> message(String id, int seq, {String sender = 'alice'}) => {
  'id': id,
  'channelId': 'd1',
  'seq': seq,
  'senderType': 'user',
  'senderId': sender,
  'content': 'Public message $id without a mention',
  'createdAt': '2026-10-21T10:00:00Z',
};

Future<(WorkspaceController, MessageAdapter)> openDm(
  WidgetTester tester, {
  List<Map<String, dynamic>>? messages,
  bool receipts = true,
  int peerSeq = 30,
  String channelType = 'dm',
  bool hasNewer = false,
  bool thread = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
  addTearDown(w.dispose);
  w.channel = RaftChannel({'id': 'd1', 'name': 'Ada', 'type': channelType});
  w.channels = [];
  w.dms = [w.channel!];
  api.routes['GET /channels/d1'] = (_) => {
    'id': 'd1',
    'name': 'Ada',
    'type': 'dm',
    if (receipts)
      'peerReadStates': [
        {'peerKind': 'agent', 'peerId': 'ada', 'maxReadSeq': peerSeq},
      ],
  };
  api.routes['GET /agents'] = (_) => [];
  api.routes['GET /servers/s1/members'] = (_) => [];
  final rows = messages ?? [message('one', 10), message('two', 20)];
  w.messageDomain.ledger.switchServer('s1');
  w.messageDomain.ledger.ingest(
    rows,
    expectedGeneration: w.messageDomain.ledger.generation,
  );
  w.messageDomain.visibleIds['d1'] = {
    for (final row in rows) row['id'] as String,
  };
  w.messageDomain.state.hasNewer = hasNewer;
  if (thread) {
    w.threadChannelId = 'd1';
    w.messageDomain.state.threadParent = RaftMessage({
      ...message('parent', 1),
      'channelId': 'parent-channel',
    });
  }
  await tester.runAsync(() => w.readReceipts.hydrate('d1'));
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: RaftChatView(controller: w, thread: thread),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
  return (w, api);
}

void main() {
  testWidgets(
    'DM without mentions shows one Read line under its last message',
    (tester) async {
      await openDm(tester);
      expect(find.byKey(const ValueKey('message-one')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-two')), findsOneWidget);
      expect(find.byKey(statusKey), findsOneWidget);
      final first = tester.getRect(find.byKey(const ValueKey('message-one')));
      final last = tester.getRect(find.byKey(const ValueKey('message-two')));
      final status = tester.getRect(find.byKey(statusKey));
      expect(status.top, greaterThan(first.bottom));
      expect(status.bottom, lessThanOrEqualTo(last.bottom));
      expect(find.text('Read'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a live read updates only the last row and follows new messages',
    (tester) async {
      final (w, _) = await openDm(tester, peerSeq: 0);
      expect(find.byKey(statusKey), findsNothing);
      final first = tester.widget(find.byKey(const ValueKey('message-one')));
      final last = tester.widget(find.byKey(const ValueKey('message-two')));
      final builds = RaftMessageTimeline.debugRowBuilds;
      w.readReceipts.consumeEvent(
        const RaftEvent('scope_read:updated', {
          'scopeId': 'd1',
          'peerKind': 'agent',
          'peerId': 'ada',
          'maxReadSeq': 20,
        }),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(statusKey), findsOneWidget);
      expect(
        tester.widget(find.byKey(const ValueKey('message-one'))),
        same(first),
      );
      expect(
        tester.widget(find.byKey(const ValueKey('message-two'))),
        isNot(same(last)),
      );
      expect(RaftMessageTimeline.debugRowBuilds - builds, 1);
      void append(Map<String, dynamic> row) {
        w.messageDomain.ledger.ingest([
          row,
        ], expectedGeneration: w.messageDomain.ledger.generation);
        w.messageDomain.visibleIds['d1']!.add(row['id'] as String);
        w.notifyListeners();
      }

      append(message('three', 30));
      await tester.pumpAndSettle();
      expect(find.byKey(statusKey), findsNothing);
      w.readReceipts.consumeEvent(
        const RaftEvent('scope_read:updated', {
          'scopeId': 'd1',
          'peerKind': 'agent',
          'peerId': 'ada',
          'maxReadSeq': 30,
        }),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(statusKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('message-three')),
          matching: find.byKey(statusKey),
        ),
        findsOneWidget,
      );
      // The source does not search backwards for the viewer's last sent row.
      append(message('four', 40, sender: 'bob'));
      await tester.pumpAndSettle();
      expect(find.byKey(statusKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final type in ['channel', 'joint', 'thread']) {
    testWidgets('$type scope never displays a DM read status', (tester) async {
      await openDm(tester, channelType: type);
      expect(find.byKey(statusKey), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('history context suppresses the line until the live edge', (
    tester,
  ) async {
    final (w, _) = await openDm(tester, hasNewer: true);
    expect(find.byKey(statusKey), findsNothing);
    w.messageDomain.state.hasNewer = false;
    w.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byKey(statusKey), findsOneWidget);
  });

  testWidgets('thread presentation never borrows its parent DM read status', (
    tester,
  ) async {
    await openDm(tester, thread: true);
    expect(find.byKey(statusKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing receipt data stays hidden and later flag removal clears it',
    (tester) async {
      final (w, api) = await openDm(tester, receipts: false);
      w.readReceipts.consumeEvent(
        const RaftEvent('scope_read:updated', {
          'scopeId': 'd1',
          'peerKind': 'agent',
          'peerId': 'ada',
          'maxReadSeq': 100,
        }),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(statusKey), findsNothing);
      api.routes['GET /channels/d1'] = (_) => {
        'peerReadStates': [
          {'peerKind': 'agent', 'peerId': 'ada', 'maxReadSeq': 30},
        ],
      };
      await tester.runAsync(() => w.readReceipts.hydrate('d1'));
      await tester.pumpAndSettle();
      expect(find.byKey(statusKey), findsOneWidget);
      api.routes['GET /channels/d1'] = (_) => {'id': 'd1'};
      await tester.runAsync(() => w.readReceipts.hydrate('d1'));
      await tester.pumpAndSettle();
      expect(find.byKey(statusKey), findsNothing);
    },
  );

  testWidgets('revoking the open DM removes its read status immediately', (
    tester,
  ) async {
    final (w, _) = await openDm(tester);
    expect(find.byKey(statusKey), findsOneWidget);
    w.sessionScope.revokeChannel('d1');
    w.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byKey(statusKey), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
