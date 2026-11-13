import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show MessageAdapter;

class _Client extends RaftClient {
  _Client(MessageAdapter a)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = a,
      );
  final incoming = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => incoming.stream;
  @override
  void joinChannel(String id) {}
  @override
  void leaveChannel(String id) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('[BP-RT-012] an open thread takes a reply from thread:updated when no '
      'message:new reaches it, and shows it once', () async {
    final a = MessageAdapter();
    a.routes['POST /auth/login'] = (_) => {
      'accessToken': 'fixture-only',
      'refreshToken': 'fixture-only',
      'user': {'id': 'alice'},
    };
    final client = _Client(a);
    addTearDown(client.incoming.close);
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
    Iterable<String> replies() => w.messageDomain.replies.map((m) => m.id);
    expect(replies(), ['reply-0']);
    final frame = {
      'parentMessageId': 'parent',
      'threadChannelId': 'thread-1',
      'replyCount': 2,
      'lastReplyAt': '2026-11-14T00:00:00Z',
      'participantIds': ['bob'],
      'latestReply': row('reply-1', 'thread-1', 9),
    };
    client.incoming.add(RaftEvent('thread:updated', frame));
    expect(replies(), ['reply-0', 'reply-1']);
    client.incoming.add(
      RaftEvent('message:new', row('reply-1', 'thread-1', 9)),
    );
    client.incoming.add(RaftEvent('thread:updated', frame));
    expect(replies(), ['reply-0', 'reply-1']);
  });
}
