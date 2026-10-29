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
    // The shared matrix gives a guest nothing server-wide, but `viewChannel`
    // is not a gate on Web (no Web component reads it): whether a guest may
    // read a channel or thread is decided by the server
    // (`canUserAccessChannel` / `canGuestReadChannel`: guest-visible, joined
    // or guest-joinable, feature gate on) and the channel list a guest
    // receives is already filtered to those. Gating on it locally kept guests
    // from loading any channel or thread messages.
    'guest' => capability == 'viewChannel',
    _ => false,
  };
}
