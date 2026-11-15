// Web utils/activityTrajectoryRecovery.ts: the Activity overview and the
// profile's Recent activity reload their turns the way the raw log does. A
// status frame without trajectory entries (a turn finished, the state moved)
// reloads after 250 ms; a reconnect reloads after 500 ms, because the live
// stream only appends while the socket stays healthy. Heartbeat and probe
// refresh frames only restate the status, and frames with entries are already
// appended elsewhere. One reload runs at a time; one more follows if another
// was asked for meanwhile.
import 'dart:async';

import 'package:raft_client/raft_client.dart';

class AgentActivityReload {
  AgentActivityReload({
    required Stream<RaftEvent> events,
    required this.agentId,
    required this.load,
  }) {
    _subscription = events.listen(_event);
  }

  final String agentId;
  final Future<void> Function() load;
  StreamSubscription<RaftEvent>? _subscription;
  Timer? _timer;
  bool _inFlight = false, _pending = false, _disposed = false;

  void _event(RaftEvent e) {
    if (e.name == 'connected') {
      _schedule(const Duration(milliseconds: 500));
      return;
    }
    final p = e.payload;
    if (e.name != 'agent:activity' ||
        p is! Map ||
        p['agentId'] != agentId ||
        p['isHeartbeat'] == true ||
        p['isRefreshOnly'] == true ||
        (p['entries'] is List && (p['entries'] as List).isNotEmpty)) {
      return;
    }
    _schedule(const Duration(milliseconds: 250));
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      _timer = null;
      unawaited(_run());
    });
  }

  Future<void> _run() async {
    if (_disposed) return;
    if (_inFlight) {
      _pending = true;
      return;
    }
    _inFlight = true;
    try {
      await load();
    } finally {
      _inFlight = false;
      if (_pending && !_disposed) {
        _pending = false;
        unawaited(_run());
      }
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _subscription?.cancel();
  }
}
