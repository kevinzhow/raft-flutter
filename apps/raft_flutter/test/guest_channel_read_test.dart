import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show fixture;

/// Web never gates reading on the server-wide `viewChannel` capability: a
/// guest's channel list is already filtered by the server and the messages
/// endpoint answers per channel (`canGuestReadChannel`). The client must load
/// what a guest may read.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a guest loads a joined channel\'s messages', () async {
    final (w, api) = await fixture('guest');
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    api.routes['GET /messages/channel/c1'] = (_) => {
      'messages': [row('m1', 'c1', 1), row('m2', 'c1', 2)],
    };
    api.routes['POST /channels/c1/read'] = (_) => {};
    await w.selectChannel(w.channel!);
    expect(w.messageDomain.messages.map((m) => m.id), ['m1', 'm2']);
    expect(
      api.calls.where((c) => c.path == '/messages/channel/c1'),
      isNotEmpty,
    );
  });

  test('a guest opens a thread of a channel it can read', () async {
    final (w, api) = await fixture('guest');
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    api.routes['GET /messages/context/parent'] = (_) => {
      'messages': [row('parent', 'c1', 1)],
    };
    api.routes['GET /channels/c1/threads/parent'] = (_) => {
      'threadChannelId': 'thread-1',
    };
    api.routes['GET /messages/channel/thread-1'] = (_) => {
      'messages': [row('r1', 'thread-1', 1)],
    };
    api.routes['POST /channels/thread-1/read'] = (_) => {};
    await w.openThreadIdentity(
      parentChannelId: 'c1',
      parentMessageId: 'parent',
      navigate: false,
    );
    expect(w.threadIdentity?.parentMessageId, 'parent');
    expect(w.replies.map((m) => m.id), ['r1']);
  });

  testWidgets('a guest reads the timeline but gets the read-only footer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (w, api) = (await tester.runAsync(() => fixture('guest')))!;
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest([
      row('m1', 'c1', 1),
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['c1'] = {'m1'};
    api.routes['GET /servers/s1/setup-projection'] = (_) => {
      'phase': 'complete',
      'surface': 'complete',
      'blocksChat': false,
    };
    api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(body: RaftChatView(controller: w)),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Message m1'), findsOneWidget);
    // No composer for a guest in a joined channel.
    expect(find.byType(RaftComposer), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
