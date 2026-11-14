import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/delegated_message.dart';
import 'package:raft_flutter/features/message_grouping.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

/// RFC 077 in Web v1.24 (delegatedMessage.ts, MessageItem, messageGrouping):
/// "sent by Friday" after the sender, "(sent by Friday)" ending a continuation,
/// a delegated message starting its own group, and a retracted message keeping
/// only its place.
void main() {
  Map<String, dynamic> row(
    String id,
    int minute, {
    Map<String, dynamic>? delegatedBy,
    String? deletedAt,
    String content = 'Body',
  }) => {
    'id': id,
    'channelId': 'c1',
    'seq': minute + 1,
    'senderId': 'carol',
    'senderType': 'user',
    'senderName': 'Carol',
    'createdAt': DateTime.utc(2026, 11, 1, 9, minute).toIso8601String(),
    'content': content,
    'delegatedBy': delegatedBy,
    'deletedAt': deletedAt,
    'reactions': [
      {
        'emoji': '👍',
        'count': 1,
        'reactorIds': ['bob'],
        'reactorNames': ['Bob'],
      },
    ],
  };
  const friday = {
    'id': 'a9',
    'name': 'friday',
    'displayName': 'Friday',
    'avatarUrl': null,
    'deleted': false,
  };

  test('reader: display name, handle fallback, deleted, people only', () {
    expect(readDelegatedBy(friday)?.name, 'Friday');
    expect(readDelegatedBy({...friday, 'displayName': ' '})?.name, 'friday');
    expect(readDelegatedBy({'id': 'a9', 'name': ''})?.deleted, isTrue);
    expect(readDelegatedBy({'name': 'x'}), isNull);
    expect(
      delegatedByOf(
        RaftMessage({'senderType': 'agent', 'delegatedBy': friday}),
      ),
      isNull,
    );
  });

  test('a delegated message never continues the sender\'s own run', () {
    final own = RaftMessage(row('m1', 0));
    final sent = RaftMessage(row('m2', 1, delegatedBy: friday));
    final again = RaftMessage(row('m3', 2, delegatedBy: friday));
    String day(DateTime d) => '${d.year}-${d.month}-${d.day}';
    bool standalone(RaftMessage _) => false;
    expect(
      messageContinuesGroup(own, sent, dayKey: day, standalone: standalone),
      isFalse,
    );
    expect(
      messageContinuesGroup(sent, again, dayKey: day, standalone: standalone),
      isTrue,
    );
  });

  test('an external author with another shown name starts a group', () {
    Map<String, dynamic> ext(String name) => {
      'id': name,
      'senderType': 'external_projection',
      'senderId': 'slack-bot',
      'externalAuthor': {'displayName': name, 'avatarUrl': null},
    };
    expect(
      sameMessageSender(RaftMessage(ext('A')), RaftMessage(ext('A'))),
      isTrue,
    );
    expect(
      sameMessageSender(RaftMessage(ext('A')), RaftMessage(ext('B'))),
      isFalse,
    );
  });

  testWidgets('the timeline says who sent it, and retracted rows go quiet', (
    t,
  ) async {
    final (w, transport) = (await t.runAsync(() => fixture('member')))!;
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    final rows = [
      row('m1', 0, delegatedBy: friday, content: 'First from Friday'),
      row('m2', 1, delegatedBy: friday, content: 'Second from Friday'),
      row(
        'm3',
        2,
        delegatedBy: {...friday, 'deleted': true},
        deletedAt: '2026-11-01T10:00:00Z',
        content: 'This message was retracted by its sender.',
      ),
    ];
    w.messageDomain.ledger.ingest(
      rows,
      expectedGeneration: w.messageDomain.ledger.generation,
    );
    w.messageDomain.visibleIds['c1'] = {'m1', 'm2', 'm3'};
    transport.routes['GET /agents'] = (_) => [];
    transport.routes['GET /servers/s1/members'] = (_) => [];
    transport.routes['GET /tasks'] = (_) => [];
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: RaftChatView(controller: w)),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await t.pumpAndSettle();
    expect(find.text('sent by Friday'), findsOneWidget);
    expect(find.text('(sent by Friday)'), findsOneWidget);
    // The retracted row continues the run (the same assistant): the
    // placeholder instead of the server's text, no reaction chips.
    expect(find.text('(sent by a deleted assistant)'), findsOneWidget);
    expect(find.text('This message was retracted.'), findsOneWidget);
    expect(
      find.textContaining('retracted by its sender', findRichText: true),
      findsNothing,
    );
    final retractedTile = t.widget<RaftMessageTile>(
      find.ancestor(
        of: find.text('This message was retracted.'),
        matching: find.byType(RaftMessageTile),
      ),
    );
    expect(retractedTile.reactions, isEmpty);
    expect(retractedTile.hoverToolbar, isNull);
  });
}
