/// Bounded in-memory caches bound to the signed-in server identity.
///
/// Panel data (a channel's files, an agent's tabs, a task's history) is kept
/// after its surface closes so a revisit paints the previous result at its
/// first frame and refreshes in the background. The only things that empty a
/// cache are the identity it was filled under changing (account, origin,
/// server, role, authentication generation) or a caller revoking an entry.
/// Nothing here is persisted to disk.
class ServerBoundCache<K, V extends Object> {
  ServerBoundCache(this._identity, {this.limit = 64, this.onEvict});

  /// null while there is no usable signed-in server; nothing is retained then.
  final String? Function() _identity;
  final int limit;
  final void Function(V value)? onEvict;
  final Map<K, V> _entries = {};
  String? _bound;

  int get length => _entries.length;

  bool _synchronize() {
    final now = _identity();
    if (now == null) {
      clear();
      _bound = null;
      return false;
    }
    if (now != _bound) {
      clear();
      _bound = now;
    }
    return true;
  }

  /// The retained value, most recently used first; null on a miss or when the
  /// identity changed since it was stored.
  V? peek(K key) {
    if (!_synchronize()) return null;
    final value = _entries.remove(key);
    if (value != null) _entries[key] = value;
    return value;
  }

  /// Stores [value]; with no usable identity it is returned uncached.
  V put(K key, V value) {
    if (!_synchronize()) return value;
    final old = _entries.remove(key);
    if (old != null && !identical(old, value)) onEvict?.call(old);
    _entries[key] = value;
    while (_entries.length > limit) {
      final eldest = _entries.keys.first;
      final dropped = _entries.remove(eldest);
      if (dropped != null) onEvict?.call(dropped);
    }
    return value;
  }

  V putIfAbsent(K key, V Function() create) => peek(key) ?? put(key, create());

  void remove(K key) {
    final value = _entries.remove(key);
    if (value != null) onEvict?.call(value);
  }

  void removeWhere(bool Function(K key, V value) test) {
    for (final key in _entries.keys.toList()) {
      final value = _entries[key]!;
      if (test(key, value)) {
        _entries.remove(key);
        onEvict?.call(value);
      }
    }
  }

  void clear() {
    final values = _entries.values.toList();
    _entries.clear();
    for (final value in values) {
      onEvict?.call(value);
    }
  }
}

/// Last accepted history of one task, with the channel that authorized it.
class TaskHistorySnapshot {
  const TaskHistorySnapshot(this.channelId, this.events);
  final String channelId;
  final List<Map<String, dynamic>> events;
}
