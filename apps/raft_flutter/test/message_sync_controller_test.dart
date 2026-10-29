import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

class _Client extends RaftClient {
  _Client(_Transport transport)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = transport,
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<void> dispose() async {
    await stream.close();
    await super.dispose();
  }
}

class _Transport implements HttpClientAdapter {
  bool enabled = true;
  Completer<void>? pending;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(o);
    dynamic body;
    if (o.path == '/auth/login') {
      body = {
        'accessToken': 'fixture',
        'refreshToken': 'fixture',
        'user': {'id': 'alice'},
      };
    } else if (o.path == '/feature-flags/evaluate') {
      if (pending != null) await pending!.future;
      body = {
        'evaluations': [
          {'key': 'sync_core_messages_v0', 'enabled': enabled},
          {
            'key': WorkspaceController.remoteComputerUpgradeFlag,
            'enabled': true,
          },
        ],
      };
    } else {
      body = {'channels': {}};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<WorkspaceController> _fixture(_Transport t) async {
  final c = _Client(t);
  await c.login('fixture', 'fixture');
  c.selectServer('s1');
  final w = WorkspaceController(c)
    ..server = RaftRecord({'id': 's1', 'role': 'owner'});
  w.messageDomain.ledger.switchServer('s1');
  return w;
}

Map<String, dynamic> message(String id, int seq) => {
  'id': id,
  'channelId': 'c1',
  'seq': seq,
  'content': 'loaded 中文',
  'commentRef': {'id': 'comment'},
};
void main() {
  test(
    'real controller accepts late socket messages and merge-only task updates',
    () async {
      final w = await _fixture(_Transport());
      addTearDown(w.dispose);
      await w.refreshMessageSyncFlag();
      expect(w.remoteComputerUpgradeEnabled, true);

      final c = w.client as _Client;
      c.stream.add(RaftEvent('message:new', message('a', 2)));
      c.stream.add(RaftEvent('message:new', message('b', 99)));
      c.stream.add(RaftEvent('message:new', message('late', 10)));
      c.stream.add(RaftEvent('message:new', message('b', 99)));
      c.stream.add(RaftEvent('message:new', message('late', 10)));
      c.stream.add(
        RaftEvent('message:updated', {
          'id': 'a',
          'channelId': 'c1',
          'taskStatus': 'done',
          'commentRef': null,
        }),
      );
      c.stream.add(
        RaftEvent('message:updated', {
          'id': 'unknown',
          'channelId': 'c1',
          'taskStatus': 'done',
        }),
      );
      expect(w.messageDomain.ledger.messages('c1').map((m) => m['id']), [
        'a',
        'late',
        'b',
      ]);
      expect(
        w.messageDomain.ledger.messages('c1').first['content'],
        'loaded 中文',
      );
      expect(w.messageDomain.ledger.messages('c1').first['commentRef'], {
        'id': 'comment',
      });
      expect(w.messageDomain.ledger.messages('c1').first['taskStatus'], 'done');
      c.stream.add(RaftEvent('channel:removed', {'channelId': 'c1'}));
      expect(w.messageDomain.ledger.messages('c1'), isEmpty);
      expect(w.messageSync.core.state('messages', 'c1'), isNull);
      c.stream.add(RaftEvent('message:new', message('private', 100)));
      expect(w.messageDomain.ledger.messages('c1'), isEmpty);
    },
  );
  test(
    'obsolete message flag is not evaluated and late ingress remains accepted',
    () async {
      final t = _Transport()..enabled = false;
      final w = await _fixture(t);
      addTearDown(w.dispose);
      await w.refreshMessageSyncFlag();
      expect(
        (t.requests.last.data as Map)['keys'],
        isNot(contains('sync_core_messages_v0')),
      );
      final c = w.client as _Client;
      c.stream.add(RaftEvent('message:new', message('new', 99)));
      c.stream.add(RaftEvent('message:new', message('late', 10)));
      expect(w.messageDomain.ledger.messages('c1').map((m) => m['id']), [
        'late',
        'new',
      ]);
    },
  );
  for (final signOut in [false, true]) {
    test(
      'late feature evaluation cannot enable ${signOut ? 'a signed-out principal' : 'another workspace'}',
      () async {
        final t = _Transport()..pending = Completer<void>();
        final w = await _fixture(t);
        addTearDown(w.dispose);
        final evaluation = w.refreshMessageSyncFlag();
        if (signOut) {
          w.client.user = null;
        } else {
          w.client.selectServer('s2');
        }
        t.pending!.complete();
        await evaluation;
        expect(w.remoteComputerUpgradeEnabled, false);
        expect(w.messageSync.core.state('messages', 'c1'), isNull);
      },
    );
  }
}
