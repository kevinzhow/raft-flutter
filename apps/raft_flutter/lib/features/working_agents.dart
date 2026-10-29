import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/personal_presentation.dart';
import '../data/workspace_controller.dart';
import 'chat_agent_presentation.dart';
import 'composer_directory.dart' show cachedChannelRoster, channelRosterChanges;
import 'route_transition_gate.dart';
import 'sender_avatar_projection.dart';

/// The working agents as raft_ui draws them: avatar artwork from the
/// permission-scoped directory, what each one is doing localized, in the order
/// they started. [only] keeps the agents whose ids are in the set (a channel's
/// members).
List<RaftWorkingAgent> workingAgentEntries(
  BuildContext context,
  ChatAgentPresentation activities,
  String origin, {
  Set<String>? only,
}) => [
  for (final work in activities.working)
    if (only == null || only.contains(work.agentId))
      ?_entry(context, activities, origin, work),
];

RaftWorkingAgent? _entry(
  BuildContext context,
  ChatAgentPresentation activities,
  String origin,
  LiveAgentWork work,
) {
  final agent = activities.agent(work.agentId);
  if (agent == null) return null;
  final name = '${agent['displayName'] ?? agent['name'] ?? ''}';
  final avatar = projectSenderAvatar(
    origin: origin,
    senderId: work.agentId,
    senderType: 'agent',
    agents: [agent],
    members: const [],
    requestSize: 54,
  );
  return RaftWorkingAgent(
    id: work.agentId,
    name: name,
    text: raftText(context, work.text),
    avatar: RaftAvatarContent(
      name: name,
      kind: RaftAvatarContentKind.agent,
      uploadedUrl: avatar.uploadedUrl,
      pixelKey: avatar.pixelKey,
    ),
  );
}

/// The summary at the top of the screen: faces and a count, opening Working
/// now. Hidden when nobody is working or the personal "Live agent activity"
/// preference is off. Data and visibility only; the parts are raft_ui's.
class NativeWorkingAgentsSummary extends StatelessWidget {
  const NativeWorkingAgentsSummary({
    super.key,
    required this.activities,
    required this.presentation,
    required this.origin,
    required this.onOpenAgent,
    this.onFrame = false,
  });
  final ChatAgentPresentation activities;
  final PersonalPresentationStore presentation;
  final String origin;
  final ValueChanged<String> onOpenAgent;
  final bool onFrame;

  @override
  Widget build(BuildContext context) => QuietListenableBuilder(
    listenable: Listenable.merge([activities, presentation]),
    builder: (context, _) {
      if (!presentation.value.liveActivity) return const SizedBox.shrink();
      return RaftWorkingSummary(
        onFrame: onFrame,
        agents: workingAgentEntries(context, activities, origin),
        onOpenAgent: onOpenAgent,
      );
    },
  );
}

/// Builds a channel header's working line: only the agents that are members of
/// [channelId] count, and nothing shows until the channel's roster is known or
/// when the personal "Live agent activity" preference is off.
class NativeChannelWorkingAgents extends StatelessWidget {
  const NativeChannelWorkingAgents({
    super.key,
    required this.controller,
    required this.channelId,
    required this.activities,
    required this.presentation,
    required this.builder,
  });
  final WorkspaceController controller;
  final String channelId;
  final ChatAgentPresentation activities;
  final PersonalPresentationStore presentation;
  final Widget Function(BuildContext context, List<RaftWorkingAgent> working)
  builder;

  @override
  Widget build(BuildContext context) => QuietListenableBuilder(
    listenable: Listenable.merge([
      activities,
      presentation,
      channelRosterChanges(controller),
    ]),
    builder: (context, _) {
      if (!presentation.value.liveActivity || activities.working.isEmpty) {
        return builder(context, const []);
      }
      final roster = cachedChannelRoster(controller, channelId);
      final members = {
        for (final row in roster?.agents ?? const <Map<String, dynamic>>[])
          if (row['id'] is String) row['id'] as String,
      };
      return builder(
        context,
        workingAgentEntries(
          context,
          activities,
          controller.client.origin,
          only: members,
        ),
      );
    },
  );
}
