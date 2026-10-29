import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

import 'profile_preview.dart';
import 'public_avatar_url.dart';

/// Web MessageInput: first usable provider handle, otherwise a compact name.
/// Projection IDs are provider identities, never Raft user or agent IDs.
RaftComposerSuggestion? externalMentionSuggestion(
  String origin,
  Map<String, dynamic> member,
) {
  if (member['provider'] != 'slack' || member['id'] is! String) return null;
  final display = member['displayName'] as String? ?? '';
  final handles = member['handles'];
  final raw =
      (handles is List ? handles.whereType<String>() : <String>[])
          .where((h) => h.trim().isNotEmpty)
          .firstOrNull ??
      display.replaceAll(RegExp(r'\s+'), '');
  final handle = raw.replaceAll(RegExp(r'[^\p{L}\p{N}_-]', unicode: true), '-');
  if (handle.isEmpty || (member['id'] as String).isEmpty) return null;
  return RaftComposerSuggestion(
    type: 'external',
    id: member['id'],
    name: handle,
    title: display,
    detail: 'Slack',
    avatar: externalMentionAvatar(
      origin,
      member,
      RaftAvatarSlotContext.compactList,
    ),
  );
}

Widget externalMentionAvatar(
  String origin,
  Map<String, dynamic> member,
  RaftAvatarSlotContext slot,
) {
  final name = member['displayName'] as String? ?? '';
  return RaftAvatarSlot(
    name: name,
    slot: slot,
    agent: false,
    server: true,
    content: RaftAvatarContent(
      name: name,
      kind: RaftAvatarContentKind.app,
      uploadedUrl: raftPublicAvatarUrl(origin, member['avatarUrl'] as String?),
      fallback: RaftExternalInitials(name: name, large: slot.size >= 48),
    ),
  );
}

Widget externalMentionPreview(
  BuildContext context,
  String origin,
  Map<String, dynamic> member,
) => externalIdentityPreviewBody(
  context,
  displayName: member['displayName'] as String? ?? '',
  avatar: externalMentionAvatar(
    origin,
    member,
    RaftAvatarSlotContext.mentionCard,
  ),
  provider: member['provider'] as String?,
  workspaceName: member['workspaceName'] as String?,
  actorKind: member['actorKind'] as String?,
);

/// Web `handleNavigateExternalMention`: a thread panel passes the thread's
/// channel, but the provider binding lives on the parent channel.
String externalMentionChannelId(WorkspaceController w, String channelId) =>
    (w.threadChannelId == channelId
        ? w.messageDomain.threadSourceChannel?.id
        : null) ??
    channelId;

/// The attribution payload for a mention, as Web builds it from the members
/// endpoint (which omits provider-side ids). `isMention` keys the profile by
/// projection id (`profile=external-mention:<channel>:<projection>`).
Map<String, dynamic> externalMentionAuthor(Map<String, dynamic> member) => {
  'projectionId': member['id'],
  'provider': member['provider'],
  'appRegistrationId': '',
  'installId': '',
  'workspaceId': '',
  'externalActorId': '',
  'workspaceName': member['workspaceName'],
  'externalConversationId': '',
  'externalMessageId': '',
  'displayName': member['displayName'],
  'actorKind': member['actorKind'],
  'avatarUrl': member['avatarUrl'],
  'avatarDigest': null,
  'actorProjectionRevision': 0,
  'isMention': true,
};

/// Web `restoreExternalMentionProfileFromUrl`: the roster entry of
/// [projectionId] in [channelId], or null.
Future<Map<String, dynamic>?> restoreExternalMentionProfile(
  WorkspaceController w,
  String channelId,
  String projectionId,
) async {
  final data = await w.client.get('/channels/$channelId/members');
  final rows = data is Map ? data['externalMembers'] : null;
  final member = (rows is List ? rows : const [])
      .whereType<Map>()
      .where((row) => row['id'] == projectionId)
      .firstOrNull;
  return member == null
      ? null
      : externalMentionAuthor(Map<String, dynamic>.from(member));
}

/// The roster entry stand-in for an `external` mention whose roster has not
/// loaded (or is hidden from a guest): only the handle is known.
Map<String, dynamic> externalMentionFallback(RaftMessage message, String id) =>
    {
      'id': id,
      'displayName':
          [
            for (final m in (message.json['mentions'] as List? ?? const []))
              if (m is Map && m['id'] == id && m['name'] is String)
                m['name'] as String,
          ].firstOrNull ??
          '',
    };
