import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/system_notification_store.dart';

class _Storage implements SearchMemoryStorage {
  final data = <String, String>{};
  final pending = <String, Completer<String?>>{};
  @override
  Future<String?> read(String key) async => pending[key]?.future ?? data[key];
  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }
}

SystemNotificationContext scope(
  String name, {
  String user = 'alice',
  bool allowed = true,
  bool server = true,
}) => SystemNotificationContext(
  scope: name,
  origin: 'https://public.invalid',
  principal: user,
  server: server ? {'id': 's', 'role': allowed ? 'owner' : 'member'} : null,
  channels: [],
  canViewMachines: allowed,
  canViewAgents: allowed,
  mobile: true,
);
Future<void> flush() async {
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('mounted machines envelope projects sanitized rows, no secret payload retained', () async {
    final storage = _Storage(), calls = <String>[];
    final store = SystemNotificationStore(
      storage: storage,
      get: (path, {query}) async {
        calls.add(path);
        if (path.endsWith('/machines')) {
          return {
            'machines': [
              {
                'id': 'm',
                'name': 'Local',
                'status': 'offline',
                'isComputer': true,
                'credential': 'never-cache',
                'computerBroadcastPolicy': {
                  'policyRevision': 4,
                  'targetVersion': '1.0.44',
                  'secret': 'never-cache',
                },
              },
            ],
          };
        }
        if (path == '/agents') {
          return [
            {
              'id': 'a',
              'status': 'active',
              'machineId': 'm',
              'apiKey': 'never-cache',
            },
          ];
        }
        expect(query, {'limit': 1});
        return {'unread_total': 2};
      },
    );
    await store.bind(scope('owner'));
    await flush();
    expect(calls, [
      '/servers/s/machines',
      '/agents',
      '/product-feedback/tickets',
    ]);
    expect(store.entries.map((n) => n.id), [
      'computer-attention',
      'feedback-replies',
    ]);
    expect(
      jsonEncode([store.machines, store.agents]),
      isNot(contains('never-cache')),
    );
    expect(store.dismiss('owner', store.entries.first.fingerprint!), isTrue);
    await store.writes;
    expect(jsonDecode(storage.data.values.single), [store.dismissed.single]);
    expect(storage.data.values.single, isNot(contains('Local')));
    store.dispose();
  });
  test('same-principal role reduction clears private rows before late HTTP completes', () async {
    final pending = Completer<dynamic>();
    final store = SystemNotificationStore(
      storage: _Storage(),
      get: (path, {query}) async {
        if (path.endsWith('/machines')) return pending.future;
        if (path == '/agents') return [];
        return {'unread_total': 0};
      },
    );
    await store.bind(scope('owner'));
    await store.bind(scope('member', allowed: false));
    await flush();
    expect(store.machines, isEmpty);
    expect(store.entries, isEmpty);
    pending.complete({
      'machines': [
        {
          'id': 'private',
          'name': 'Private',
          'status': 'offline',
          'isComputer': true,
        },
      ],
    });
    await flush();
    expect(store.machines, isEmpty);
    expect(store.entries, isEmpty);
    expect(store.loading, isFalse);
    store.dispose();
  });
  test(
    'accepted detail count beats already-pending unread list response',
    () async {
      var defer = false;
      final old = Completer<dynamic>();
      final store = SystemNotificationStore(
        storage: _Storage(),
        get: (path, {query}) async {
          if (path.endsWith('/machines')) return {'machines': []};
          if (path == '/agents') return [];
          return defer ? old.future : {'unread_total': 3};
        },
      );
      await store.bind(scope('owner'));
      await flush();
      expect(store.feedbackUnread, 3);
      defer = true;
      final pending = store.refresh();
      expect(store.reconcileFeedback('owner', 0), isTrue);
      old.complete({'unread_total': 3});
      await pending;
      expect(store.feedbackUnread, 0);
      expect(store.entries, isEmpty);
      expect(store.reconcileFeedback('old', 8), isFalse);
      store.dispose();
    },
  );
  test(
    'late dismissal storage cannot undo local choice and logout is immediate',
    () async {
      final storage = _Storage();
      final store = SystemNotificationStore(
        storage: storage,
        get: (path, {query}) async {
          if (path.endsWith('/machines')) {
            return {
              'machines': [
                {
                  'id': 'm',
                  'name': 'Local',
                  'status': 'offline',
                  'isComputer': true,
                },
              ],
            };
          }
          if (path == '/agents') return [];
          return {'unread_total': 0};
        },
      );
      await store.bind(scope('first'));
      await flush();
      final old = Completer<String?>();
      storage.pending[store.context!.storageKey!] = old;
      final bind = store.bind(scope('changed'));
      await flush();
      final fingerprint = store.entries.single.fingerprint!;
      expect(store.dismiss('changed', fingerprint), isTrue);
      old.complete('[]');
      await bind;
      expect(store.entries, isEmpty);
      expect(store.dismissed, {fingerprint});
      await store.bind(scope('logout', user: '', server: false));
      expect(store.loading, isFalse);
      expect(store.machines, isEmpty);
      expect(store.dismissed, isEmpty);
      expect(store.dismiss('changed', fingerprint), isFalse);
      await store.writes;
      store.dispose();
    },
  );
  test(
    'malformed machines fail closed rather than silently granting readiness',
    () async {
      final store = SystemNotificationStore(
        storage: _Storage(),
        get: (path, {query}) async => path.endsWith('/machines')
            ? {
                'machines': [null],
              }
            : path == '/agents'
            ? []
            : {'unread_total': 0},
      );
      await store.bind(scope('owner'));
      await flush();
      expect(store.machineReady, isFalse);
      expect(store.failed, isTrue);
      expect(store.entries, isEmpty);
      store.dispose();
    },
  );
  test('transient feedback outage retains accepted unread count instead of claiming read', () async {
    var unavailable = false;
    final store = SystemNotificationStore(
      storage: _Storage(),
      get: (path, {query}) async {
        if (path.endsWith('/machines')) return {'machines': []};
        if (path == '/agents') return [];
        if (unavailable) throw StateError('Unavailable fixture');
        return {'unread_total': 2};
      },
    );
    await store.bind(scope('owner'));
    await flush();
    expect(store.feedbackUnread, 2);
    unavailable = true;
    await store.refresh();
    expect(store.failed, isTrue);
    expect(store.feedbackUnread, 2);
    expect(store.entries.single.id, 'feedback-replies');
    store.dispose();
  });
  test(
    'invalid feedback receipts preserve count; only valid zero clears it',
    () async {
      dynamic count = 5;
      final store = SystemNotificationStore(
        storage: _Storage(),
        get: (path, {query}) async {
          if (path.endsWith('/machines')) return {'machines': []};
          if (path == '/agents') return [];
          return {'unread_total': count};
        },
      );
      await store.bind(scope('owner'));
      await flush();
      for (final invalid in [null, -1, 1.5, 9007199254740992]) {
        count = invalid;
        await store.refresh();
        expect(store.feedbackUnread, 5);
        expect(store.failed, isTrue);
      }
      expect(store.reconcileFeedback('owner', 9007199254740992), isFalse);
      count = 0;
      await store.refresh();
      expect(store.feedbackUnread, 0);
      expect(store.failed, isFalse);
      store.dispose();
    },
  );
}
