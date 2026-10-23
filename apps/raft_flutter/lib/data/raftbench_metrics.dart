// Task and cost aggregates of the RaftBench overview (Web `taskMetrics.ts`
// `comparisonWindow`, `periodMetrics.ts`, `costMetrics.ts`). Each parser
// throws a [FormatException] for a response that is not exactly the contract:
// the overview never infers a total from a malformed or partial answer.

const _day = 86400000;

/// The two equal comparison windows: the latest [days] complete UTC days and
/// the [days] before them (today is excluded), aligned to billing's day buckets.
class RaftbenchWindow {
  const RaftbenchWindow({
    required this.start,
    required this.end,
    required this.previousStart,
    required this.days,
  });

  /// Epoch milliseconds.
  final int start, end, previousStart;
  final int days;

  factory RaftbenchWindow.at(DateTime now, {int days = 7}) {
    if (days < 1 || days > 90) {
      throw const FormatException('Invalid comparison window');
    }
    final utc = now.toUtc();
    final end = DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
    ).millisecondsSinceEpoch;
    final start = end - days * _day;
    return RaftbenchWindow(
      start: start,
      end: end,
      previousStart: start - days * _day,
      days: days,
    );
  }

  static String iso(int millis) => DateTime.fromMillisecondsSinceEpoch(
    millis,
    isUtc: true,
  ).toIso8601String();
}

bool _count(Object? v) => v is int && v >= 0;
bool _hours(Object? v) => v == null || (v is num && v.isFinite && v >= 0);
bool _date(Object? v) =>
    v == null || (v is String && DateTime.tryParse(v) != null);
Map<String, Object?> _row(Object? value, String what) {
  if (value is! Map) throw FormatException('Invalid $what');
  return Map<String, Object?>.from(value);
}

/// `GET /tasks/server/snapshot-metrics`: current task states over every
/// accessible task source.
class RaftbenchTaskSnapshot {
  const RaftbenchTaskSnapshot({
    required this.surfaces,
    required this.total,
    required this.todo,
    required this.inProgress,
    required this.inReview,
    required this.done,
    required this.closed,
    required this.humanCreated,
    required this.agentCreated,
    required this.durationSamples,
    required this.medianHours,
    required this.p90Hours,
    required this.firstCreatedAt,
    required this.latestCreatedAt,
    required this.latestUpdatedAt,
  });
  final int surfaces, total, todo, inProgress, inReview, done, closed;
  final int humanCreated, agentCreated, durationSamples;
  final double? medianHours, p90Hours;
  final String? firstCreatedAt, latestCreatedAt, latestUpdatedAt;

  factory RaftbenchTaskSnapshot.parse(Object? value) {
    final row = _row(value, 'task snapshot');
    const keys = [
      'surfaces',
      'total',
      'todo',
      'inProgress',
      'inReview',
      'done',
      'closed',
      'humanCreated',
      'agentCreated',
      'durationSamples',
    ];
    if (keys.any((key) => !_count(row[key])) ||
        !_hours(row['medianHours']) ||
        !_hours(row['p90Hours']) ||
        !_date(row['firstCreatedAt']) ||
        !_date(row['latestCreatedAt']) ||
        !_date(row['latestUpdatedAt'])) {
      throw const FormatException('Invalid task snapshot');
    }
    int n(String key) => row[key]! as int;
    if (n('total') !=
            n('todo') +
                n('inProgress') +
                n('inReview') +
                n('done') +
                n('closed') ||
        n('total') != n('humanCreated') + n('agentCreated')) {
      throw const FormatException('Invalid task snapshot');
    }
    return RaftbenchTaskSnapshot(
      surfaces: n('surfaces'),
      total: n('total'),
      todo: n('todo'),
      inProgress: n('inProgress'),
      inReview: n('inReview'),
      done: n('done'),
      closed: n('closed'),
      humanCreated: n('humanCreated'),
      agentCreated: n('agentCreated'),
      durationSamples: n('durationSamples'),
      medianHours: (row['medianHours'] as num?)?.toDouble(),
      p90Hours: (row['p90Hours'] as num?)?.toDouble(),
      firstCreatedAt: row['firstCreatedAt'] as String?,
      latestCreatedAt: row['latestCreatedAt'] as String?,
      latestUpdatedAt: row['latestUpdatedAt'] as String?,
    );
  }
}

class RaftbenchTaskPeriod {
  const RaftbenchTaskPeriod({
    required this.completed,
    required this.durationSamples,
    required this.meanHours,
    required this.medianHours,
  });
  final int completed, durationSamples;
  final double? meanHours, medianHours;

  factory RaftbenchTaskPeriod.parse(Object? value) {
    final p = _row(value, 'task period');
    final completed = p['completed'], samples = p['durationSamples'];
    if (!_count(completed) ||
        !_count(samples) ||
        (samples as int) > (completed as int) ||
        !_hours(p['meanHours']) ||
        !_hours(p['medianHours']) ||
        (samples == 0
            ? p['meanHours'] != null || p['medianHours'] != null
            : p['meanHours'] == null || p['medianHours'] == null)) {
      throw const FormatException('Invalid task period');
    }
    return RaftbenchTaskPeriod(
      completed: completed,
      durationSamples: samples,
      meanHours: (p['meanHours'] as num?)?.toDouble(),
      medianHours: (p['medianHours'] as num?)?.toDouble(),
    );
  }
}

/// `GET /tasks/server/period-metrics`: completed tasks of the latest complete
/// window against the previous one.
class RaftbenchTaskPeriods {
  const RaftbenchTaskPeriods({
    required this.current,
    required this.previous,
    required this.surfaces,
  });
  final RaftbenchTaskPeriod current, previous;
  final int surfaces;

  factory RaftbenchTaskPeriods.parse(Object? value, RaftbenchWindow window) {
    final row = _row(value, 'task metrics');
    bool at(Object? v, int millis) =>
        v is String && DateTime.tryParse(v)?.millisecondsSinceEpoch == millis;
    if (!_count(row['surfaces']) ||
        !at(row['from'], window.previousStart) ||
        !at(row['midpoint'], window.start) ||
        !at(row['to'], window.end)) {
      throw const FormatException('Invalid task window');
    }
    return RaftbenchTaskPeriods(
      current: RaftbenchTaskPeriod.parse(row['current']),
      previous: RaftbenchTaskPeriod.parse(row['previous']),
      surfaces: row['surfaces']! as int,
    );
  }
}

/// `GET /billing/hosted-runtime-usage` folded into the two windows. Billing's
/// ACL stays authoritative; no tokens, provider identity or task attribution
/// are retained.
class RaftbenchCostComparison {
  const RaftbenchCostComparison({
    required this.currentUsd,
    required this.previousUsd,
    required this.unpriced,
    required this.estimated,
  });
  final double currentUsd, previousUsd;
  final bool unpriced, estimated;

  factory RaftbenchCostComparison.parse(Object? value, RaftbenchWindow window) {
    if (value is! Map) throw const FormatException('Invalid spend response');
    final row = Map<String, Object?>.from(value);
    final from = row['from'] is String
        ? DateTime.tryParse(row['from']! as String)
        : null;
    final to = row['to'] is String
        ? DateTime.tryParse(row['to']! as String)
        : null;
    final periods = row['periods'];
    if (row['currency'] != 'USD' ||
        row['estimated'] is! bool ||
        periods is! List ||
        row['bucket'] != 'day' ||
        from == null ||
        from.millisecondsSinceEpoch > window.previousStart ||
        to == null ||
        to.millisecondsSinceEpoch < window.end) {
      throw const FormatException('Invalid spend window');
    }
    var current = 0.0, previous = 0.0, unpriced = false;
    final seen = <int>{};
    for (final period in periods) {
      if (period is! Map) throw const FormatException('Invalid spend period');
      final p = Map<String, Object?>.from(period);
      final start = p['start'] is String
          ? DateTime.tryParse(p['start']! as String)
          : null;
      final time = start?.millisecondsSinceEpoch;
      final total = p['totalUsd'];
      final missing = p['unpriced'];
      if (time == null ||
          time % _day != 0 ||
          seen.contains(time) ||
          total is! num ||
          !total.isFinite ||
          missing is! List ||
          !missing.every((item) => item is String)) {
        throw const FormatException('Invalid spend period');
      }
      seen.add(time);
      if (time < window.previousStart || time >= window.end) continue;
      if (time >= window.start) {
        current += total;
      } else {
        previous += total;
      }
      unpriced = unpriced || missing.isNotEmpty;
    }
    return RaftbenchCostComparison(
      currentUsd: current,
      previousUsd: previous,
      unpriced: unpriced,
      estimated: row['estimated']! as bool,
    );
  }
}
