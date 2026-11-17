// The RaftBench conversation-insights contract as the Web client reads it
// (`HostedAnalysis.tsx` `Dashboard`): `GET /raftbench`, `GET /raftbench/agents`.
//
// Responses are read permissively like the Web does: an unknown field is
// ignored and an unknown status or kind is kept as the raw string, which the
// view presents as "Unknown". The server owns the counts; nothing here
// derives a result.

String? _string(Object? v) => v is String ? v : null;
int _int(Object? v, [int fallback = 0]) =>
    v is num && v.isFinite ? v.toInt() : fallback;
int? _intOrNull(Object? v) => v is num && v.isFinite ? v.toInt() : null;
List<Map<String, Object?>> _rows(Object? v) => v is List
    ? [
        for (final item in v)
          if (item is Map) Map<String, Object?>.from(item),
      ]
    : const [];
List<String> _strings(Object? v) => v is List
    ? [
        for (final item in v)
          if (item is String) item,
      ]
    : const [];

/// A message reference the analysis cites: the channel `#name` and the message
/// id (8 characters or a full id).
class RaftbenchEvidenceRef {
  const RaftbenchEvidenceRef(this.target, this.messageId);
  final String target, messageId;

  factory RaftbenchEvidenceRef.parse(Map<String, Object?> json) =>
      RaftbenchEvidenceRef(
        _string(json['target']) ?? '',
        _string(json['messageId']) ?? '',
      );
}

class RaftbenchPattern {
  const RaftbenchPattern({
    required this.kind,
    required this.explanation,
    required this.evidence,
    required this.counterevidence,
    required this.evidenceLevel,
    required this.intent,
    required this.suggestion,
  });

  /// `repeated_clarification`, `repeated_attempt`, `unsupported_completion`
  /// or `successful_practice`.
  final String kind, explanation, evidenceLevel, intent, suggestion;
  final List<RaftbenchEvidenceRef> evidence, counterevidence;

  factory RaftbenchPattern.parse(Map<String, Object?> json) => RaftbenchPattern(
    kind: _string(json['kind']) ?? '',
    explanation: _string(json['explanation']) ?? '',
    evidence: [
      for (final r in _rows(json['evidence'])) RaftbenchEvidenceRef.parse(r),
    ],
    counterevidence: [
      for (final r in _rows(json['counterevidence']))
        RaftbenchEvidenceRef.parse(r),
    ],
    evidenceLevel: _string(json['evidenceLevel']) ?? 'insufficient',
    intent: _string(json['intent']) ?? 'unknown',
    suggestion: _string(json['suggestion']) ?? '',
  );
}

/// The four pattern kinds, in the Web's order (`RAFTBENCH_PATTERN_KINDS`).
const raftbenchPatternKinds = [
  'repeated_clarification',
  'repeated_attempt',
  'unsupported_completion',
  'successful_practice',
];

/// One finding's reviewer vote (`findingFeedback[i]`): `value` is `agree`,
/// `inaccurate` or null (no vote). Parallel to the report's patterns.
class RaftbenchFeedback {
  const RaftbenchFeedback({
    required this.id,
    required this.version,
    required this.value,
    required this.evidenceAt,
  });
  final String id, version;
  final String? value, evidenceAt;

  static List<RaftbenchFeedback> parseList(Object? v) => [
    for (final r in _rows(v))
      RaftbenchFeedback(
        id: _string(r['id']) ?? '',
        version: _string(r['version']) ?? '',
        value: _string(r['value']),
        evidenceAt: _string(r['evidenceAt']),
      ),
  ];
}

class RaftbenchSkippedRange {
  const RaftbenchSkippedRange(this.from, this.to, this.messages);
  final String from, to;

  /// Null when the count is unknown.
  final int? messages;
}

class RaftbenchReport {
  const RaftbenchReport({
    required this.status,
    required this.reason,
    required this.gaps,
    required this.patterns,
  });
  final String? status, reason;
  final List<String> gaps;
  final List<RaftbenchPattern> patterns;

  factory RaftbenchReport.parse(Map<String, Object?> json) => RaftbenchReport(
    status: _string(json['status']),
    reason: _string(json['reason']),
    gaps: _strings(json['gaps']),
    patterns: [
      for (final p in _rows(json['patterns'])) RaftbenchPattern.parse(p),
    ],
  );
}

class RaftbenchRun {
  const RaftbenchRun({
    required this.runId,
    required this.status,
    required this.from,
    required this.to,
    required this.updatedAt,
    required this.fetchedMessages,
    required this.skippedRanges,
    required this.stopReason,
    required this.exhausted,
    required this.failureReason,
    required this.report,
    this.sourceKind,
    this.unreadFailures = const {},
  });

  /// `channel` or `thread` while a stream is read; null on older servers.
  final String? sourceKind;

  /// Failed reads per stream (`channel` / `thread`), from `unreadRetries`.
  final Map<String, int> unreadFailures;

  /// `stale`, `queued`, `running`, `ready`, `partial` or `failed`.
  final String runId, status, from, to, updatedAt, stopReason;
  final int fetchedMessages;
  final List<RaftbenchSkippedRange> skippedRanges;
  final bool exhausted;
  final String? failureReason;
  final RaftbenchReport? report;

  factory RaftbenchRun.parse(Map<String, Object?> json) {
    final report = json['report'];
    return RaftbenchRun(
      runId: _string(json['runId']) ?? '',
      status: _string(json['status']) ?? '',
      from: _string(json['from']) ?? '',
      to: _string(json['to']) ?? '',
      updatedAt: _string(json['updatedAt']) ?? '',
      fetchedMessages: _int(json['fetchedMessages']),
      skippedRanges: [
        for (final r in _rows(json['skippedRanges']))
          RaftbenchSkippedRange(
            _string(r['from']) ?? '',
            _string(r['to']) ?? '',
            _intOrNull(r['messages']),
          ),
      ],
      stopReason: _string(json['stopReason']) ?? '',
      exhausted: json['exhausted'] == true,
      failureReason: _string(json['failureReason']),
      sourceKind: _string(json['sourceKind']),
      unreadFailures: {
        if (json['unreadRetries'] is Map)
          for (final e in (json['unreadRetries'] as Map).entries)
            if (e.key is String && e.value is Map)
              e.key as String: _int((e.value as Map)['failures']),
      },
      report: report is Map
          ? RaftbenchReport.parse(Map<String, Object?>.from(report))
          : null,
    );
  }
}

class RaftbenchProgress {
  const RaftbenchProgress({
    required this.readMessages,
    required this.completedBatches,
    required this.scannedThroughAt,
    this.streamRead = const {},
  });
  final int readMessages, completedBatches;
  final String? scannedThroughAt;

  /// Messages read per stream (`streams.channel` / `streams.thread`); empty on
  /// servers that read thread replies together with channels.
  final Map<String, int> streamRead;
}

/// First-pass message labeling (`triage`): `off`, `no_key`, `running`,
/// `idle` or `budget_exhausted`.
class RaftbenchTriage {
  const RaftbenchTriage({
    required this.state,
    required this.triagedMessages,
    required this.labeledMessages,
    required this.todayTokens,
    required this.dailyTokenLimit,
  });
  final String state;
  final int triagedMessages, labeledMessages, todayTokens, dailyTokenLimit;

  /// `min(100, round(today / limit * 100))`, 0 without a limit.
  int get usage => dailyTokenLimit > 0
      ? (todayTokens / dailyTokenLimit * 100).round().clamp(0, 100)
      : 0;
}

class RaftbenchCoverage {
  const RaftbenchCoverage({
    required this.totalMessages,
    required this.windowMessages,
    required this.earliestAt,
    required this.latestAt,
    required this.from,
    required this.to,
    required this.checkedAt,
  });
  final int totalMessages, windowMessages;
  final String? earliestAt, latestAt;
  final String from, to, checkedAt;
}

class RaftbenchProvisioning {
  const RaftbenchProvisioning({
    required this.state,
    required this.error,
    required this.profile,
  });

  /// `active` once the analysis agent runs; `failed` when it could not start.
  final String state;
  final String? error, profile;
}

class RaftbenchPagination {
  const RaftbenchPagination({
    required this.page,
    required this.pageCount,
    required this.total,
    required this.pageSize,
  });
  final int page, pageCount, total, pageSize;
}

class RaftbenchDashboard {
  const RaftbenchDashboard({
    required this.historyFrom,
    required this.progress,
    required this.coverage,
    required this.enabled,
    required this.revision,
    required this.channelIds,
    required this.agentId,
    required this.provisioning,
    required this.intervalMinutes,
    required this.run,
    required this.pagination,
    this.findingFeedback = const [],
    this.kindCounts,
    this.triage,
  });
  final List<RaftbenchFeedback> findingFeedback;

  /// `findingIndex.kindCounts`; null on servers without the finding index.
  final Map<String, int>? kindCounts;
  final RaftbenchTriage? triage;
  final String? historyFrom, agentId;
  final RaftbenchProgress? progress;
  final RaftbenchCoverage? coverage;
  final bool enabled;
  final int revision, intervalMinutes;
  final List<String> channelIds;
  final RaftbenchProvisioning? provisioning;
  final RaftbenchRun? run;
  final RaftbenchPagination pagination;

  factory RaftbenchDashboard.parse(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid RaftBench dashboard');
    }
    final json = Map<String, Object?>.from(value);
    final progress = json['progress'], coverage = json['coverage'];
    final provisioning = json['provisioning'], run = json['run'];
    final pagination = json['pagination'];
    final index = json['findingIndex'], triage = json['triage'];
    Map<String, Object?> map(Object? v) => Map<String, Object?>.from(v as Map);
    return RaftbenchDashboard(
      historyFrom: _string(json['historyFrom']),
      findingFeedback: RaftbenchFeedback.parseList(json['findingFeedback']),
      kindCounts: index is Map && map(index)['kindCounts'] is Map
          ? {
              for (final e in (map(index)['kindCounts'] as Map).entries)
                if (e.key is String) e.key as String: _int(e.value),
            }
          : null,
      triage: triage is Map
          ? RaftbenchTriage(
              state: _string(map(triage)['state']) ?? 'off',
              triagedMessages: _int(map(triage)['triagedMessages']),
              labeledMessages: _int(map(triage)['labeledMessages']),
              todayTokens: _int(map(triage)['todayTokens']),
              dailyTokenLimit: _int(map(triage)['dailyTokenLimit']),
            )
          : null,
      progress: progress is Map
          ? RaftbenchProgress(
              readMessages: _int(map(progress)['readMessages']),
              completedBatches: _int(map(progress)['completedBatches']),
              scannedThroughAt: _string(map(progress)['scannedThroughAt']),
              streamRead: {
                if (map(progress)['streams'] is Map)
                  for (final e in (map(progress)['streams'] as Map).entries)
                    if (e.key is String && e.value is Map)
                      e.key as String: _int((e.value as Map)['readMessages']),
              },
            )
          : null,
      coverage: coverage is Map
          ? RaftbenchCoverage(
              totalMessages: _int(map(coverage)['totalMessages']),
              windowMessages: _int(map(coverage)['windowMessages']),
              earliestAt: _string(map(coverage)['earliestAt']),
              latestAt: _string(map(coverage)['latestAt']),
              from: _string(map(coverage)['from']) ?? '',
              to: _string(map(coverage)['to']) ?? '',
              checkedAt: _string(map(coverage)['checkedAt']) ?? '',
            )
          : null,
      enabled: json['enabled'] == true,
      revision: _int(json['revision']),
      channelIds: _strings(json['channelIds']),
      agentId: _string(json['agentId']),
      provisioning: provisioning is Map
          ? RaftbenchProvisioning(
              state: _string(map(provisioning)['state']) ?? '',
              error: _string(map(provisioning)['error']),
              profile: _string(map(provisioning)['profile']),
            )
          : null,
      intervalMinutes: _int(json['intervalMinutes'], 15),
      run: run is Map ? RaftbenchRun.parse(map(run)) : null,
      pagination: pagination is Map
          ? RaftbenchPagination(
              page: _int(map(pagination)['page'], 1),
              pageCount: _int(map(pagination)['pageCount'], 1),
              total: _int(map(pagination)['total']),
              pageSize: _int(map(pagination)['pageSize'], 5),
            )
          : const RaftbenchPagination(
              page: 1,
              pageCount: 1,
              total: 0,
              pageSize: 5,
            ),
    );
  }

  RaftbenchDashboard copyWith({bool? enabled, bool clearRun = false}) =>
      RaftbenchDashboard(
        historyFrom: historyFrom,
        progress: progress,
        coverage: coverage,
        enabled: enabled ?? this.enabled,
        revision: revision,
        channelIds: channelIds,
        agentId: agentId,
        provisioning: provisioning,
        intervalMinutes: intervalMinutes,
        run: clearRun ? null : run,
        pagination: pagination,
        findingFeedback: findingFeedback,
        kindCounts: kindCounts,
        triage: triage,
      );
}

/// A dedicated, read-only RaftBench service agent of this server.
class RaftbenchServiceAgent {
  const RaftbenchServiceAgent({
    required this.agentId,
    required this.name,
    required this.state,
    required this.ready,
  });
  final String agentId, name;
  final String? state;
  final bool ready;

  static List<RaftbenchServiceAgent> parseList(Object? value) {
    if (value is! Map) return const [];
    return [
      for (final row in _rows(value['agents']))
        RaftbenchServiceAgent(
          agentId: _string(row['agentId']) ?? '',
          name: _string(row['name']) ?? '',
          state: _string(row['state']),
          ready: row['ready'] == true,
        ),
    ];
  }
}

/// An agent that may be granted read access to the findings
/// (`GET /raftbench/readers`).
class RaftbenchReader {
  const RaftbenchReader({
    required this.agentId,
    required this.name,
    required this.displayName,
    required this.enabled,
  });
  final String agentId, name;
  final String? displayName;
  final bool enabled;

  /// `displayName || name` (an empty display name falls back).
  String get label => displayName?.isNotEmpty == true ? displayName! : name;

  static List<RaftbenchReader> parseList(Object? value) {
    if (value is! Map) throw const FormatException('Invalid readers');
    final rows = value['readers'];
    if (rows is! List) throw const FormatException('Invalid readers');
    return [
      for (final row in _rows(rows))
        RaftbenchReader(
          agentId: _string(row['agentId']) ?? '',
          name: _string(row['name']) ?? '',
          displayName: _string(row['displayName']),
          enabled: row['enabled'] == true,
        ),
    ];
  }
}

/// One pattern kind of the grouped "All" view: the findings read so far, their
/// votes, and the kind's total on the server.
class RaftbenchGroup {
  const RaftbenchGroup({
    required this.patterns,
    required this.feedback,
    required this.total,
  });
  final List<RaftbenchPattern> patterns;
  final List<RaftbenchFeedback> feedback;
  final int total;
}
