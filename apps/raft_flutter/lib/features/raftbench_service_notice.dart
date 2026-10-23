// Whether the open conversation is a DM with the RaftBench service agent (Web
// ChatPanel `dmAgent?.raftbenchService`); its footer is RaftbenchServiceDmNotice.
import '../data/workspace_controller.dart';

/// Web `dmAgent?.raftbenchService`: the open conversation is a DM with an
/// agent the server marks as the dedicated RaftBench analysis agent.
bool isRaftbenchServiceDm(WorkspaceController w) {
  final channel = w.channel;
  if (channel == null || channel.type != 'dm') return false;
  final peer = channel.json['peerId'];
  return channel.json['peerType'] == 'agent' &&
      peer is String &&
      w.services.entityDirectory.agent(peer)?['raftbenchService'] == true;
}
