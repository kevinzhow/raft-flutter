// Web utils/agentDiagnosticInfo.ts `buildAgentDiagnosticInfo`: the text of
// "Copy Diagnostic Info" and of the runtime error banner's Copy info. An
// external agent runs outside Raft (no Computer, daemon or managed status), so
// its text carries the external facts of `GET /agents/:id/external-diagnostics`
// instead: provisioning, presence, reported status, push webhook, cursor pulls
// and account connections.

/// `EXTERNAL_AGENT_ONLINE_WINDOW_MS`.
const externalAgentOnlineWindowMs = 120000;

/// `GET /agents/:id/external-diagnostics` carries a view with these parts; a
/// body without them (an older server) counts as unavailable.
Map<String, dynamic>? admittedExternalDiagnostics(Object? value) {
  if (value is! Map ||
      value['presence'] is! Map ||
      value['status'] is! Map ||
      value['push'] is! Map) {
    return null;
  }
  return Map<String, dynamic>.from(value);
}

String _iso(DateTime? value) =>
    value == null ? 'unknown' : value.toUtc().toIso8601String();

String _isoMs(Object? ms) => ms is num
    ? _iso(DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true))
    : 'unknown';

String _isoString(Object? value) {
  final date = value is String ? DateTime.tryParse(value) : null;
  return date == null ? 'none' : _iso(date);
}

String _orUnknown(Object? value) {
  final text = value is String ? value.trim() : '';
  return text.isEmpty ? 'unknown' : text;
}

String _orNull(Object? value) {
  final text = value is String ? value.trim() : '';
  return text.isEmpty ? 'null' : text;
}

String _activityKind(String? activity, String? detailKind) =>
    detailKind != null &&
        detailKind.isNotEmpty &&
        detailKind != 'none' &&
        detailKind != 'other'
    ? detailKind
    : activity ?? 'other';

String _connectionLine(Map connection) {
  final state = connection['state'];
  final account = connection['account'];
  final reason = connection['reason'];
  final suffix = state == 'connected' && account is String && account.isNotEmpty
      ? ' ($account)'
      : state == 'unavailable' && reason is String && reason.isNotEmpty
      ? ' ($reason)'
      : '';
  return '${connection['provider']}Connection: $state$suffix';
}

List<String> _externalLines({
  required Map agent,
  required String? serverId,
  required String? activity,
  required String? detailKind,
  required String? activityDetail,
  required int? lastActivityAtMs,
  required Map<String, dynamic>? diagnostics,
  required DateTime reportedAt,
}) {
  final presence = diagnostics?['presence'] as Map?;
  final status = diagnostics?['status'] as Map?;
  final lastSeenAt = diagnostics != null
      ? presence!['lastSeenAt']
      : agent['lastSeenAt'];
  final lastSeen = lastSeenAt is String ? DateTime.tryParse(lastSeenAt) : null;
  final windowMs = presence?['onlineWindowMs'] is num
      ? (presence!['onlineWindowMs'] as num).toInt()
      : externalAgentOnlineWindowMs;
  final online =
      lastSeen != null &&
      reportedAt.millisecondsSinceEpoch - lastSeen.millisecondsSinceEpoch <
          windowMs;
  final lines = [
    'reportedAtUtc: ${_iso(reportedAt)}',
    'serverId: ${_orUnknown(serverId)}',
    'agentId: ${agent['id']}',
    'runtime: ${_orUnknown(agent['runtime'])}',
    'lastSeenAtUtc: ${_isoString(lastSeenAt)}',
    'online: ${online ? 'yes' : 'no'} (window ${(windowMs / 1000).round()}s)',
    'activity: ${_orUnknown(status?['activity'] ?? activity)}',
    'activityKind: ${status?['detailKind'] ?? _activityKind(activity, detailKind)}',
    'activityDetail: ${_orNull((status?['detail'] ?? activityDetail) as String?)}',
    'lastActivityAtUtc: ${_isoMs(lastActivityAtMs)}',
  ];
  if (diagnostics == null) {
    lines.add('externalDiagnostics: unavailable');
    return lines;
  }
  final provider = diagnostics['provider'] as Map?;
  final push = diagnostics['push'] as Map;
  final events = diagnostics['events'] is Map
      ? diagnostics['events'] as Map
      : const {};
  lines.addAll([
    'statusObservedAtUtc: ${_isoString(status!['observedAt'])}',
    'statusProtocolAdoptedAtUtc: ${status['statusProtocolAdoptedAt'] != null ? _isoString(status['statusProtocolAdoptedAt']) : 'none (hook-derived status)'}',
    'providerKind: ${provider?['kind'] ?? 'none'}',
  ]);
  if (provider != null) {
    lines.addAll([
      'provisioningState: ${provider['state']}${provider['syncPending'] == true ? ' (sync pending)' : ''}',
      'providerAgentId: ${_orNull(provider['providerAgentId'] as String?)}',
      'provisioningLastError: ${provider['lastErrorCode'] != null ? '${provider['lastErrorCode']} at ${_isoString(provider['lastErrorAt'])}' : 'none'}',
    ]);
  }
  lines.add(
    'pushWebhook: ${push['registered'] != true
        ? 'not_registered'
        : push['enabled'] == true
        ? 'enabled'
        : 'disabled (${push['disabledReason'] ?? 'unknown'})'}',
  );
  if (push['registered'] == true) {
    lines.addAll([
      'pushEndpointHost: ${_orUnknown(push['endpointHost'])}',
      'pushConsecutiveFailures: ${push['consecutiveFailures']}',
      'pushLastDeliveryAtUtc: ${_isoString(push['lastDeliveryAt'])}',
      'pushLastAttemptAtUtc: ${_isoString(push['lastAttemptAt'])}',
      'pushLastError: ${push['lastError'] ?? 'none'}',
    ]);
  }
  lines.addAll([
    'eventsLastCursorPullAtUtc: ${_isoString(events['lastCursorPullAt'])}',
    'eventsPendingCursorAcks: ${events['pendingCursorAckCount']}',
    for (final c in (diagnostics['connections'] as List? ?? const []))
      if (c is Map) _connectionLine(c),
    'diagnosticsGeneratedAtUtc: ${_isoString(diagnostics['generatedAt'])}',
  ]);
  return lines;
}

/// [title] is the catalog line `agent.diagnosticInfo.title`; [activity] is the
/// agent's current activity, [lastActivityAtMs] the newest activity-log row.
String buildAgentDiagnosticInfo({
  required Map agent,
  required String title,
  required String? serverId,
  Map? machine,
  required String? activity,
  String? detailKind,
  String? activityDetail,
  int? lastActivityAtMs,
  String? errorMessage,
  Map<String, dynamic>? externalDiagnostics,
  DateTime? reportedAt,
}) {
  final reported = (reportedAt ?? DateTime.now()).toUtc();
  final copiedError = activity == 'error' ? (errorMessage?.trim() ?? '') : '';
  final external = agent['external'] == true || agent['runtime'] == 'external';
  if (external) {
    return [
      title,
      if (copiedError.isNotEmpty) 'errorMessage: $copiedError',
      ..._externalLines(
        agent: agent,
        serverId: serverId,
        activity: activity,
        detailKind: detailKind,
        activityDetail: activityDetail,
        lastActivityAtMs: lastActivityAtMs,
        diagnostics: externalDiagnostics,
        reportedAt: reported,
      ),
    ].join('\n');
  }
  return [
    title,
    if (copiedError.isNotEmpty) 'errorMessage: $copiedError',
    'reportedAtUtc: ${_iso(reported)}',
    'serverId: ${_orUnknown(serverId)}',
    'agentId: ${agent['id']}',
    'machineId: ${_orUnknown(agent['machineId'] ?? machine?['id'])}',
    'sessionId: ${_orNull(agent['sessionId'] as String?)}',
    'runtime: ${_orUnknown(agent['runtime'])}',
    'model: ${_orUnknown(agent['model'])}',
    'computerVersion: ${_orUnknown(machine?['computerVersion'])}',
    'daemonVersion: ${_orUnknown(machine?['daemonVersion'])}',
    'agentStatus: ${_orUnknown(agent['status'])}',
    'activity: ${_orUnknown(activity ?? 'unknown')}',
    'activityKind: ${_activityKind(activity, detailKind)}',
    'lastActivityAtUtc: ${_isoMs(lastActivityAtMs)}',
  ].join('\n');
}
