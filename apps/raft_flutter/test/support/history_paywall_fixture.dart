import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

/// Answers JSON routes; a route may return `(status, body)` for a failure.
class HistoryAdapter implements HttpClientAdapter {
  final routes = <String, FutureOr<dynamic> Function(RequestOptions)>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    final route = routes['${o.method} ${o.path}'];
    final answer = route == null
        ? (404, {'error': 'Unexpected endpoint'})
        : await route(o);
    final (status, body) = answer is (int, Object?) ? answer : (200, answer);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(WorkspaceController, HistoryAdapter)> historyFixture({
  String type = 'public',
}) async {
  final a = HistoryAdapter();
  a.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  a.routes['POST /channels/c1/read'] = (_) => {};
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = a,
  );
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'role': 'member', 'slug': 'free-one'});
  w.channel = RaftChannel({
    'id': 'c1',
    'name': 'test',
    'type': type,
    'joined': true,
  });
  w.channels = [w.channel!];
  w.messageDomain.ledger.switchServer('s1');
  return (w, a);
}

Map<String, dynamic> hiddenMessage(
  String id, {
  String sender = 'Mina',
  String text = 'older note',
  String type = 'user',
}) => {
  'id': id,
  'senderType': type,
  'senderId': 'u-$id',
  'senderName': sender,
  'senderAvatarUrl': null,
  'createdAt': '2026-09-20T10:00:00.000Z',
  'preview': text,
};
