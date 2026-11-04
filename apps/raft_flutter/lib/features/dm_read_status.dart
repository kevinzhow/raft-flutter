import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_messages.dart';
import 'agent_read_badge.dart';

/// Web ChatPanel + MessageItem: the live DM's last row, if its human sender
/// is the viewer and the scope's accepted peer frontier proves it read.
/// A context window's last loaded row is not the conversation's last row.
String? dmReadStatusMessageId(
  WorkspaceController w,
  List<RaftMessage> rows, {
  required bool thread,
}) {
  final channel = w.channel;
  final last = rows.lastOrNull;
  if (thread ||
      w.messageDomain.state.hasNewer ||
      channel?.type != 'dm' ||
      last == null ||
      last.channelId != channel!.id ||
      w.server?.id != w.client.serverId ||
      w.sessionScope.revokedChannels.contains(channel.id) ||
      w.sessionScope.revokedServers.contains(w.client.serverId) ||
      WorkspaceMessages.isPendingSend(last) ||
      !agentReadEligible(channel, last, w.client.user?.id) ||
      last.json['sourceServerId'] != null &&
          last.json['sourceServerId'] != w.client.serverId ||
      ![
        ...w.dms,
        ...w.channels.where((row) => row.type == 'dm'),
      ].any((row) => row.id == channel.id)) {
    return null;
  }
  watchReadFrontiers(w, channel.id);
  return w.readReceipts
          .project(channel.id, int.tryParse(last.string('seq')))
          .read
      ? last.id
      : null;
}
