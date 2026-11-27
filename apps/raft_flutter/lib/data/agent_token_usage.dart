enum AgentUsagePeriod {
  week(7),
  fortnight(14),
  month(30);

  const AgentUsagePeriod(this.days);
  final int days;
}

String agentUsageDay(DateTime instant) =>
    instant.toUtc().toIso8601String().substring(0, 10);

String _shiftDay(String day, int offset) => agentUsageDay(
  DateTime.parse('${day}T00:00:00Z').add(Duration(days: offset)),
);

Map<String, String> agentUsageQuery(
  AgentUsagePeriod period,
  DateTime now, {
  String? agentId,
}) {
  final today = agentUsageDay(now);
  return {
    'from': _shiftDay(today, 1 - 2 * period.days),
    'to': today,
    'agents': ?agentId,
  };
}

typedef UsageContext = ({int used, int window});
typedef UsageModel = ({String? runtime, String model});

class AgentTokenCounts {
  const AgentTokenCounts({
    this.inputNew,
    this.cacheRead,
    this.cacheWrite,
    this.output,
    this.reasoning,
    this.turns = 0,
  });

  factory AgentTokenCounts.parse(Map row) => AgentTokenCounts(
    inputNew: _count(row['input_new']),
    cacheRead: _count(row['cache_read']),
    cacheWrite: _count(row['cache_write']),
    output: _count(row['output']),
    reasoning: _count(row['reasoning_output']),
    turns: _count(row['turns']) ?? 0,
  );

  final int? inputNew, cacheRead, cacheWrite, output, reasoning;
  final int turns;

  static int? _count(Object? value) =>
      value is int && value >= 0 ? value : null;
  static int? _add(int? first, int? second) =>
      second == null ? first : (first ?? 0) + second;

  AgentTokenCounts operator +(AgentTokenCounts other) => AgentTokenCounts(
    inputNew: _add(inputNew, other.inputNew),
    cacheRead: _add(cacheRead, other.cacheRead),
    cacheWrite: _add(cacheWrite, other.cacheWrite),
    output: _add(output, other.output),
    reasoning: _add(reasoning, other.reasoning),
    turns: turns + other.turns,
  );

  int? total({bool withCacheReads = true}) => [
    inputNew,
    cacheWrite,
    output,
    if (withCacheReads) ?cacheRead,
  ].fold<int?>(null, _add);
}

typedef _UsageRow = ({
  String day,
  String agentId,
  UsageModel model,
  AgentTokenCounts counts,
});
typedef _UsageAgent = ({String? since, bool supported});
typedef AgentUsageDay = ({
  String day,
  bool noData,
  bool partial,
  AgentTokenCounts counts,
});
typedef AgentUsageModel = ({UsageModel model, int? tokens});
typedef AgentUsageFigures = ({
  List<AgentUsageDay> days,
  List<AgentUsageModel> models,
  AgentTokenCounts counts,
  int? compared,
  int? base,
  String? baseDay,
  String? since,
  UsageContext? context,
  int reporting,
  bool noData,
  bool empty,
  bool supported,
});

class AgentUsageReport {
  AgentUsageReport.parse(Object? source) {
    if (source is! Map ||
        _day(source['from']) == null ||
        _day(source['to']) == null ||
        source['as_of'] is! String ||
        source['rows'] is! List) {
      throw const FormatException('Invalid agent usage report');
    }
    from = _day(source['from'])!;
    to = _day(source['to'])!;
    asOf = DateTime.parse(source['as_of'] as String).toUtc();
    since = _day(source['since']);
    visibleAgents = AgentTokenCounts._count(source['visible_agents']) ?? 0;
    for (final row in _maps(source['rows'])) {
      final day = _day(row['day']);
      final id = row['agent_id'];
      if (day == null || id is! String) continue;
      final runtime = row['runtime'];
      final model = row['model'];
      _rowsByAgent.putIfAbsent(id, () => []).add((
        day: day,
        agentId: id,
        model: (
          runtime: runtime is String ? runtime : null,
          model: model is String ? model : '',
        ),
        counts: AgentTokenCounts.parse(row),
      ));
    }
    for (final row in _maps(source['agents'])) {
      if (row['agent_id'] case final String id) {
        _agents[id] = (
          since: _day(row['since']),
          supported: row['usage_reported'] != false,
        );
      }
    }
    for (final row in _maps(source['context'])) {
      final id = row['agent_id'];
      final used = AgentTokenCounts._count(row['context_used']);
      final window = AgentTokenCounts._count(row['context_window']);
      if (id is String && used != null && window != null && window > 0) {
        _context[id] = (used: used, window: window);
      }
    }
  }

  late final String from, to;
  late final DateTime asOf;
  late final String? since;
  late final int visibleAgents;
  final _rowsByAgent = <String, List<_UsageRow>>{};
  final _agents = <String, _UsageAgent>{};
  final _context = <String, UsageContext>{};

  Iterable<String> get agentIds => _agents.keys;

  static Iterable<Map> _maps(Object? value) =>
      value is List ? value.whereType<Map>() : const [];

  static String? _day(Object? value) {
    if (value is! String || value.length != 10) return null;
    final parsed = DateTime.tryParse('${value}T00:00:00Z');
    return parsed != null && agentUsageDay(parsed) == value ? value : null;
  }

  AgentUsageFigures figures(
    AgentUsagePeriod period, {
    String? agentId,
    Set<String>? listedAgents,
    String? selectedDay,
    bool withCacheReads = false,
  }) {
    final agent = _agents[agentId];
    final agentSince = agentId != null
        ? agent?.since
        : _agents.entries
              .where((entry) => listedAgents?.contains(entry.key) ?? true)
              .map((entry) => entry.value.since)
              .nonNulls
              .fold<String?>(
                null,
                (earliest, day) =>
                    earliest == null || day.compareTo(earliest) < 0
                    ? day
                    : earliest,
              );
    final start = agentSince != null && agentSince.compareTo(since ?? '') > 0
        ? agentSince
        : since;
    final rows = agentId != null
        ? _rowsByAgent[agentId] ?? const []
        : _rowsByAgent.entries
              .where((entry) => listedAgents?.contains(entry.key) ?? true)
              .expand((entry) => entry.value);
    final partialDay = agentUsageDay(asOf);
    bool hasData(String day) =>
        day.compareTo(from) >= 0 && day.compareTo(start ?? '') >= 0;

    final byDay = <String, AgentTokenCounts>{};
    for (final row in rows) {
      byDay.update(
        row.day,
        (counts) => counts + row.counts,
        ifAbsent: () => row.counts,
      );
    }
    AgentTokenCounts sumPeriod(Iterable<String> days) {
      final present = days.map((day) => byDay[day]).nonNulls;
      if (present.isEmpty && days.any(hasData)) {
        return const AgentTokenCounts(inputNew: 0, cacheRead: 0, output: 0);
      }
      return present.fold(const AgentTokenCounts(), (sum, next) => sum + next);
    }

    final range = [
      for (var index = 1 - period.days; index <= 0; index++)
        _shiftDay(to, index),
    ];
    final displayed = selectedDay == null ? range : [selectedDay];
    final shown = displayed.toSet();
    final reporting = <String>{};
    final models = <UsageModel, AgentTokenCounts>{};
    for (final row in rows.where((row) => shown.contains(row.day))) {
      reporting.add(row.agentId);
      models.update(
        row.model,
        (counts) => counts + row.counts,
        ifAbsent: () => row.counts,
      );
    }
    final modelTotals =
        [
          for (final entry in models.entries)
            (
              model: entry.key,
              tokens: entry.value.total(withCacheReads: withCacheReads),
            ),
        ]..sort(
          (first, second) => (second.tokens ?? 0).compareTo(first.tokens ?? 0),
        );
    final fullDays = displayed.where((day) => day != partialDay).toList();
    final previous = [
      for (final day in fullDays)
        _shiftDay(day, selectedDay == null ? -fullDays.length : -7),
    ];
    final canCompare = previous.isNotEmpty && hasData(previous.first);
    return (
      days: [
        for (final day in range)
          (
            day: day,
            noData: !hasData(day),
            partial: day == partialDay,
            counts: byDay[day] ?? const AgentTokenCounts(),
          ),
      ],
      models: modelTotals,
      counts: sumPeriod(displayed),
      compared: canCompare
          ? sumPeriod(fullDays).total(withCacheReads: withCacheReads)
          : null,
      base: canCompare
          ? sumPeriod(previous).total(withCacheReads: withCacheReads)
          : null,
      baseDay: selectedDay == null ? null : previous.firstOrNull,
      since: start,
      context: selectedDay == null || selectedDay == to
          ? _context[agentId]
          : null,
      reporting: reporting.length,
      noData: !displayed.any(hasData),
      empty: rows.isEmpty,
      supported: agent?.supported ?? true,
    );
  }
}
