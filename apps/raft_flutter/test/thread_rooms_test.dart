import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/message_history_events.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show MessageAdapter;

/// Source ThreadPanel: an open thread joins its room and its parent's, joins
/// them again after a reconnect, and leaves its own room when it closes.
class _Client extends RaftClient {
  _Client(MessageAdapter a)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = a,
      );
  final joined = <String>[], left = <String>[];
  @override
  void joinChannel(String id) => joined.add(id);
  @override
  void leaveChannel(String id) => left.add(id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('[BP-RT-056] an open thread joins both rooms, rejoins after a reconnect and leaves its room on close', () async {
    final a = MessageAdapter();
    a.routes['POST /auth/login'] = (_) => {
      'accessToken': 'fixture-only',
      'refreshToken': 'fixture-only',
      'user': {'id': 'alice'},
    };
    final client = _Client(a);
    await client.login('fixture', 'fixture');
    client.selectServer('s1');
    final w = WorkspaceController(client);
    addTearDown(w.dispose);
    w.server = RaftRecord({'id': 's1', 'role': 'member'});
    w.channel = RaftChannel({'id': 'c1', 'name': 'test', 'joined': true});
    w.channels = [w.channel!];
    w.messageDomain.ledger.switchServer('s1');
    a.routes['GET /messages/context/parent'] = (_) => {
      'messages': [row('parent', 'c1', 1)],
    };
    a.routes['GET /messages/channel/thread-1'] = (_) => {
      'messages': [row('reply-0', 'thread-1', 2)],
    };
    await w.openThreadIdentity(
      parentChannelId: 'c1',
      parentMessageId: 'parent',
      initialThreadChannelId: 'thread-1',
      navigate: false,
    );
    for (var i = 0; i < 40 && w.messageDomain.threadParentLoading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(client.joined, containsAll(['thread-1', 'c1']));
    client.joined.clear();
    // rooms:joined after a reconnect: the server does not know the thread room.
    await MessageHistoryEvents.resume(w);
    expect(client.joined, containsAll(['thread-1', 'c1']));
    w.closeThread();
    expect(client.left, ['thread-1']);
  });
}
