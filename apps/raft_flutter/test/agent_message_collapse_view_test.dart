import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

/// Phone is the compact window (390). Desktop is wide (1280). Both use the
/// same rule: an unread agent message starts open, a read one stays folded.
const layouts = <(String, double)>[('phone', 390), ('desktop', 1280)];

Map<String, dynamic> longRow({required int seq, required bool agent}) => {
  'id': 'm1',
  'channelId': 'c1',
  'seq': '$seq',
  'senderId': agent ? 'bot' : 'bob',
  'senderType': agent ? 'agent' : 'user',
  'senderName': agent ? 'Bot' : 'Bob',
  'content': List.filled(40, 'Reading line.').join('\n'),
  'createdAt': '2026-10-16T00:00:00Z',
};

Future<WorkspaceController> mount(
  WidgetTester tester, {
  required double width,
  required bool agent,
  required int seq,
  required int maxRead,
}) async {
  SharedPreferences.setMockInitialValues({});
  final (w, api) = (await tester.runAsync(() => fixture('member')))!;
  addTearDown(w.dispose);
  api.routes['POST /channels/c1/read'] = (_) => {
    'maxReadSeq': seq,
    'readStateVersion': 2,
  };
  expect(
    w.readState.consumeUpdate(
      {
        'serverId': 's1',
        'scopeId': 'c1',
        'maxReadSeq': maxRead,
        'readStateVersion': 1,
      },
      serverId: 's1',
      principalId: 'alice',
    ),
    'accepted',
  );
  w.channel = RaftChannel({
    'id': 'c1',
    'name': 'test',
    'joined': true,
    'collapseLongMessages': true,
  });
  w.channels = [w.channel!];
  w.messageDomain.ledger.switchServer('s1');
  w.messageDomain.ledger.ingest([
    longRow(seq: seq, agent: agent),
  ], expectedGeneration: w.messageDomain.ledger.generation);
  w.messageDomain.visibleIds['c1'] = {'m1'};
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(body: RaftChatView(controller: w)),
    ),
  );
  await tester.pumpAndSettle();
  return w;
}

Finder messageToggle(String label) => find.descendant(
  of: find.byKey(const ValueKey('message-m1')),
  matching: find.text(label),
);

void main() {
  for (final (name, width) in layouts) {
    testWidgets('$name layout opens an unread agent message', (tester) async {
      await mount(tester, width: width, agent: true, seq: 2, maxRead: 1);
      expect(messageToggle('Collapse'), findsOneWidget);
      expect(messageToggle('Show more'), findsNothing);
    });

    testWidgets('$name layout folds a read agent message', (tester) async {
      await mount(tester, width: width, agent: true, seq: 1, maxRead: 1);
      expect(messageToggle('Show more'), findsOneWidget);
      expect(messageToggle('Collapse'), findsNothing);
    });

    testWidgets('$name layout folds an unread message from a person', (
      tester,
    ) async {
      await mount(tester, width: width, agent: false, seq: 2, maxRead: 1);
      expect(messageToggle('Show more'), findsOneWidget);
      expect(messageToggle('Collapse'), findsNothing);
    });

    testWidgets(
      '$name layout keeps the open message open when the read cursor passes it',
      (tester) async {
        final w = await mount(
          tester,
          width: width,
          agent: true,
          seq: 4,
          maxRead: 1,
        );
        expect(messageToggle('Collapse'), findsOneWidget);
        expect(
          w.readState.consumeUpdate(
            {
              'serverId': 's1',
              'scopeId': 'c1',
              'maxReadSeq': 4,
              'readStateVersion': 3,
            },
            serverId: 's1',
            principalId: 'alice',
          ),
          'accepted',
        );
        w.notifyListeners();
        await tester.pumpAndSettle();
        expect(messageToggle('Collapse'), findsOneWidget);
        expect(messageToggle('Show more'), findsNothing);
      },
    );

    testWidgets('$name layout keeps a manual collapse', (tester) async {
      final w = await mount(
        tester,
        width: width,
        agent: true,
        seq: 4,
        maxRead: 1,
      );
      await tester.ensureVisible(messageToggle('Collapse'));
      await tester.pumpAndSettle();
      await tester.tap(messageToggle('Collapse'));
      await tester.pumpAndSettle();
      expect(messageToggle('Show more'), findsOneWidget);
      w.notifyListeners();
      await tester.pumpAndSettle();
      expect(messageToggle('Show more'), findsOneWidget);
      expect(messageToggle('Collapse'), findsNothing);
    });
  }
}
