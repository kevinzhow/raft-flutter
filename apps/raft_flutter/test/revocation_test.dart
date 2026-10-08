import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

class _Transport implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async => ResponseBody.fromString(
    jsonEncode(
      o.path == '/auth/login'
          ? {
              'accessToken': 'test-only',
              'refreshToken': 'test-only',
              'user': {'id': 'alice'},
            }
          : {'error': 'offline'},
    ),
    o.path == '/auth/login' ? 200 : 503,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  test('authoritative server revocation clears UI synchronously and queued native cache despite offline transport', () async {
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = _Transport(),
    );
    await client.login('test', 'test');
    client.selectServer('private-server');
    final db = DriftWorkspaceCache(NativeDatabase.memory());
    final w = WorkspaceController(client, cache: db);
    w.server = RaftRecord({'id': 'private-server', 'role': 'owner'});
    w.servers = [w.server!];
    w.ledger.switchServer('private-server');
    w.channel = RaftChannel({
      'id': 'private-channel',
      'name': 'private',
      'joined': true,
    });
    w.channels = [w.channel!];
    w.ledger.ingest([
      {
        'id': 'm1',
        'channelId': 'private-channel',
        'content': 'private body',
        'seq': '1',
      },
    ], expectedGeneration: w.ledger.generation);
    w.visibleIds['private-channel'] = {'m1'};
    w.saveDraft('private draft');
    await db.write(
      client.origin,
      'alice',
      'private-server',
      'window',
      'private-channel',
      {
        'messages': [
          {'content': 'private body'},
        ],
      },
    );
    expect(w.messages, hasLength(1));
    w.revokeServer('private-server');
    expect(w.server, isNull);
    expect(w.channel, isNull);
    expect(client.serverId, isNull);
    expect(w.servers, isEmpty);
    expect(w.messages, isEmpty);
    expect(w.drafts, isEmpty);
    await w.flushCache();
    expect(
      await db.read(
        client.origin,
        'alice',
        'private-server',
        'draft',
        'private-channel',
      ),
      isNull,
    );
    expect(
      await db.read(
        client.origin,
        'alice',
        'private-server',
        'window',
        'private-channel',
      ),
      isNull,
    );
    await w.selectServer(RaftRecord({'id': 'private-server', 'role': 'owner'}));
    expect(w.server, isNull);
    w.dispose();
    await db.close();
  });
}
