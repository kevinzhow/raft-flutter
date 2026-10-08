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
