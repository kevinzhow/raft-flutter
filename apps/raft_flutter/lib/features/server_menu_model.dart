import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_server_unread.dart';
import '../data/workspace_controller.dart';
import 'public_avatar_url.dart';
import 'workspace_desktop_window.dart';

const workspaceShortcutKeys = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

/// What the Home server switcher and the phone's server tab list: the same
/// servers in the same order with the same unread rules (Web `useServerSwitcher`
/// feeds both). Lifted out of the workspace so the two surfaces cannot drift.
List<RaftServerMenuRow> serverMenuRows(
  BuildContext context,
  WorkspaceController w, {
  required int? Function(String serverId) activityCountOf,
  required SourceServerUnreadStore serverUnread,
  required void Function(RaftRecord server) onSelect,
  bool desktopShortcuts = false,
}) => [
  for (final (index, server) in w.servers.indexed)
    RaftServerMenuRow(
      id: server.id,
      name: server.name,
      slug: server.string('slug'),
      avatarUrl: raftPublicAvatarUrl(
        w.client.origin,
        server.json['avatarUrl'] as String?,
      ),
      current: server.id == w.server?.id,
      publicPageLive: server.json['publicPageLive'] == true,
      activityUnreadCount: activityCountOf(server.id),
      pushMuted: serverUnread[server.id]?.pushMuted ?? false,
      shortcutLabel: desktopShortcuts && index < workspaceShortcutKeys.length
          ? '${usesCommandShortcuts() ? '⌘' : 'Ctrl+'}${index + 1}'
          : null,
      onSelected: () => onSelect(server),
      onAuxiliary: serverWindowAction(context, w, server),
      onOpenWindow: nativeServerWindowAction(context, w, server),
    ),
];

/// The switcher's footer: join the community server (until joined), switch or
/// create, invite a human.
class ServerMenuActions {
  const ServerMenuActions({this.join, required this.choose, this.invite});
  final RaftMenuEntry? join;
  final RaftMenuEntry choose;
  final RaftServerMenuAction? invite;
  List<RaftMenuEntry> get all => [?join, choose, ?invite];
}

ServerMenuActions serverMenuActions(
  BuildContext context,
  WorkspaceController w, {
  required bool joiningCommunity,
  required VoidCallback onJoinCommunity,
  required VoidCallback? onChoose,
  required VoidCallback onInvite,
}) => ServerMenuActions(
  join: w.servers.any((server) => server.string('slug') == 'community')
      ? null
      : RaftMenuEntry(
          label: raftText(context, 'Join community'),
          glyph: RaftGlyph.plus,
          onPressed: joiningCommunity ? null : onJoinCommunity,
        ),
  choose: RaftMenuEntry(
    label: raftText(context, 'Switch or create server'),
    glyph: RaftGlyph.plus,
    onPressed: onChoose,
  ),
  invite: w.can('inviteMembers')
      ? RaftServerMenuAction(
          tone: RaftServerMenuActionTone.invite,
          label: raftText(context, 'Invite human'),
          glyph: RaftGlyph.userPlus,
          onPressed: onInvite,
        )
      : null,
);

/// The Home switcher's dot and the server tab's avatar dot: another server has
/// unread items (never this one's own).
bool otherServerUnread(
  WorkspaceController w,
  int? Function(String serverId) activityCountOf,
) => w.servers.any(
  (s) => s.id != w.server?.id && (activityCountOf(s.id) ?? 0) > 0,
);
