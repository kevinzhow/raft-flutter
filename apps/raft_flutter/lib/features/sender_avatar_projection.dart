import 'external_sender.dart';
import 'public_avatar_url.dart';

/// Permitted presentation fields only. URLs are transient discovery data,
/// never persisted or logged; the pure renderer performs public image requests.
///
/// No Gravatar: server v1.24 retired `gravatarHash` (always empty,
/// shared actorResolveContract.ts DEPRECATED_GRAVATAR_HASH) and Web v1.24
/// deleted GravatarAvatar, ignoring a hash an older server still sends. A
/// person without an uploaded avatar draws the placeholder on every server.
class SenderAvatarProjection {
  const SenderAvatarProjection({
    required this.identity,
    required this.kind,
    this.uploadedUrl,
    this.pixelKey,
  });
  final String identity, kind;
  final String? uploadedUrl, pixelKey;
}

bool raftUploadedHumanAvatar(String? value) {
  final uri = value == null ? null : Uri.tryParse(value);
  return uri != null &&
      RegExp(
        r'^/(?:api/)?avatars/users/[0-9a-f]+\.webp$',
        caseSensitive: false,
      ).hasMatch(uri.path);
}

/// How a person's avatar is drawn (Web utils/humanAvatar.ts
/// `humanAvatarSource`, v1.24): their uploaded photo, their built pixel
/// avatar (`pixel-human:v1:...`, shared humanAvatar.ts), or the User
/// placeholder (none, or one Raft doesn't draw, such as an older social
/// provider's profile URL).
enum RaftHumanAvatarSource { uploaded, pixel, placeholder }

RaftHumanAvatarSource raftHumanAvatarSource(String? avatarUrl) {
  if (raftUploadedHumanAvatar(avatarUrl)) return RaftHumanAvatarSource.uploaded;
  if (avatarUrl != null && avatarUrl.startsWith('pixel-human:v1:')) {
    return RaftHumanAvatarSource.pixel;
  }
  return RaftHumanAvatarSource.placeholder;
}

SenderAvatarProjection projectSenderAvatar({
  required String origin,
  required String senderId,
  required String senderType,
  required List<Map<String, dynamic>> agents,
  required List<Map<String, dynamic>> members,
  Map<String, dynamic>? currentUser,
  Map<String, dynamic>? externalAuthor,
  // Message-carried `senderAvatarUrl`: the first-paint source when the
  // directory has no row for this sender yet (never overrides a directory row).
  String? carriedAvatarUrl,
  // The open channel's roster (`GET /channels/:id/members`): the only place a
  // joint-peer sender (another server's human or agent) is listed, since the
  // server directory holds this server's people only. Web `ChatPanel` overlays
  // it on the directory (`memberById` / `agentById`), so it is searched first.
  List<Map<String, dynamic>> channelAgents = const [],
  List<Map<String, dynamic>> channelMembers = const [],
}) {
  if (senderType == 'external_projection') {
    return SenderAvatarProjection(
      identity: '$senderType:$senderId',
      kind: 'app',
      uploadedUrl: raftPublicAvatarUrl(
        origin,
        externalSenderPresentation(externalAuthor).avatarUrl,
      ),
    );
  }
  final isAgent = senderType == 'agent';
  Map<String, dynamic>? resolved;
  for (final rows
      in isAgent ? [channelAgents, agents] : [channelMembers, members]) {
    for (final row in rows) {
      if ((isAgent ? row['id'] : row['userId'] ?? row['id']) == senderId) {
        resolved = row;
        break;
      }
    }
    if (resolved != null) break;
  }
  final rawUrl = resolved == null ? carriedAvatarUrl : resolved['avatarUrl'];
  if (isAgent) {
    final pixel = rawUrl is String && rawUrl.startsWith('pixel:')
        ? rawUrl.substring(6)
        : null;
    return SenderAvatarProjection(
      identity: 'agent:$senderId',
      kind: 'agent',
      pixelKey: pixel,
      uploadedUrl: pixel == null
          ? raftPublicAvatarUrl(origin, rawUrl is String ? rawUrl : null)
          : null,
    );
  }
  // Own identity is permitted even before the member directory arrives.
  if (currentUser?['id'] == senderId) resolved ??= currentUser;
  final humanUrl = resolved == null ? carriedAvatarUrl : resolved['avatarUrl'];
  return SenderAvatarProjection(
    identity: 'user:$senderId',
    kind: 'human',
    uploadedUrl: humanUrl is String && raftUploadedHumanAvatar(humanUrl)
        ? raftPublicAvatarUrl(origin, humanUrl)
        : null,
  );
}

/// TasksPanel's typed option keys project only the authorized directory's art.
/// Selection, membership and request authority remain with the resource owner.
Map<String, SenderAvatarProjection> projectTaskFilterAvatars({
  required String origin,
  required Iterable<String> identityKeys,
  required List<Map<String, dynamic>> agents,
  required List<Map<String, dynamic>> members,
  Map<String, dynamic>? currentUser,
}) => {
  for (final key in identityKeys)
    if (key.startsWith('user:') || key.startsWith('agent:'))
      key: projectSenderAvatar(
        origin: origin,
        senderId: key.substring(key.indexOf(':') + 1),
        senderType: key.substring(0, key.indexOf(':')),
        agents: agents,
        members: members,
        currentUser: currentUser,
      ),
};
