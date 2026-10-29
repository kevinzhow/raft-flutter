import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/system_notification_store.dart';

class _Memory implements SearchMemoryStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

SystemNotificationContext _context({
  String scope = 'owner',
  Map<String, dynamic>? server,
}) => SystemNotificationContext(
  scope: scope,
  origin: 'https://example.invalid',
  principal: 'alice',
  server: server ?? {'id': 'server', 'role': 'owner', 'plan': 'pro'},
  channels: const [],
  canViewMachines: true,
  canViewAgents: true,
  mobile: false,
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  for (final shared in [false, true]) {
    test('unchanged refresh and rebind do not publish ($shared)', () async {
      final store = SystemNotificationStore(
        storage: _Memory(),
        entities: shared
            ? () => const SystemNotificationEntities(
                machines: [],
                agents: [],
                ready: true,
              )
            : null,
        get: (path, {query}) async =>
            path == '/product-feedback/tickets' ? {'unread_total': 0} : [],
      );
      addTearDown(store.dispose);
      await store.bind(_context());
      await _settle();
      var published = 0;
      store.addListener(() => ++published);
      await store.refresh();
      await store.bind(_context());
      expect(store.reconcileFeedback('owner', 0), isTrue);
      expect(published, 0);
    });
  }

  test(
    'changed feedback copy publishes even when notice count is equal',
    () async {
      var unread = 1;
      final store = SystemNotificationStore(
        storage: _Memory(),
        get: (path, {query}) async =>
            path == '/product-feedback/tickets' ? {'unread_total': unread} : [],
      );
      addTearDown(store.dispose);
      await store.bind(_context());
      await _settle();
      var published = 0;
      store.addListener(() => ++published);
      await store.refresh();
      expect(published, 0);
      unread = 2;
      await store.refresh();
      expect(published, 1);
      expect(store.entries.single.parameters['count'], 2);
      expect(store.entries.single.body, contains('2 feedback'));
      expect(store.reconcileFeedback('owner', 2), isTrue);
      expect(published, 1);
      expect(store.reconcileFeedback('owner', 0), isTrue);
      expect(published, 2);
      expect(store.entries, isEmpty);
    },
  );

  test(
    'shared machine copy and destination stay current without duplicate reads',
    () async {
      var machines = <Map<String, dynamic>>[
        {'id': 'm1', 'name': 'First', 'status': 'offline'},
      ];
      final store = SystemNotificationStore(
        storage: _Memory(),
        entities: () => SystemNotificationEntities(
          machines: machines,
          agents: const [],
          ready: true,
        ),
        get: (_, {query}) async => {'unread_total': 0},
      );
      addTearDown(store.dispose);
      await store.bind(_context());
      await _settle();
      var published = 0;
      store.addListener(() => ++published);
      machines = [Map.of(machines.single)];
      await store.bind(_context());
      expect(published, 0);
      machines.single['name'] = 'Renamed';
      await store.bind(_context());
      expect(published, 1);
      expect(store.entries.single.title, 'Renamed is offline');
      machines = [
        {'id': 'm2', 'name': 'Renamed', 'status': 'offline'},
      ];
      await store.bind(_context());
      expect(published, 2);
      expect(store.entries.single.targetId, 'm2');
    },
  );

  test('authority change publishes even with two empty projections', () async {
    final store = SystemNotificationStore(
      storage: _Memory(),
      get: (path, {query}) async =>
          path == '/product-feedback/tickets' ? {'unread_total': 0} : [],
    );
    addTearDown(store.dispose);
    await store.bind(_context());
    await _settle();
    var published = 0;
    store.addListener(() => ++published);
    await store.bind(_context(scope: 'new authority'));
    await _settle();
    expect(published, 1);
    expect(store.entries, isEmpty);
  });

  test(
    'deadline crossing updates the same notification without new server data',
    () async {
      var now = DateTime.utc(2026, 10, 17, 12);
      final server = {
        'id': 'server',
        'role': 'owner',
        'plan': 'free',
        'planDowngradedAt': '2026-10-11T00:00:00Z',
      };
      final store = SystemNotificationStore(
        storage: _Memory(),
        clock: () => now,
        get: (path, {query}) async =>
            path == '/product-feedback/tickets' ? {'unread_total': 0} : [],
      );
      addTearDown(store.dispose);
      await store.bind(_context(server: server));
      await _settle();
      var published = 0;
      store.addListener(() => ++published);
      await store.refresh();
      expect(published, 0);
      now = DateTime.utc(2026, 10, 18);
      await store.refresh();
      expect(published, 1);
      expect(store.entries.single.parameters['expired'], isTrue);
    },
  );
}
