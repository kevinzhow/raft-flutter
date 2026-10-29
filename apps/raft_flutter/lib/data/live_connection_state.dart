import 'dart:async';

import 'package:raft_client/raft_client.dart';

import 'workspace_entity_directory.dart';

/// One root-session owner for watchdog timestamps and bounded status recovery.
/// Borrowed presentations do not subscribe or keep their own recovery clocks.
class LiveConnectionState {
  LiveConnectionState({
    required this.client,
    required this.scope,
    required this.directory,
    required this.disposed,
  }) {
    _events = client.events.listen(_event);
  }
  final RaftClient client;
  final WorkspaceEntityScope? Function() scope;
  final WorkspaceEntityDirectory directory;
  final bool Function() disposed;
  DateTime Function() clock = DateTime.now;
  late final StreamSubscription<RaftEvent> _events;
  WorkspaceEntityScope? _acceptedScope;
  DateTime? _heartbeat, _inbound, _statusRead;
  bool _closed = false;

  bool _current() {
    if (_closed || disposed()) return false;
    final next = scope();
    if (_acceptedScope != next) {
      _acceptedScope = next;
      _heartbeat = _inbound = _statusRead = null;
    }
    return next != null;
  }

  void _event(RaftEvent event) {
    if (!_current()) return;
    final at = clock();
    _inbound = at;
    if (event.name == 'connected') _heartbeat = _statusRead = at;
    if (event.name == 'heartbeat') _heartbeat = at;
  }

  /// The visible platform host calls this every ten seconds. A connection
  /// must lack both heartbeats for 90 s and all inbound events for 120 s.
  void check({DateTime? now}) {
    if (!_current() || !client.connected) return;
    final at = now ?? clock();
    final heartbeat = _heartbeat, inbound = _inbound;
    if (heartbeat != null &&
        inbound != null &&
        at.difference(heartbeat) > const Duration(seconds: 90) &&
        at.difference(inbound) > const Duration(seconds: 120)) {
      _heartbeat = _inbound = at;
      client.connect();
      return;
    }
    final last = _statusRead ?? at;
    _statusRead ??= at;
    if (at.difference(last) >= const Duration(minutes: 10)) {
      _statusRead = at;
      if (directory.started) directory.revalidateStatus();
    }
  }

  void dispose() {
    _closed = true;
    unawaited(_events.cancel());
  }
}
