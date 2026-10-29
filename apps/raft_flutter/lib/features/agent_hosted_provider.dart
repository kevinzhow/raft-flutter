// Whether cloud agents can be offered on this server, and the models a new
// cloud agent may start on. Web `useAgentRuntimeProvider` (the server's
// `antiproton_hosted_runtime` flag, then the availability probe
// `GET /agent-runtime-providers/:kind`) and `useHostedRuntimeModels`
// (`GET /agent-runtime-providers/:kind/models`). Both answer once per mount
// of the surface that asks (the create dialog, the migration start dialog,
// the retry panel); a failure shows nothing, like Web.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/agent_hosted_runtime.dart';
import '../data/feature_flag_client_facts.dart';
import '../data/workspace_controller.dart';
import 'private_route_guard.dart' show workspaceAuthority;

/// `AgentRuntimeProviderAvailabilityView` for the viewer's server, behind the
/// hosted-runtime flag. [load] reads the flag and the probe; [migration] also
/// reads the hosted-migration flag in the same call.
class HostedRuntimeAvailability extends ChangeNotifier {
  HostedRuntimeAvailability(this.controller, {this.migration = false});

  final WorkspaceController controller;

  /// Also evaluate `agent_migration_hosted_v0` (the migration target).
  final bool migration;

  bool _available = false, _migrationFlag = false, _resolved = false;
  bool _disposed = false;
  int _request = 0;

  /// The flag is on and the deployment has the provider configured.
  bool get available => _available;

  /// `agent_migration_hosted_v0` is on (only read when [migration]).
  bool get migrationFlag => _migrationFlag;

  /// The migration start dialog may offer the cloud as a target.
  bool get migrationAvailable => _available && _migrationFlag;

  /// A first answer arrived (the surface may stop treating "no" as unknown).
  bool get resolved => _resolved;

  /// The last answer per workspace session, so reopening a profile or a dialog
  /// does not ask again within [cacheFor]. Web keeps the flag in its store for
  /// the session.
  static final _answers = Expando<_Answer>('hosted availability');
  static const cacheFor = Duration(seconds: 60);

  Future<void> load() async {
    final w = controller;
    final server = w.server;
    if (server == null) return;
    final request = ++_request;
    final authority = workspaceAuthority(w);
    final known = _answers[w];
    if (known != null &&
        known.authority == authority &&
        known.migration == migration &&
        DateTime.now().difference(known.at) < cacheFor) {
      _adopt(known.available, known.migrationFlag);
      return;
    }
    bool stale() =>
        _disposed || request != _request || authority != workspaceAuthority(w);
    var available = false, migrationFlag = false;
    try {
      final keys = [
        antiprotonHostedRuntimeFlag,
        if (migration) agentMigrationHostedFlag,
      ];
      final result = await w.client.post(
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(keys: keys, serverId: server.id),
      );
      if (stale()) return;
      bool on(String key) =>
          result is Map &&
          result['evaluations'] is List &&
          (result['evaluations'] as List).whereType<Map>().any(
            (f) => f['key'] == key && f['enabled'] == true,
          );
      migrationFlag = on(agentMigrationHostedFlag);
      if (on(antiprotonHostedRuntimeFlag) && (!migration || migrationFlag)) {
        final probe = await w.query(
          hostedRuntimeProviderPath(hostedRuntimeProviderKind),
        );
        if (stale()) return;
        available = probe is Map && probe['available'] == true;
      }
    } catch (_) {
      // Unknown means not offered (Web `setAvailable(false)`).
      if (stale()) return;
      available = false;
    }
    _answers[w] = _Answer(authority, migration, available, migrationFlag);
    _adopt(available, migrationFlag);
  }

  void _adopt(bool available, bool migrationFlag) {
    if (_disposed) return;
    if (available == _available &&
        migrationFlag == _migrationFlag &&
        _resolved) {
      return;
    }
    _available = available;
    _migrationFlag = migrationFlag;
    _resolved = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _Answer {
  _Answer(this.authority, this.migration, this.available, this.migrationFlag)
    : at = DateTime.now();
  final String authority;
  final bool migration, available, migrationFlag;
  final DateTime at;
}

enum HostedModelsStatus { loading, error, ready }

/// `useHostedRuntimeModels`: the offered models, fetched once per mount while
/// [enabled] and again on [reload].
class HostedModelsLoader extends ChangeNotifier {
  HostedModelsLoader(this.controller, {this.kind = hostedRuntimeProviderKind});

  final WorkspaceController controller;
  final String kind;

  HostedModelsStatus _status = HostedModelsStatus.loading;
  HostedModelsList? _view;
  bool _disposed = false, _started = false;
  int _request = 0;

  HostedModelsStatus get status => _status;
  HostedModelsList? get view => _view;

  /// Reads the list the first time [enabled] turns on; a later call is a
  /// no-op until [reload].
  void ensure(bool enabled) {
    if (!enabled || _started) return;
    _started = true;
    unawaited(reload());
  }

  Future<void> reload() async {
    final w = controller;
    final request = ++_request;
    final authority = workspaceAuthority(w);
    _started = true;
    final was = _status;
    _status = HostedModelsStatus.loading;
    if (was != HostedModelsStatus.loading) _notify();
    try {
      final parsed = HostedModelsList.parse(
        await w.query(hostedRuntimeModelsListPath(kind)),
      );
      if (_disposed ||
          request != _request ||
          authority != workspaceAuthority(w)) {
        return;
      }
      _view = parsed;
      _status = parsed == null
          ? HostedModelsStatus.error
          : HostedModelsStatus.ready;
    } catch (_) {
      if (_disposed ||
          request != _request ||
          authority != workspaceAuthority(w)) {
        return;
      }
      _status = HostedModelsStatus.error;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
