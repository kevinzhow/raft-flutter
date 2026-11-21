import 'dart:async';

import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

import 'support/get_cache_harness.dart';

void main() {
  late GetCacheWire wire;
  late RaftClient client;
  late DateTime now;

  setUp(() async {
    now = DateTime.utc(2026, 11, 21);
    wire = GetCacheWire();
    client = await openGetCacheClient(wire, () => now);
  });

  tearDown(() => client.dispose());

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
      expect(wire.requests(path), 2);

      now = now.add(const Duration(seconds: 11));
      wire.versions[path] = 2;
      final hold = wire.holds[path] = Completer<void>();
      final refresh = client.observeGet(path, onData: publish);
      expect(shown, [1, 1]);
      hold.complete();
      await refresh;
      expect(shown, [1, 1, 2]);
      expect(wire.requests(path), 3);

      now = now.add(const Duration(seconds: 11));
      await client.observeGet(path, onData: publish);
      expect(shown, [1, 1, 2, 2]);
      expect(wire.requests(path), 4);
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

  for (final (method, path, data, affected, untouched)
      in <(String, String, Map<String, String>?, String, String?)>[
        (
          'POST',
          '/channels/saved',
          null,
          '/channels/saved',
          '/channels/unread',
        ),
        ('POST', '/channels/main/read', null, '/channels/inbox', '/agents'),
        (
          'POST',
          '/channels/inbox/read-all',
          null,
          '/channels/unread',
          '/agents',
        ),
        (
          'POST',
          '/tasks/channel/main',
          null,
          '/tasks/channel/main',
          '/tasks/channel/other',
        ),
        (
          'POST',
          '/v2/messages',
          {'channelId': 'main'},
          '/messages/channel/main',
          '/messages/channel/other',
        ),
        (
          'PATCH',
          '/messages/m1',
          {'channelId': 'main'},
          '/messages/m1/reactions/viewer',
          '/messages/m2/reactions/viewer',
        ),
        ('PATCH', '/agents/a1', null, '/agents', '/messages/channel/main'),
        (
          'POST',
          '/artifacts/save-attachment',
          null,
          '/artifacts/conversations/main',
          '/agents',
        ),
        (
          'PATCH',
          '/artifacts/a1',
          null,
          '/artifacts/a1/details',
          '/artifacts/a2/details',
        ),
        (
          'DELETE',
          '/integrations/marketplace/a1/install',
          null,
          '/integrations/marketplace',
          '/channels/main',
        ),
        (
          'PUT',
          '/mcp/servers/a1',
          null,
          '/integrations/overview',
          '/channels/main',
        ),
        ('PATCH', '/channels/main', null, '/channels/main/files', null),
      ]) {
    test('$method $path invalidates $affected', () async {
      await client.get(affected);
      if (untouched != null) await client.get(untouched);
      wire.versions[affected] = 2;
      await client.request(method, path, data: data);
      expect((await client.get(affected))['version'], 2);
      if (untouched != null) {
        await client.get(untouched);
        expect(wire.requests(untouched), 1);
      }
    });
  }

  test(
    'a pending write bypasses affected fresh reads until its reply',
    () async {
      const task = '/tasks/channel/main/number/3';
      const files = '/channels/other/files';
      await client.get(task);
      await client.get(files);
      wire.versions[task] = 2;
      final hold = wire.writeHold = Completer<void>();
      final update = client.patch(
        '/tasks/task/status',
        data: {'status': 'done'},
      );
      try {
        expect((await client.get(task))['version'], 2);
        await client.get(files);
        expect(wire.requests(files), 1);
      } finally {
        hold.complete();
        await update;
      }
      wire.versions[task] = 3;
      expect((await client.get(task))['version'], 3);
      expect(wire.requests(task), 3);
    },
  );

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
      const RaftEvent('task:created', {
        'channelId': 'main',
        'tasks': [
          {'id': 't1', 'taskNumber': 2},
          {'id': 't2', 'taskNumber': 3},
        ],
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
      const RaftEvent('channel:updated', {
        'channel': {'id': 'main', 'name': 'Renamed'},
      }),
      '/channels/main',
      '/channels/other',
    ),
    (
      const RaftEvent('channel:updated', {'channelId': 'main'}),
      '/messages/channel/main',
      '/auth/me',
    ),
    (
      const RaftEvent('channel:members-updated', {'channelId': 'main'}),
      '/messages/channel/main',
      '/auth/me',
    ),
    (
      const RaftEvent('read_state:updated', {'scopeId': 'main'}),
      '/channels/unread',
      '/tasks/t2/history',
    ),
    (
      const RaftEvent('scope_read:updated', {'scopeId': 'main'}),
      '/channels/main',
      '/channels/other',
    ),
    (
      const RaftEvent('read_state:updated_bulk', {
        'scopes': [
          {'scopeId': 'main'},
        ],
      }),
      '/channels/inbox',
      '/agents',
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
    'an invalidated older refusal cannot evict a current response',
    () async {
      const path = '/channels/main';
      wire.statuses['GET $path'] = 404;
      final hold = wire.holds[path] = Completer<void>();
      final rejected = expectLater(
        client.get(path),
        throwsA(isA<RaftApiException>()),
      );
      while (wire.requests(path) == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      client.invalidateReadsForEvent(
        const RaftEvent('channel:updated', {'channelId': 'main'}),
      );
      wire.statuses.remove('GET $path');
      wire.holds.remove(path);
      wire.versions[path] = 2;
      expect((await client.get(path))['version'], 2);
      hold.complete();
      await rejected;
      expect(client.peekGet(path), containsPair('version', 2));
    },
  );

  test('an event fences publication of an older observed refresh', () async {
    const path = '/tasks/channel/main/number/3';
    await client.get(path);
    now = now.add(const Duration(seconds: 11));
    wire.versions[path] = 2;
    final hold = wire.holds[path] = Completer<void>();
    final shown = <int>[];
    final observation = client.observeGet(
      path,
      onData: (body) => shown.add(body['version'] as int),
    );
    expect(shown, [1]);
    while (wire.requests(path) < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    client.invalidateReadsForEvent(
      const RaftEvent('task:updated', {
        'channelId': 'main',
        'task': {'id': 'task-3', 'taskNumber': 3},
      }),
    );
    wire.holds.remove(path);
    wire.versions[path] = 3;
    expect((await client.get(path))['version'], 3);
    hold.complete();
    await observation;
    expect(shown, [1]);
  });

  test('read-only POST routes keep unrelated snapshots warm', () async {
    const task = '/tasks/channel/main/number/3';
    const saved = '/channels/saved';
    await client.get(task);
    await client.get(saved);
    await client.post('/objects/summaries', data: {'refs': []});
    await client.post('/messages/m1/link-cards/read');
    await client.post(
      '/channels/saved/check',
      data: {
        'messageIds': ['m1'],
      },
    );
    await client.get(task);
    await client.get(saved);
    expect(wire.requests(task), 1);
    expect(wire.requests(saved), 1);
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
      wire.responses['/channels/private-receipts'] = {
        'peerReadStates': [
          {'peerId': 'fixture', 'maxReadSeq': 7},
        ],
      };
      wire.responses['/channels/private-summary'] = {
        'peerReadSummary': {'peerCount': 1},
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
