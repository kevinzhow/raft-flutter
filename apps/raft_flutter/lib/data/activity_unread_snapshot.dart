// Source: packages/web/src/store/activityUnreadSnapshot.ts and
// packages/web/src/components/thread/activityVisit.ts at v1.24.0.
import 'package:flutter/foundation.dart';

import 'resource_row_reconcile.dart';

/// Under an Unread filter Activity's list only grows: every row it has shown
/// that was then read stays where it was, shown read, until the list changes
/// (server, filter, scope), the visit ends ([ActivityVisit]) or it reloads.
/// Read is a signal ([ActivityUnreadSnapshotStore.noteRead]), not an absence:
/// a row the store stops listing for another reason (Done elsewhere, access
/// lost, a shorter window) leaves. Display only: rows and totals stay the
/// server's. Pure Dart; the Activity list holds one store per workspace.
class ActivityUnreadSnapshot {
  const ActivityUnreadSnapshot({
    required this.list,
    required this.visit,
    required this.rows,
    required this.kept,
    required this.read,
  });

  /// The list it was taken of (server, filter, scope, sort); another list
  /// takes a new snapshot.
  final String list;

  /// The Activity visit it was taken in; the next visit takes a new one.
  final int visit;

  /// The rows as last shown, in order.
  final List<Map<String, dynamic>> rows;

  /// The rows the store no longer lists, kept read, the earliest first.
  final List<String> kept;

  /// The rows read since it was taken, and not unread again since.
  final Set<String> read;

  ActivityUnreadSnapshot copyWith({
    List<Map<String, dynamic>>? rows,
    List<String>? kept,
    Set<String>? read,
  }) => ActivityUnreadSnapshot(
    list: list,
    visit: visit,
    rows: rows ?? this.rows,
    kept: kept ?? this.kept,
    read: read ?? this.read,
  );

  /// At most this many read rows are kept; past it the earliest leave.
  static const maxKept = 500;

  static String? _key(Map row) => activityItemKey(row);

  /// Whether the row shows read (Web `isRead`).
  static bool isRead(Map row) {
    if (row['kind'] == 'mention_action') return true;
    final quiet =
        ((row['unreadCount'] as num?) ?? 0) == 0 && row['hasMention'] != true;
    return row['kind'] == 'object'
        ? quiet
        : quiet && row['firstUnreadMessageId'] == null;
  }

  /// The row shown read: the same copy once it is, so showing it changes nothing.
  static Map<String, dynamic> asRead(Map<String, dynamic> row) => isRead(row)
      ? row
      : {
          ...row,
          'unreadCount': 0,
          'hasMention': false,
          'firstUnreadMessageId': null,
          'firstMentionMessageId': null,
          if (row['unreadParts'] != null) 'unreadParts': null,
        };

  /// Its latest activity: a new message changes it, and with it the row's
  /// place in the store.
  static String activityOf(Map row) {
    if (row['kind'] == 'mention_action') return '${row['messageId']}';
    if (row['kind'] == 'object') return '${row['doneFrontierSeq']}';
    final latest = row['kind'] == 'thread'
        ? row['latestActivityMessageId']
        : row['lastMessageId'];
    return '$latest:${row['latestActivitySeq'] ?? ''}';
  }

  /// The list to show: [items] in the store's order, with each row of
  /// [previous] that was read and the store no longer lists back where it
  /// was, read; and the keys of those rows, the earliest kept first.
  static ({List<Map<String, dynamic>> rows, List<String> kept}) show(
    List<Map<String, dynamic>> items,
    ActivityUnreadSnapshot? previous,
  ) {
    if (previous == null) return (rows: items, kept: const []);
    final listed = <String, Map<String, dynamic>>{
      for (final item in items) ?_key(item): item,
    };
    final leaving = <String>{};
    for (final row in previous.rows) {
      final key = _key(row);
      if (key != null && !listed.containsKey(key) && previous.read.contains(key)) {
        leaving.add(key);
      }
    }
    if (leaving.isEmpty) return (rows: items, kept: const []);
    final order = [
      for (final key in previous.kept)
        if (leaving.contains(key)) key,
    ];
    final known = order.toSet();
    for (final key in leaving) {
      if (known.add(key)) order.add(key);
    }
    final kept = order.length > maxKept
        ? order.sublist(order.length - maxKept)
        : order;
    final keeping = kept.toSet();

    // Each kept row stays after the nearest row above it that has not moved:
    // one the store listed then and lists now with the same latest activity.
    // With none above, it goes before the nearest one below that has not
    // moved; with none at all, after the store's rows.
    final wasKept = previous.kept.toSet();
    bool stays(Map<String, dynamic> row, String key) {
      final now = listed[key];
      return now != null && !wasKept.contains(key) && activityOf(now) == activityOf(row);
    }

    final followers = <String, List<Map<String, dynamic>>>{};
    final leaders = <String, List<Map<String, dynamic>>>{};
    String? after;
    var leading = <Map<String, dynamic>>[];
    for (final row in previous.rows) {
      final key = _key(row);
      if (key == null) continue;
      if (stays(row, key)) {
        if (after == null && leading.isNotEmpty) {
          leaders[key] = leading;
          leading = [];
        }
        after = key;
        continue;
      }
      if (!keeping.contains(key)) continue;
      if (after == null) {
        leading.add(asRead(row));
      } else {
        (followers[after] ??= []).add(asRead(row));
      }
    }
    final rows = <Map<String, dynamic>>[];
    for (final item in items) {
      final key = _key(item);
      if (key != null) rows.addAll(leaders[key] ?? const []);
      rows.add(item);
      if (key != null) rows.addAll(followers[key] ?? const []);
    }
    rows.addAll(leading);
    return (rows: rows, kept: kept);
  }
}

/// Web `activityVisit`: the Activity visit a snapshot belongs to. It ends when
/// the last Activity surface (the list, an opened conversation pane) leaves;
/// the next surface to appear starts a new one.
class ActivityVisit {
  int _surfaces = 0;
  int _visit = 0;

  /// The current visit (starts at 1 on the first surface).
  int get current => _visit;

  /// An Activity surface mounted; returns the call that unmounts it.
  VoidCallback enter() {
    if (_surfaces == 0) _visit++;
    _surfaces++;
    var left = false;
    return () {
      if (left) return;
      left = true;
      _surfaces--;
    };
  }

  bool get active => _surfaces > 0;
}

/// The one snapshot of a workspace and what moves it (Web module state).
class ActivityUnreadSnapshotStore {
  ActivityUnreadSnapshot? _snapshot;
  ActivityUnreadSnapshot? get current => _snapshot;

  /// The list of Activity's server, filter, scope and sort.
  static String listKey({
    required String? serverId,
    required String filter,
    String? scope,
    String sort = 'desc',
  }) => '$serverId|$filter|${scope ?? ''}|$sort';

  /// Rows to show for [items] under [list]: the kept read rows put back, and
  /// the result recorded as what the next change is shown against. A null
  /// [list] (not an Unread list) ends the snapshot and shows [items].
  List<Map<String, dynamic>> shown(
    List<Map<String, dynamic>> items, {
    required String? list,
    required int visit,
  }) {
    if (list == null) {
      _snapshot = null;
      return items;
    }
    final previous = _snapshot != null &&
            _snapshot!.list == list &&
            _snapshot!.visit == visit
        ? _snapshot
        : null;
    final shown = ActivityUnreadSnapshot.show(items, previous);
    _record(list, visit, shown.rows, shown.kept, previous);
    return shown.rows;
  }

  void _record(
    String list,
    int visit,
    List<Map<String, dynamic>> rows,
    List<String> kept,
    ActivityUnreadSnapshot? current,
  ) {
    if (current != null &&
        _sameRows(current.rows, rows) &&
        listEquals(current.kept, kept)) {
      return;
    }
    _snapshot = ActivityUnreadSnapshot(
      list: list,
      visit: visit,
      rows: rows,
      kept: kept,
      read: current?.read ?? const {},
    );
  }

  static bool _sameRows(List a, List b) =>
      a.length == b.length && Iterable<int>.generate(a.length).every((i) => identical(a[i], b[i]));

  /// The visit ended, or another server: take the next snapshot afresh.
  void drop() => _snapshot = null;

  /// The store read these rows (here or on another device): once it stops
  /// listing them, the list keeps them, read.
  void noteRead(Iterable<String> keys) {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    Set<String>? read;
    for (final key in keys) {
      if (snapshot.read.contains(key) || (read?.contains(key) ?? false)) continue;
      read ??= {...snapshot.read};
      read.add(key);
    }
    if (read != null) _snapshot = snapshot.copyWith(read: read);
  }

  /// The store's rows changed: a row noted read that it lists unread again (a
  /// new message) is no longer read.
  void forgetUnreadAgain(Iterable<Map<String, dynamic>> items) {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.read.isEmpty) return;
    final again = [
      for (final item in items)
        if (((item['unreadCount'] as num?) ?? 0) > 0)
          if (activityItemKey(item) case final key?
              when snapshot.read.contains(key))
            key,
    ];
    if (again.isEmpty) return;
    _snapshot = snapshot.copyWith(read: snapshot.read.difference(again.toSet()));
  }

  /// The snapshot's copy of the row [key] when it is kept (the store no
  /// longer lists it).
  Map<String, dynamic>? keptRow(String key) {
    final snapshot = _snapshot;
    if (snapshot == null || !snapshot.kept.contains(key)) return null;
    return snapshot.rows.where((row) => activityItemKey(row) == key).firstOrNull;
  }

  /// Where to put the row [key] among [items] so it stays where the list
  /// shows it (Mark as Unread on a row kept read).
  int indexOf(String key, List<Map<String, dynamic>> items) {
    final rows = _snapshot?.rows ?? const <Map<String, dynamic>>[];
    final at = rows.indexWhere((row) => activityItemKey(row) == key);
    if (at == -1) return items.length;
    int indexIn(Map<String, dynamic> row) =>
        items.indexWhere((item) => activityItemKey(item) == activityItemKey(row));
    for (final row in rows.skip(at + 1)) {
      final index = indexIn(row);
      if (index != -1) return index;
    }
    for (final row in rows.take(at).toList().reversed) {
      final index = indexIn(row);
      if (index != -1) return index + 1;
    }
    return items.length;
  }

  /// Takes the rows that match out of the snapshot (Done, the conversation gone).
  void dropWhere(bool Function(Map<String, dynamic> row) matches) {
    final snapshot = _snapshot;
    if (snapshot == null || !snapshot.rows.any(matches)) return;
    final rows = [for (final row in snapshot.rows) if (!matches(row)) row];
    final left = {for (final row in rows) activityItemKey(row)};
    _snapshot = snapshot.copyWith(
      rows: rows,
      kept: [for (final key in snapshot.kept) if (left.contains(key)) key],
    );
  }

  /// Takes the kept row [key] out (Done on it); the returned call puts it back
  /// where it was, read, if the Done fails while the same list is shown.
  VoidCallback? take(String key) {
    final taken = _snapshot;
    if (taken == null) return null;
    final index = taken.rows.indexWhere((row) => activityItemKey(row) == key);
    if (index == -1 || !taken.kept.contains(key)) return null;
    final item = taken.rows[index];
    final above = [
      for (final row in taken.rows.take(index)) activityItemKey(row),
    ].reversed.toList();
    dropWhere((row) => activityItemKey(row) == key);
    return () {
      final now = _snapshot;
      if (now == null || now.list != taken.list || now.visit != taken.visit) return;
      if (now.rows.any((row) => activityItemKey(row) == key)) return;
      final keys = [for (final row in now.rows) activityItemKey(row)];
      final anchor = above.where(keys.contains).firstOrNull;
      final at = anchor == null ? 0 : keys.indexOf(anchor) + 1;
      _snapshot = now.copyWith(
        rows: [...now.rows.take(at), item, ...now.rows.skip(at)],
        kept: [...now.kept, key],
        read: {...now.read, key},
      );
    };
  }

  /// The store's patches to its rows, applied to the snapshot's copies too.
  void patch(Map<String, dynamic> Function(Map<String, dynamic> row) apply) {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final rows = [for (final row in snapshot.rows) apply(row)];
    if (!_sameRows(rows, snapshot.rows)) _snapshot = snapshot.copyWith(rows: rows);
  }
}
