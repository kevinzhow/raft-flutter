import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

class _Wire implements HttpClientAdapter {
  final reads = <String, int>{};
  final versions = <String, int>{};
  final holds = <String, Completer<void>>{};
  final statuses = <String, int>{};
  final cacheControl = <String, String>{};
  final responses = <String, Object>{};
  String account = 'alice';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancellation,
  ) async {
    final server = options.headers['X-Server-Id'];
    final path = options.uri.path.substring('/api'.length);
    final version = versions[path] ?? 1;
    if (options.method == 'GET') {
      reads.update(
        '$server ${options.uri.path}',
        (n) => n + 1,
        ifAbsent: () => 1,
      );
      if (holds[path] case final hold?) await hold.future;
    }
    final body = switch (path) {
      '/auth/login' => {
        'accessToken': 'access-for-$account',
        'refreshToken': 'refresh-for-$account',
        'user': {'id': account},
      },
      _ =>
        responses[path] ??
            {
              'server': server,
              'version': version,
              'query': options.uri.query,
              'rows': ['original'],
            },
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      statuses['${options.method} $path'] ?? 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (cacheControl[path] case final header?) 'cache-control': [header],
      },
    );
  }

  int requests(String path, [String server = 's1']) =>
      reads['$server /api$path'] ?? 0;

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Wire wire;
  late RaftClient client;
  late DateTime now;

  setUp(() async {
    now = DateTime.utc(2026, 11, 21);
    wire = _Wire();
    client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = wire,
      governor: RateLimitGovernor(now: () => now),
    );
    await client.login('fixture', 'local-only');
    client.selectServer('s1');
  });

  tearDown(() => client.dispose());

  for (final path in [
    '/channels',
    '/channels/dm',
    '/channels/conversation',
    '/channels/unread',
    '/channels/main/members',
    '/channels/main/files',
    '/channels/inbox',
    '/channels/saved',
    '/agents',
    '/servers/s1/members',
    '/servers/s1/members/person/profile',
    '/tasks/channel/main/number/3',
    '/tasks/task/history',
    '/tasks/server',
    '/tasks/server/counts',
    '/messages/channel/conversation',
    '/messages/search',
    '/artifacts/conversations/main',
    '/artifacts/artifact-id/details',
    '/integrations/marketplace',
    '/integrations/overview',
  ]) {
    test('revisiting $path reuses the accepted response', () async {
      final first = await client.get(path);
      expect(wire.requests(path), 1);
      expect(await client.get(path), first);
      expect(wire.requests(path), 1);
    });
  }

  test(
    'identical pending reads share transport and return independent bodies',
    () async {
      const path = '/tasks/channel/main/number/3';
      final hold = wire.holds[path] = Completer<void>();
      final first = client.get(path, query: {'scope': 'main'});
      final second = client.get(path, query: {'scope': 'main'});
      hold.complete();
      final before = await first as Map;
      (before['rows'] as List).add('mutation');
      expect((await second)['rows'], ['original']);
      expect((await client.get(path, query: {'scope': 'main'}))['rows'], [
        'original',
      ]);
      expect(wire.requests(path), 1);
      expect(
        (await client.get(path, query: {'scope': 'other'}))['query'],
        'scope=other',
      );
      expect(wire.requests(path), 2);
    },
  );

  test(
    'writes retire affected GETs while unrelated families stay warm',
    () async {
      const task = '/tasks/channel/main/number/3';
      const files = '/channels/other/files';
      await client.get(task);
      await client.get(files);
      wire.versions[task] = 2;
      await client.patch('/tasks/task/status', data: {'status': 'done'});
      expect((await client.get(task))['version'], 2);
      expect(wire.requests(task), 2);
      await client.get(files);
      expect(wire.requests(files), 1);
    },
  );

  test('changing servers and signing in again retire retained data', () async {
    const path = '/tasks/channel/main/number/3';
    await client.get(path);
    client.selectServer('s2');
    expect((await client.get(path))['server'], 's2');
    client.selectServer('s1');
    await client.get(path);
    expect(wire.requests(path), 2);
    await client.logout();
    wire.account = 'bob';
    await client.login('fixture', 'local-only');
    client.selectServer('s1');
    await client.get(path);
    expect(wire.requests(path), 3);
  });

  test(
    'a stale revisit publishes immediately, then only publishes a change',
    () async {
      const path = '/tasks/channel/main/number/3';
      await client.get(path);
      final shown = <int>[];
      void publish(dynamic body) => shown.add(body['version'] as int);

      await client.observeGet(path, onData: publish);
      expect(shown, [1]);
      expect(wire.requests(path), 1);

      now = now.add(const Duration(seconds: 11));
      wire.versions[path] = 2;
      final hold = wire.holds[path] = Completer<void>();
      final refresh = client.observeGet(path, onData: publish);
      expect(shown, [1, 1]);
      hold.complete();
      await refresh;
      expect(shown, [1, 1, 2]);
      expect(wire.requests(path), 2);

      now = now.add(const Duration(seconds: 11));
      await client.observeGet(path, onData: publish);
      expect(shown, [1, 1, 2, 2]);
      expect(wire.requests(path), 3);
    },
  );

  test(
    'explicit authority probes and expired snapshots reach the server',
    () async {
      const path = '/channels/main';
      await client.get(path);
      wire.versions[path] = 2;
      expect((await RaftClient.runFresh(() => client.get(path)))['version'], 2);
      expect(wire.requests(path), 2);
      now = now.add(const Duration(minutes: 3));
      expect(client.peekGet(path), isNull);
      expect((await client.get(path))['version'], 2);
      expect(wire.requests(path), 3);
    },
  );

  test('a rejected background read retires the displayed cache', () async {
    const path = '/channels/main';
    await client.get(path);
    now = now.add(const Duration(seconds: 13));
    wire.statuses['GET $path'] = 403;
    await expectLater(
      client.observeGet(path, onData: (_) {}),
      throwsA(isA<RaftApiException>().having((e) => e.status, 'status', 403)),
    );
    expect(client.peekGet(path), isNull);
  });

  test('a failed write preserves existing reads', () async {
    const path = '/tasks/channel/main/number/3';
    await client.get(path);
    wire.statuses['PATCH /tasks/task'] = 409;
    await expectLater(
      client.patch('/tasks/task'),
      throwsA(isA<RaftApiException>()),
    );
    await client.get(path);
    expect(wire.requests(path), 1);
  });

  for (final (event, affected, untouched) in [
    (
      const RaftEvent('message:updated', {'id': 'm1', 'channelId': 'main'}),
      '/messages/channel/main',
      '/messages/channel/other',
    ),
    (
      const RaftEvent('thread:updated', {
        'parentMessageId': 'parent',
        'threadChannelId': 'thread',
        'latestReply': {
          'conversationContext': {'parentChannelId': 'main'},
        },
      }),
      '/messages/channel/main',
      '/messages/channel/other',
    ),
    (
      const RaftEvent('task:updated', {
        'channelId': 'main',
        'task': {'id': 't1', 'taskNumber': 3},
      }),
      '/tasks/channel/main/number/3',
      '/tasks/channel/main/number/4',
    ),
    (
      const RaftEvent('task:deleted', {'taskId': 't1', 'channelId': 'main'}),
      '/tasks/t1/history',
      '/tasks/t2/history',
    ),
    (
      const RaftEvent('agent:updated', {'agentId': 'a1'}),
      '/agents',
      '/messages/channel/other',
    ),
    (
      const RaftEvent('artifact:updated', {'artifactId': 'a1'}),
      '/artifacts/a1/details',
      '/artifacts/a2/details',
    ),
    (
      const RaftEvent('channel:updated', {'channelId': 'main'}),
      '/channels/main',
      '/channels/other',
    ),
    (
      const RaftEvent('channel:members-updated', {'channelId': 'main'}),
      '/messages/channel/main',
      '/auth/me',
    ),
    (
      const RaftEvent('read:updated', {'channelId': 'main'}),
      '/channels/unread',
      '/tasks/t2/history',
    ),
    (
      const RaftEvent('message:read', {'channelId': 'main'}),
      '/channels/unread',
      '/messages/channel/main',
    ),
    (
      const RaftEvent('saved:updated', {}),
      '/channels/saved',
      '/channels/unread',
    ),
    (const RaftEvent('sync:changed', {}), '/channels/unread', '/auth/me'),
  ]) {
    test('${event.name} invalidates $affected', () async {
      await client.get(affected);
      await client.get(untouched);
      wire.versions[affected] = 2;
      client.invalidateReadsForEvent(event);
      expect((await client.get(affected))['version'], 2);
      expect(wire.requests(affected), 2);
      if (untouched != '/auth/me') {
        await client.get(untouched);
        expect(wire.requests(untouched), 1);
      }
    });
  }

  test('an invalidated older response cannot refill the cache', () async {
    const path = '/messages/channel/main';
    final hold = wire.holds[path] = Completer<void>();
    final before = client.get(path);
    while (wire.requests(path) == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    client.invalidateReadsForEvent(
      const RaftEvent('message:new', {'channelId': 'main'}),
    );
    wire.holds.remove(path);
    wire.versions[path] = 2;
    expect((await client.get(path))['version'], 2);
    hold.complete();
    expect((await before)['version'], 1);
    expect((await client.get(path))['version'], 2);
    expect(wire.requests(path), 2);
  });

  test(
    'does not retain server no-store, secret-bearing or oversized replies',
    () async {
      wire.cacheControl['/channels/main'] = 'private, no-store';
      wire.responses['/agents'] = [
        {
          'id': 'agent',
          'envVars': {'TOKEN': 'fixture-only'},
        },
      ];
      wire.responses['/messages/channel/main'] = {
        'messages': ['x' * (384 * 1024)],
      };
      for (final path in wire.responses.keys.followedBy(['/channels/main'])) {
        await client.get(path);
        await client.get(path);
        expect(wire.requests(path), 2, reason: path);
      }
    },
  );

  test('least recently used entries are dropped at the entry limit', () async {
    const retained = '/channels/retained';
    const dropped = '/channels/dropped';
    await client.get(retained);
    await client.get(dropped);
    for (var index = 0; index < 126; index++) {
      await client.get('/channels/room-$index');
    }
    await client.get(retained);
    await client.get('/channels/overflow');
    expect(client.peekGet(dropped), isNull);
    expect(client.peekGet(retained), isNotNull);
  });

  for (final path in [
    '/auth/me',
    '/auth/passkeys',
    '/billing/summary',
    '/agents/agent-id/connections/provider',
    '/agents/agent-id',
    '/attachments/attachment-id/url',
    '/artifacts/artifact-id',
    '/artifacts/artifact-id/open',
    '/messages/message-id/app-link-previews',
    '/sync/changes',
    '/unknown',
  ]) {
    test('never retains $path', () async {
      await client.get(path);
      wire.versions[path] = 2;
      expect((await client.get(path))['version'], 2);
      expect(wire.requests(path), 2);
    });
  }
}
