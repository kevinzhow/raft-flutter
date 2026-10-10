import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/personal_presentation.dart';
import 'chat_agent_presentation.dart';
import 'sender_avatar_projection.dart';

/// Source ConnectedLiveAgentActivityBar: shows the newest live work item of
/// the (permission-scoped) [ChatAgentPresentation] when the personal
/// "live activity" preference is on. Data and visibility only; the strip
/// itself is raft_ui's [RaftLiveAgentActivityBar].
class NativeLiveAgentActivityBar extends StatelessWidget {
  const NativeLiveAgentActivityBar({
    super.key,
    required this.activities,
    required this.presentation,
    required this.origin,
  });
  final ChatAgentPresentation activities;
  final PersonalPresentationStore presentation;
  final String origin;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([activities, presentation]),
    builder: (context, _) {
      final latest = activities.latest;
      if (!presentation.value.liveActivity || latest == null) {
        return const SizedBox.shrink();
      }
      final agent = activities.agent(latest.agentId);
      if (agent == null) return const SizedBox.shrink();
      final name = '${agent['displayName'] ?? agent['name'] ?? ''}';
      final avatar = projectSenderAvatar(
        origin: origin,
        senderId: latest.agentId,
        senderType: 'agent',
        agents: [agent],
        members: const [],
        requestSize: 36,
      );
      return RaftLiveAgentActivityBar(
        agentName: name,
        text: raftText(context, latest.text),
        activity: latest.activity == 'thinking'
            ? RaftActivityTone.thinking
            : RaftActivityTone.working,
        avatarContent: RaftAvatarContent(
          name: name,
          kind: RaftAvatarContentKind.agent,
          uploadedUrl: avatar.uploadedUrl,
          pixelKey: avatar.pixelKey,
        ),
      );
    },
  );
}
