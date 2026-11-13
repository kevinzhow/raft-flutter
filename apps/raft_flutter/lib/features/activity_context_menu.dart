import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

/// Identifies a command offered by an Activity row menu.
enum ActivityContextAction { toggleRead, done, follow, unfollow }

/// Builds the Web InboxContextMenu with the existing design system menu.
///
/// Every row has Done. Unfollowed threads offer Follow without a read toggle.
Widget buildActivityContextMenu(
  BuildContext context,
  Map<String, dynamic> row, {
  required VoidCallback onDismiss,
  required ValueChanged<ActivityContextAction> onAction,
  bool? unread,
}) {
  final thread = row['kind'] == 'thread';
  final following = row['isFollowing'] != false;
  // InboxContextMenu `showsUnread`: a count, or the marked-unread flag.
  unread ??= (row['unreadCount'] as num? ?? 0) > 0;
  return RaftSidebarContextMenu(
    width: 184,
    onDismiss: onDismiss,
    entries: [
      if (!thread || following)
        RaftSidebarMenuItem(
          label: raftText(context, unread ? 'Mark as read' : 'Mark as unread'),
          glyph: unread
              ? RaftGlyph.messageSquareCheck
              : RaftGlyph.messageSquareDot,
          itemKey: const ValueKey('activity-menu-toggle-read'),
          onPressed: () => onAction(ActivityContextAction.toggleRead),
        ),
      RaftSidebarMenuItem(
        label: raftText(context, 'Done'),
        glyph: RaftGlyph.check,
        onPressed: () => onAction(ActivityContextAction.done),
      ),
      if (thread)
        RaftSidebarMenuItem(
          label: raftText(context, following ? 'Unfollow' : 'Follow'),
          glyph: following ? RaftGlyph.bellOff : RaftGlyph.bell,
          onPressed: () => onAction(
            following
                ? ActivityContextAction.unfollow
                : ActivityContextAction.follow,
          ),
        ),
    ],
  );
}
