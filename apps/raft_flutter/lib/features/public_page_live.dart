// Where the Web client shows that a server's public page is live
// (`server.publicPageLive`, Sidebar.tsx / ChatPanel.tsx / AppTopBar.tsx):
// a globe after the server name, and a # with a small globe for each channel
// anyone can read there.
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

/// The current server's public page is live. The server list is the fresh
/// source (the owner who flips Public access reloads it); the selected
/// server record is the fallback until the list holds it.
bool serverPublicPageLive(WorkspaceController w) {
  final current = w.server;
  if (current == null) return false;
  final listed = w.servers.where((s) => s.id == current.id).firstOrNull;
  return (listed ?? current).json['publicPageLive'] == true;
}

/// `serverPublicPageLive && channel.guestVisible === true && !channel.archivedAt`
/// for an ordinary channel: anyone can read it on the public page.
bool channelOnPublicPage(WorkspaceController w, RaftChannel channel) =>
    channel.type == 'channel' &&
    channel.json['guestVisible'] == true &&
    !channel.archived &&
    serverPublicPageLive(w);

/// The sidebar row's glyph for a channel on the public page (Web 16px), in
/// the colour the row would draw its own glyph in; null for any other row.
Widget? channelPublicLeading(
  BuildContext context,
  WorkspaceController w,
  RaftChannel channel,
) {
  if (!channelOnPublicPage(w, channel)) return null;
  final t = RaftTokens.of(context);
  // RaftNavItem `_dimmed`: a channel row that is not selected and not joined.
  final selected = w.section == 'chat' && w.channel?.id == channel.id;
  final dimmed = !selected && !channel.joined;
  return RaftPublicChannelMark(
    size: 16,
    color: dimmed
        ? t.brutal
              ? t.strong.withValues(alpha: .4)
              : t.colors['foreground-placeholder']
        : t.brutal
        ? t.strong
        : t.colors['foreground-icon'],
  );
}
