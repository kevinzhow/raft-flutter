import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/session_scope.dart';

/// Live facts. Constructing a snapshot does not advance or normalize an epoch.
typedef WorkspaceSessionIdentity = ({
  String origin,
  int generation,
  String? principalId,
  String? serverId,
  String? role,
});

/// Receiver-local authority, lifecycle and the existing ordered transitions.
/// Domain state and I/O are supplied through separate explicit ports.
abstract interface class WorkspaceSessionContext {
  /// Original receiver identity, including the existing task-discussion tag.
  Object get receiverKey;
  bool get disposed;
  WorkspaceSessionIdentity get identity;
  RaftRecord? get server;
  bool can(String capability, {RaftChannel? resource});
  bool isChannelRevoked(String id);
  bool isServerRevoked(String id);
  String syncIdentity();
  String? panelIdentity();
  WorkspaceTransitionPort get transitions;

  /// Enters the original notification pipeline; does not coalesce notifications.
  void changed();
}

/// Adapts the existing SessionScope. It exposes no binding or handler maps.
/// Registration/disposal stays at the single composition root.
abstract interface class WorkspaceTransitionPort {
  ServerSelection selectServer(RaftRecord next);
  void resetServer(String? serverId);
  void revokeServer(String serverId);
  void revokeChannel(String channelId);
}
