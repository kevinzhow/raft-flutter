import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/features/resource_search.dart';
import 'package:raft_flutter/features/search_home.dart';

class _Storage implements SearchMemoryStorage {
  final values = <String, String>{};
  Completer<String?>? pending;
  bool denied = false;
  @override
  Future<String?> read(String key) async {
    if (denied) throw StateError('Denied');
    return pending?.future ?? values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (denied) throw StateError('Denied');
    values[key] = value;
  }
}

void main() {
  final now = DateTime.utc(2026, 10, 8);
  const scope = SearchMemoryScope('https://one.invalid', 's', 'u');
  test(
    'history trims, bounds, deduplicates case and rejects corrupt storage',
    () {
      final history = normalizeSearchHistory([
        '  Android ',
        'android',
        42,
        '',
        'x' * 210,
        ...List.generate(20, (i) => '$i'),
      ]);
      expect(history.first, 'Android');
      expect(history[1].length, 200);
      expect(history.length, 15);
      expect(SearchMemoryData.decode('{invalid', now).history, isEmpty);
      final snapshot = SearchStateSnapshot.fromJson({
        'senderKey': 'label:private name',
        'scopes': ['agents', 'invalid', 'agents'],
        'range': 'forever',
        'sort': 'recent',
      });
      expect(snapshot.senderKey, isNull);
      expect(snapshot.scopes, ['agents']);
      expect(snapshot.range, 'any');
      expect(snapshot.sort, 'recent');
    },
  );
  test(
    'usage expires, deduplicates and bounds future events/keys without labels',
    () {
      final stamp = now.millisecondsSinceEpoch;
      final normalized = normalizeSearchUsage({
        'channel:c': [
          stamp,
          stamp,
          now.subtract(const Duration(days: 91)).millisecondsSinceEpoch,
          stamp + const Duration(minutes: 6).inMilliseconds,
          double.nan,
        ],
        'computer:pc': [stamp],
        'cached-private-title': {'title': 'Private label'},
        for (var i = 0; i < 70; i++)
          'agent:a$i': List.generate(30, (j) => stamp - 1 - j),
      }, now);
      expect(normalized.length, 64);
      expect(normalized['channel:c'], isNotNull);
      expect(normalized.containsKey('computer:pc'), isFalse);
      expect(normalized.values.every((v) => v.length <= 24), isTrue);
      expect(
        searchUsageScore([
          now.subtract(const Duration(days: 7)).millisecondsSinceEpoch,
        ], now),
        closeTo(.5, .000001),
      );
    },
  );
  test('late storage read cannot overwrite newer local state; scopes stay isolated', () async {
    final storage = _Storage()..pending = Completer<String?>();
    final store = SearchMemoryStore(storage: storage, clock: () => now);
    final load = store.load(scope);
    store.rememberQuery(scope, 'Fresh query');
    storage.pending!.complete(
      jsonEncode({
        'history': ['Stale query'],
      }),
    );
    expect((await load).history, ['Fresh query']);
    store.saveState(
      scope,
      const SearchStateSnapshot(query: 'Fresh query', channelId: 'c'),
    );
    store.recordOpen(scope, 'channel:c');
    expect((await store.load(scope)).state.query, 'Fresh query');
    await store.flush();
    expect(
      store
          .current(const SearchMemoryScope('https://one.invalid', 's', 'other'))
          .history,
      isEmpty,
    );
    expect(
      store
          .current(const SearchMemoryScope('https://two.invalid', 's', 'u'))
          .history,
      isEmpty,
    );
    expect(
      store
          .current(const SearchMemoryScope('https://one.invalid', 'other', 'u'))
          .usage,
      isEmpty,
    );
    expect(storage.values[scope.key], isNot(contains('Stale query')));
    expect(storage.values[scope.key], contains('channel:c'));
  });
  test(
    'optional denied storage preserves in-memory navigation convenience',
    () async {
      final store = SearchMemoryStore(
        storage: _Storage()..denied = true,
        clock: () => now,
      );
      await store.load(scope);
      store.rememberQuery(scope, 'First');
      store.rememberQuery(scope, 'first');
      store.rememberQuery(scope, 'Second');
      store.removeQuery(scope, 'FIRST');
      await store.flush();
      expect(store.current(scope).history, ['Second']);
      store.clearHistory(scope);
      expect(store.current(scope).history, isEmpty);
    },
  );
  test('frequent rows resolve only fresh permitted catalog and exclude hidden/self/archive/computer', () {
    final stamp = now.millisecondsSinceEpoch;
    const visible = SearchEntity(
      'channel',
      'visible',
      'Current name',
      'Channel',
      {},
    );
    const archived = SearchEntity('channel', 'archive', 'Archived', 'Channel', {
      'archivedAt': '2026-01-01',
    });
    const self = SearchEntity('user', 'u', 'Self', '', {});
    const hidden = SearchEntity('agent', 'a', 'Hidden', '', {});
    const computer = SearchEntity('computer', 'pc', 'Computer', '', {});
    final usage = {
      for (final key in [
        'channel:visible',
        'channel:removed',
        'channel:archive',
        'human:u',
        'agent:a',
        'computer:pc',
      ])
        key: [stamp],
    };
    List<SearchEntity> choose(List<SearchEntity> catalog) =>
        frequentSearchEntities(
          catalog: catalog,
          usage: usage,
          principal: 'u',
          now: now,
          hiddenDmIds: {'dm'},
          dms: [
            {'id': 'dm', 'peerId': 'a', 'peerType': 'agent'},
          ],
        );
    expect(
      choose([visible, archived, self, hidden, computer]).map((e) => e.title),
      ['Current name'],
    );
    expect(choose([]), isEmpty);
    expect(
      usage.keys,
      contains('channel:removed'),
    ); // IDs retained, private payload absent.
  });
}
