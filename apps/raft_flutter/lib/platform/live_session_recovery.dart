import 'dart:async';

import 'package:raft_client/raft_client.dart' show RaftEvent;
import 'package:raft_ui/raft_ui.dart' show RaftForegroundPeriodic;

import '../data/workspace_controller.dart';

/// One visible-session watchdog per root coordinator. The directory owns the
/// accepted state; this host only schedules its bounded recovery policy.
class LiveSessionRecovery {
  LiveSessionRecovery({DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final DateTime Function() clock;
  WorkspaceController? _workspace;
  StreamSubscription<RaftEvent>? _connection;
  RaftForegroundPeriodic? _timer;

  void bind(WorkspaceController? workspace) {
    final root = workspace?.ownsClient == true ? workspace : null;
    if (identical(root, _workspace)) return;
    _timer?.dispose();
    _timer = null;
    unawaited(_connection?.cancel());
    _workspace = root;
    _connection = root?.client.events.listen((event) {
      if (event.name == 'connected' ||
          event.name == 'disconnected' ||
          event.name == 'connection:error') {
        _syncTimer();
      }
    }, onDone: _stopTimer);
    _syncTimer();
  }

  void _stopTimer() {
    _timer?.dispose();
    _timer = null;
  }

  void _syncTimer() {
    if (_workspace?.client.connected != true) {
      _stopTimer();
      return;
    }
    _timer ??= RaftForegroundPeriodic(
      const Duration(seconds: 10),
      () => _workspace?.services.liveConnection?.check(now: clock()),
    );
  }

  void dispose() {
    _stopTimer();
    unawaited(_connection?.cancel());
    _connection = null;
    _workspace = null;
  }
}
