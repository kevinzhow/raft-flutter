import 'dart:async';
import 'dart:collection';

/// Local reads and each reason for a wire read are counted separately.
enum HistoryReadReason {
  local,
  missing,
  evicted,
  incremental,
  tail,
  gap,
  aged,
  manual,
  reconnect,
  failed,
}

typedef HistoryReadKey = (
  String,
  String,
  String,
  String,
  String,
  String,
  String,
);

/// Coalesces identical wire reads and permits one stale-range check per
/// foreground visit. A verification date never expires a saved message.
class HistoryReadPolicy {
  HistoryReadPolicy({DateTime Function()? now}) : now = now ?? DateTime.now;
  final DateTime Function() now;
  static const refreshAge = Duration(hours: 24);
  final _counts = <HistoryReadReason, int>{};
  final _flights = <HistoryReadKey, Future<Map<String, dynamic>>>{};
  final _visits = <Object, (int, Set<HistoryReadKey>)>{};
  final _work = <Future<void>>{};
  bool closed = false;

  Map<HistoryReadReason, int> get counts => UnmodifiableMapView(_counts);
  void count(HistoryReadReason reason) =>
      _counts.update(reason, (n) => n + 1, ifAbsent: () => 1);

  bool claim(
    Object owner,
    int visit,
    HistoryReadKey key,
    DateTime? verified, {
    bool force = false,
  }) {
    if (closed) return false;
    final age = verified == null ? null : now().difference(verified);
    if (!force && age != null && !age.isNegative && age < refreshAge) {
      return false;
    }
    var held = _visits[owner];
    if (held == null || held.$1 != visit) {
      held = (visit, <HistoryReadKey>{});
      _visits[owner] = held;
    }
    return force || held.$2.add(key);
  }

  Future<Map<String, dynamic>> fetch(
    HistoryReadKey key,
    HistoryReadReason reason,
    Future<Map<String, dynamic>> Function() read,
  ) {
    if (closed) return Future.error(StateError('History store is closed.'));
    final held = _flights[key];
    if (held != null) return held;
    count(reason);
    late final Future<Map<String, dynamic>> result;
    result = Future<Map<String, dynamic>>.sync(read).whenComplete(() {
      if (identical(_flights[key], result)) _flights.remove(key);
    });
    _flights[key] = result;
    return result;
  }

  void background(Future<void> Function() action) {
    if (closed) return;
    late final Future<void> result;
    result = Future<void>.sync(action)
        .catchError((Object _, StackTrace _) {
          count(HistoryReadReason.failed);
        })
        .whenComplete(() => _work.remove(result));
    _work.add(result);
  }

  Future<void> get settled async {
    while (_work.isNotEmpty) {
      await Future.wait(_work.toList());
    }
  }

  void forget(Object owner) => _visits.remove(owner);
  void forgetAccount(String origin, String principal) {
    for (final held in _visits.values) {
      held.$2.removeWhere((key) => key.$1 == origin && key.$2 == principal);
    }
    _flights.removeWhere((key, _) => key.$1 == origin && key.$2 == principal);
  }

  void close() {
    closed = true;
    _flights.clear();
    _visits.clear();
  }
}
