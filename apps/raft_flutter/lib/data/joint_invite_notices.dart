import 'system_notification_projection.dart';

/// One row of `GET /channels/joint-invites`: an invite to the current server
/// addressed to the current user (Web `PendingJointInvite`).
class PendingJointInvite {
  const PendingJointInvite({
    required this.id,
    required this.fromServerName,
    required this.fromServerSlug,
    required this.channelName,
    required this.expiresAt,
  });
  final String id, fromServerName, fromServerSlug, channelName, expiresAt;
}

/// Parses the response; rows without an id are skipped rather than invented.
List<PendingJointInvite> parseJointInvites(dynamic raw) {
  final rows = raw is Map ? raw['invites'] : null;
  if (rows is! List) return const [];
  return [
    for (final row in rows)
      if (row is Map && row['id'] is String && (row['id'] as String).isNotEmpty)
        PendingJointInvite(
          id: row['id'] as String,
          fromServerName: '${row['fromServerName'] ?? ''}',
          fromServerSlug: '${row['fromServerSlug'] ?? ''}',
          channelName: '${row['channelName'] ?? ''}',
          expiresAt: '${row['expiresAt'] ?? ''}',
        ),
  ];
}

/// RFC 075 section 4.5: only owners and admins can be invited (and accept), so
/// nobody else reads the list (Web `usePendingJointInvites`).
bool canBeInvitedToJointChannel(Map<String, dynamic>? server) =>
    server != null && ['owner', 'admin'].contains(server['role']);

/// The notification-center rows for [invites]; Web puts them first
/// (useSystemNotifications section 0a). The dismissal key is the id.
List<SystemNotice> jointInviteNotices(List<PendingJointInvite> invites) => [
  for (final invite in invites)
    SystemNotice(
      id: 'joint-invite:${invite.id}',
      kind: SystemNoticeKind.info,
      title: 'Invitation to join #${invite.channelName}',
      body: '${invite.fromServerName} invited this server to a joint channel.',
      destination: SystemNoticeDestination.jointInvite,
      targetId: invite.id,
      fingerprint: 'joint-invite:${invite.id}',
      parameters: {
        'channel': invite.channelName,
        'server': invite.fromServerName,
      },
    ),
];
