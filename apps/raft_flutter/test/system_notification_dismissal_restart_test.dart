import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/system_notification_store.dart';

/// A dismissed notification-bell notice stays dismissed across an app restart
/// (a new store on the same device storage), without hiding a different one,
/// and a stored list in a format the app cannot read never hides or blocks one.

class _Storage implements SearchMemoryStorage {
  final data = <String, String>{};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }
}

SystemNotificationContext _scope({String server = 's'}) =>
    SystemNotificationContext(
      scope: 'scope-$server',
      origin: 'https://public.invalid',
      principal: 'alice',
      server: {'id': server, 'role': 'owner'},
      channels: [],
      canViewMachines: true,
      canViewAgents: true,
      mobile: true,
    );

Map<String, dynamic> _machine(String id, {String status = 'offline'}) => {
  'id': id,
  'name': 'Box $id',
  'status': status,
  'isComputer': false,
};

SystemNotificationStore _store(
  _Storage storage,
  List<Map<String, dynamic>> machines,
) => SystemNotificationStore(
  storage: storage,
  get: (path, {query}) async {
    if (path.endsWith('/machines')) return {'machines': machines};
    if (path == '/agents') return [];
    return {'unread_total': 0};
  },
);

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('a dismissed notice is still dismissed after a restart', () async {
    final storage = _Storage();
    var store = _store(storage, [_machine('m1')]);
    await store.bind(_scope());
    await _settle();
    final shown = store.entries.single;
    expect(shown.id, 'machine-offline');
    expect(store.dismiss('scope-s', shown.fingerprint!), isTrue);
    expect(store.entries, isEmpty);
    await store.writes;
    store.dispose();

    // Restart: a new store reads the same device storage.
    store = _store(storage, [_machine('m1')]);
    await store.bind(_scope());
    await _settle();
    expect(store.entries, isEmpty);
    store.dispose();
  });

  test('a restart does not hide a different problem or another server', () async {
    final storage = _Storage();
    var store = _store(storage, [_machine('m1')]);
    await store.bind(_scope());
    await _settle();
    store.dismiss('scope-s', store.entries.single.fingerprint!);
    await store.writes;
    store.dispose();

    // Another computer goes offline: a different condition, shown.
    store = _store(storage, [_machine('m1'), _machine('m2')]);
    await store.bind(_scope());
    await _settle();
    expect(store.entries.map((e) => e.id), ['machine-offline']);
    expect(store.entries.single.title, contains('Box m2'));
    store.dispose();

    // The same problem on another server was never dismissed there.
    store = _store(storage, [_machine('m1')]);
    await store.bind(_scope(server: 'other'));
    await _settle();
    expect(store.entries.map((e) => e.id), ['machine-offline']);
    store.dispose();
  });

  test('a computer that is back online shows nothing, dismissed or not', () async {
    final storage = _Storage();
    final store = _store(storage, [_machine('m1', status: 'online')]);
    await store.bind(_scope());
    await _settle();
    expect(store.entries, isEmpty);
    store.dispose();
  });

  test('an unreadable stored list never hides or blocks a notice', () async {
    final key = _scope().storageKey!;
    for (final stored in [
      'not json',
      '{"dismissed":["machine-offline:m1"]}',
      '[1, null, {"a": 1}, ""]',
      jsonEncode(['x' * 5000]),
    ]) {
      final storage = _Storage()..data[key] = stored;
      final store = _store(storage, [_machine('m1')]);
      await store.bind(_scope());
      await _settle();
      expect(store.entries.map((e) => e.id), ['machine-offline'], reason: stored);
      // Dismissing still works and replaces the unreadable value.
      expect(store.dismiss('scope-s', store.entries.single.fingerprint!), isTrue);
      await store.writes;
      expect(jsonDecode(storage.data[key]!), [
        'machine-offline:m1',
      ], reason: stored);
      store.dispose();
    }
  });
}
