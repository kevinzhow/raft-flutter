import 'dart:async';

import 'package:raft_client/raft_client.dart' show RaftChannel, RaftMessage;

import '../data/read_receipts.dart';
import '../data/workspace_controller.dart';

/// Web MentionLink #693: whether an @mentioned agent has read [message], for
/// the marker on its mention. Only the human who sent the message sees it
/// (`agentReadBadgesEnabled`), only for agents, and only where the server
/// reports per-peer read frontiers: `null` draws
/// nothing, never "unread".
bool? agentMentionRead(
  WorkspaceController w,
  RaftMessage message,
  String agentId, {
  bool hydrate = true,
}) {
  final channelId = message.channelId;
  final channel = channelId == w.threadChannelId
      ? w.messageDomain.threadSourceChannel
      : w.messageDomain.threadChannelResource(channelId);
  if (w.services.entityDirectory.agent(agentId)?['managedByAppInstallId'] !=
          null ||
      w.sessionScope.revokedChannels.contains(channelId) ||
      w.sessionScope.revokedServers.contains(w.client.serverId)) {
    return null;
  }
  if (!agentReadEligible(channel, message, w.client.user?.id)) return null;
  if (hydrate) watchReadFrontiers(w, channelId);
  return projectAgentReadReceipt(
    w.readReceipts.scope(channelId),
    agentId,
    int.tryParse(message.string('seq')),
  );
}

String? agentMentionReadRevision(WorkspaceController w, RaftMessage message) {
  final mentions = message.json['mentions'];
  if (message.senderId != w.client.user?.id || mentions is! List) return null;
  final revision = StringBuffer();
  for (final mention in mentions) {
    if (mention case {'type': 'agent', 'id': final String id}) {
      revision.write(switch (agentMentionRead(w, message, id, hydrate: false)) {
        true => 'r',
        false => 'u',
        null => '-',
      });
    }
  }
  return revision.isEmpty ? null : revision.toString();
}

/// Whether [message] may carry read markers: its sender is the viewer, a
/// human, in a channel that has read frontiers (Web
/// `isReadReceiptScopeEligible`: the accepted detail decides which peers count.
bool agentReadEligible(
  RaftChannel? channel,
  RaftMessage message,
  String? viewerId,
) =>
    channel != null &&
    viewerId != null &&
    message.senderId == viewerId &&
    const {'user', 'human'}.contains(message.string('senderType')) &&
    channel.name != 'all';

class _ReadFrontierRequests {
  Object? identity;
  final scopes = <String>{};
}

final _asked = Expando<_ReadFrontierRequests>('read receipt scopes asked');

/// Reads the channel's read frontiers once per session; mounted views subscribe
/// to [ReadReceipts] directly so live updates do not broadcast workspace-wide.
void watchReadFrontiers(WorkspaceController w, String channelId) {
  final receipts = w.readReceipts;
  final asked = _asked[w] ??= _ReadFrontierRequests();
  final identity = (
    w.client.origin,
    w.client.user?.id,
    w.client.generation,
    w.client.serverId,
  );
  if (asked.identity != identity) {
    asked.identity = identity;
    asked.scopes.clear();
  }
  if (!asked.scopes.add(channelId)) return;
  if (receipts.wasHydrated(channelId)) return;
  unawaited(receipts.hydrate(channelId));
}
