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
      linkLabel: onViewBilling == null ? null : 'View Billing',
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
