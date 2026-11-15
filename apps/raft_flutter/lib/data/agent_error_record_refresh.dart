// Web store/agentErrorRecordRefresh.ts (#proj-raft-computer:#48): the server
// stores an agent's runtime error (with its `requiredAction`) but pushes only
// the error activity, and emits that before the store write. When an error
// shows that the agent's record does not describe, the record is re-read once
// the burst settles, so the own-billing state and the banner update.
//
// Bounded: at most one re-read per agent per distinct error detail. The detail
// last asked for is remembered (one entry per agent, overwritten), so an error
// that never lands in the record (another error path, a failed store write)
// restated by later frames costs no further requests; a different detail asks
// once more.
import 'dart:async';

class AgentErrorRecordRefresh {
  AgentErrorRecordRefresh({
    required this.reread,
    this.delay = const Duration(milliseconds: 1500),
  });

  /// Re-reads one agent's record (`GET /agents/:id`) into its row, keeping the
  /// live activity (the socket's is newer).
  final Future<void> Function(String agentId) reread;
  final Duration delay;
  final _timers = <String, Timer>{};
  final _askedDetail = <String, String>{};

  /// Whether the live error is one the agent's stored record does not describe
  /// yet (Web `agentErrorRecordStale`).
  static bool stale({
    required Object? lastRuntimeError,
    required String activity,
    required String detail,
  }) =>
      activity == 'error' &&
      !(lastRuntimeError is Map && lastRuntimeError['message'] == detail);

  /// Web `scheduleAgentErrorRecordRefresh`.
  void schedule(String agentId, String detail) {
    if (_askedDetail[agentId] == detail) return;
    _askedDetail[agentId] = detail;
    _timers[agentId]?.cancel();
    _timers[agentId] = Timer(delay, () {
      _timers.remove(agentId);
      unawaited(reread(agentId));
    });
  }

  void clear() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _askedDetail.clear();
  }
}
