import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/panel_caches.dart';

void main() {
  test('entries survive until the server identity changes, then drop at once', () {
    String? identity = 'alice|s1|owner';
    final evicted = <String>[];
    final cache = ServerBoundCache<String, String>(
      () => identity,
      onEvict: evicted.add,
    );
    cache.put('a', 'one');
    expect(cache.peek('a'), 'one');
    expect(cache.putIfAbsent('a', () => 'other'), 'one');
    // Channel switches, threads, tab changes never touch the identity.
    expect(cache.peek('a'), 'one');
    identity = 'alice|s1|member';
    expect(cache.peek('a'), isNull);
    expect(cache.length, 0);
    expect(evicted, ['one']);
    cache.put('a', 'two');
    identity = 'bob|s1|member';
    expect(cache.peek('a'), isNull);
  });

  test('nothing is retained while no signed-in server is selected', () {
    String? identity = 'alice|s1|owner';
    final cache = ServerBoundCache<String, String>(() => identity);
    cache.put('a', 'one');
    identity = null;
    expect(cache.peek('a'), isNull);
    expect(cache.put('b', 'two'), 'two');
    expect(cache.length, 0);
    identity = 'alice|s1|owner';
    expect(cache.peek('a'), isNull, reason: 'dropped, not parked');
    expect(cache.peek('b'), isNull);
  });

  test('bounded least recently used eviction and targeted revocation', () {
    final evicted = <String>[];
    final cache = ServerBoundCache<String, String>(
      () => 'id',
      limit: 2,
      onEvict: evicted.add,
    );
    cache.put('a', 'A');
    cache.put('b', 'B');
    expect(cache.peek('a'), 'A');
    cache.put('c', 'C');
    expect(cache.peek('b'), isNull);
    expect(evicted, ['B']);
    cache.removeWhere((key, value) => value == 'A');
    expect(cache.peek('a'), isNull);
    expect(cache.peek('c'), 'C');
    cache.remove('c');
    expect(cache.length, 0);
  });
}
