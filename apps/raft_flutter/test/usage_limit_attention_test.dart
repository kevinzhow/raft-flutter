import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/system_notification_store.dart';
import 'package:raft_flutter/data/usage_limit_attention.dart';

class _Storage implements SearchMemoryStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

Map<String, dynamic> incident(
  String id, {
  String provider = 'claude',
  String? seenAt,
  String? resetsAt = '2026-10-21T10:00:00.000Z',
  List<String> agents = const ['a1', 'a2'],
}) => {
  'id': id,
  'kind': 'usage_limit_reached',
  'severity': 'warning',
  'state': 'active',
  'activatedAt': '2026-10-21T08:00:00.000Z',
  'lastObservedAt': '2026-10-21T08:30:00.000Z',
  'seenAt': seenAt,
  'machine': {'id': 'm-$id', 'name': 'Box $id'},
  'provider': provider,
  'windowKey': 'five_hour',
  'resetsAt': resetsAt,
  'affectedAgentIds': agents,
};

Map<String, dynamic> snapshot(List<Map<String, dynamic>> rows) => {
  'contractVersion': serverSystemAttentionContract,
  'generatedAt': '2026-10-21T08:31:00.000Z',
  'snapshotMode': 'replace',
  'unseenCount': rows.where((r) => r['seenAt'] == null).length,
  'notifications': rows,
};

SystemNotificationContext scope(String name, {bool owner = true}) =>
    SystemNotificationContext(
      scope: name,
      origin: 'https://public.invalid',
      principal: 'alice',
      server: {'id': 's', 'role': owner ? 'owner' : 'member'},
      channels: [],
      canViewMachines: true,
      canViewAgents: true,
      mobile: false,
    );

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  group('parseUsageLimitSnapshot', () {
    test('reads the v1 contract and counts unseen incidents', () {
      final parsed = parseUsageLimitSnapshot(
        snapshot([
          incident('a', provider: 'codex'),
          incident('b', seenAt: '2026-10-21T08:40:00.000Z', resetsAt: null),
        ]),
      )!;
      expect(parsed.incidents.map((i) => i.id), ['a', 'b']);
      expect(parsed.unseenCount, 1);
      expect(parsed.incidents.first.provider, 'codex');
      expect(parsed.incidents.first.affectedAgents, 2);
      expect(parsed.incidents.first.machineName, 'Box a');
      expect(parsed.incidents.last.resetsAt, isNull);
      expect(parsed.incidents.last.seen, isTrue);
    });

    test('drops any other contract version or malformed envelope', () {
      for (final raw in [
        {
          ...snapshot([incident('a')]),
          'contractVersion': 'server-system-attention-v2',
        },
        {
          ...snapshot([incident('a')]),
        }..remove('contractVersion'),
        {
          ...snapshot([incident('a')]),
          'notifications': 'nope',
        },
        'text',
        null,
        <Object?>[],
      ]) {
        expect(parseUsageLimitSnapshot(raw), isNull);
      }
    });

    test('labels providers like Web: three named, everything else Grok', () {
      expect(usageLimitProviderName('claude'), 'Claude');
      expect(usageLimitProviderName('codex'), 'Codex');
      expect(usageLimitProviderName('kimi'), 'Kimi');
      expect(usageLimitProviderName('grok'), 'Grok');
      expect(usageLimitProviderName('gemini'), 'Grok');
      final notices = usageLimitNotices(
        parseUsageLimitSnapshot(snapshot([incident('f', provider: 'gemini')])),
      );
      expect(notices.single.title, 'Grok usage limit reached');
    });

    test('skips rows the client cannot present instead of inventing them', () {
      final parsed = parseUsageLimitSnapshot(
        snapshot([
          incident('ok'),
          {...incident('no-machine'), 'machine': null},
          {...incident('other-kind'), 'kind': 'something_else'},
          {...incident('no-id'), 'id': null},
          {...incident('no-provider'), 'provider': null},
        ]),
      )!;
      expect(parsed.incidents.map((i) => i.id), ['ok']);
    });

    test('an empty replace snapshot clears the feed', () {
      expect(parseUsageLimitSnapshot(snapshot([]))!.incidents, isEmpty);
    });
  });

  group('usageLimitNotices', () {
    test('builds warning entries that point at the Computer', () {
      final notices = usageLimitNotices(
        parseUsageLimitSnapshot(
          snapshot([
            incident('a'),
            incident('b', seenAt: '2026-10-21T09:00:00.000Z'),
          ]),
        ),
      );
      expect(notices.map((n) => n.id), ['usage-limit:a', 'usage-limit:b']);
      expect(notices.first.title, 'Claude usage limit reached');
      expect(notices.first.targetId, 'm-a');
      expect(notices.first.incidentId, 'a');
      expect(
        notices.first.fingerprint,
        isNull,
        reason: 'server-side dismissal',
      );
      expect(notices.map((n) => n.unread), [true, false]);
    });
  });

  group('SystemNotificationStore usage limits', () {
    SystemNotificationStore build({
      required Future<dynamic> Function(String path) get,
      Future<dynamic> Function(String path)? post,
      Future<bool> Function()? gate,
      DateTime Function()? clock,
    }) => SystemNotificationStore(
      storage: _Storage(),
      clock: clock,
      get: (path, {query}) async {
        if (path.contains('system-notifications-v2')) return get(path);
        if (path.endsWith('/machines')) return {'machines': []};
        if (path == '/agents') return [];
        return {'unread_total': 0};
      },
      post: post ?? (path) async => {'ok': true},
      usageLimitGate: gate ?? () async => true,
    );

    test('flag off: no read, no entries', () async {
      final calls = <String>[];
      final store = build(
        gate: () async => false,
        get: (path) async {
          calls.add(path);
          return snapshot([incident('a')]);
        },
      );
      await store.bind(scope('one'));
      await flush();
      await flush();
      expect(calls, isEmpty);
      expect(store.entries.where((n) => n.incidentId != null), isEmpty);
      store.dispose();
    });

    test(
      'flag on: reads the receiver snapshot and counts only unread',
      () async {
        final calls = <String>[];
        final store = build(
          get: (path) async {
            calls.add(path);
            return snapshot([
              incident('a'),
              incident('b', seenAt: '2026-10-21T09:00:00.000Z'),
            ]);
          },
        );
        await store.bind(scope('one'));
        await flush();
        await flush();
        expect(calls, ['/servers/s/system-notifications-v2']);
        expect(store.entries.map((n) => n.id).take(2), [
          'usage-limit:a',
          'usage-limit:b',
        ]);
        expect(store.unreadCount, 1);
        store.dispose();
      },
    );

    test('markUsageLimitsSeen posts one receipt per unread incident', () async {
      final posts = <String>[];
      final store = build(
        post: (path) async {
          posts.add(path);
          return {'ok': true};
        },
        get: (path) async => snapshot([
          incident('a'),
          incident('b', seenAt: '2026-10-21T09:00:00.000Z'),
          incident('c'),
        ]),
        clock: () => DateTime.utc(2026, 10, 21, 9, 30),
      );
      await store.bind(scope('one'));
      await flush();
      await flush();
      expect(store.unreadCount, 2);
      await store.markUsageLimitsSeen('one');
      expect(posts, [
        '/servers/s/system-notifications-v2/a/seen',
        '/servers/s/system-notifications-v2/c/seen',
      ]);
      expect(store.unreadCount, 0);
      expect(store.entries.map((n) => n.id).take(3), [
        'usage-limit:a',
        'usage-limit:b',
        'usage-limit:c',
      ], reason: 'seen entries stay listed');
      // Idempotent: a second opening sends nothing.
      await store.markUsageLimitsSeen('one');
      expect(posts, hasLength(2));
      store.dispose();
    });

    test(
      'a failed seen write leaves the incident unread for the next opening',
      () async {
        var fail = true;
        final posts = <String>[];
        final store = build(
          post: (path) async {
            posts.add(path);
            if (fail) throw StateError('offline');
            return {'ok': true};
          },
          get: (path) async => snapshot([incident('a')]),
        );
        await store.bind(scope('one'));
        await flush();
        await flush();
        await store.markUsageLimitsSeen('one');
        expect(store.unreadCount, 1);
        fail = false;
        await store.markUsageLimitsSeen('one');
        expect(store.unreadCount, 0);
        expect(posts, hasLength(2));
        store.dispose();
      },
    );

    test('dismiss posts the receipt and removes the entry', () async {
      final posts = <String>[];
      final store = build(
        post: (path) async {
          posts.add(path);
          return {'ok': true};
        },
        get: (path) async => snapshot([incident('a'), incident('b')]),
      );
      await store.bind(scope('one'));
      await flush();
      await flush();
      await store.dismissUsageLimit('one', 'a');
      expect(posts, ['/servers/s/system-notifications-v2/a/dismiss']);
      expect(
        store.entries.where((n) => n.incidentId != null).map((n) => n.id),
        ['usage-limit:b'],
      );
      store.dispose();
    });

    test('a failed dismiss keeps the entry', () async {
      final store = build(
        post: (path) async => throw StateError('500'),
        get: (path) async => snapshot([incident('a')]),
      );
      await store.bind(scope('one'));
      await flush();
      await flush();
      await store.dismissUsageLimit('one', 'a');
      expect(store.entries.where((n) => n.incidentId != null), hasLength(1));
      store.dispose();
    });

    test(
      'a receipt for another scope or unknown incident is never sent',
      () async {
        final posts = <String>[];
        final store = build(
          post: (path) async {
            posts.add(path);
            return {'ok': true};
          },
          get: (path) async => snapshot([incident('a')]),
        );
        await store.bind(scope('one'));
        await flush();
        await flush();
        await store.dismissUsageLimit('stale-scope', 'a');
        await store.dismissUsageLimit('one', 'not-listed');
        await store.markUsageLimitSeen('one', 'not-listed');
        expect(posts, isEmpty);
        store.dispose();
      },
    );

    test('a read failure clears the feed; a wrong contract keeps it', () async {
      var mode = 'ok';
      final store = build(
        get: (path) async {
          if (mode == 'throw') throw StateError('down');
          if (mode == 'contract') {
            return {...snapshot([]), 'contractVersion': 'other'};
          }
          return snapshot([incident('a')]);
        },
      );
      await store.bind(scope('one'));
      await flush();
      await flush();
      expect(store.unreadCount, 1);
      mode = 'contract';
      await store.refreshUsageLimit();
      expect(store.unreadCount, 1, reason: 'unknown contract is ignored');
      mode = 'throw';
      await store.refreshUsageLimit();
      expect(store.unreadCount, 0, reason: 'fail closed');
      mode = 'ok';
      await store.refreshUsageLimit();
      expect(store.unreadCount, 1);
      store.dispose();
    });

    test('a replace snapshot drops incidents the server resolved', () async {
      var rows = [incident('a'), incident('b')];
      final store = build(get: (path) async => snapshot(rows));
      await store.bind(scope('one'));
      await flush();
      await flush();
      rows = [incident('b')];
      await store.refreshUsageLimit();
      expect(
        store.entries.where((n) => n.incidentId != null).map((n) => n.id),
        ['usage-limit:b'],
      );
      store.dispose();
    });

    test(
      'an unresolved flag stays off and is evaluated again on the next read',
      () async {
        var evaluations = 0;
        final store = build(
          gate: () async {
            if (++evaluations == 1) throw StateError('flags down');
            return true;
          },
          get: (path) async => snapshot([incident('a')]),
        );
        await store.bind(scope('one'));
        await flush();
        await flush();
        expect(store.unreadCount, 0);
        await store.refreshUsageLimit();
        expect(store.unreadCount, 1);
        await store.refreshUsageLimit();
        expect(evaluations, 2, reason: 'a resolved flag is not re-evaluated');
        store.dispose();
      },
    );

    test('a read that finishes after a scope change is discarded', () async {
      final late = Completer<dynamic>();
      var first = true;
      final store = build(
        get: (path) {
          if (first) {
            first = false;
            return late.future;
          }
          return Future.value(snapshot([]));
        },
      );
      await store.bind(scope('one'));
      await flush();
      await store.bind(scope('two'));
      await flush();
      await flush();
      late.complete(snapshot([incident('old')]));
      await flush();
      await flush();
      expect(store.entries.where((n) => n.incidentId != null), isEmpty);
      store.dispose();
    });

    test('without a gate and post the feed stays off', () async {
      final calls = <String>[];
      final store = SystemNotificationStore(
        storage: _Storage(),
        get: (path, {query}) async {
          calls.add(path);
          return path.endsWith('/machines') ? {'machines': []} : [];
        },
      );
      await store.bind(scope('one'));
      await flush();
      await store.refreshUsageLimit();
      expect(
        calls.where((p) => p.contains('system-notifications-v2')),
        isEmpty,
      );
      store.dispose();
    });
  });
}
