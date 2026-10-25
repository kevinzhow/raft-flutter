import 'dart:collection';

import 'package:flutter/foundation.dart';

/// A small bounded least-recently-used memo for pure, content-keyed results
/// (highlighted code spans, parsed Markdown). Keys must carry every input
/// that changes the result; values must be immutable or treated as such.
class RaftLruCache<K, V> {
  RaftLruCache(this.capacity) : assert(capacity > 0);
  final int capacity;
  final _entries = LinkedHashMap<K, V>();

  /// Lookup statistics, exposed so tests can prove a result was reused.
  @visibleForTesting
  int hits = 0, misses = 0;

  int get length => _entries.length;

  V putIfAbsent(K key, V Function() compute) {
    if (_entries.containsKey(key)) {
      hits++;
      // Re-insert to mark the entry most recently used.
      final existing = _entries.remove(key) as V;
      _entries[key] = existing;
      return existing;
    }
    misses++;
    final value = compute();
    _entries[key] = value;
    if (_entries.length > capacity) _entries.remove(_entries.keys.first);
    return value;
  }

  void clear() {
    _entries.clear();
    hits = misses = 0;
  }
}
