import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

/// Deleting the open workspace must not surface "Could not complete that. Try again.": work
/// still running against the deleted server is stale, not a failure.
class _Server implements HttpClientAdapter {
  final deleted = <String>{};
  final calls = <String>[];
  Completer<void>? holdDelete, holdReads, holdFirstServers;
  var serverReads = 0;
  bool onlyA = false, failServers = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add('${o.method} ${o.path} ${o.headers['X-Server-Id'] ?? ''}');
    Object body = o.method == 'GET' ? <Object>[] : {};
    var status = 200;
    final scope = o.headers['X-Server-Id'];
    if (scope == 'A' && o.method == 'GET') await holdReads?.future;
    if (o.path == '/auth/login') {
      body = {
        'accessToken': 'test-only',
        'refreshToken': 'test-only',
        'user': {'id': 'alice'},
      };
    } else if (o.method == 'DELETE' && o.path == '/servers/A') {
      await holdDelete?.future;
      deleted.add('A');
    } else if (o.path == '/servers') {
      if (serverReads++ == 0) await holdFirstServers?.future;
      if (failServers) status = 503;
      body = failServers
          ? {'error': 'offline'}
          : [
              if (!deleted.contains('A'))
                {'id': 'A', 'name': 'Alpha', 'role': 'owner'},
              if (!onlyA) {'id': 'B', 'name': 'Beta', 'role': 'owner'},
            ];
    } else if (scope != null && deleted.contains(scope)) {
      status = 403;
      body = {'error': 'You are not a member of this server'};
    }
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

class _Client extends RaftClient {
  _Client(_Server s)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = s,
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  bool get connected => true;
  @override
  void connect() {}
}

void main() {
  test(
    'deleting the open server leaves no error and opens the next one',
    () async {
      final server = _Server();
      final client = _Client(server);
      await client.login('t', 't');
      final w = WorkspaceController(client);
      addTearDown(w.dispose);
      final a = RaftRecord({'id': 'A', 'name': 'Alpha', 'role': 'owner'});
      final b = RaftRecord({'id': 'B', 'name': 'Beta', 'role': 'owner'});
      w.servers = [a, b];
      // Server A is open and its loads (channels, sidebar, members) are still
      // waiting on the network when it is deleted.
      server.holdReads = Completer<void>();
      unawaited(w.selectServer(a));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final errors = <String>[];
      w.addListener(() {
        if (w.error != null) errors.add(w.error!);
      });

      // The delete request is in flight; the socket reports the membership
      // removal first, then the HTTP answer arrives (the production order).
      server.holdDelete = Completer<void>();
      final request = client.exitServer('A', delete: true);
      await Future<void>.delayed(Duration.zero);
      server.holdFirstServers = Completer<void>();
      server.holdDelete!.complete();
      client.stream.add(
        const RaftEvent('server:membership-removed', {'serverId': 'A'}),
      );
      await request;
      w.revokeServer('A');
      await w.recoverMembership();
      // The membership refresh the socket event started answers late, after
      // the next server was selected: its fence now fails.
      server.holdFirstServers!.complete();
      server.holdReads!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(errors, isEmpty, reason: server.calls.join('\n'));
      expect(w.error, isNull);
      expect(w.server?.id, 'B');
      expect(client.serverId, 'B');
    },
  );

  test('deleting the only server leaves no error and no open server', () async {
    final server = _Server()..onlyA = true;
    final client = _Client(server);
    await client.login('t', 't');
    final w = WorkspaceController(client);
    addTearDown(w.dispose);
    final a = RaftRecord({'id': 'A', 'name': 'Alpha', 'role': 'owner'});
    w.servers = [a];
    await w.selectServer(a);
    await client.exitServer('A', delete: true);
    w.revokeServer('A');
    await w.recoverMembership();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(w.error, isNull);
    expect(w.server, isNull);
    expect(w.servers, isEmpty);
  });

  test('a membership refresh that really fails still reports', () async {
    final server = _Server();
    final client = _Client(server);
    await client.login('t', 't');
    final w = WorkspaceController(client);
    addTearDown(w.dispose);
    final b = RaftRecord({'id': 'B', 'name': 'Beta', 'role': 'owner'});
    w.servers = [b];
    await w.selectServer(b);
    server.failServers = true;
    await w.recoverMembership();
    expect(w.error, isNotNull);
  });
}
