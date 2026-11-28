import 'models.dart';

/// Raft shared serverPermissions.ts at the pinned reference revision.
const raftServerCapabilities = <String>{
  'createChannels',
  'editChannelMetadata',
  'archiveChannels',
  'deleteChannels',
  'changeChannelVisibility',
  'manageVisitorAccess',
  'federateChannels',
  'joinPublicChannels',
  'addChannelMembers',
  'removeChannelMembers',
  'changeChannelMemberRoles',
  'viewMembers',
  'inviteMembers',
  'removeMembers',
  'changeMemberRoles',
  'viewServerProfile',
  'viewServerSettings',
  'editServerSettings',
  'manageIntegrations',
  'manageExternalAuth',
  'rotateServerSecrets',
  'viewAgents',
  'createAgents',
  'editAgents',
  'controlAgentRuntime',
  'stopAgents',
  'resetAgentWorkspace',
  'deleteAgents',
  'migrateAgents',
  'issueAgentCredentials',
  'viewMachines',
  'registerMachines',
  'editMachines',
  'controlComputers',
  'removeMachines',
  'rotateMachineKeys',
  'assignTasks',
  'deleteAnyTask',
  'viewBilling',
  'manageBilling',
  'manageSso',
};
const _memberCapabilities = <String>{
  'viewServerProfile',
  'createChannels',
  'joinPublicChannels',
  'addChannelMembers',
  'viewMembers',
  'viewAgents',
  'controlAgentRuntime',
  'viewMachines',
  'assignTasks',
};
const _channelManagementCapabilities = <String>{
  'editChannelMetadata',
  'archiveChannels',
  'deleteChannels',
  'changeChannelVisibility',
  'manageVisitorAccess',
  'federateChannels',
  'addChannelMembers',
  'removeChannelMembers',
  'changeChannelMemberRoles',
};
bool raftCan(
  String? role,
  String capability, {
  Map? channelCapabilities,
  String? channelType,
}) {
  if (!raftServerCapabilities.contains(capability)) return false;
  if (_channelManagementCapabilities.contains(capability)) {
    if (channelCapabilities != null) {
      return channelCapabilities[capability] == true;
    }
    if (channelType == 'joint' || channelType == 'dm') return false;
  }
  return switch (role) {
    'owner' => true,
    'admin' => capability != 'manageBilling' && capability != 'manageSso',
    'member' => _memberCapabilities.contains(capability),
    _ => false,
  };
}

bool raftCanReadAdmittedConversation(String? role) =>
    const {'owner', 'admin', 'member', 'guest'}.contains(role);

bool raftCanInWorkspace(
  String? role,
  String capability, {
  RaftChannel? channel,
}) {
  if (capability == 'viewChannel') return raftCanReadAdmittedConversation(role);
  final projection = channel?.json['channelCapabilities'];
  return raftCan(
    role,
    capability,
    channelCapabilities: projection is Map ? projection : null,
    channelType: channel?.type,
  );
}

bool raftCanProjectedChannel(RaftChannel channel, String capability) {
  final projection = channel.json['channelCapabilities'];
  return _channelManagementCapabilities.contains(capability) &&
      projection is Map &&
      projection[capability] == true;
}

bool raftCanWriteTaskChannel(String? role, RaftChannel? channel) =>
    raftCanReadAdmittedConversation(role) &&
    channel != null &&
    channel.joined &&
    !channel.archived &&
    channel.json['deletedAt'] == null &&
    channel.canPost &&
    (role != 'guest' ||
        channel.name != 'all' &&
            (const {'channel', 'private'}.contains(channel.type) ||
                channel.type == 'joint' &&
                    channel.string('jointRole') == 'host'));

bool raftAuthorizeTaskWrite({
  required bool canWriteChannel,
  required Object? readOnlyReason,
}) => canWriteChannel && readOnlyReason == null;
