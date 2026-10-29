import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart' show raftText;

import '../data/personal_presentation.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_agent_presence.dart';
import 'agent_metadata_projection.dart';
import 'message_reference_directory.dart';
import 'model_label_catalog.dart';
import 'private_route_guard.dart';

/// Message metadata borrows the workspace's accepted Agent state. Event
/// admission and ordering belong to the shared directory, including for a
/// message surface opened after the newest event arrived.
class MessageAgentPresentation extends ChangeNotifier {
  MessageAgentPresentation(this.w, this.directory, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now {
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
  final DateTime Function() clock;
  final _identities = Expando<AgentPresentationIdentity>();
  final _deadlines = <String, DateTime>{};
  DateTime? _nextExpiry;
  int _presenceRevision = -1;
  Object? _presenceAuthority;
  bool ended = false;
  Timer? externalExpiry;
  String? authority;
  Object? notified;
  final _presence = <String, _PresenceSignal>{};
  final _presenceFacts = <String, Object?>{};

  /// A presence event rebuilds only avatars of the affected Agent.
  Listenable presenceOf(String id) => _presence.putIfAbsent(id, () {
    _presenceFacts[id] = _facts(id);
    _rememberDeadline(id);
    scheduleExternalExpiry();
    return _PresenceSignal();
  });

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

  WorkspaceAgentPresence? _row(String id) =>
      authorized ? directory.store.agentPresence(id) : null;

  AgentPresentationIdentity _identity(WorkspaceAgentPresence row) =>
      _identities[row] ??= AgentPresentationIdentity(
        id: row.id,
        status: row.status,
        runtime: row.runtime,
        machineId: row.machineId,
        model: row.model,
        description: row.description,
        external: row.external,
        deleted: row.deleted,
        hosted: row.hosted,
        lastSeenAt: row.lastSeenAt,
      );

  AgentPresentationIdentity? identity(String id) {
    final row = _row(id);
    return row == null ? null : _identity(row);
  }

  AgentAmbientDisplay? display(String id) {
    final row = _row(id);
    return row == null
        ? null
        : resolveAgentAmbientDisplay(
            identity: _identity(row),
            now: clock(),
            current: normalizeAgentSnapshotActivity(
              status: row.status,
              activity: row.activity,
              activityKind: row.activityKind,
              detailKind: row.detailKind,
              detail: row.detail,
            ),
          );
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
      value.hosted,
      ambient.activity,
      ambient.detailKind,
      ambient.detail,
      ambient.online,
      ambient.external,
      ambient.deactivated,
    );
  }

  void _refreshPresence(String id) {
    final facts = _facts(id);
    if (_presenceFacts[id] != facts) {
      _presenceFacts[id] = facts;
      _presence[id]?.ping();
    }
    _rememberDeadline(id);
  }

  void _presenceChanged({bool force = false}) {
    if (ended) return;
    final change = directory.store.agentPresenceChange;
    if (!force && change.revision == _presenceRevision) return;
    final all =
        force || change.id == null || change.revision != _presenceRevision + 1;
    _presenceRevision = change.revision;
    if (all) {
      for (final id in _presence.keys.toList()) {
        _refreshPresence(id);
      }
    } else if (_presence.containsKey(change.id)) {
      _refreshPresence(change.id!);
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
    final presenceAuthority = (authority, authorized);
    _presenceChanged(force: presenceAuthority != _presenceAuthority);
    _presenceAuthority = presenceAuthority;
    if (facts == notified) return;
    notified = facts;
    notifyListeners();
  }

  void _rememberDeadline(String id) {
    final row = _row(id);
    final seen = row?.lastSeenAt;
    final end = seen?.add(const Duration(seconds: 120));
    if (row != null &&
        row.external &&
        !row.deleted &&
        end != null &&
        end.isAfter(clock())) {
      _deadlines[id] = end;
    } else {
      _deadlines.remove(id);
    }
  }

  /// Only observed senders need an external-presence deadline. Unrelated
  /// events neither scan the directory nor replace an unchanged timer.
  void scheduleExternalExpiry() {
    DateTime? next;
    for (final end in _deadlines.values) {
      if (next == null || end.isBefore(next)) next = end;
    }
    if (next == _nextExpiry && externalExpiry?.isActive == true) return;
    externalExpiry?.cancel();
    externalExpiry = null;
    _nextExpiry = next;
    if (next == null) return;
    // ignore: raft_lints/avoid_unreviewed_idle_work -- One shot for an observed external sender; expiry removes elapsed deadlines and stops when no future deadline remains.
    externalExpiry = Timer(next.difference(clock()), () {
      externalExpiry = null;
      _nextExpiry = null;
      final now = clock();
      final expired = [
        for (final entry in _deadlines.entries)
          if (!entry.value.isAfter(now)) entry.key,
      ];
      for (final id in expired) {
        _refreshPresence(id);
      }
      scheduleExternalExpiry();
    });
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
    _deadlines.clear();
    super.dispose();
  }
}

class _PresenceSignal extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Web `MessageItem` `agentModelLabelText`: next to an agent sender's name a
/// cloud agent reads "Cloud agent · Free for a limited time" (its runtime and
/// model are the external placeholders); every other agent its model name.
/// Null when the viewer hides model names.
String? messageAgentModelLabel(
  BuildContext context, {
  required AgentPresentationScope scope,
  required AgentPresentationIdentity identity,
}) {
  final show =
      PersonalPresentationScope.maybeOf(context)?.value.modelName ?? true;
  if (show && identity.hosted) {
    return raftText(context, 'Cloud agent · Free for a limited time');
  }
  return agentPresentationModelLabel(
    scope: scope,
    identity: identity,
    showModelName: show,
  );
}
