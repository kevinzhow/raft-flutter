import '../data/source_time_formatter.dart';

/// Web `inboxItemTime`: the time a row shows, which is the time it is grouped
/// by. Null when the row has none readable.
DateTime? activityRowTime(Map<String, dynamic> row) {
  final raw = switch (row['kind']) {
    'thread' || 'object' => row['lastActivityAt'],
    'mention_action' => row['createdAt'],
    _ => row['lastMessageAt'],
  };
  return raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
}

/// Web `sortInboxRowsByTime`: stable, by the time shown in [direction]
/// (`desc` default), rows with no readable time last either way.
List<Map<String, dynamic>> sortActivityRowsByTime(
  Iterable<Map<String, dynamic>> rows, {
  String direction = 'desc',
}) {
  final sign = direction == 'asc' ? 1 : -1;
  final indexed = [
    for (final (i, row) in rows.indexed) (i, row, activityRowTime(row)),
  ];
  indexed.sort((a, b) {
    final (ai, _, at) = a;
    final (bi, _, bt) = b;
    if (at == null || bt == null) {
      final byUnreadable = (at == null ? 1 : 0) - (bt == null ? 1 : 0);
      return byUnreadable != 0 ? byUnreadable : ai - bi;
    }
    final byTime = at.compareTo(bt) * sign;
    return byTime != 0 ? byTime : ai - bi;
  });
  return [for (final (_, row, _) in indexed) row];
}

/// One group of rows of the same calendar day.
class ActivityDayGroup {
  const ActivityDayGroup({
    required this.day,
    required this.label,
    required this.rows,
  });

  /// `YYYY-MM-DD` in the person's zone; empty for rows with no readable time.
  final String day;

  /// The heading; empty (no heading) for rows with no readable time.
  final String label;
  final List<Map<String, dynamic>> rows;

  /// Stable across Today turning into Yesterday, so the group's rows stay put.
  String get key => day.isEmpty ? 'activity-day-none' : 'activity-day-$day';
}

/// Web `groupInboxRowsByDay`: one group per day that has rows, in list order.
/// A time ahead of the clock counts as today.
List<ActivityDayGroup> groupActivityRowsByDay(
  Iterable<Map<String, dynamic>> rows, {
  required SourceTimeFormatter formatter,
  required DateTime now,
  String direction = 'desc',
}) {
  final today = formatter.dayKey(now);
  final groups = <String, ({String label, List<Map<String, dynamic>> rows})>{};
  for (final row in sortActivityRowsByTime(rows, direction: direction)) {
    final at = activityRowTime(row);
    final raw = at == null ? '' : formatter.dayKey(at);
    final day = raw.compareTo(today) > 0 ? today : raw;
    final group = groups.putIfAbsent(
      day,
      () => (
        label: at == null ? '' : formatter.dayLabel(at.isAfter(now) ? now : at, now: now),
        rows: <Map<String, dynamic>>[],
      ),
    );
    group.rows.add(row);
  }
  return [
    for (final entry in groups.entries)
      ActivityDayGroup(
        day: entry.key,
        label: entry.value.label,
        rows: entry.value.rows,
      ),
  ];
}
