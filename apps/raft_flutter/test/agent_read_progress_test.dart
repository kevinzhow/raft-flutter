import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

const _status = ValueKey('agent-read-status');
const _ada = ValueKey('agent-read-face-ada');

Map<String, Object> _message(
  String id,
  int seq, {
  String sender = 'alice',
  String type = 'user',
  String content = 'A public fixture message.',
  List<Map<String, String>> mentions = const [],
}) => {
  'id': id,
  'channelId': 'c1',
  'seq': seq,
  'senderId': sender,
  'senderType': type,
  'content': content,
  'mentions': mentions,
  'createdAt': '2026-11-18T10:00:00Z',
};

Map<String, Object> _peer(String id, int seq, {bool muted = false}) => {
  'peerId': id,
  'peerKind': 'agent',
  'maxReadSeq': seq,
  'mutedChannel': muted,
};

Finder _inside(String message, Key key) => find.descendant(
  of: find.byKey(ValueKey('message-wrapper-$message')),
  matching: find.byKey(key),
);

Future<WorkspaceController> _open(
  WidgetTester tester, {
  bool enabled = true,
  bool hasNewer = false,
  List<Map<String, Object>>? messages,
  List<Map<String, Object>>? peers,
}) async {
  SharedPreferences.setMockInitialValues({});
  final (workspace, api) = (await tester.runAsync(() => fixture('owner')))!;
  addTearDown(workspace.dispose);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
  api.routes['POST /feature-flags/evaluate'] = (request) => {
    'evaluations': [
      for (final key in (request.data as Map)['keys'] as List)
        {'key': key, 'enabled': enabled && key == 'agent_read_progress_v0'},
    ],
  };
  api.routes['GET /channels/c1'] = (_) => {
    'id': 'c1',
    'name': 'test',
    'peerReadStates': peers ?? [_peer('ada', 10, muted: true)],
  };
  api.routes['GET /agents'] = (_) => [
    {'id': 'ada', 'displayName': 'Ada'},
    {'id': 'bea', 'displayName': 'Bea'},
    {'id': 'cam', 'displayName': 'Cam'},
    {'id': 'dan', 'displayName': 'Dan'},
  ];
  api.routes['GET /servers/s1/members'] = (_) => [];
  final rows =
      messages ??
      [_message('one', 10, sender: 'ada', type: 'agent'), _message('two', 20)];
  final ledger = workspace.messageDomain.ledger;
  ledger.switchServer('s1');
  ledger.ingest(rows, expectedGeneration: ledger.generation);
  workspace.messageDomain.visibleIds['c1'] = {
    for (final row in rows) row['id'] as String,
  };
  workspace.messageDomain.state.hasNewer = hasNewer;
  await tester.runAsync(() => workspace.readReceipts.hydrate('c1'));
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(body: RaftChatView(controller: workspace)),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
  return workspace;
}

void main() {
  testWidgets('the face moves and the mute hint clears in one frame', (
    tester,
  ) async {
    final workspace = await _open(tester);
    expect(_inside('one', _ada), findsOneWidget);
    expect(_inside('two', _status), findsOneWidget);
    final firstBody = find.text('A public fixture message.').first;
    final before = tester.getSize(firstBody);
    workspace.readReceipts.consumeEvent(
      const RaftEvent('read_progress:updated', {
        'scopeId': 'c1',
        'peers': [
          {'peerId': 'ada', 'maxReadSeq': 20},
        ],
      }),
    );
    await tester.pump();
    expect(_inside('one', _ada), findsNothing);
    expect(_inside('two', _ada), findsOneWidget);
    expect(_inside('two', _status), findsNothing);
    expect(tester.getSize(firstBody), before);
  });

  for (final (flag, history) in [(false, false), (true, true)]) {
    testWidgets('flag $flag and history $history suppress faces and hints', (
      tester,
    ) async {
      await _open(tester, enabled: flag, hasNewer: history);
      expect(find.byKey(_ada), findsNothing);
      expect(find.byKey(_status), findsNothing);
    });
  }

  testWidgets('a folded system frontier belongs to its disclosure header', (
    tester,
  ) async {
    await _open(
      tester,
      messages: [
        _message('one', 10, sender: 'ada', type: 'agent'),
        {..._message('system-one', 20), 'messageType': 'system'},
        {..._message('system-two', 30), 'messageType': 'system'},
      ],
      peers: [_peer('ada', 30)],
    );
    expect(_inside('system-one', _ada), findsOneWidget);
    expect(_inside('system-two', _ada), findsNothing);
    await tester.tap(find.byKey(const ValueKey('system-message-group-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(_ada), findsOneWidget);
  });

  testWidgets('narrow rows show two faces and accessible overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _open(
      tester,
      messages: [
        _message(
          'one',
          10,
          mentions: [
            for (final name in ['Ada', 'Bea', 'Cam', 'Dan'])
              {'type': 'agent', 'id': name.toLowerCase(), 'displayName': name},
          ],
        ),
      ],
      peers: [
        for (final id in ['ada', 'bea', 'cam', 'dan']) _peer(id, 10),
      ],
    );
    expect(find.byKey(_ada), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-read-face-bea')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-read-face-cam')), findsNothing);
    expect(find.text('+2'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pump();
      expect(
        find.bySemanticsLabel('Ada, Bea, Cam, and Dan read up to here'),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
    expect(tester.takeException(), isNull);
  });
}
