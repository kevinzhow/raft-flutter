import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

class _MembershipTransport implements HttpClientAdapter {
  final started = Completer<void>();
  final oldSnapshot = Completer<ResponseBody>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    if (options.path == '/servers') {
      if (!started.isCompleted) started.complete();
      return oldSnapshot.future;
    }
    return ResponseBody.fromString(
      jsonEncode({
        'accessToken': 'test-only',
        'refreshToken': 'test-only',
        'user': {'id': 'alice'},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('own role revocation synchronously closes privileged section and fences older membership HTTP', () async {
    final transport = _MembershipTransport();
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = transport,
    );
    await client.login('test', 'test');
    client.selectServer('s1');
    final owner = RaftRecord({'id': 's1', 'role': 'owner'});
    final w = WorkspaceController(client)
      ..server = owner
      ..servers = [owner];
    addTearDown(() async {
      w.dispose();
      await client.dispose();
    });
    w.setSection('providers');
    expect(w.section, 'providers');
    final recovering = w.recoverMembership();
    await transport.started.future;
    w.applyMembershipRole({
      'serverId': 's1',
      'userId': 'alice',
      'role': 'guest',
    });
    expect(w.server!.string('role'), 'guest');
    expect(w.section, 'chat');
    expect(w.canVisitSection('providers'), false);
    transport.oldSnapshot.complete(
      ResponseBody.fromString(
        jsonEncode([owner.json]),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      ),
    );
    await recovering;
    expect(w.server!.string('role'), 'guest');
    expect(w.servers.single.string('role'), 'guest');
    w.setSection('providers');
    expect(w.section, 'chat');
    w.applyMembershipRole({
      'serverId': 's1',
      'userId': 'someone-else',
      'role': 'owner',
    });
    w.applyMembershipRole({
      'serverId': 'unknown',
      'userId': 'alice',
      'role': 'owner',
    });
    expect(w.server!.string('role'), 'guest');
  });
}
