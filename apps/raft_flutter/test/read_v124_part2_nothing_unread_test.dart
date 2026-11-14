import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

// Source: packages/web/src/components/thread/inboxRowActions.ts
// (toggleActivityRowRead, queueReadToggle) at v1.24.0-source.1
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

Future<(WorkspaceController, _Adapter, _Client)> _fixture() async {
  final a = _Adapter();
  a.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  a.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
  a.routes['GET /channels/unread'] = (_) => {'channels': {}};
  a.routes['POST /channels/c1/read-all'] = (_) => {
    'maxReadSeq': '5',
    'readStateVersion': 3,
    'unreadCount': 0,
  };
  final client = _Client(a);
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'role': 'owner'});
  w.channel = RaftChannel({'id': 'c1', 'name': 'test', 'joined': true});
  w.channels = [w.channel!];
  addTearDown(w.dispose);
  return (w, a, client);
}

Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('[BP-READ-036] a nothing answer to Mark as unread is reported once; a counted one is not', () async {
    final (w, a, _) = await _fixture();
    var told = 0;
    a.routes['POST /channels/c1/unread'] = (_) => {
      'outcome': 'nothing',
      'unreadCount': 0,
      'readStateVersion': 2,
      'maxReadSeq': '5',
    };
    await w.conversationReads.markUnreadWithProjection(
      'c1',
      onNothingUnread: () => told++,
    );
    expect(told, 1);
    a.routes['POST /channels/c1/unread'] = (_) => {
      'outcome': 'counted',
      'unreadCount': 1,
      'readStateVersion': 3,
      'maxReadSeq': '4',
    };
    await w.conversationReads.markUnreadWithProjection(
      'c1',
      onNothingUnread: () => told++,
    );
    expect(told, 1);
  });
}
