import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import 'agent_metadata_projection.dart';
import 'message_reference_directory.dart';
import 'private_route_guard.dart';

/// Authorized directory/activity adapter for message metadata. Ambient presence
/// persists until a real terminal event; it is separate from the 90s work ticker.
/// It is scoped by the server-level [directoryAuthority]: channel switches and
/// thread opens keep the accepted identities, and a directory revalidation
/// keeps presenting them until the replacement is accepted.
class MessageAgentPresentation extends ChangeNotifier {
  MessageAgentPresentation(this.w, this.directory) {
    projection = AgentAmbientProjection(currentScope);
    directory.addListener(changed);
    w.addListener(changed);
    events = w.client.events.listen(event);
    changed();
  }
  final WorkspaceController w;
  final MessageReferenceDirectory directory;
  late final AgentAmbientProjection projection;
  StreamSubscription<RaftEvent>? events;
  AgentAmbientSnapshot? snapshot;
  int requestRevision = -1, acceptedRevision = -1;
  bool ended = false;
  Timer? externalExpiry;
  String? authority;
  final identities = <String, AgentPresentationIdentity>{};

  /// Facts behind the last whole-presentation notification.
  Object? notified;

  /// Per-agent presence signals. Live activity and last-seen events notify
  /// only the agent they concern, so a heartbeat rebuilds the avatars that
  /// show that agent instead of every row of every mounted chat.
  final _presence = <String, _PresenceSignal>{};

  /// Notifies when [display] (or the last-seen part of [identity]) of agent
  /// [id] changes through a realtime event. Whole-directory changes notify
  /// this presentation itself.
  Listenable presenceOf(String id) =>
      _presence.putIfAbsent(id, _PresenceSignal.new);
  void _presenceChanged(String id) => _presence[id]?.ping();

  /// Notifies listeners only when the presented facts changed. Runs on every
  /// workspace notification.
  void _notifyIfChanged() {
    final facts = (
      authority,
      authorityCurrent,
      directory.loading,
      requestRevision,
      acceptedRevision,
    );
    if (facts == notified) return;
    notified = facts;
    notifyListeners();
  }

  AgentPresentationScope get currentScope => (
    origin: w.client.origin,
    principal: w.client.user?.id ?? '',
    server: w.server?.id ?? '',
    authorityRevision: w.client.generation,
  );
  bool get authorityCurrent =>
      !ended &&
      authority == directoryAuthority(w) &&
      directory.scope == authority &&
      w.can('viewAgents');
  // Only an identity without settled data withdraws presentation; an in-place
  // revalidation keeps it. The merge snapshot rejects an older REST receipt.
  bool get authorized => authorityCurrent && !directory.loading;

  void changed() {
    if (ended) return;
    final next = directoryAuthority(w);
    if (authority != next) {
      authority = next;
      // The pure scope includes the explicit principal/server. A role or
      // capability change also retires every prior projection here.
      projection.adopt(currentScope);
      projection.replaceAuthorizedDirectory(currentScope, const []);
      identities.clear();
      requestRevision = acceptedRevision = -1;
      snapshot = null;
    }
    if (!authorityCurrent) {
      externalExpiry?.cancel();
      externalExpiry = null;
      identities.clear();
      projection.replaceAuthorizedDirectory(currentScope, const []);
      _notifyIfChanged();
      return;
    }
    if (requestRevision != directory.requestRevision) {
      requestRevision = directory.requestRevision;
      snapshot = projection.beginSnapshot();
    }
    if (!directory.loading && acceptedRevision != directory.acceptedRevision) {
      acceptedRevision = directory.acceptedRevision;
      final previous = Map<String, AgentPresentationIdentity>.from(identities);
      identities.clear();
      final activities = <String, AgentAmbientActivity>{};
      for (final row in directory.agents) {
        final id = row['id'];
        if (id is! String) continue;
        final status = row['status'] is String
            ? row['status'] as String
            : 'offline';
        final incomingSeen = row['lastSeenAt'] is String
            ? DateTime.tryParse(row['lastSeenAt'])
            : null;
        final previousSeen = previous[id]?.lastSeenAt;
        final lastSeen =
            previousSeen != null &&
                (incomingSeen == null || previousSeen.isAfter(incomingSeen))
            ? previousSeen
            : incomingSeen;
        identities[id] = AgentPresentationIdentity(
          id: id,
          status: status,
          runtime: row['runtime'] as String?,
          machineId: row['machineId'] as String?,
          model: row['model'] as String?,
          description: row['description'] as String?,
          external: row['runtime'] == 'external',
          lastSeenAt: lastSeen,
          deleted: row['deletedAt'] != null,
        );
        activities[id] = normalizeAgentSnapshotActivity(
          status: status,
          activity: row['activity'] as String?,
          activityKind: row['activityKind'] as String?,
          detailKind: row['detailKind'] as String?,
          detail: row['activityDetail'] is String
              ? row['activityDetail'] as String
              : '',
        );
      }
      projection.replaceAuthorizedDirectory(currentScope, identities.values);
      projection.hydrate(snapshot ?? projection.beginSnapshot(), activities);
    }
    scheduleExternalExpiry();
    _notifyIfChanged();
  }

  void scheduleExternalExpiry() {
    externalExpiry?.cancel();
    externalExpiry = null;
    if (!authorityCurrent) return;
    final now = DateTime.now();
    final ends = [
      for (final row in identities.values)
        if (row.external && !row.deleted && row.lastSeenAt != null)
          row.lastSeenAt!.add(const Duration(milliseconds: 120000)),
    ].where((end) => end.isAfter(now)).toList()..sort();
    if (ends.isEmpty) return;
    externalExpiry = Timer(ends.first.difference(now), () {
      if (!ended && authorityCurrent) {
        for (final row in identities.values) {
          if (row.external) _presenceChanged(row.id);
        }
        scheduleExternalExpiry();
      }
    });
  }

  void event(RaftEvent event) {
    if (!authorityCurrent) return;
    if (event.name == 'connected') {
      projection.resetSequenceBaseline();
      directory.refresh();
      changed();
      return;
    }
    if ((event.name != 'agent:activity' && event.name != 'agent:seen') ||
        event.payload is! Map) {
      return;
    }
    final value = event.payload as Map;
    final id = value['agentId'];
    if (id is! String ||
        !identities.containsKey(id) ||
        value['serverId'] != null && value['serverId'] != w.server?.id) {
      return;
    }
    if (event.name == 'agent:seen') {
      final seen = value['lastSeenAt'] is String
          ? DateTime.tryParse(value['lastSeenAt'])
          : null;
      final old = identities[id]!;
      if (seen == null ||
          old.lastSeenAt != null && !seen.isAfter(old.lastSeenAt!)) {
        return;
      }
      identities[id] = AgentPresentationIdentity(
        id: old.id,
        status: old.status,
        runtime: old.runtime,
        machineId: old.machineId,
        model: old.model,
        description: old.description,
        external: old.external,
        deleted: old.deleted,
        lastSeenAt: seen,
      );
      projection.replaceAuthorizedDirectory(currentScope, identities.values);
      scheduleExternalExpiry();
      _presenceChanged(id);
      return;
    }
    final result = projection.apply(
      expected: currentScope,
      agentId: id,
      activity: value['activity'] as String?,
      activityKind: value['activityKind'] as String?,
      detail: value['detail'] is String ? value['detail'] as String : '',
      detailKind: value['detailKind'] as String?,
      serverSeq: int.tryParse('${value['serverSeq']}'),
      launchId: value['launchId'] as String?,
    );
    if (result == AgentAmbientApply.applied) _presenceChanged(id);
    if (result == AgentAmbientApply.conflict) {
      // The shared directory revalidation owns the reconcile and its fence.
      directory.refresh();
      changed();
    }
  }

  AgentPresentationIdentity? identity(String id) =>
      authorized ? identities[id] : null;
  AgentAmbientDisplay? display(String id) =>
      authorized ? projection.display(id, DateTime.now()) : null;

  @override
  void dispose() {
    ended = true;
    externalExpiry?.cancel();
    unawaited(events?.cancel());
    directory.removeListener(changed);
    w.removeListener(changed);
    identities.clear();
    for (final signal in _presence.values) {
      signal.dispose();
    }
    _presence.clear();
    super.dispose();
  }
}

class _PresenceSignal extends ChangeNotifier {
  void ping() => notifyListeners();
}
