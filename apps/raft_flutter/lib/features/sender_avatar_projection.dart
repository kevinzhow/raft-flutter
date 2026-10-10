import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'public_avatar_url.dart';

/// Permitted presentation fields only. URLs/hashes are transient discovery data,
/// never persisted or logged; the pure renderer performs public image requests.
class SenderAvatarProjection {
  const SenderAvatarProjection({
    required this.identity,
    required this.kind,
    this.uploadedUrl,
    this.gravatarUrl,
    this.pixelKey,
  });
  final String identity, kind;
  final String? uploadedUrl, gravatarUrl, pixelKey;
}

bool raftUploadedHumanAvatar(String? value) {
  final uri = value == null ? null : Uri.tryParse(value);
  return uri != null &&
      RegExp(
        r'^/(?:api/)?avatars/users/[0-9a-f]+\.webp$',
        caseSensitive: false,
      ).hasMatch(uri.path);
}

SenderAvatarProjection projectSenderAvatar({
  required String origin,
  required String senderId,
  required String senderType,
  required List<Map<String, dynamic>> agents,
  required List<Map<String, dynamic>> members,
  Map<String, dynamic>? currentUser,
  Map<String, dynamic>? externalAuthor,
  double requestSize = 80,
  // Message-carried `senderAvatarUrl`: the first-paint source when the
  // directory has no row for this sender yet (never overrides a directory row).
  String? carriedAvatarUrl,
}) {
  if (senderType == 'external_projection') {
    return SenderAvatarProjection(
      identity: '$senderType:$senderId',
      kind: 'app',
      uploadedUrl: raftPublicAvatarUrl(
        origin,
        externalAuthor?['avatarUrl'] as String?,
      ),
    );
  }
  final isAgent = senderType == 'agent';
  final rows = isAgent ? agents : members;
  Map<String, dynamic>? resolved;
  for (final row in rows) {
    if ((isAgent ? row['id'] : row['userId'] ?? row['id']) == senderId) {
      resolved = row;
      break;
    }
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
  var hash = resolved?['gravatarHash'];
  if (currentUser?['id'] == senderId) {
    // Own identity is permitted even before the member directory arrives.
    resolved ??= currentUser;
    hash ??= resolved?['gravatarHash'];
    final email = currentUser?['email'];
    if (hash == null && email is String && email.trim().isNotEmpty) {
      hash = sha256.convert(utf8.encode(email.trim().toLowerCase())).toString();
    }
  }
  final humanUrl = resolved == null ? carriedAvatarUrl : resolved['avatarUrl'];
  return SenderAvatarProjection(
    identity: 'user:$senderId',
    kind: 'human',
    uploadedUrl: humanUrl is String && raftUploadedHumanAvatar(humanUrl)
        ? raftPublicAvatarUrl(origin, humanUrl)
        : null,
    gravatarUrl:
        hash is String &&
            RegExp(r'^[0-9a-f]{64}$', caseSensitive: false).hasMatch(hash)
        ? Uri.https('www.gravatar.com', '/avatar/${hash.toLowerCase()}', {
            's': '${requestSize.round()}',
            'd': '404',
          }).toString()
        : null,
  );
}
