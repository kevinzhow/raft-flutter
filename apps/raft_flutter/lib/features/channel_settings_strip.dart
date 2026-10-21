// The Slack (external) side of the channel overflow members strip
// (ChannelOverflowMenu.tsx `MembersStrip`): the count line and the avatar
// tiles for the bridge participants that are shown beside, never inside, the
// Raft roster.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'channel_form_fields.dart';
import 'create_channel_dialog.dart' show ChannelMemberCandidate;

/// `message.chatPanel.overflow.membersSummary` / `...membersSummaryWithSlack`.
/// The Slack clause appears only when the channel has Slack participants.
String channelMembersSummary(
  BuildContext context, {
  required int humans,
  required int agents,
  int slack = 0,
}) {
  if (Localizations.localeOf(context).languageCode == 'zh') {
    return slack > 0
        ? raftFormat(
            context,
            '{humans} humans · {agents} agents · {slack} Slack',
            {'humans': humans, 'agents': agents, 'slack': slack},
          )
        : raftFormat(context, '{humans} humans · {agents} agents', {
            'humans': humans,
            'agents': agents,
          });
  }
  final base =
      '$humans ${humans == 1 ? 'human' : 'humans'} · '
      '$agents ${agents == 1 ? 'agent' : 'agents'}';
  return slack > 0 ? '$base · $slack Slack' : base;
}

/// One Slack participant tile: the human avatar slot with the
/// `message.chatPanel.overflow.slackMemberLabel` name ("{name} (Slack)").
RaftStripMember slackStripMember(
  BuildContext context,
  Map<String, dynamic> member, {
  String? origin,
}) {
  final name = '${member['displayName'] ?? ''}';
  return RaftStripMember(
    label: raftFormat(context, '{name} (Slack)', {'name': name}),
    avatar: ChannelCandidateAvatar(
      candidate: ChannelMemberCandidate(
        kind: 'human',
        id: '${member['id']}',
        name: name,
        avatarUrl: member['avatarUrl'] as String?,
      ),
      avatarContext: RaftMountedAvatarContext.panelHeader,
      origin: origin,
    ),
  );
}
