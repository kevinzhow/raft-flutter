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

/// Web `canStopThisTurn` (AgentDetailPanel.tsx): not a bounded projection; a
/// Computer agent, or a hosted external one that is `active`; its creator or
/// anyone with `controlAgentRuntime`; and of a personal assistant only its
/// owner or a server owner/admin.
bool canStopThisAgentTurn({
  required Map agent,
  required String? currentUserId,
  required bool controlAgentRuntime,
  required bool boundedPublic,
  required bool external,
  bool isAssistant = false,
  bool isAssistantOwner = false,
  bool isServerAdmin = false,
}) {
  final hosted = agent['hostedRuntime'];
  final canStopTurn =
      !boundedPublic &&
      (!external || (hosted is Map && hosted['state'] == 'active')) &&
      canViewAgentPrivateSurfaces(agent, currentUserId, controlAgentRuntime);
  return canStopTurn && (!isAssistant || isAssistantOwner || isServerAdmin);
}

/// Web `canStopSubagentsOf` (stopSubagent.ts): a viewer may stop one of this
/// agent's subagents with Stop turn's runtime authority, on a live agent whose
/// runtime can stop a single subagent (Codex, Claude Code, Kimi, Qoder). The
/// server checks the authority again.
bool canStopSubagentsOf({
  required Map agent,
  required bool controlAgentRuntime,
}) =>
    controlAgentRuntime &&
    agent['deletedAt'] == null &&
    const {'codex', 'claude', 'kimi-sdk', 'qoder'}.contains(agent['runtime']);

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

  /// Web `canStopThisTurn`: the one command "Stop current turn" (a Computer
  /// agent, or a hosted external agent whose runtime is active), for a viewer
  /// who may control runtimes (or its creator).
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
  return AgentProfileAccess(
    boundedPublic: bounded,
    canManage: canManage,
    canViewPrivate: canViewPrivate,
    canControlRuntime: canControl,
    canStopHostedTurn: canStopThisAgentTurn(
      agent: agent,
      currentUserId: currentUserId,
      controlAgentRuntime: controlAgentRuntime,
      boundedPublic: bounded,
      external: external,
    ),
    sourceServerLabel: agentSourceServerLabel(agent, currentServerId),
  );
}

/// Web PixelAvatar `isCustomAvatar`: an uploaded image, not `pixel:*` artwork.
bool isCustomAgentAvatar(String? avatarUrl) =>
    avatarUrl != null &&
    avatarUrl.isNotEmpty &&
    !avatarUrl.startsWith('pixel:');
