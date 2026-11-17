import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

/// Identifies a command offered by an Activity row menu.
enum ActivityContextAction {
  toggleRead,
  done,
  follow,
  unfollow,

  /// Mute Activity / Unmute Activity (R39); the page saves it (no undo toast:
  /// only the swipe's Mute has one).
  mute,
  unmute,
}

/// Web `canToggleActivityRowRead`: every row but an unfollowed thread's (it no
/// longer counts unread), and an object row only while it is unread (the
/// contract has no Mark as unread for it).
bool canToggleActivityRowRead(Map<String, dynamic> row) {
  if (row['kind'] == 'object') return ((row['unreadCount'] as num?) ?? 0) > 0;
  return row['kind'] != 'thread' || row['isFollowing'] != false;
}

/// Web `canToggleActivityMute` (`channelDomain.ts`): a DM only where the server
/// says it can be muted (a DM with an App bot, `activityMuteSupported`), and a
/// stored mute keeps its Unmute; a joined channel, private or joint channel.
bool canToggleActivityMute(RaftChannel? channel) {
  if (channel == null) return false;
  if (channel.type == 'dm') {
    return channel.json['activityMuteSupported'] == true ||
        channel.flag('activityMuted');
  }
  return const ['channel', 'private', 'joint'].contains(channel.type) &&
      channel.json['joined'] == true;
}

/// Builds the Web InboxContextMenu with the existing design system menu.
///
/// Every row has Done. A channel, or a DM with an App bot, offers Mute
/// Activity / Unmute Activity when [muteChannel] (the row's stored channel)
/// can be muted. An unfollowed thread offers Follow without a read toggle; an
/// object row only "Mark as read", and only while unread.
Widget buildActivityContextMenu(
  BuildContext context,
  Map<String, dynamic> row, {
  required VoidCallback onDismiss,
  required ValueChanged<ActivityContextAction> onAction,
  bool? unread,
  RaftChannel? muteChannel,
}) {
  final thread = row['kind'] == 'thread';
  final following = row['isFollowing'] != false;
  // InboxContextMenu `showsUnread`: a count, or the marked-unread flag.
  unread ??= (row['unreadCount'] as num? ?? 0) > 0;
  // Mute is for a channel or DM row only (not a thread's or a mention's).
  final mutable = row['kind'] == 'channel' || row['kind'] == 'dm';
  muteChannel = mutable ? muteChannel : null;
  final muted = muteChannel?.flag('activityMuted') == true;
  return RaftSidebarContextMenu(
    width: 184,
    onDismiss: onDismiss,
    entries: [
      if (canToggleActivityRowRead(row))
        RaftSidebarMenuItem(
          label: raftText(context, unread ? 'Mark as read' : 'Mark as unread'),
          glyph: unread
              ? RaftGlyph.messageSquareCheck
              : RaftGlyph.messageSquareDot,
          itemKey: const ValueKey('activity-menu-toggle-read'),
          onPressed: () => onAction(ActivityContextAction.toggleRead),
        ),
      RaftSidebarMenuItem(
        label: raftText(context, 'Mark as Done'),
        glyph: RaftGlyph.check,
        itemKey: const ValueKey('activity-menu-done'),
        onPressed: () => onAction(ActivityContextAction.done),
      ),
      // The message menu's Unfollow / Follow icons: the bell is Mute's.
      if (thread)
        RaftSidebarMenuItem(
          label: raftText(context, following ? 'Unfollow' : 'Follow'),
          glyph: following ? RaftGlyph.unfollowThread : RaftGlyph.followThread,
          itemKey: const ValueKey('activity-menu-follow'),
          onPressed: () => onAction(
            following
                ? ActivityContextAction.unfollow
                : ActivityContextAction.follow,
          ),
        ),
      if (canToggleActivityMute(muteChannel))
        RaftSidebarMenuItem(
          label: raftText(context, muted ? 'Unmute Activity' : 'Mute Activity'),
          glyph: muted ? RaftGlyph.bell : RaftGlyph.bellOff,
          itemKey: const ValueKey('activity-menu-mute'),
          onPressed: () => onAction(
            muted ? ActivityContextAction.unmute : ActivityContextAction.mute,
          ),
        ),
    ],
  );
}
