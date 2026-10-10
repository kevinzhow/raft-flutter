import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/sidebar_disclosure.dart';

class _SyncStorage extends _Storage implements SynchronousSearchMemoryStorage {
  @override
  bool ready = true;
  @override
  String? readSync(String key) => values[key];
}

class _Storage implements SearchMemoryStorage {
  final values = <String, String>{};
  final pending = <String, Completer<String?>>{};
  @override
  Future<String?> read(String key) async => pending[key]?.future ?? values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  test('preloaded storage answers in the same call, before any await', () {
    final storage = _SyncStorage()
      ..values['raft:sidebar-disclosure:["https://fixture.invalid","alice","s"]'] =
          '{"system:channels":true}';
    final store = SidebarDisclosureStore(storage: storage);
    var notified = 0;
    store.addListener(() => notified++);
    unawaited(
      store.bind(
        origin: 'https://fixture.invalid',
        principal: 'alice',
        server: 's',
        scope: 'a',
      ),
    );
    expect(store.collapsed, {'system:channels': true});
    expect(notified, greaterThan(0));
    store.dispose();
  });

  test(
    'disclosure persists booleans and isolates account, origin and workspace',
    () async {
      final storage = _Storage();
      final store = SidebarDisclosureStore(storage: storage);
      Future<void> bind(
        String origin,
        String user,
        String server,
        String scope,
      ) => store.bind(
        origin: origin,
        principal: user,
        server: server,
        scope: scope,
      );
      await bind('https://fixture.invalid', 'alice', 'first', 'a');
      final first = store.key!;
      expect(store.setExpanded('a', 'system:channels', false), isTrue);
      await store.writes;
      expect(jsonDecode(storage.values[first]!), {'system:channels': true});
      for (final scope in [
        ['https://fixture.invalid', 'bob', 'first'],
        ['https://other.invalid', 'alice', 'first'],
        ['https://fixture.invalid', 'alice', 'second'],
      ]) {
        await bind(scope[0], scope[1], scope[2], 'other');
        expect(store.collapsed, isEmpty);
        expect(store.setExpanded('a', 'system:channels', false), isFalse);
      }
      await bind('https://fixture.invalid', 'alice', 'first', 'returned');
      expect(store.collapsed['system:channels'], isTrue);
      store.dispose();
    },
  );

  test(
    'pending old role/account read cannot overwrite current local choice',
    () async {
      final storage = _Storage();
      final store = SidebarDisclosureStore(storage: storage);
      await store.bind(
        origin: 'https://fixture.invalid',
        principal: 'alice',
        server: 's',
        scope: 'owner',
      );
      final pending = Completer<String?>();
      storage.pending[store.key!] = pending;
      final late = store.bind(
        origin: 'https://fixture.invalid',
        principal: 'alice',
        server: 's',
        scope: 'member',
      );
      expect(store.collapsed, isEmpty);
      expect(store.setExpanded('owner', 'private', false), isFalse);
      expect(store.setExpanded('member', 'system:channels', false), isTrue);
      pending.complete('{"private":true,"system:channels":false}');
      await late;
      expect(store.collapsed, {'system:channels': true});
      await store.writes;
      store.dispose();
    },
  );

  test(
    'logout clears immediately and discards a late workspace read',
    () async {
      final storage = _Storage();
      final store = SidebarDisclosureStore(storage: storage);
      await store.bind(
        origin: 'fixture',
        principal: 'alice',
        server: 's',
        scope: 'first',
      );
      final pending = Completer<String?>();
      storage.pending[store.key!] = pending;
      final late = store.bind(
        origin: 'fixture',
        principal: 'alice',
        server: 's',
        scope: 'changed',
      );
      await store.bind(
        origin: 'fixture',
        principal: null,
        server: null,
        scope: 'logout',
      );
      pending.complete('{"private":true}');
      await late;
      expect(store.collapsed, isEmpty);
      expect(store.setExpanded('logout', 'private', false), isFalse);
      store.dispose();
    },
  );
}
