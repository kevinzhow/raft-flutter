import 'package:raft_client/raft_client.dart';

import 'workspace_session_bindings.dart';

/// Server membership events share one authority-recovery path. A peer's
/// departure changes the entity directory only; self events must also refresh
/// server membership, channels and DMs, as Web refreshMembersForServer does.
void consumeWorkspaceMemberEvent(
  RaftEvent event, {
  required RaftClient client,
  required WorkspaceSessionEntries entries,
  required WorkspaceSessionChannels directory,
}) {
  if (!const {
    'server:member-added',
    'server:member:left',
    'server:member-removed',
    'server:member-updated',
  }.contains(event.name)) {
    return;
  }
  final payload = event.payload;
  if (payload is! Map ||
      (payload['serverId'] != null && payload['serverId'] != client.serverId)) {
    return;
  }
  final updated = event.name == 'server:member-updated';
  if (updated) entries.applyMembershipRole(payload);
  if (updated || payload['userId'] == client.user?.id) {
    entries.recoverMembership();
    directory.refreshChannels();
  }
}
