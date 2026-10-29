import 'system_notification_projection.dart';

/// Feature flag gating the durable usage-limit attention feed (Web
/// `USAGE_LIMIT_ATTENTION_FEATURE_FLAG_KEY`).
const usageLimitAttentionFlag = 'usage_limit_attention_v0';

/// `SERVER_SYSTEM_ATTENTION_CONTRACT_VERSION`: a snapshot with any other
/// version is dropped, never partly read.
const serverSystemAttentionContract = 'server-system-attention-v1';

/// Display name of a provider (Web `useSystemNotifications` section 0): the
/// three named ones, and "Grok" for everything else, exactly as Web does.
String usageLimitProviderName(String provider) => switch (provider) {
  'claude' => 'Claude',
  'codex' => 'Codex',
  'kimi' => 'Kimi',
  _ => 'Grok',
};

/// One active usage-limit incident for the current receiver
/// (`UsageLimitAttentionNotification`).
class UsageLimitIncident {
  const UsageLimitIncident({
    required this.id,
    required this.provider,
    required this.machineId,
    required this.machineName,
    required this.affectedAgents,
    this.resetsAt,
    this.seenAt,
  });
  final String id, provider, machineId, machineName;
  final int affectedAgents;
  final String? resetsAt, seenAt;
  bool get seen => seenAt != null;

  UsageLimitIncident markedSeen(String at) => UsageLimitIncident(
    id: id,
    provider: provider,
    machineId: machineId,
    machineName: machineName,
    affectedAgents: affectedAgents,
    resetsAt: resetsAt,
    seenAt: seenAt ?? at,
  );
}

/// A replace-snapshot of `GET /servers/:id/system-notifications-v2`.
class UsageLimitSnapshot {
  const UsageLimitSnapshot(this.incidents);
  final List<UsageLimitIncident> incidents;

  /// Incidents this receiver has not seen yet (`unseenCount`).
  int get unseenCount => incidents.where((i) => !i.seen).length;

  UsageLimitSnapshot markSeen(String id, String at) => UsageLimitSnapshot([
    for (final i in incidents) i.id == id ? i.markedSeen(at) : i,
  ]);
  UsageLimitSnapshot without(String id) => UsageLimitSnapshot([
    for (final i in incidents)
      if (i.id != id) i,
  ]);
}

/// Parses a snapshot; null when [raw] is not a current-contract response.
/// Rows the client cannot present (no id, machine or provider) are
/// skipped rather than invented.
UsageLimitSnapshot? parseUsageLimitSnapshot(dynamic raw) {
  if (raw is! Map || raw['contractVersion'] != serverSystemAttentionContract) {
    return null;
  }
  final rows = raw['notifications'];
  if (rows is! List) return null;
  final incidents = <UsageLimitIncident>[];
  for (final row in rows) {
    if (row is! Map || row['kind'] != 'usage_limit_reached') continue;
    final id = row['id'], provider = row['provider'], machine = row['machine'];
    if (id is! String ||
        id.isEmpty ||
        provider is! String ||
        machine is! Map ||
        machine['id'] is! String ||
        (machine['id'] as String).isEmpty) {
      continue;
    }
    final agents = row['affectedAgentIds'];
    final resetsAt = row['resetsAt'], seenAt = row['seenAt'];
    incidents.add(
      UsageLimitIncident(
        id: id,
        provider: provider,
        machineId: machine['id'] as String,
        machineName: '${machine['name'] ?? ''}',
        affectedAgents: agents is List ? agents.length : 0,
        resetsAt: resetsAt is String && resetsAt.isNotEmpty ? resetsAt : null,
        seenAt: seenAt is String && seenAt.isNotEmpty ? seenAt : null,
      ),
    );
  }
  return UsageLimitSnapshot(List.unmodifiable(incidents));
}

/// Notification entries for [snapshot], newest first as the server orders them.
List<SystemNotice> usageLimitNotices(UsageLimitSnapshot? snapshot) => [
  for (final i in snapshot?.incidents ?? const <UsageLimitIncident>[])
    SystemNotice(
      id: 'usage-limit:${i.id}',
      kind: SystemNoticeKind.warning,
      title: '${usageLimitProviderName(i.provider)} usage limit reached',
      body: i.resetsAt == null
          ? '${i.affectedAgents} ${i.affectedAgents == 1 ? 'agent' : 'agents'} on ${i.machineName} may pause until usage is available again.'
          : '${i.affectedAgents} ${i.affectedAgents == 1 ? 'agent' : 'agents'} on ${i.machineName} may pause. Usage is expected to reset ${i.resetsAt}.',
      destination: SystemNoticeDestination.computer,
      targetId: i.machineId,
      incidentId: i.id,
      unread: !i.seen,
      parameters: {
        'provider': usageLimitProviderName(i.provider),
        'count': i.affectedAgents,
        'computer': i.machineName,
        'reset': i.resetsAt,
      },
    ),
];
