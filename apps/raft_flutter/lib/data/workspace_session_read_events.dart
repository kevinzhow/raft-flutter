import 'package:raft_client/raft_client.dart';

import 'workspace_session.dart';

/// `read_state:updated` / `read_state:updated_bulk` (Web socketBridge
/// readStateUpdated): each accepted scope fact projects the read into the
/// channel rows and the held message windows, then the ledger is persisted.
void consumeReadStateEvent(WorkspaceSession s, RaftEvent event) {
  if (event.name != 'read_state:updated' &&
      event.name != 'read_state:updated_bulk') {
    return;
  }
  final payload = event.payload;
  final client = s.client;
  if (payload is Map && client.serverId != null && client.user != null) {
    final updates = event.name.endsWith('_bulk')
        ? (payload['scopes'] as List? ?? [])
        : [payload];
    for (final update in updates) {
      if (update is Map) {
        final fact = {...update, 'serverId': payload['serverId']};
        final outcome = s.readState.consumeUpdate(
          fact,
          serverId: client.serverId!,
          principalId: client.user!.id,
        );
        if (outcome == 'accepted' && fact['scopeId'] is String) {
          s.directory.projectReadState(fact['scopeId'] as String);
          s.messages.applyReadStateHint(fact);
        }
      }
    }
  }
  s.directory.persistReadState();
}
