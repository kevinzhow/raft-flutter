/// Web agent profile gates (`AgentDetailPanel.tsx`, `agentVisibility.ts`).
///
/// A joint-channel agent from another server, or a `channel_summary`
/// projection, stays on the public profile for every viewer. On this server
/// the creator keeps the private pages even when they are only a member.
library;

/// `isRemoteJointAgent`: the agent belongs to a different server than the one
/// currently open.
bool isRemoteJointAgent(Map agent, String? currentServerId) {
  final serverId = agent['serverId'];
  return currentServerId != null &&
      currentServerId.isNotEmpty &&
      serverId is String &&
      serverId.isNotEmpty &&
      serverId != currentServerId;
}

/// `agent.profileProjection === "channel_summary"`.
bool isChannelSummaryAgent(Map agent) =>
    agent['profileProjection'] == 'channel_summary';

/// `isBoundedPublicProjection`.
bool isBoundedPublicAgent(Map agent, String? currentServerId) =>
    isRemoteJointAgent(agent, currentServerId) || isChannelSummaryAgent(agent);

/// `agent.serverName || agent.serverSlug`, only for a remote joint agent.
String? agentSourceServerLabel(Map agent, String? currentServerId) {
  if (!isRemoteJointAgent(agent, currentServerId)) return null;
  for (final key in const ['serverName', 'serverSlug']) {
    final value = agent[key];
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}

/// `creatorType === "user" && creatorId === currentUserId`.
bool agentCreatorIsCurrentUser(Map agent, String? currentUserId) =>
    currentUserId != null &&
    currentUserId.isNotEmpty &&
    agent['creatorType'] == 'user' &&
    agent['creatorId'] == currentUserId;

/// `canViewAgentPrivateSurfaces`.
bool canViewAgentPrivateSurfaces(
  Map agent,
  String? currentUserId,
  bool capability,
) => capability || agentCreatorIsCurrentUser(agent, currentUserId);

/// The flags [AgentDetailPanel] uses, matching Web's panel gates.
///
/// A bounded projection forces the public profile even when the viewer is the
/// creator or holds `editAgents` on the current server. Private tabs would
/// read data that projection does not carry.
class AgentProfileAccess {
  const AgentProfileAccess({
    required this.boundedPublic,
    required this.canManage,
    required this.canViewPrivate,
    required this.canControlRuntime,
    required this.sourceServerLabel,
    this.canStopHostedTurn = false,
  });

  final bool boundedPublic;
  final bool canManage;
  final bool canViewPrivate;
  final bool canControlRuntime;

  /// A cloud agent, for a viewer who may control runtimes (or its creator):
  /// the one command "Stop current turn" (the profile offers it while the
  /// agent is up, by the status it just read).
  final bool canStopHostedTurn;
  final String? sourceServerLabel;
}

AgentProfileAccess agentProfileAccess({
  required Map agent,
  required String? currentServerId,
  required String? currentUserId,
  required bool editAgents,
  required bool controlAgentRuntime,
  required bool external,
}) {
  final bounded = isBoundedPublicAgent(agent, currentServerId);
  final canManage =
      !bounded && canViewAgentPrivateSurfaces(agent, currentUserId, editAgents);
  final canViewPrivate =
      !bounded && canViewAgentPrivateSurfaces(agent, currentUserId, canManage);
  final canControl =
      !bounded &&
      !external &&
      canViewAgentPrivateSurfaces(agent, currentUserId, controlAgentRuntime);
  final hosted = agent['hostedRuntime'];
  return AgentProfileAccess(
    boundedPublic: bounded,
    canManage: canManage,
    canViewPrivate: canViewPrivate,
    canControlRuntime: canControl,
    canStopHostedTurn:
        !bounded &&
        external &&
        hosted is Map &&
        canViewAgentPrivateSurfaces(agent, currentUserId, controlAgentRuntime),
    sourceServerLabel: agentSourceServerLabel(agent, currentServerId),
  );
}

/// Web PixelAvatar `isCustomAvatar`: an uploaded image, not `pixel:*` artwork.
bool isCustomAgentAvatar(String? avatarUrl) =>
    avatarUrl != null &&
    avatarUrl.isNotEmpty &&
    !avatarUrl.startsWith('pixel:');
