import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

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
