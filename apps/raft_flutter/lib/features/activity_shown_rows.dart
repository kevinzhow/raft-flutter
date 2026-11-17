// The order the Activity list shows its rows in, and its day groups, kept per
// row so a resize or one live event does not read the whole window again
// (activity_row_key_work_test, activity_incremental_work_test).

import '../data/source_time_formatter.dart';
import 'activity_day_groups.dart';

class _RowTime {
  _RowTime(this.at);
  final DateTime? at;
  String? day, stamp;
}

class ActivityShownRows {
  static final _times = Expando<_RowTime>();

  static _RowTime _of(Map<String, dynamic> row) =>
      _times[row] ??= _RowTime(activityRowTime(row));

  List<Map<String, dynamic>>? _base, _ordered;

  /// [rows] newest first by the time each row shows (Web `sortInboxRowsByTime`,
  /// stable, rows with no time last): [rows] itself when it already is.
  List<Map<String, dynamic>> order(List<Map<String, dynamic>> rows) {
    if (identical(rows, _base)) return _ordered!;
    DateTime? previous;
    var unreadable = false, sorted = true;
    for (final row in rows) {
      final at = _of(row).at;
      if (at == null) {
        unreadable = true;
      } else if (unreadable || (previous != null && at.isAfter(previous))) {
        sorted = false;
        break;
      } else {
        previous = at;
      }
    }
    final result = sorted ? rows : sortActivityRowsByTime(rows);
    _base = rows;
    return _ordered = result;
  }

  List<Map<String, dynamic>>? _groupRows;
  Object? _groupStamp;
  List<ActivityDayGroup>? _groups;

  /// [groupActivityRowsByDay] of the ordered [rows], remembered while the rows
  /// and the formatter's person and day stay. [stamp] says which person
  /// (zone, locale, clock format).
  List<ActivityDayGroup> groups(
    List<Map<String, dynamic>> rows, {
    required SourceTimeFormatter formatter,
    required DateTime now,
    required Object stamp,
  }) {
    final today = formatter.dayKey(now);
    final key = (stamp, today);
    if (identical(rows, _groupRows) && _groupStamp == key) return _groups!;
    final groups = <String, ({String label, List<Map<String, dynamic>> rows})>{};
    for (final row in rows) {
      final info = _of(row);
      final at = info.at;
      var raw = '';
      if (at != null) {
        if (info.stamp != '$stamp') {
          info.day = formatter.dayKey(at);
          info.stamp = '$stamp';
        }
        raw = info.day!;
      }
      final day = raw.compareTo(today) > 0 ? today : raw;
      final group = groups.putIfAbsent(
        day,
        () => (
          label: at == null
              ? ''
              : formatter.dayLabel(at.isAfter(now) ? now : at, now: now),
          rows: <Map<String, dynamic>>[],
        ),
      );
      group.rows.add(row);
    }
    _groupRows = rows;
    _groupStamp = key as Object;
    return _groups = [
      for (final e in groups.entries)
        ActivityDayGroup(day: e.key, label: e.value.label, rows: e.value.rows),
    ];
  }
}
