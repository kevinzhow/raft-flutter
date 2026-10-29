/// "Was this read recently enough?" for refreshes started by returning to the
/// foreground (alt-tab on a desktop does it many times a minute) rather than
/// by the person asking. [due] answers once per [window] and records the read.
class Freshness {
  Freshness(this.window, {DateTime Function()? now}) : _now = now ?? DateTime.now;
  final Duration window;
  final DateTime Function() _now;
  DateTime? _at;

  /// True when the last read is older than [window] (or there is none); that
  /// read is then counted as started now.
  bool due() {
    final now = _now();
    final last = _at;
    if (last != null && now.difference(last) < window) return false;
    _at = now;
    return true;
  }

  /// Something else just read the same data: count it as fresh.
  void touch() => _at = _now();

  void reset() => _at = null;
}
