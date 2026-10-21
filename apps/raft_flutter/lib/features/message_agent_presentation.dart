import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import 'agent_metadata_projection.dart';
import 'message_reference_directory.dart';
import 'model_label_catalog.dart';
import 'private_route_guard.dart';

/// Message metadata borrows the workspace's accepted Agent state. Event
/// admission and ordering belong to the shared directory, including for a
/// message surface opened after the newest event arrived.
class MessageAgentPresentation extends ChangeNotifier {
  MessageAgentPresentation(this.w, this.directory) {
    directory.addListener(changed);
    w.addListener(changed);
    directory.store.addListener(_presenceChanged);
    // Sender rows name a model from the server's shared catalog, so they
    // repaint when it arrives. The session loads it once (Web
    // watchModelLabelCatalog); pages only read.
    modelLabels = ModelLabelCatalogStore.of(w)
      ..addListener(notifyListeners)
      ..load();
    changed();
  }
  late final ModelLabelCatalogStore modelLabels;
  final WorkspaceController w;
  final MessageReferenceDirectory directory;
  bool ended = false;
  Timer? externalExpiry;
  String? authority;
  Object? notified;
  final _presence = <String, _PresenceSignal>{};
  final _presenceFacts = <String, Object?>{};

  /// A presence event rebuilds only avatars of the affected Agent.
  Listenable presenceOf(String id) {
    _presenceFacts.putIfAbsent(id, () => _facts(id));
    return _presence.putIfAbsent(id, _PresenceSignal.new);
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
  bool get authorized => authorityCurrent && !directory.loading;

  Map<String, dynamic>? _row(String id) {
    if (!authorized) return null;
    final live = directory.store.agent(id);
    if (live != null) return live;
    // Deleted authors still identify historical messages, without live presence.
    return directory.agents.where((row) => row['id'] == id).firstOrNull;
  }

  AgentPresentationIdentity? identity(String id) {
    final row = _row(id);
    if (row == null) return null;
    return AgentPresentationIdentity(
      id: id,
      status: row['status'] is String ? row['status'] as String : 'offline',
      runtime: row['runtime'] as String?,
      machineId: row['machineId'] as String?,
      model: row['model'] as String?,
      description: row['description'] as String?,
      external: row['external'] == true || row['runtime'] == 'external',
      deleted: row['deletedAt'] != null,
      lastSeenAt: row['lastSeenAt'] is String
          ? DateTime.tryParse(row['lastSeenAt'] as String)
          : null,
    );
  }

  AgentAmbientDisplay? display(String id) {
    final row = _row(id);
    return row == null ? null : agentRowAmbientDisplay(row);
  }

  Object? _facts(String id) {
    final value = identity(id), ambient = display(id);
    if (value == null || ambient == null) return null;
    return (
      value.status,
      value.runtime,
      value.machineId,
      value.model,
      value.description,
      value.lastSeenAt,
      value.deleted,
      ambient.activity,
      ambient.detailKind,
      ambient.detail,
      ambient.online,
      ambient.external,
      ambient.deactivated,
    );
  }

  void _presenceChanged() {
    if (ended) return;
    for (final entry in _presence.entries) {
      final facts = _facts(entry.key);
      if (_presenceFacts[entry.key] == facts) continue;
      _presenceFacts[entry.key] = facts;
      entry.value.ping();
    }
    scheduleExternalExpiry();
  }

  void changed() {
    if (ended) return;
    authority = directoryAuthority(w);
    final facts = (
      authority,
      authorityCurrent,
      directory.loading,
      directory.requestRevision,
      directory.acceptedRevision,
    );
    _presenceChanged();
    if (facts == notified) return;
    notified = facts;
    notifyListeners();
  }

  /// External credential presence expires after 120 seconds. This is a
  /// presentation deadline, not another copy of Agent state or a status pull.
  void scheduleExternalExpiry() {
    externalExpiry?.cancel();
    externalExpiry = null;
    if (!authorized) return;
    final now = DateTime.now();
    final ends = <DateTime>[
      for (final row in directory.agents)
        if (identity('${row['id']}') case final value?)
          if (value.external && !value.deleted && value.lastSeenAt != null)
            value.lastSeenAt!.add(const Duration(milliseconds: 120000)),
    ].where((end) => end.isAfter(now)).toList()..sort();
    if (ends.isEmpty) return;
    externalExpiry = Timer(ends.first.difference(now), _presenceChanged);
  }

  /// Compatibility for focused ingress tests; production subscribes once in
  /// the shared directory rather than once per rendered message surface.
  @visibleForTesting
  void event(RaftEvent event) => directory.store.receive(event);

  @override
  void dispose() {
    ended = true;
    externalExpiry?.cancel();
    directory.store.removeListener(_presenceChanged);
    directory.removeListener(changed);
    w.removeListener(changed);
    modelLabels.removeListener(notifyListeners);
    for (final signal in _presence.values) {
      signal.dispose();
    }
    _presence.clear();
    _presenceFacts.clear();
    super.dispose();
  }
}

class _PresenceSignal extends ChangeNotifier {
  void ping() => notifyListeners();
}
