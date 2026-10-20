import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/agent_message_collapse.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

/// Web `CollapsibleMessageContent`: a message taller than 320px collapses
/// behind "Show more". The one intentional difference is Kevin's rule (task
/// #151): an unread agent message starts open (the per-visit rules are in
/// `agent_message_collapse_*_test.dart`). What follows is the Web alignment
/// around it: who collapses, the toggle's semantics, the viewport on expand and
/// collapse, and the messages that never collapse.
const layouts = <(String, double)>[('phone', 390), ('desktop', 1280)];

Map<String, dynamic> row({
  required String id,
  required bool agent,
  int lines = 40,
  Map<String, dynamic>? actionMetadata,
}) => {
  'id': id,
  'channelId': 'c1',
  'seq': '${id.hashCode.abs() % 1000 + 2}',
  'senderId': agent ? 'bot' : 'bob',
  'senderType': agent ? 'agent' : 'user',
  'senderName': agent ? 'Bot' : 'Bob',
  'content': List.filled(lines, 'Reading line.').join('\n'),
  'createdAt': '2026-10-16T00:00:00Z',
  'actionMetadata': ?actionMetadata,
};

Future<WorkspaceController> prepare(
  WidgetTester tester, {
  required double width,
  required List<Map<String, dynamic>> rows,
  int maxRead = 1,
  bool collapse = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final (w, api) = (await tester.runAsync(() => fixture('member')))!;
  addTearDown(w.dispose);
  api.routes['POST /channels/c1/read'] = (_) => {
    'maxReadSeq': 9999,
    'readStateVersion': 2,
  };
  w.readState.consumeUpdate(
    {
      'serverId': 's1',
      'scopeId': 'c1',
      'maxReadSeq': maxRead,
      'readStateVersion': 1,
    },
    serverId: 's1',
    principalId: 'alice',
  );
  w.channel = RaftChannel({
    'id': 'c1',
    'name': 'test',
    'joined': true,
    'collapseLongMessages': collapse,
  });
  w.channels = [w.channel!];
  w.messageDomain.ledger.switchServer('s1');
  w.messageDomain.ledger.ingest(
    rows,
    expectedGeneration: w.messageDomain.ledger.generation,
  );
  w.messageDomain.visibleIds['c1'] = {for (final r in rows) r['id'] as String};
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return w;
}

Future<void> mountChat(WidgetTester tester, WorkspaceController w) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(body: RaftChatView(controller: w)),
    ),
  );
  await tester.pumpAndSettle();
}

Finder toggle(String id, String label) => find.descendant(
  of: find.byKey(ValueKey('message-$id')),
  matching: find.text(label),
);

void main() {
  for (final (name, width) in layouts) {
    testWidgets('$name layout collapses a long message from a person, read or '
        'not, and a read agent message', (tester) async {
      final w = await prepare(
        tester,
        width: width,
        maxRead: 9999,
        rows: [
          row(id: 'p1', agent: false),
          row(id: 'a1', agent: true),
        ],
      );
      await mountChat(tester, w);
      for (final id in ['p1', 'a1']) {
        expect(toggle(id, 'Show more'), findsOneWidget, reason: id);
        expect(toggle(id, 'Collapse'), findsNothing, reason: id);
      }
    });

    testWidgets('$name layout: an unread person message collapses, an unread '
        'agent message starts open', (tester) async {
      final w = await prepare(
        tester,
        width: width,
        rows: [
          row(id: 'p1', agent: false),
          row(id: 'a1', agent: true),
        ],
      );
      await mountChat(tester, w);
      expect(toggle('p1', 'Show more'), findsOneWidget);
      expect(toggle('a1', 'Collapse'), findsOneWidget);
      expect(toggle('a1', 'Show more'), findsNothing);
    });
  }

  testWidgets('the toggle announces whether the message is expanded', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final w = await prepare(
      tester,
      width: 390,
      maxRead: 9999,
      rows: [row(id: 'm1', agent: true)],
    );
    await mountChat(tester, w);
    bool? expanded(String label) => tester
        .getSemantics(toggle('m1', label))
        .getSemanticsData()
        .flagsCollection
        .isExpanded
        .toBoolOrNull();
    expect(expanded('Show more'), isFalse);
    await tester.ensureVisible(toggle('m1', 'Show more'));
    await tester.pumpAndSettle();
    await tester.tap(toggle('m1', 'Show more'));
    await tester.pumpAndSettle();
    expect(expanded('Collapse'), isTrue);
    handle.dispose();
  });

  testWidgets('expanding at the live tail keeps the message where it is', (
    tester,
  ) async {
    final w = await prepare(
      tester,
      width: 390,
      rows: [
        for (var i = 0; i < 12; i++) row(id: 'a$i', agent: false, lines: 3),
        row(id: 'm1', agent: false, lines: 60),
      ],
    );
    await mountChat(tester, w);
    final tile = find.byKey(const ValueKey('message-m1'));
    final top = tester.getTopLeft(tile).dy;
    final bottom = tester.getBottomLeft(tile).dy;
    await tester.tap(toggle('m1', 'Show more'));
    await tester.pumpAndSettle();
    // Web `preserveTimelineViewport`: the message grows downward from where
    // the reader sees it; the latest end is not followed.
    expect(tester.getTopLeft(tile).dy, top);
    expect(tester.getBottomLeft(tile).dy, greaterThan(bottom));
    // Collapsing at the end brings it back where it was.
    await tester.ensureVisible(toggle('m1', 'Collapse'));
    await tester.pumpAndSettle();
    await tester.tap(toggle('m1', 'Collapse'));
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(tile).dy, lessThanOrEqualTo(800));
    expect(tester.getBottomLeft(tile).dy, greaterThan(0));
  });

  testWidgets('a short message has no toggle', (tester) async {
    final w = await prepare(
      tester,
      width: 390,
      rows: [row(id: 'm1', agent: true, lines: 3)],
    );
    await mountChat(tester, w);
    expect(toggle('m1', 'Show more'), findsNothing);
    expect(toggle('m1', 'Collapse'), findsNothing);
  });

  testWidgets('a channel with Collapse long messages off shows it all', (
    tester,
  ) async {
    final w = await prepare(
      tester,
      width: 390,
      rows: [row(id: 'm1', agent: true)],
      collapse: false,
    );
    await mountChat(tester, w);
    expect(toggle('m1', 'Show more'), findsNothing);
    expect(toggle('m1', 'Collapse'), findsNothing);
  });

  test('action cards and forwarded bundles never collapse', () {
    final channel = {'collapseLongMessages': true};
    expect(longMessagesCollapse({}, channel), isTrue);
    expect(longMessagesCollapse({}, null), isTrue);
    expect(longMessagesCollapse({}, {'collapseLongMessages': false}), isFalse);
    for (final kind in ['action-card', 'forwarded-bundle']) {
      expect(
        longMessagesCollapse({
          'actionMetadata': {'kind': kind},
        }, channel),
        isFalse,
        reason: kind,
      );
    }
    expect(
      longMessagesCollapse({
        'actionMetadata': {'kind': 'something-else'},
      }, channel),
      isTrue,
    );
  });
}
