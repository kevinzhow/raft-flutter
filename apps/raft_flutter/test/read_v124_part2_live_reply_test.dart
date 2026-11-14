import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

// Source: packages/web/src/store/visibleConversations.ts at v1.24.0-source.1
// (liveReplyUnread) as used by socketBridge thread:updated.
/// A route result that answers with an HTTP error status.
class _Status {
  const _Status(this.code);
  final int code;
}

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final Map<String, FutureOr<dynamic> Function(RequestOptions)> routes = {};
  int count(String route) =>
      calls.where((o) => '${o.method} ${o.path}' == route).length;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    final route = routes['${o.method} ${o.path}'];
    final value = route == null ? const _Status(404) : await route(o);
    final status = value is _Status ? value.code : 200;
    return ResponseBody.fromString(
      jsonEncode(value is _Status ? {'error': 'Fixture failure'} : value),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Client extends RaftClient {
  _Client(_Adapter adapter)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  void emit(String name, [dynamic payload]) =>
      stream.add(RaftEvent(name, payload));
  @override
  Future<void> dispose() async {
    await stream.close();
    await super.dispose();
  }
}

const _followed = 'GET /channels/threads/followed';
Map<String, dynamic> _row(String parent, String thread) => {
  'parentMessageId': parent,
  'threadChannelId': thread,
  'parentChannelId': 'c1',
  'replyCount': 1,
  'lastReplyAt': '2026-10-10T00:00:00.000Z',
  'unreadCount': 0,
};

Future<(WorkspaceController, _Adapter, _Client)> _fixture({
  List<Map<String, dynamic>> followed = const [],
}) async {
  final a = _Adapter();
  a.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  a.routes[_followed] = (_) => {'threads': followed};
  a.routes['GET /channels/unread'] = (_) => {'channels': {}};
  final client = _Client(a);
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'role': 'owner'});
  w.channel = RaftChannel({'id': 'c1', 'name': 'test', 'joined': true});
  w.channels = [w.channel!];
  return (w, a, client);
}

Map<String, dynamic> _thread(String id, {int unread = 0, String? latest}) => {
  ..._row('p-$id', id),
  'unreadCount': unread,
  'latestActivitySeq': ?latest,
};

void main() {
  Map<String, dynamic> reply(String id, {String sender = 'bob'}) => {
    'id': id,
    'senderType': 'user',
    'senderId': sender,
    'mentions': [
      {'type': 'user', 'id': 'alice'},
    ],
  };

  Map<String, dynamic> update(String thread, Map<String, dynamic> latest) => {
    'threadChannelId': thread,
    'replyCount': 3,
    'lastReplyAt': '2026-10-11T00:00:00.000Z',
    'latestReply': latest,
  };

  test('[BP-READ-065] liveReplyUnread: own reply leaves the count, another one adds one', () async {
    final (w, _, c) = await _fixture(followed: [_thread('t1'), _thread('t2')]);
    addTearDown(w.dispose);
    w.followedThreads.start();
    await w.followedThreads.idle;
    // Sent from another device or window by the member: unchanged.
    c.emit('thread:updated', update('t1', reply('r1', sender: 'alice')));
    c.emit('thread:updated', update('t2', reply('r2')));
    final rows = {
      for (final r in w.followedThreads.threads) r['threadChannelId']: r,
    };
    expect(rows['t1']!['unreadCount'], 0, reason: 'own reply is not unread');
    expect(rows['t1']!['hasMention'], isNot(true));
    expect(rows['t1']!['firstUnreadMessageId'], isNull);
    expect(rows['t2']!['unreadCount'], 1);
    expect(rows['t2']!['hasMention'], true);
    expect(rows['t2']!['firstUnreadMessageId'], 'r2');
  });

  test(
    '[BP-READ-065] a payload unreadCount still wins over the rule',
    () async {
      final (w, _, c) = await _fixture(followed: [_thread('t1')]);
      addTearDown(w.dispose);
      w.followedThreads.start();
      await w.followedThreads.idle;
      c.emit('thread:updated', {
        ...update('t1', reply('r1', sender: 'alice')),
        'unreadCount': 4,
      });
      expect(w.followedThreads.threads.single['unreadCount'], 4);
    },
  );
}
