/// Raft shared serverPermissions.ts at the pinned reference revision.
const raftServerCapabilities = <String>{
  'viewChannel',
  'createChannels',
  'editChannelMetadata',
  'archiveChannels',
  'deleteChannels',
  'changeChannelVisibility',
  'manageGuestAccess',
  'federateChannels',
  'viewChannelMembers',
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
};
const _memberCapabilities = <String>{
  'viewServerProfile',
  'viewChannel',
  'createChannels',
  'viewChannelMembers',
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
  'manageGuestAccess',
  'federateChannels',
  'addChannelMembers',
  'removeChannelMembers',
  'changeChannelMemberRoles',
};
bool raftCan(
  String? role,
  String capability, {
  Map<String, dynamic>? channelCapabilities,
}) {
  if (!raftServerCapabilities.contains(capability)) return false;
  if (channelCapabilities != null &&
      _channelManagementCapabilities.contains(capability)) {
    return channelCapabilities[capability] == true;
  }
  return switch (role) {
    'owner' => true,
    'admin' => capability != 'manageBilling',
    'member' => _memberCapabilities.contains(capability),
    _ => false,
  };
}
