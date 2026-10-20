import 'dart:convert';

import '../data/runtime_error.dart' show spawnLookupReason;
import 'agent_metadata_catalog.dart';

/// Only the adapter constructs this from the current authorized workspace.
/// Account/origin/server and authority revision must all be retained.
typedef AgentPresentationScope = ({
  String origin,
  String principal,
  String server,
  int authorityRevision,
});

/// Display fields only, from the authorized directory; no credentials/config.
class AgentPresentationIdentity {
  const AgentPresentationIdentity({
    required this.id,
    required this.status,
    this.runtime,
    this.machineId,
    this.model,
    this.description,
    this.external = false,
    this.lastSeenAt,
    this.deleted = false,
  });
  final String id, status;
  final String? runtime, machineId, model, description;
  final bool external, deleted;
  final DateTime? lastSeenAt;
}

class AgentAmbientActivity {
  const AgentAmbientActivity({
    required this.activity,
    this.detailKind = 'other',
    this.detail = '',
  });
  final String activity, detailKind, detail;
}

class AgentAmbientDisplay {
  const AgentAmbientDisplay({
    required this.activity,
    required this.online,
    required this.external,
    required this.deactivated,
    required this.detailKind,
    required this.detail,
  });
  final String activity, detailKind, detail;
  final bool online, external, deactivated;
  bool get showPresence => !deactivated;
}

/// Mounted source resolveAgentDisplayState: no 90-second expiry for managed
/// current activity. External presence uses a strict 120000ms lastSeen floor.
/// This deliberately differs from REST normalizeActivity(active) => working.
AgentAmbientDisplay resolveAgentAmbientDisplay({
  required AgentPresentationIdentity identity,
  required DateTime now,
  AgentAmbientActivity? current,
  String stoppedDetail = 'Stopped',
}) {
  final external = identity.external || identity.runtime == 'external';
  final seen = identity.lastSeenAt;
  final seenOnline =
      seen != null && now.difference(seen).inMilliseconds < 120000;
  final usable = !external || seenOnline ? current : null;
  final activity =
      usable?.activity ??
      (external
          ? (seenOnline ? 'online' : 'offline')
          : (identity.status == 'active' ? 'online' : 'offline'));
  final stopped = !external && identity.status == 'stopped' && usable == null;
  return AgentAmbientDisplay(
    activity: activity,
    online: activity != 'offline',
    external: external,
    deactivated: identity.deleted,
    detailKind: usable?.detailKind ?? (stopped ? 'stopped' : 'none'),
    detail: usable?.detail ?? (stopped ? stoppedDetail : ''),
  );
}

/// Source /agents hydration, not the no-entry fallback above.
AgentAmbientActivity normalizeAgentSnapshotActivity({
  required String status,
  String? activity,
  String? activityKind,
  String? detailKind,
  String detail = '',
}) => AgentAmbientActivity(
  activity: sourceAgentActivities.contains(activityKind ?? activity)
      ? (activityKind ?? activity)!
      : (status == 'active' ? 'working' : 'offline'),
  detailKind: sourceAgentDetailKinds.contains(detailKind)
      ? detailKind!
      : 'other',
  detail: detail,
);

/// Web `a || b`: [preferred] unless it is null or an empty string. Server
/// `displayName` can be `""`, which `??` would keep.
String nonEmptyOr(Object? preferred, Object? fallback) {
  if (preferred is String && preferred.isNotEmpty) return preferred;
  return fallback == null ? '' : '$fallback';
}

/// Web `agent.displayName || agent.name`.
String agentRowName(Map row) => nonEmptyOr(row['displayName'], row['name']);

/// The typed detail kind of a directory row: REST rows carry
/// `activityDetailKind` (agentOrchestrator formatActivityFromSnapshot), the
/// socket patch keeps `detailKind`.
String? agentRowDetailKind(Map row) =>
    (row['activityDetailKind'] ?? row['detailKind']) as String?;

/// The lookup reason of the row's current `runtime_unavailable` start failure:
/// the socket patch's own value when it has one, else the REST row's typed
/// `spawnFailure` carrier.
String? agentRowSpawnLookupReason(Map row) {
  if (row.containsKey('spawnLookupReason')) {
    return row['spawnLookupReason'] is String
        ? row['spawnLookupReason'] as String
        : null;
  }
  return spawnLookupReason(agentRowDetailKind(row), row['spawnFailure']);
}

/// A directory row's current activity as the source hydrates it:
/// normalizeActivity(activityKind ?? activity, status).
AgentAmbientActivity agentRowActivity(Map row) {
  final status = row['status'] is String ? row['status'] as String : 'offline';
  return normalizeAgentSnapshotActivity(
    status: status,
    activity: row['activity'] as String?,
    activityKind: row['activityKind'] as String?,
    detailKind: agentRowDetailKind(row),
    detail: row['activityDetail'] is String
        ? row['activityDetail'] as String
        : '',
  );
}

/// Ambient display of one directory row (`/agents` row merged with socket
/// patches). [live] is a newer `{activity, detail, detailKind}` frame.
AgentAmbientDisplay agentRowAmbientDisplay(
  Map row, {
  Map? live,
  DateTime? now,
}) {
  final status = row['status'] is String ? row['status'] as String : 'offline';
  var current = agentRowActivity(row);
  final liveActivity = live?['activityKind'] ?? live?['activity'];
  if (live != null && sourceAgentActivities.contains(liveActivity)) {
    current = AgentAmbientActivity(
      activity: liveActivity as String,
      detailKind: sourceAgentDetailKinds.contains(live['detailKind'])
          ? live['detailKind'] as String
          : 'other',
      detail: live['detail'] is String ? live['detail'] as String : '',
    );
  }
  return resolveAgentAmbientDisplay(
    identity: AgentPresentationIdentity(
      id: '${row['id']}',
      status: status,
      runtime: row['runtime'] as String?,
      external: row['external'] == true || row['runtime'] == 'external',
      deleted: row['deletedAt'] != null,
      lastSeenAt: row['lastSeenAt'] is String
          ? DateTime.tryParse(row['lastSeenAt'] as String)
          : null,
    ),
    now: now ?? DateTime.now(),
    current: current,
  );
}

/// Source utils/activity.ts getActivityTextDescriptor: either a catalog
/// [source] with [values], or a [raw] server string shown verbatim.
typedef AgentActivityDescriptor = ({
  String source,
  Map<String, Object?> values,
  bool raw,
});

String? _errorMessage(Object? value) {
  if (value is! Map) return null;
  for (final key in const ['message', 'error_description', 'error']) {
    final v = value[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  final nested = _errorMessage(value['error']);
  if (nested != null) return nested;
  final errors = value['errors'];
  if (errors is List) {
    for (final item in errors) {
      final message = _errorMessage(item);
      if (message != null) return message;
    }
  }
  return null;
}

/// Source getActivityErrorDisplayDetail: the `message` of a JSON error blob.
String agentActivityErrorDetail(String? detail) {
  final trimmed = detail?.trim() ?? '';
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    try {
      final message = _errorMessage(jsonDecode(trimmed));
      if (message != null) return message;
    } on FormatException {
      // Fall through to the raw detail.
    }
  }
  return trimmed;
}

AgentActivityDescriptor agentActivityDescriptor(
  String activity, [
  String? detail,
  String? detailKind,
]) {
  AgentActivityDescriptor key(String s, [Map<String, Object?> v = const {}]) =>
      (source: s, values: v, raw: false);
  AgentActivityDescriptor raw(String s) =>
      (source: s, values: const {}, raw: true);
  final text = detail ?? '';
  switch (detailKind) {
    case 'delivery_unconsumed':
      return key('Messages delivered, runtime not responding');
    case 'wake_crash_loop_blocked':
      return key('Automatic wake paused — start manually');
    case 'terminal_failure_paused':
      return text.isNotEmpty
          ? raw(text)
          : key(
              'Automatic wake paused after repeated runtime failures — a manual start lifts it',
            );
  }
  switch (activity) {
    case 'online':
      return key('Online');
    case 'thinking':
      return key('Thinking…');
    case 'working':
      if (detailKind == 'starting' || detailKind == 'runtime_starting') {
        return key('Starting…');
      }
      if (detailKind == 'compacting_context') {
        return key('Compacting context…');
      }
      return text.isNotEmpty ? raw(text) : key('Working…');
    case 'error':
      final error = agentActivityErrorDetail(text);
      return error.isEmpty
          ? key('Error')
          : key('Error: {detail}', {'detail': error});
    case 'offline':
      if (detailKind == 'runtime_unavailable' && text.isNotEmpty) {
        return raw(text);
      }
      return key(
        detailKind == 'stopped'
            ? "Stopped — won't receive messages until restarted"
            : 'Offline',
      );
    default:
      return raw(activity);
  }
}

String _plainFormat(String source, Map<String, Object?> values) =>
    source.replaceAllMapped(
      RegExp(r'\{([a-zA-Z0-9_]+)\}'),
      (m) => values.containsKey(m[1]) ? '${values[m[1]]}' : m[0]!,
    );

/// Source formatActivityText(activity, detail, detailKind). [translate]
/// localizes a catalog [source] (default: English); raw server strings are
/// never translated.
String agentActivityText(
  String activity,
  String? detail,
  String? detailKind, {
  String Function(String source, Map<String, Object?> values) translate =
      _plainFormat,
}) {
  final d = agentActivityDescriptor(activity, detail, detailKind);
  return d.raw ? d.source : translate(d.source, d.values);
}

/// Source formatAgentDisplayStateText: an external agent that is not online
/// but was seen reads "Last active <time>" ([relativeTime] formats it).
/// `withDetail: false` withholds the activity detail (public projections).
String agentDisplayText(
  AgentAmbientDisplay display, {
  DateTime? lastSeenAt,
  String Function(DateTime seen)? relativeTime,
  bool withDetail = true,
  String Function(String source, Map<String, Object?> values) translate =
      _plainFormat,
}) {
  if (display.external && !display.online && lastSeenAt != null) {
    final time = relativeTime?.call(lastSeenAt) ?? '';
    if (time.isNotEmpty) return translate('Last active {time}', {'time': time});
  }
  return withDetail
      ? agentActivityText(
          display.activity,
          display.detail,
          display.detailKind,
          translate: translate,
        )
      : agentActivityText(display.activity, '', null, translate: translate);
}

/// Source resolveAgentServerRoleDisplay: null hides the chip; otherwise
/// `(known, label)` where label is `admin`/`member` or the title-cased role.
({bool known, String label})? agentServerRoleChip(
  Object? serverRole, {
  Object? deletedAt,
}) {
  if (deletedAt != null && deletedAt != '') return null;
  final raw = serverRole is String ? serverRole.trim() : '';
  if (raw.isEmpty) return null;
  if (raw == 'admin' || raw == 'member') return (known: true, label: raw);
  final first = raw[0];
  final upper = first.toUpperCase();
  return (
    known: false,
    label: first == first.toLowerCase() && upper != first
        ? upper + raw.substring(1)
        : raw,
  );
}

/// No network access. Adapter supplies a server/account/authority-fenced catalog.
class AgentModelLabelCatalog {
  AgentModelLabelCatalog({
    required this.scope,
    required Map<String, Map<String, Map<String, String>>> machines,
  }) : machines = Map.unmodifiable(
         machines.map(
           (machine, runtimes) => MapEntry(
             machine,
             Map<String, Map<String, String>>.unmodifiable(
               runtimes.map(
                 (runtime, models) => MapEntry(
                   runtime,
                   Map<String, String>.unmodifiable(models),
                 ),
               ),
             ),
           ),
         ),
       );
  final AgentPresentationScope scope;
  final Map<String, Map<String, Map<String, String>>> machines;
}

String? agentPresentationModelLabel({
  required AgentPresentationScope scope,
  required AgentPresentationIdentity identity,
  bool showModelName = true,
  AgentModelLabelCatalog? catalog,
}) {
  final model = identity.model;
  if (!showModelName || model == null || model.isEmpty) return null;
  if (catalog?.scope == scope) {
    final label =
        catalog!.machines[identity.machineId]?[identity.runtime]?[model];
    if (label != null && label.isNotEmpty) return label;
  }
  return sourceRuntimeModelLabels[identity.runtime]?[model] ?? model;
}

/// Never translate a private description or replace it with the literal Agent.
/// Human role labels are translated by the adapter, not looked up as identity.
String? agentPresentationSubtitle(AgentPresentationIdentity identity) {
  final value = identity.description;
  return value != null && value.isNotEmpty ? value : null;
}

String? humanPresentationSubtitle({
  String? description,
  String? localizedRole,
}) => description != null && description.isNotEmpty
    ? description
    : (localizedRole != null && localizedRole.isNotEmpty
          ? localizedRole
          : null);

enum AgentAmbientApply { applied, stale, conflict, invalid, unauthorized }

class AgentAmbientSnapshot {
  AgentAmbientSnapshot._(this.scope, this.requestId, Map<String, int> versions)
    : versions = Map.unmodifiable(versions);
  final AgentPresentationScope scope;
  final int requestId;
  final Map<String, int> versions;
}

/// Transient ambient state, separate from ChatAgentPresentation's work ticker.
/// No timers, persistence, HTTP, callbacks, raw error carriers or model config.
/// Authority adoption clears directory and activity; catalog resolution separately
/// requires the same full scope. Socket timestamps
/// never adjudicate current state: only per-agent serverSeq does so.
class AgentAmbientProjection {
  AgentAmbientProjection(AgentPresentationScope scope) : _scope = scope;
  AgentPresentationScope _scope;
  AgentPresentationScope get scope => _scope;
  Map<String, AgentPresentationIdentity> _identities = {};
  final Map<String, AgentAmbientActivity> _current = {};
  final Map<String, int> _versions = {}, _sequences = {};
  final Map<String, String> _launches = {};
  int _requestId = 0;

  void adopt(AgentPresentationScope next) {
    if (next == scope) return;
    _scope = next;
    _identities = {};
    _current.clear();
    _versions.clear();
    resetSequenceBaseline();
    _requestId++;
  }

  void replaceAuthorizedDirectory(
    AgentPresentationScope expected,
    Iterable<AgentPresentationIdentity> identities,
  ) {
    if (expected != scope) return;
    _identities = {for (final identity in identities) identity.id: identity};
    _current.removeWhere((id, _) => !_identities.containsKey(id));
    _versions.removeWhere((id, _) => !_identities.containsKey(id));
    _sequences.removeWhere((id, _) => !_identities.containsKey(id));
    _launches.removeWhere((id, _) => !_identities.containsKey(id));
  }

  AgentAmbientSnapshot beginSnapshot() =>
      AgentAmbientSnapshot._(scope, ++_requestId, _versions);

  /// Preserve any socket state changed after this particular REST request.
  /// Source resets sequence baselines after authoritative REST/reconnect.
  bool hydrate(
    AgentAmbientSnapshot request,
    Map<String, AgentAmbientActivity> activities,
  ) {
    if (request.scope != scope || request.requestId != _requestId) return false;
    for (final id in _identities.keys) {
      if ((_versions[id] ?? 0) > (request.versions[id] ?? 0)) continue;
      final next = activities[id];
      if (next != null && sourceAgentActivities.contains(next.activity)) {
        _current[id] = next;
      }
    }
    resetSequenceBaseline();
    return true;
  }

  void resetSequenceBaseline() {
    _sequences.clear();
    _launches.clear();
  }

  AgentAmbientApply apply({
    required AgentPresentationScope expected,
    required String agentId,
    String? activity,
    String? activityKind,
    String detail = '',
    String? detailKind,
    int? serverSeq,
    String? launchId,
  }) {
    if (expected != scope || !_identities.containsKey(agentId)) {
      return AgentAmbientApply.unauthorized;
    }
    final nextKind = activityKind ?? activity;
    if (!sourceAgentActivities.contains(nextKind)) {
      return AgentAmbientApply.invalid;
    }
    final next = AgentAmbientActivity(
      activity: nextKind!,
      detail: detail,
      detailKind: sourceAgentDetailKinds.contains(detailKind)
          ? detailKind!
          : 'other',
    );
    final current = _current[agentId];
    final last = _sequences[agentId];
    if (serverSeq != null && last != null && serverSeq <= last) {
      final detailAuthorityUpgrade =
          serverSeq == last &&
          current != null &&
          current.activity == next.activity &&
          current.detail.trim().isNotEmpty == next.detail.trim().isNotEmpty &&
          current.detailKind == 'other' &&
          next.detailKind != 'other';
      if (!detailAuthorityUpgrade) {
        final conflict =
            serverSeq == last &&
            current != null &&
            (current.activity != next.activity ||
                current.detailKind != next.detailKind ||
                current.detail.trim().isNotEmpty !=
                    next.detail.trim().isNotEmpty);
        return conflict ? AgentAmbientApply.conflict : AgentAmbientApply.stale;
      }
    }
    final changed =
        current == null ||
        current.activity != next.activity ||
        current.detail != next.detail ||
        current.detailKind != next.detailKind;
    _current[agentId] = next;
    if (changed) _versions[agentId] = (_versions[agentId] ?? 0) + 1;
    if (serverSeq != null) _sequences[agentId] = serverSeq;
    if (launchId != null) _launches[agentId] = launchId;
    return AgentAmbientApply.applied;
  }

  AgentAmbientDisplay? display(String agentId, DateTime now) {
    final identity = _identities[agentId];
    return identity == null
        ? null
        : resolveAgentAmbientDisplay(
            identity: identity,
            now: now,
            current: _current[agentId],
          );
  }
}
