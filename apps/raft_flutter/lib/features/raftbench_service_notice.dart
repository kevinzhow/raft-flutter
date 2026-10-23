// The footer of a DM with the RaftBench service agent (Web ChatPanel
// `raftbench-service-dm-notice`): the agent is read-only analysis, it never
// replies, so the composer is replaced by an info banner.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

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

class RaftbenchServiceDmNotice extends StatelessWidget {
  const RaftbenchServiceDmNotice({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('raftbench-service-dm-notice'),
    color: RaftTokens.of(context).canvas,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: RaftBanner(
        status: RaftBannerRecipeStatus.info,
        textAlign: TextAlign.center,
        description: 'This read-only analysis agent does not reply to DMs. Results appear on the RaftBench page.',
      ),
    ),
  );
}
