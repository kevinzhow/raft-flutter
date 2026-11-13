// The widget a regular channel conversation shows instead of its composer
// (Web ChatPanel `ConversationPanelFooter` chain; the state is decided in
// channel_footer_states.dart, the footer widgets live in raft_ui).
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'channel_footer_states.dart';
import 'raftbench_service_notice.dart';

/// Null shows the composer. The RaftBench service agent's DM comes first: it
/// never replies, whatever else the footer chain would say.
Widget? channelFooterReplacement(
  BuildContext context,
  WorkspaceController w,
  DateTime now, {
  required VoidCallback? onOpenChannelSettings,
  required VoidCallback? onViewBilling,
  required Future<void> Function() onJoin,
}) {
  final channel = w.channel;
  if (channel == null) return null;
  if (isRaftbenchServiceDm(w)) return const RaftbenchServiceDmNotice();
  final guest = w.server?.string('role') == 'guest';
  return switch (channelFooterKind(w, now)) {
    null || ChannelFooterKind.composer => null,
    ChannelFooterKind.archived => RaftChannelArchivedFooter(
      message: 'This channel is archived.',
      linkLabel: w.can('archiveChannels') && onOpenChannelSettings != null
          ? 'Unarchive'
          : null,
      onLink: onOpenChannelSettings,
    ),
    ChannelFooterKind.jointLocked => RaftChannelBannerFooter(
      message: "This Joint Channel is read-only because it has more than 2 free servers. It becomes writable again when one server's admin upgrades or a free server leaves.",
      linkLabel: onViewBilling == null ? null : 'View billing',
      onLink: onViewBilling,
    ),
    ChannelFooterKind.guestReadOnly => const RaftChannelBannerFooter(
      message: 'Guest access is read-only. You can read and follow updates, but you cannot post or react.',
    ),
    ChannelFooterKind.join => RaftChannelJoinFooter(
      channelName: channel.name,
      onJoin: onJoin,
      explanation: guest
          ? 'Joining adds this channel to your sidebar and follows its updates. It does not enable posting or reactions.'
          : null,
    ),
  };
}

/// ThreadPanel's parent-channel policy, shared with the conversation footer
/// owner rather than retaining conversation state decisions in ChatView.
Widget? threadFooterReplacement(
  BuildContext context,
  WorkspaceController w,
  DateTime now, {
  required bool selectionActive,
  required VoidCallback? onViewBilling,
  required Future<void> Function() onJoin,
}) {
  final parent = w.messageDomain.threadSourceChannel;
  if (parent == null) return null;
  final guest = w.server?.string('role') == 'guest';
  final joined = parent.joined;
  final guestJoinable = parent.json['guestJoinable'] == true;
  if (guest && (joined || !guestJoinable)) {
    return const RaftChannelBannerFooter(
      message: 'Guest access is read-only. You can read and follow this thread, but you cannot reply or react.',
    );
  }
  if (selectionActive) return null;
  if (jointChannelReadOnly(parent.json, now)) {
    return RaftChannelBannerFooter(
      message: "This Joint Channel is read-only because it has more than 2 free servers. It becomes writable again when one server's admin upgrades or a free server leaves.",
      linkLabel: onViewBilling == null ? null : 'View billing',
      onLink: onViewBilling,
    );
  }
  if (joined) return null;
  return RaftChannelJoinFooter(
    channelName: parent.name,
    label: guest ? 'Join channel' : 'Join channel to reply',
    onJoin: onJoin,
    explanation: guest
        ? 'Joining follows the parent channel. Guest access remains read-only.'
        : null,
  );
}
