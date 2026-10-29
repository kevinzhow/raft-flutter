import 'dart:collection';

/// A map that forgets its least recently used entry once it holds more than
/// [maxEntries]. Reading or writing a key makes it the most recent. Values must
/// not be null (a miss is `null`).
class BoundedLruMap<K, V extends Object> extends MapBase<K, V> {
  BoundedLruMap(this.maxEntries) {
    if (maxEntries < 1) throw ArgumentError('maxEntries must be positive.');
  }

  final int maxEntries;
  final _entries = <K, V>{};

  @override
  V? operator [](Object? key) {
    final value = _entries.remove(key);
    if (value == null) return null;
    _entries[key as K] = value;
    return value;
  }

  @override
  void operator []=(K key, V value) {
    _entries.remove(key);
    _entries[key] = value;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  @override
  void clear() => _entries.clear();

  @override
  Iterable<K> get keys => _entries.keys;

  @override
  V? remove(Object? key) => _entries.remove(key);

  @override
  bool containsKey(Object? key) => _entries.containsKey(key);

  @override
  int get length => _entries.length;
}

/// A set that forgets its least recently added element once it holds more than
/// [maxEntries]; adding an element again makes it the most recent.
class BoundedLruSet<E> extends SetBase<E> {
  BoundedLruSet(this.maxEntries) {
    if (maxEntries < 1) throw ArgumentError('maxEntries must be positive.');
  }

  final int maxEntries;
  final _entries = <E>{};

  @override
  bool add(E value) {
    final fresh = !_entries.remove(value);
    _entries.add(value);
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.first);
    }
    return fresh;
  }

  @override
  bool contains(Object? element) => _entries.contains(element);

  @override
  Iterator<E> get iterator => _entries.iterator;

  @override
  int get length => _entries.length;

  @override
  E? lookup(Object? element) => _entries.lookup(element);

  @override
  bool remove(Object? value) => _entries.remove(value);

  @override
  Set<E> toSet() => _entries.toSet();

  @override
  void clear() => _entries.clear();
}
