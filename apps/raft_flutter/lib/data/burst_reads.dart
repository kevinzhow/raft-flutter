/// Bookkeeping for server reads started by events and by returning to the
/// foreground (not by the person asking): when each was last made, and whether
/// a server-directory read is already on its way.
class BurstReads {
  final Map<String, DateTime> _at = {};
  int _directoryReads = 0;

  /// True when the read called [name] is older than [freshness] (or none was
  /// made); that read is then counted as started now.
  bool due(String name, Duration freshness) {
    final now = DateTime.now();
    final last = _at[name];
    if (last != null && now.difference(last) < freshness) return false;
    _at[name] = now;
    return true;
  }

  void clear() => _at.clear();

  /// A directory read (the boot load or its revalidation) is in flight. It
  /// delivers the directory itself, so a refresh that merely repeats it must
  /// not start another read: a new read would retire this one.
  bool get directoryReading => _directoryReads > 0;

  /// Runs [read] as a directory read, however it ends.
  Future<T> directoryRead<T>(Future<T> Function() read) async {
    _directoryReads++;
    try {
      return await read();
    } finally {
      _directoryReads--;
    }
  }
}
