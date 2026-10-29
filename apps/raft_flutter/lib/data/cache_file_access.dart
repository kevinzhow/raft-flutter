import 'dart:async';

/// Tracks only active file lookups. Reads of unrelated entries never join the
/// mutation queue; deletion drains the handles for the paths it removes.
class CacheFileAccess {
  final _active = <String, Set<CacheFileLookup>>{};
  final _writing = <String>{};

  CacheFileLookup? begin(String path) {
    if (_writing.contains(path)) return null;
    late final CacheFileLookup lookup;
    lookup = CacheFileLookup._(() {
      final active = _active[path]!;
      active.remove(lookup);
      if (active.isEmpty) _active.remove(path);
    });
    (_active[path] ??= {}).add(lookup);
    return lookup;
  }

  /// Called inside the mutation queue. An atomic replacement must not race
  /// an existing reader's Windows handle or timestamp update.
  Future<T> write<T>(String path, Future<T> Function() task) async {
    _writing.add(path);
    try {
      await Future.wait([
        for (final lookup in _active[path]?.toList() ?? <CacheFileLookup>[])
          lookup._done.future,
      ]);
      return await task();
    } finally {
      _writing.remove(path);
    }
  }

  /// The caller first removes these paths from its index. Invalidation is
  /// synchronous: a late lookup cannot return or restore revoked content.
  Future<void> invalidateWhere(bool Function(String) matches) {
    final pending = <Future<void>>[];
    for (final entry in _active.entries) {
      if (!matches(entry.key)) continue;
      for (final lookup in entry.value) {
        lookup.valid = false;
        pending.add(lookup._done.future);
      }
    }
    return Future.wait(pending);
  }
}

class CacheFileLookup {
  CacheFileLookup._(this._release);
  final void Function() _release;
  final _done = Completer<void>();
  bool valid = true;

  void release() {
    _release();
    _done.complete();
  }
}
