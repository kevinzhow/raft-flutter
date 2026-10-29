import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;

/// Web ThreadPanel passes `mentionChannelId={parentChannelId}`: the thread
/// composer's @ candidates come from the thread's SOURCE channel (roster +
/// server directory), never from whichever channel the main pane has open.
const _agents = ['cindy', 'codexgame', 'codexmac', 'cody', 'codexwin', 'grok'];
Map<String, dynamic> _agent(String name) => {
  'id': name,
  'name': name[0].toUpperCase() + name.substring(1),
  'status': 'active',
  'runtime': 'codex',
};

Map<String, dynamic> _human(String id, String name) => {
  'id': id,
  'userId': id,
  'name': name,
};

void _routes(MessageAdapter a, {required int outsiders}) {
  final everyone = [
    ..._agents.map(_agent),
    for (var i = 0; i < outsiders; i++) _agent('outsider$i'),
  ];
  a.routes['GET /agents'] = (_) => everyone;
  a.routes['GET /servers/s1/members'] = (_) => [
    _human('alice', 'alice'),
    _human('kevin', 'kevin'),
  ];
  a.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
  // #raft-flutter: two humans and the six agents.
  a.routes['GET /channels/c1/members'] = (_) => {
    'humans': [_human('alice', 'alice'), _human('kevin', 'kevin')],
    'agents': _agents.map(_agent).toList(),
  };
  // The channel the main pane happens to have open: a small private channel.
  a.routes['GET /channels/cx/members'] = (_) => {
    'humans': [_human('kevin', 'kevin')],
    'agents': [_agent('cindy'), _agent('codexgame')],
  };
}

Future<void> _mountThread(
  WidgetTester t, {
  required String mainChannelType,
  String parentType = 'channel',
  int outsiders = 0,
}) async {
  await t.binding.setSurfaceSize(const Size(900, 800));
  addTearDown(() => t.binding.setSurfaceSize(null));
  final (w, a) = (await t.runAsync(() => fixture('owner')))!;
  addTearDown(w.dispose);
  _routes(a, outsiders: outsiders);
  final parent = RaftChannel({
    'id': 'c1',
    'name': 'raft-flutter',
    'type': parentType,
    'joined': true,
  });
  final main = RaftChannel({
    'id': 'cx',
    'name': 'other',
    'type': mainChannelType,
    'joined': true,
  });
  w.channels = [parent, main];
  w.channel = main;
  w.messageDomain.ledger.switchServer('s1');
  w.messageDomain.state.threadParent = RaftMessage({
    'id': 'parent',
    'channelId': 'c1',
    'seq': 1,
    'senderType': 'user',
    'senderId': 'kevin',
    'content': 'Parent',
  });
  w.threadChannelId = 'thread-c1';
  w.messageDomain.ledger.ingest([
    // Oldest to newest: cindy, then codexmac, then kevin spoke last.
    for (final (i, s) in [
      (1, ('agent', 'cindy')),
      (2, ('agent', 'codexmac')),
      (3, ('user', 'kevin')),
    ])
      {
        'id': 'r$i',
        'channelId': 'thread-c1',
        'seq': i,
        'senderType': s.$1,
        'senderId': s.$2,
        'content': 'reply $i',
        'createdAt': '2026-06-22T02:30:0$i.000Z',
      },
  ], expectedGeneration: w.messageDomain.ledger.generation);
  w.messageDomain.visibleIds['thread-c1'] = {'r1', 'r2', 'r3'};
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: RaftDensityScope(
          density: RaftDensity.desktop,
          child: RaftChatView(controller: w, thread: true),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  final input = find.descendant(
    of: find.byType(RaftComposer),
    matching: find.byType(EditableText),
  );
  await t.tap(input);
  await t.enterText(input, '@');
  for (var i = 0; i < 10; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await t.pump(const Duration(milliseconds: 20));
  }
}

List<String> _shown(WidgetTester t) => [
  for (final e in find
      .byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('composer-suggestion-'),
      )
      .evaluate())
    (e.widget.key as ValueKey<String>).value.substring(
      'composer-suggestion-'.length,
    ),
];

Set<String> _supplied(WidgetTester t) => {
  for (final s in t.widget<RaftComposer>(find.byType(RaftComposer)).suggestions)
    if (s.isMention) '${s.type}-${s.id}',
};

void main() {
  testWidgets(
    'thread @ is scoped to the source channel while the main pane has a small private channel open',
    (t) async {
      await _mountThread(t, mainChannelType: 'private');
      expect(_supplied(t), {
        'user-alice',
        'user-kevin',
        for (final a in _agents) 'agent-$a',
      });
      // Recent speakers lead the (all in-channel) list: kevin, codexmac,
      // cindy, then roster order.
      expect(_shown(t).take(3), [
        'user-kevin',
        'agent-codexmac',
        'agent-cindy',
      ]);
    },
  );

  testWidgets(
    'thread @ is scoped to the source channel while the main pane has another public channel open',
    (t) async {
      await _mountThread(t, mainChannelType: 'channel');
      expect(
        _supplied(t),
        containsAll([
          'agent-codexmac',
          'agent-cody',
          'agent-codexwin',
          'agent-grok',
        ]),
      );
      expect(
        t
            .widget<RaftComposer>(find.byType(RaftComposer))
            .suggestions
            .where((s) => s.isMention)
            .every((s) => s.inChannel),
        isTrue,
      );
    },
  );
}
