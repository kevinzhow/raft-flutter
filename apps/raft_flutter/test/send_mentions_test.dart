import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

class _Transport implements HttpClientAdapter {
  final writes = <Map<String, dynamic>>[];
  Completer<void>? pending;
  bool fail = true;
  Completer<void>? pagePending;
  bool requestedPage = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    dynamic body;
    int status = 200;
    if (o.path == '/auth/login') {
      body = {
        'accessToken': 'fixture',
        'refreshToken': 'fixture',
        'user': {'id': 'alice'},
      };
    } else if (o.path.startsWith('/messages/channel/')) {
      requestedPage = true;
      if (pagePending != null) await pagePending!.future;
      body = {'messages': [], 'threadSummariesByParentMessageId': {}};
    } else if (o.path == '/v2/messages') {
      writes.add(Map<String, dynamic>.from(jsonDecode(jsonEncode(o.data))));
      if (pending != null) await pending!.future;
      status = fail ? 503 : 200;
      body = fail
          ? {'error': 'Offline'}
          : {
              'message': {
                'id': 'receipt',
                'channelId': o.data['channelId'],
                'content': o.data['content'],
                'seq': '5',
              },
            };
    } else {
      body = {'channels': []};
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

Future<WorkspaceController> _fixture(_Transport transport) async {
  final c = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = transport,
  );
  await c.login('fixture', 'fixture');
  c.selectServer('s1');
  final w = WorkspaceController(c)
    ..server = RaftRecord({'id': 's1', 'role': 'owner'})
    ..channel = RaftChannel({'id': 'c1', 'name': 'general', 'joined': true});
  w.ledger.switchServer('s1');
  return w;
}

void main() {
  test(
    'conversion pauses writes without consuming the existing retry identity',
    () async {
      final t = _Transport(), w = await _fixture(t);
      addTearDown(w.dispose);
      expect(await w.send('retained draft'), false);
      final identity = t.writes.single['randomId'];
      w.channel = RaftChannel({
        ...w.channel!.json,
        'conversionJob': {'id': 'job', 'status': 'running', 'phase': 'prepare'},
      });
      expect(w.conversationPaused, true);
      expect(await w.send('retained draft'), false);
      expect(t.writes, hasLength(1));
      expect(w.error, 'Channel conversion in progress');
      w.channel = RaftChannel({
        ...w.channel!.json,
        'conversionJob': {
          'id': 'job',
          'status': 'failed',
          'phase': 'prepare',
          'progress': {'rollbackState': 'restored'},
        },
      });
      t.fail = false;
      expect(w.conversationPaused, false);
      expect(await w.send('retained draft'), true);
      expect(t.writes.last['randomId'], identity);
      expect(w.error, isNull);
    },
  );
  test(
    'conversion arriving during history refresh cancels a pending send',
    () async {
      final t = _Transport()..pagePending = Completer<void>();
      final w = await _fixture(t);
      addTearDown(w.dispose);
      w.hasNewer = true;
      final sending = w.send('retained draft');
      while (!t.requestedPage) {
        await Future<void>.delayed(Duration.zero);
      }
      w.channel = RaftChannel({
        ...w.channel!.json,
        'conversionCommand': {
          'id': 'command',
          'status': 'pending',
          'kind': 'start',
        },
      });
      t.pagePending!.complete();
      expect(await sending, false);
      expect(t.writes, isEmpty);
    },
  );
  test('failed mention send retries same identity and changes request for a different identity', () async {
    final t = _Transport(), w = await _fixture(t);
    addTearDown(w.dispose);
    final human = [
      {'type': 'user', 'id': 'human', 'name': 'shared'},
    ];
    expect(await w.send('@shared 中文', mentions: human), false);
    expect(await w.send('@shared 中文', mentions: human), false);
    expect(t.writes[1]['randomId'], t.writes[0]['randomId']);
    expect(t.writes[0]['mentions'], human);
    expect(
      await w.send(
        '@shared 中文',
        mentions: [
          {'type': 'agent', 'id': 'agent', 'name': 'shared'},
        ],
      ),
      false,
    );
    expect(t.writes[2]['randomId'], isNot(t.writes[1]['randomId']));
  });
  test(
    'caller mutation cannot change an in-flight structured mention payload',
    () async {
      final t = _Transport()..pending = Completer<void>(),
          w = await _fixture(t);
      addTearDown(w.dispose);
      final mentions = <Map<String, dynamic>>[
        {'type': 'user', 'id': 'human', 'name': 'shared'},
      ];
      final sending = w.send('@shared', mentions: mentions);
      mentions.single['id'] = 'changed';
      mentions.add({'type': 'agent', 'id': 'other', 'name': 'other'});
      while (t.writes.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(t.writes.single['mentions'], [
        {'type': 'user', 'id': 'human', 'name': 'shared'},
      ]);
      t.pending!.complete();
      expect(await sending, false);
    },
  );
  test('an accepted late send cannot rehydrate a revoked channel', () async {
    final t = _Transport()
          ..pending = Completer<void>()
          ..fail = false,
        w = await _fixture(t);
    addTearDown(w.dispose);
    final sending = w.send('private source');
    while (t.writes.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    w.channel = null;
    w.channelGeneration++;
    w.ledger.revokeChannel('c1');
    w.visibleIds.remove('c1');
    t.pending!.complete();
    expect(await sending, true);
    expect(w.ledger.messages('c1'), isEmpty);
    expect(w.visibleIds.containsKey('c1'), false);
  });
  test('navigation during latest-history refresh cannot send an old draft to the new channel', () async {
    final t = _Transport()..pagePending = Completer<void>();
    final w = await _fixture(t);
    addTearDown(w.dispose);
    w.hasNewer = true;
    final refreshed = <int>[];
    final sending = w.send(
      'old private draft',
      onWindowRefreshed: refreshed.add,
    );
    while (!t.requestedPage) {
      await Future<void>.delayed(Duration.zero);
    }
    w.channel = RaftChannel({'id': 'c2', 'name': 'other', 'joined': true});
    w.channelGeneration++;
    t.pagePending!.complete();
    expect(await sending, false);
    expect(t.writes, isEmpty);
    expect(refreshed, isEmpty);
    expect(w.error, isNull);
  });
  test(
    'late failed send cannot place an old conversation error in a new channel',
    () async {
      final t = _Transport()..pending = Completer<void>();
      final w = await _fixture(t);
      addTearDown(w.dispose);
      final sending = w.send('old draft');
      while (t.writes.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      w.channel = RaftChannel({'id': 'c2', 'name': 'other', 'joined': true});
      w.channelGeneration++;
      t.pending!.complete();
      expect(await sending, false);
      expect(w.error, isNull);
    },
  );
  test('only the controller intentional current-channel refresh publishes its accepted window', () async {
    final t = _Transport()..fail = false;
    final w = await _fixture(t);
    addTearDown(w.dispose);
    w.hasNewer = true;
    final refreshed = <int>[];
    expect(
      await w.send('current draft', onWindowRefreshed: refreshed.add),
      true,
    );
    expect(refreshed, [w.channelGeneration]);
    expect(t.writes.single['channelId'], 'c1');
  });
  test('plain sends omit mentions and preserve retry identity', () async {
    final t = _Transport(), w = await _fixture(t);
    addTearDown(w.dispose);
    await w.send('plain');
    await w.send('plain', mentions: []);
    expect(t.writes.every((r) => !r.containsKey('mentions')), true);
    expect(t.writes[1]['randomId'], t.writes[0]['randomId']);
  });
}
