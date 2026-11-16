// An agent's Lounge as a conversation (Web v1.24 features/channel/ChatPanel.tsx
// `isLounge`): the header names it "{Name}'s Lounge" and draws its agent's face
// with the Lounge mark (`LoungeAvatar`), a notice under the header says who is
// here, the composer reads "Message {Name}'s Lounge", and where the viewer may
// read but not post (`canPost` false) the composer is a disabled stand-in.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart';
import '../data/user_error.dart' show userErrorText;
import '../data/workspace_controller.dart';
import 'agent_lounge.dart';
import 'sender_avatar_projection.dart';
import 'workspace_channel_header.dart' show WorkspaceChannelHeader;

/// The Lounge's header: the DM header's layout (its agent's face opens that
/// agent's profile, the name, the muted bell, Search and Settings), without a
/// presence light. Null where [header]'s channel is not a Lounge.
Widget? loungeHeaderFor(BuildContext context, WorkspaceChannelHeader header) {
  final channel = header.channel, controller = header.controller;
  final agentId = channel.loungeAgentId;
  if (agentId == null) return null;
  final name = loungeAgentName(controller, channel);
  final agent = controller.services.entityDirectory.agent(agentId);
  final face = projectSenderAvatar(
    origin: controller.client.origin,
    senderId: agentId,
    senderType: 'agent',
    agents: [
      if (agent != null) {...agent, 'id': agentId},
    ],
    members: const [],
  );
  return RaftDmHeader(
    key: header.headerKey,
    name: loungeTitle(context, controller, channel),
    avatar: RaftLoungeAvatar(
      name: name,
      content: RaftAvatarContent(
        name: name,
        kind: RaftAvatarContentKind.agent,
        uploadedUrl: face.uploadedUrl,
        pixelKey: face.pixelKey,
        fallback: const RaftMountedAvatarFallback(
          avatarContext: RaftMountedAvatarContext.panelHeader,
          identity: RaftMountedAvatarIdentity.agent,
        ),
      ),
    ),
    avatarSemanticLabel: name,
    muted: channel.flag('activityMuted'),
    mutedLabel: raftText(
      context,
      'Activity muted. Direct mentions can still notify you.',
    ),
    onBack: header.onBack,
    backKey: header.backKey,
    backLabel: header.backLabel,
    onSearch: header.onSearch,
    onSettings: header.onSettings,
    onAvatarTap: () => controller.openProfile(RaftProfileKind.agent, agentId),
    searchLabel: raftText(context, 'Search This Channel'),
    settingsLabel: raftText(context, 'Channel Details and Settings'),
  );
}

/// "Who is here", always on top of the conversation (`lounge-audience-notice`);
/// null for any other conversation.
Widget? loungeAudienceNotice(
  BuildContext context,
  WorkspaceController w, {
  required bool thread,
}) {
  if (thread || !isLoungeChannel(w.channel)) return null;
  return RaftPanelNotice(
    key: const ValueKey('lounge-audience-notice'),
    status: RaftPanelNoticeRecipeStatus.info,
    content: (context, style) => Text(
      raftText(
        context,
        'Members of this server can take part. Other agents can read it.',
      ),
      style: style,
    ),
  );
}

/// The Lounge composer's placeholder, "Message {Name}'s Lounge"; null for any
/// other conversation.
String? loungeComposerHint(BuildContext context, WorkspaceController w) {
  final channel = w.channel;
  if (channel == null || !isLoungeChannel(channel)) return null;
  return raftFormat(context, 'Message {channel}', {
    'channel': loungeTitle(context, w, channel),
  });
}

/// An archived Lounge's banner action (Web `LoungeUnarchiveAction`): a Lounge
/// has no settings page to open, so the banner unarchives in place, and only
/// for viewers whose server role may archive channels (the caller decides). A
/// refusal shows the server's words, else "Failed to unarchive channel".
Future<void> unarchiveLounge(
  BuildContext context,
  WorkspaceController w,
) async {
  final id = w.channel?.id;
  if (id == null) return;
  final scope = w.client.generation;
  try {
    await w.command('POST', '/channels/$id/unarchive');
    if (scope == w.client.generation) await w.refreshChannel(id);
  } catch (e) {
    if (context.mounted && scope == w.client.generation) {
      showRaftToast(
        context,
        userErrorText(
          e,
          fallback: 'Failed to unarchive channel',
          where: 'unarchive lounge',
        ),
      );
    }
  }
}
