import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/source_activity_unread_store.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

// Source: packages/web/src/store/channelRealtimeSync.ts
// (isMessageActivitySuppressedByMute) at v1.24.0-source.1
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

void main() {
  test('[BP-READ-047] a muted channel suppresses the Activity refresh unless the message mentions me, is in a thread or in a task conversation', () async {
    final a = _Adapter();
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
    w.server = RaftRecord({'id': 's1', 'role': 'owner'});
    w.channels = [
      RaftChannel({
        'id': 'muted',
        'name': 'quiet',
        'joined': true,
        'activityMuted': true,
        'muteFromSeq': '10',
      }),
      RaftChannel({
        'id': 'muted-all',
        'name': 'quieter',
        'joined': true,
        'activityMuted': true,
      }),
      RaftChannel({'id': 'loud', 'name': 'loud', 'joined': true}),
    ];
    final store = w.activityUnread..start();
    bool refreshes(Map<String, dynamic> message) => store.ownsPageRefresh(
      RaftEvent('message:new', message),
      view: SourceActivityUnreadStore.defaultInboxView,
      loadedRows: 0,
    );
    Map<String, dynamic> message(String channel, int seq, [Map? extra]) => {
      'id': 'm$seq',
      'channelId': channel,
      'seq': seq,
      ...?extra,
    };

    expect(refreshes(message('loud', 12)), isTrue);
    expect(refreshes(message('muted', 12)), isFalse, reason: 'past the mute');
    expect(refreshes(message('muted', 8)), isTrue, reason: 'before the mute');
    expect(refreshes(message('muted-all', 3)), isFalse);
    expect(
      refreshes(
        message('muted', 12, {
          'mentions': [
            {'type': 'user', 'id': 'alice'},
          ],
        }),
      ),
      isTrue,
      reason: 'a mention reaches Activity',
    );
    expect(
      refreshes(
        message('muted', 12, {
          'conversationContext': {'channelType': 'thread'},
        }),
      ),
      isTrue,
    );
    expect(
      refreshes(
        message('muted', 12, {
          'conversationContext': {'channelType': 'task'},
        }),
      ),
      isTrue,
      reason: 'a task conversation follows the thread rule, not the mute',
    );
  });
}
