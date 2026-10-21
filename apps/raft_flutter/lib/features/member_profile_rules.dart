/// Pure ports of the Web human profile rules (`HumanDetailPanel.tsx`,
/// `humanMembershipStatus.ts`, `humanRoleTransitions.ts`,
/// `resolveHumanProfile.ts`) so they are testable without widgets.
library;

import 'member_server_badges.dart';

/// `getHumanDepartureLabel`: `Left` / `Removed` for a departed member.
String? humanDepartureLabel(Object? membershipStatus) =>
    switch (membershipStatus) {
      'left' => 'Left',
      'removed' => 'Removed',
      _ => null,
    };

/// `human.displayName || human.name` (empty strings fall back, unlike `??`).
String humanDisplayName(Map? row) {
  final display = row?['displayName'];
  if (display is String && display.isNotEmpty) return display;
  final name = row?['name'];
  return name == null ? '' : '$name';
}

/// `isRemoteJointHuman`: the profile belongs to a different server than the
/// one currently open (joint-channel peer).
bool isRemoteJointHuman(Map profile, String? currentServerId) {
  final serverId = profile['serverId'];
  return currentServerId != null &&
      currentServerId.isNotEmpty &&
      serverId is String &&
      serverId.isNotEmpty &&
      serverId != currentServerId;
}

/// `human.profileProjection === "channel_summary"` (identity-only card).
bool isChannelSummaryHuman(Map profile) =>
    profile['profileProjection'] == 'channel_summary';

/// `sourceServerLabel`: every server the person participates through when any
/// of them is not the open one, joined with ", " (a person on both sides of a
/// joint channel lists both); null for a purely local profile.
String? humanSourceServerLabel(Map profile, String? currentServerId) {
  final labels = memberServerBadgeLabels(profile, currentServerId);
  return labels.isEmpty ? null : labels.join(', ');
}

/// `membershipStatus === "active"`. The server always sends the field on the
/// profile route; a live directory row without it is treated as active
/// (`resolveHumanProfile.ts`: live-only members are `membershipStatus:"active"`).
bool isActiveMembership(Object? membershipStatus) =>
    membershipStatus == null || membershipStatus == 'active';

/// `getEditableHumanServerRoles` (`humanRoleTransitions.ts:5-25`) with
/// `canTransitionServerRole` (`serverPermissions.ts:207-222`).
List<String> editableHumanServerRoles({
  required String? actorRole,
  required String? targetRole,
  required bool isSelf,
  required int ownerCount,
  required bool serverGuestEnabled,
}) {
  if (targetRole == null || targetRole.isEmpty) return const [];
  if (!serverGuestEnabled && targetRole == 'guest') return const [];
  bool can(String next) {
    if (actorRole == null || actorRole.isEmpty || targetRole == next) {
      return false;
    }
    if (actorRole == 'owner') {
      return !(targetRole == 'owner' && next != 'owner' && ownerCount <= 1);
    }
    if (actorRole == 'admin') {
      return !isSelf &&
          targetRole != 'owner' &&
          targetRole != 'admin' &&
          next != 'owner' &&
          (targetRole == 'member' || targetRole == 'guest');
    }
    return false;
  }

  return [
    for (final r in const ['owner', 'admin', 'member', 'guest'])
      if ((serverGuestEnabled || r != 'guest') && can(r)) r,
  ];
}

/// `canEditRole`.
bool canEditHumanRole({
  required Object? membershipStatus,
  required bool remoteJoint,
  required bool hasChangeMemberRoles,
  required List<String> editableRoles,
}) =>
    isActiveMembership(membershipStatus) &&
    !remoteJoint &&
    hasChangeMemberRoles &&
    editableRoles.isNotEmpty;

/// `canRemove`: owners need another owner to be removable, an owner actor may
/// remove anyone else, an admin only plain members.
bool canRemoveHuman({
  required Object? membershipStatus,
  required bool remoteJoint,
  required bool hasRemoveMembers,
  required bool isSelf,
  required String? targetRole,
  required String? actorRole,
  required int ownerCount,
}) =>
    isActiveMembership(membershipStatus) &&
    !remoteJoint &&
    hasRemoveMembers &&
    !isSelf &&
    (targetRole == 'owner'
        ? actorRole == 'owner' && ownerCount > 1
        : actorRole == 'owner' || targetRole == 'member');

/// `canMessageHuman`: guests (either side) only reach an existing DM.
bool canMessageHuman({
  required Object? membershipStatus,
  required bool remoteJoint,
  required String? actorRole,
  required String? targetRole,
  bool hasExistingDm = false,
}) =>
    isActiveMembership(membershipStatus) &&
    !remoteJoint &&
    ((actorRole != 'guest' && targetRole != 'guest') || hasExistingDm);
