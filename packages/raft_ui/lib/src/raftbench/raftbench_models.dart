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
  });

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
  });
  final int readMessages, completedBatches;
  final String? scannedThroughAt;
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
  });
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
    Map<String, Object?> map(Object? v) => Map<String, Object?>.from(v as Map);
    return RaftbenchDashboard(
      historyFrom: _string(json['historyFrom']),
      progress: progress is Map
          ? RaftbenchProgress(
              readMessages: _int(map(progress)['readMessages']),
              completedBatches: _int(map(progress)['completedBatches']),
              scannedThroughAt: _string(map(progress)['scannedThroughAt']),
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
