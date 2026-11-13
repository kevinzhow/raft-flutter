// What a socket heartbeat means for this session (Web store/heartbeatGate.ts):
// whether the member rooms are joined, and when a heartbeat re-reads the
// visible scopes.
import 'dart:async';

import 'workspace_session.dart';

/// Server v1.24 socket/index.ts joinMemberConversationRooms: after connecting
/// the rooms are [pending] until `rooms:joined`; a failed room lookup sends
/// `rooms:join_failed` once and keeps retrying, and until `rooms:joined` no
/// channel `message:new` arrives ([failed], Web noteRoomsJoinDegraded).
enum RoomsJoin { joined, pending, failed }

class HeartbeatGate {
  HeartbeatGate._();
  static final _gates = Expando<HeartbeatGate>('heartbeat gate');

  /// The gate of [session]; it lives as long as the session.
  static HeartbeatGate of(WorkspaceSession session) =>
      _gates[session] ??= HeartbeatGate._();

  RoomsJoin rooms = RoomsJoin.joined;
  bool get joining => rooms == RoomsJoin.pending;

  /// `rooms:join_failed`: not joined yet; `rooms:joined` follows.
  void failed() => rooms = RoomsJoin.failed;

  void heartbeat(WorkspaceSession session, dynamic payload) {
    // A lost `rooms:joined`: the connection's first heartbeat stands in.
    if (rooms == RoomsJoin.pending) return session.roomsJoined();
    // Degraded: no message:new until `rooms:joined`, so every heartbeat
    // re-reads what is on screen (Web heartbeatNeedsScopeSync).
    if (rooms == RoomsJoin.failed) {
      return unawaited(session.messages.syncVisibleScopes());
    }
    final seq = payload is Map ? BigInt.tryParse('${payload['seq']}') : null;
    final synced = session.gapSyncedThrough, ledger = session.ledger;
    if (seq == null ||
        seq <= ledger.watermark ||
        synced != null && synced.$1 == ledger.generation && seq <= synced.$2) {
      return;
    }
    unawaited(session.messages.syncVisibleScopes(through: seq));
  }
}
