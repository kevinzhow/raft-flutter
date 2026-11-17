import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_activity_session.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart' show ActivityClient;
import 'message_presentation_test.dart' show fixture;

Map<String, dynamic> activityRow(String id, int seq, String at) => {
  'id': id,
  'channelId': 'c1',
  'seq': seq,
  'senderType': 'user',
  'senderId': 'alice',
  'senderName': 'Alice',
  'content': 'Forum $id',
  'createdAt': at,
};

void main() {
  testWidgets('mounting a second conversation does not notify during layout', (
    t,
  ) async {
    final client = ActivityClient();
    await client.login('fixture', 'fixture');
    client.selectServer('s1');
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'})
      ..channel = RaftChannel({
        'id': 'c1',
        'type': 'channel',
        'threadSort': 'activity',
      });
    addTearDown(w.dispose);
    client.responses['POST /feature-flags/evaluate'] = {
      'evaluations': [
        {'key': 'channel_thread_sort_v0', 'enabled': true},
      ],
    };
    client.responses['GET /messages/channel/c1/by-activity'] = {'messages': []};
    final session = ChannelActivitySession.of(w);
    await session.ready;
    Widget view({required bool show}) => MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: Column(
          children: [
            ListenableBuilder(
              listenable: session,
              builder: (_, _) => const SizedBox(),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (_, _) =>
                    show ? RaftChatView(controller: w) : const SizedBox(),
              ),
            ),
          ],
        ),
      ),
    );
    await t.pumpWidget(view(show: false));
    await t.pumpWidget(view(show: true));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(client.posts.where((p) => p.endsWith('/by-activity')), hasLength(1));
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('activity channel reads its page and renders standalone order', (
    t,
  ) async {
    final (w, api) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    addTearDown(() => t.pumpWidget(const SizedBox()));
    await t.binding.setSurfaceSize(const Size(856, 944));
    addTearDown(() => t.binding.setSurfaceSize(null));
    w.channel = RaftChannel({
      'id': 'c1',
      'type': 'channel',
      'joined': true,
      'threadSort': 'activity',
    });
    w.channels = [w.channel!];
    final older = activityRow('older', 1, '2026-11-01T10:00:00Z');
    final newer = activityRow('newer', 2, '2026-11-01T11:00:00Z');
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest([
      older,
      newer,
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['c1'] = {'older', 'newer'};
    api.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'channel_thread_sort_v0', 'enabled': true},
      ],
    };
    api.routes['GET /messages/channel/c1/by-activity'] = (_) => {
      'messages': [
        {...older, 'activityAt': '2026-11-01T12:00:00Z'},
        newer,
      ],
      'hasMore': false,
    };
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: RaftChatView(controller: w)),
      ),
    );
    await t.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pumpAndSettle();
    expect(
      api.calls.where((c) => c.path.endsWith('/by-activity')),
      hasLength(1),
    );
    final first = find.byKey(const ValueKey('message-newer'));
    final second = find.byKey(const ValueKey('message-older'));
    expect(t.getTopLeft(first).dy, lessThan(t.getTopLeft(second).dy));
    expect(find.byType(RaftConversationDateHeader), findsNothing);
    expect(t.widget<RaftMessageTile>(first).continuation, isFalse);
    expect(t.widget<RaftMessageTile>(second).continuation, isFalse);
    expect(w.messageDomain.messages.map((m) => m.id), ['older', 'newer']);
    w.channel = RaftChannel({
      'id': 'c1',
      'type': 'channel',
      'joined': true,
      'threadSort': 'time',
    });
    w.channels = [w.channel!];
    w.notifyListeners();
    await t.pumpAndSettle();
    expect(t.getTopLeft(second).dy, lessThan(t.getTopLeft(first).dy));
    expect(find.byType(RaftConversationDateHeader), findsOneWidget);
    expect(t.widget<RaftMessageTile>(first).continuation, isTrue);
    await t.pumpWidget(const SizedBox());
  });
}
