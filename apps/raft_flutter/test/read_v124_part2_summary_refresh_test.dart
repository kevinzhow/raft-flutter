// Source: packages/web/src/store/serverUnreadSummaryRefresh.ts at v1.24.0-source.1
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/source_server_unread.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

class _Adapter implements HttpClientAdapter {
  int summaries = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    final Object body;
    if (o.path == '/servers/unread-summary') {
      summaries++;
      body = [
        {'serverId': 's2', 'unreadCount': 1, 'activityUnreadCount': 1},
      ];
    } else if (o.path == '/auth/login') {
      body = {
        'accessToken': 'fixture-only',
        'refreshToken': 'fixture-only',
        'user': {'id': 'alice'},
      };
    } else {
      body = {'error': 'Unexpected endpoint'};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      body is Map && body.containsKey('error') ? 404 : 200,
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
}

Map<String, dynamic> _scope(String id) => {
  'serverId': 's1',
  'scopeId': id,
  'readStateVersion': 3,
};

/// Web store/serverUnreadSummaryRefresh.ts: a read the server saved (here or
/// on another device) reads the cross-server summary 300 ms later; a burst of
/// frames is one request.
void main() {
  Future<(WorkspaceController, _Adapter, _Client)> fixture() async {
    final adapter = _Adapter();
    final client = _Client(adapter);
    await client.login('fixture', 'fixture');
    client.selectServer('s1');
    final w = WorkspaceController(client);
    w.server = RaftRecord({'id': 's1', 'role': 'owner'});
    addTearDown(w.dispose);
    return (w, adapter, client);
  }

  test('[BP-READ-030] [BP-READ-031] [BP-READ-051] read frames refresh the summary once, 300 ms later', () async {
    final (w, adapter, client) = await fixture();
    final store = SourceServerUnreadStore(w);
    fakeAsync((async) {
      void settle() {
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
      }

      unawaited(store.refresh());
      settle();
      expect(adapter.summaries, 1);
      client.emit('read_state:updated', _scope('c1'));
      client.emit('read_state:updated', _scope('c2'));
      client.emit('read_state:updated_bulk', {
        'serverId': 's1',
        'scopes': [_scope('c3'), 'bad entry'],
      });
      async.elapse(const Duration(milliseconds: 299));
      async.flushMicrotasks();
      expect(adapter.summaries, 1, reason: 'not before 300 ms');
      async.elapse(const Duration(milliseconds: 2));
      settle();
      expect(adapter.summaries, 2, reason: 'a burst is one request');
      client.emit('read_state:updated', _scope('c1'));
      settle();
      expect(adapter.summaries, 3, reason: 'the next frame starts a new one');
    });
    store.dispose();
  });

  test('a malformed single read frame refreshes nothing', () async {
    final (w, adapter, client) = await fixture();
    final store = SourceServerUnreadStore(w);
    fakeAsync((async) {
      unawaited(store.refresh());
      async.elapse(const Duration(seconds: 1));
      client.emit('read_state:updated', {'serverId': 's1'});
      client.emit('read_state:updated', {'scopeId': 'c1'});
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(adapter.summaries, 1);
    });
    store.dispose();
  });

  test('disposing the store cancels a pending refresh', () async {
    final (w, adapter, client) = await fixture();
    final store = SourceServerUnreadStore(w);
    fakeAsync((async) {
      unawaited(store.refresh());
      async.elapse(const Duration(seconds: 1));
      client.emit('read_state:updated', _scope('c1'));
      store.dispose();
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(adapter.summaries, 1);
    });
  });
}
