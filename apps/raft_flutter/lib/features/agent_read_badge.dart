import 'dart:async';

import 'package:raft_client/raft_client.dart' show RaftChannel, RaftMessage;

import '../data/read_receipts.dart';
import '../data/workspace_controller.dart';

/// Web MentionLink #693: whether an @mentioned agent has read [message], for
/// the marker on its mention. Only the human who sent the message sees it
/// (`agentReadBadgesEnabled`), only for agents, and only where the server
/// reports per-peer read frontiers (flag `read_receipts_v0`): `null` draws
/// nothing, never "unread".
bool? agentMentionRead(
  WorkspaceController w,
  RaftMessage message,
  String agentId,
) {
  final channelId = message.channelId;
  final channel = [
    ...w.channels,
    ...w.dms,
  ].where((c) => c.id == channelId).firstOrNull;
  if (!agentReadEligible(channel, message, w.client.user?.id)) return null;
  watchReadFrontiers(w, channelId);
  return projectAgentReadReceipt(
    w.readReceipts.scope(channelId),
    agentId,
    int.tryParse(message.string('seq')),
  );
}

/// Whether [message] may carry read markers: its sender is the viewer, a
/// human, in a channel that has read frontiers (Web
/// `isReadReceiptScopeEligible`: not `all`, a joint channel or a thread).
bool agentReadEligible(
  RaftChannel? channel,
  RaftMessage message,
  String? viewerId,
) =>
    channel != null &&
    viewerId != null &&
    message.senderId == viewerId &&
    const {'user', 'human'}.contains(message.string('senderType')) &&
    channel.name != 'all' &&
    channel.type != 'joint' &&
    channel.type != 'thread';

class _ReadFrontierRequests {
  Object? identity;
  final scopes = <String>{};
}

final _asked = Expando<_ReadFrontierRequests>('read receipt scopes asked');
final _watched = Expando<bool>('read receipts watched');

/// Reads the channel's read frontiers once per session, and repaints the rows
/// when they arrive or move.
void watchReadFrontiers(WorkspaceController w, String channelId) {
  final receipts = w.readReceipts;
  if (_watched[w] != true) {
    _watched[w] = true;
    receipts.addListener(w.notifyListeners);
    w.services.disposeWithSession(
      () => receipts.removeListener(w.notifyListeners),
    );
  }
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
  if (receipts.scope(channelId) != null) return;
  unawaited(receipts.hydrate(channelId));
}
