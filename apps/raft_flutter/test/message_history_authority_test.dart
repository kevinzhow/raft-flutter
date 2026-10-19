import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://history-authority.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('server');
  }
  Completer<Map<String, dynamic>>? pending;
  final started = Completer<void>();
  @override
  void joinChannel(String id) {}
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {};
  @override
  Future<dynamic> post(String path, {dynamic data}) async => {};
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    BigInt? before,
    BigInt? after,
    int limit = 50,
  }) async {
    if (!started.isCompleted) started.complete();
    return pending?.future ??
        Future.value({
          'messages': [
            {
              'id': 'fresh',
              'channelId': id,
              'seq': '2',
              'content': 'Current role response',
            },
          ],
          'historyLimited': false,
        });
  }
}

void main() {
  test(
    'an HTTP response from before a role ABA cycle cannot become a window',
    () async {
      final client = _Client(),
          db = DriftWorkspaceCache(NativeDatabase.memory());
      final channel = RaftChannel({
        'id': 'chat',
        'type': 'private',
        'joined': true,
      });
      final w = WorkspaceController(client, cache: db)
        ..server = RaftRecord({'id': 'server', 'role': 'owner'})
        ..channels = [channel];
      w.messageDomain.ledger.switchServer('server');
      try {
        await w.refreshMessageSyncFlag();
        final stale = Completer<Map<String, dynamic>>();
        client.pending = stale;
        final opening = w.selectChannel(
          channel,
          navigate: false,
          autoRead: false,
        );
        await client.started.future;
        for (final role in ['guest', 'owner']) {
          w.applyMembershipRole({
            'userId': 'alice',
            'serverId': 'server',
            'role': role,
          });
        }
        stale.complete({
          'messages': [
            {
              'id': 'stale',
              'channelId': 'chat',
              'seq': '1',
              'content': 'Old role response',
            },
          ],
          'historyLimited': false,
        });
        await opening;
        await w.flushCache();
        expect(w.messageDomain.messages, isEmpty);
        expect(
          await db.read(client.origin, 'alice', 'server', 'window', 'chat'),
          isNull,
        );
        client.pending = null;
        await w.selectChannel(channel, navigate: false, autoRead: false);
        expect(w.messageDomain.messages.map((m) => m.id), ['fresh']);
      } finally {
        await w.flushCache();
        w.dispose();
        await client.dispose();
        await db.close();
      }
    },
  );
}
