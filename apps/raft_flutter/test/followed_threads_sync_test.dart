import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/followed_threads_store.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

/// Source threadStore / socketBridge v1.21.23: a reply that mentions the
/// member lights the thread's @ mark, a reply into a read thread is its first
/// unread, replies into unknown threads share one reload, and a read elsewhere
/// lowers (never raises) a thread's unread count.
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

Future<void> _settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('[BP-READ-065] a live reply that mentions the member lights the @ mark; a reply into a read thread names its first unread', () async {
    final (w, _, c) = await _fixture(
      followed: [_thread('t1'), _thread('t2', unread: 2)],
    );
    addTearDown(w.dispose);
    w.followedThreads.start();
    await w.followedThreads.idle;
    c.emit('thread:updated', {
      'threadChannelId': 't1',
      'replyCount': 2,
      'lastReplyAt': '2026-10-11T00:00:00.000Z',
      'latestReply': {
        'id': 'r1',
        'mentions': [
          {'type': 'user', 'id': 'alice'},
        ],
      },
    });
    c.emit('thread:updated', {
      'threadChannelId': 't2',
      'replyCount': 3,
      'lastReplyAt': '2026-10-11T00:00:01.000Z',
      'latestReply': {'id': 'r2', 'mentions': []},
    });
    final rows = {
      for (final r in w.followedThreads.threads) r['threadChannelId']: r,
    };
    expect(rows['t1']!['unreadCount'], 1);
    expect(rows['t1']!['hasMention'], true);
    expect(rows['t1']!['firstUnreadMessageId'], 'r1');
    // Already unread: the first unread stays, no mention appears.
    expect(rows['t2']!['hasMention'], isNot(true));
    expect(rows['t2']!['firstUnreadMessageId'], isNull);
  });

  test('[BP-READ-065] replies into threads that are not in the list share one reload', () async {
    final (w, a, c) = await _fixture(followed: [_thread('t1')]);
    addTearDown(w.dispose);
    w.followedThreads.start();
    await w.followedThreads.idle;
    final before = a.count(_followed);
    for (var i = 0; i < 5; i++) {
      c.emit('thread:updated', {
        'threadChannelId': 'new-$i',
        'parentMessageId': 'p$i',
      });
    }
    await _settle();
    expect(
      a.count(_followed),
      before,
      reason: 'held for the coalescing window',
    );
    await Future<void>.delayed(
      FollowedThreadsStore.refreshDelay + const Duration(milliseconds: 50),
    );
    await w.followedThreads.idle;
    expect(a.count(_followed), before + 1);
  });

  test('[BP-READ-030] a read on another device lowers a followed thread, never raises it, and a late zero keeps newer activity', () async {
    final (w, _, _) = await _fixture(
      followed: [
        _thread('t1', unread: 4, latest: '9'),
        _thread('t2', unread: 1),
      ],
    );
    addTearDown(w.dispose);
    w.followedThreads.start();
    await w.followedThreads.idle;
    int unread(String id) =>
        w.followedThreads.threads.firstWhere(
              (r) => r['threadChannelId'] == id,
            )['unreadCount']
            as int;
    w.followedThreads.applyReadStateHint({
      'scopeId': 't1',
      'unreadCount': 2,
      'maxReadSeq': 5,
    });
    expect(unread('t1'), 2);
    w.followedThreads.applyReadStateHint({
      'scopeId': 't1',
      'unreadCount': 3,
      'maxReadSeq': 6,
    });
    expect(unread('t1'), 2, reason: 'never raised');
    // A zero for frontier 5 cannot erase the reply at seq 9 this device knows.
    w.followedThreads.applyReadStateHint({
      'scopeId': 't1',
      'unreadCount': 0,
      'maxReadSeq': 5,
    });
    expect(unread('t1'), 2);
    w.followedThreads.applyReadStateHint({
      'scopeId': 't1',
      'unreadCount': 0,
      'maxReadSeq': 9,
    });
    expect(unread('t1'), 0);
    w.followedThreads.applyReadStateHint({
      'scopeId': 'unknown',
      'unreadCount': 0,
    });
    expect(unread('t2'), 1);
  });
}
