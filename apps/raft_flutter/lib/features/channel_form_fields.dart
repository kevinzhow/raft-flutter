// `AvatarSlot` adapter for the channel dialogs' candidate rows (create
// channel, add member): agent pixel artwork / public uploads resolved against
// the API origin.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'create_channel_dialog.dart';
import 'public_avatar_url.dart';

/// `AvatarSlot` for a picker candidate: agents paint their pixel artwork or
/// public upload; humans use the `humanPlaceholder` User glyph when asked.
class ChannelCandidateAvatar extends StatelessWidget {
  const ChannelCandidateAvatar({
    super.key,
    required this.candidate,
    required this.avatarContext,
    this.humanPlaceholder = false,
    this.origin,
    this.presence,
  });
  final ChannelMemberCandidate candidate;
  final RaftMountedAvatarContext avatarContext;
  final bool humanPlaceholder;
  final String? origin;
  final RaftAvatarPresence? presence;
  @override
  Widget build(BuildContext context) {
    final agent = candidate.kind == 'agent';
    final url = candidate.avatarUrl;
    final pixel = agent && url != null && url.startsWith('pixel:')
        ? url.substring(6)
        : null;
    final uploaded = pixel == null && origin != null
        ? raftPublicAvatarUrl(origin!, url)
        : null;
    return RaftMountedAvatarFrame(
      name: candidate.label,
      avatarContext: avatarContext,
      identity: agent
          ? RaftMountedAvatarIdentity.agent
          : RaftMountedAvatarIdentity.human,
      presence: presence,
      child: agent && (pixel != null || uploaded != null)
          ? RaftAvatarContent(
              name: candidate.label,
              kind: RaftAvatarContentKind.agent,
              pixelKey: pixel,
              uploadedUrl: uploaded,
            )
          : !agent && !humanPlaceholder && uploaded != null
          ? RaftAvatarContent(name: candidate.label, uploadedUrl: uploaded)
          : null,
    );
  }
}
