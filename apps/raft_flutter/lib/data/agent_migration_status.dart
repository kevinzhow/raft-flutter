// Web components/agentMigration/useAgentMigrationStatus + realtime.ts for the
// agent detail panel: the agent's latest migration, read once, re-read on a
// migration push for this agent, a reconnect or the rooms rejoin, and every 2s
// (foreground only) while it is active so a missed push cannot leave it stale.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart' show RaftForegroundPeriodic;

import 'migration_error.dart';
import 'workspace_controller.dart';

class AgentMigrationStatus extends ChangeNotifier {
  AgentMigrationStatus(this.w, this.agentId) {
    // A revisit shows the last accepted status at its first frame.
    final cached = w.agentTabCache.peek(_cacheKey);
    if (cached is Map<String, dynamic>) migration = cached;
    _events = w.client.events.listen(_event);
    unawaited(reload());
  }

  final WorkspaceController w;
  final String agentId;

  /// Web `realtime.ts` `pollMs`.
  static const pollInterval = Duration(seconds: 2);

  /// The latest migration; empty when the agent has none (or none is known).
  Map<String, dynamic> migration = const {};

  /// The last read failed. The accepted migration is kept.
  bool failed = false;

  /// What the failed read threw (Web `statusError` source); null while the
  /// last read succeeded.
  Object? error;

  String get _cacheKey => 'migration-status/$agentId';
  StreamSubscription<RaftEvent>? _events;
  RaftForegroundPeriodic? _poll;
  int _request = 0;
  bool _reading = false, _disposed = false;

  /// Web `isActiveMigrationState(notice.state)`.
  bool get active => migrationPhase(migration['state'] as String?) == 'active';

  void _event(RaftEvent e) {
    final p = e.payload;
    if (e.name == 'connected' ||
        e.name == 'rooms:joined' ||
        e.name == 'agent:migration-updated' &&
            p is Map &&
            p['agentId'] == agentId) {
      unawaited(reload());
    }
  }

  Future<void> reload() async {
    if (_disposed) return;
    final request = ++_request, generation = w.client.generation;
    _reading = true;
    try {
      final value = await w.query('/agents/$agentId/migration');
      if (_disposed ||
          request != _request ||
          generation != w.client.generation) {
        return;
      }
      final next = value is Map && value['migration'] is Map
          ? Map<String, dynamic>.from(value['migration'] as Map)
          : <String, dynamic>{};
      migration = next;
      failed = false;
      error = null;
      if (next.isEmpty) {
        w.agentTabCache.remove(_cacheKey);
      } else {
        w.agentTabCache.put(_cacheKey, next);
      }
    } catch (e) {
      if (_disposed || request != _request) return;
      failed = true;
      error = e;
    } finally {
      _reading = false;
    }
    if (_disposed) return;
    _follow();
    notifyListeners();
  }

  void _follow() {
    if (active) {
      _poll ??= RaftForegroundPeriodic(pollInterval, () {
        if (!_disposed && !_reading) unawaited(reload());
      });
    } else {
      _poll?.dispose();
      _poll = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _events?.cancel();
    _poll?.dispose();
    _poll = null;
    super.dispose();
  }
}
