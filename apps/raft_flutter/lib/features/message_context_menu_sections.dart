import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'message_menu_targets.dart';
import 'message_task_actions.dart';

/// The message context menu's content (Web v1.24 MessageItem context menu,
/// MessageItem.tsx:4777-5000): the reaction row, then the sections by what
/// the action does. Keep going here: Reply in thread, Follow, Mark thread as
/// unread, the task entry. Take it elsewhere: Copy link, Copy Markdown,
/// Select text (touch), Forward, Select message. Just for me: Save,
/// Translate, Mark the channel or DM as unread. [pick] receives the chosen
/// entry's id; the caller runs it after the menu closes.
///
/// [translate] is null when manual translation is not offered, else whether
/// it is pending. [follow] is null when the thread cannot be followed here,
/// else whether it is followed. View Context (agent messages) is not here
/// yet.
RaftMessageContextMenu messageContextMenu(
  BuildContext menuContext,
  WorkspaceController w, {
  required ValueChanged<String> pick,
  required ValueChanged<String>? onReact,
  required bool taskItems,
  required Map<String, dynamic>? task,
  required bool? translate,
  required bool select,
  required bool thread,
  required bool saved,
  required bool? follow,
  required MessageMenuTargets targets,
}) {
  RaftMessageContextMenuItem item(String value, String label, Widget icon) =>
      RaftMessageContextMenuItem(
        key: ValueKey('message-menu-$value'),
        label: raftText(menuContext, label),
        icon: icon,
        onPressed: () => pick(value),
      );
  final unreadIcon = raftMessageMenuIcon(RaftGlyph.messageSquareDot);
  return RaftMessageContextMenu(
    onDismiss: () => Navigator.of(menuContext).pop(),
    reactionLabel: (emoji) =>
        raftFormat(menuContext, 'React with {emoji}', {'emoji': emoji}),
    onReact: onReact,
    sections: [
      [
        if (thread)
          item(
            'thread',
            'Reply in thread',
            Builder(
              builder: (c) => RaftMessageThreadGlyph(
                size: 14,
                color: DefaultTextStyle.of(c).style.color,
              ),
            ),
          ),
        if (follow != null)
          follow
              ? item(
                  'unfollow',
                  'Unfollow thread',
                  raftMessageMenuIcon(RaftGlyph.messageCircleOff),
                )
              : item(
                  'follow',
                  'Follow thread',
                  raftMessageMenuIcon(RaftGlyph.messageCirclePlus),
                ),
        if (targets.markThread != null)
          item('mark-thread-unread', 'Mark thread as unread', unreadIcon),
        if (taskItems)
          task == null
              ? messageTaskMenuItem(w, item)
              : task['status'] == 'done'
              ? item(
                  'task-reopen',
                  'Reopen task',
                  raftMessageMenuIcon(RaftGlyph.rotateCcw),
                )
              : item(
                  'task-done',
                  'Mark as Done',
                  raftMessageMenuIcon(RaftGlyph.checkCircle),
                ),
      ],
      [
        item('copy-link', 'Copy link', raftMessageMenuIcon(RaftGlyph.link)),
        item(
          'copy-markdown',
          'Copy Markdown',
          raftMessageMenuIcon(RaftGlyph.copy),
        ),
        if (targets.selectText)
          item(
            'select-text',
            'Select text',
            raftMessageMenuIcon(RaftGlyph.squareDashedText),
          ),
        if (targets.forward)
          item('forward', 'Forward', raftMessageMenuIcon(RaftGlyph.forward)),
        if (select)
          item(
            'select',
            'Select message',
            raftMessageMenuIcon(RaftGlyph.listChecks),
          ),
      ],
      [
        item(
          'save',
          saved ? 'Remove from Saved' : 'Save',
          raftMessageMenuIcon(
            saved ? RaftGlyph.bookmarkMinus : RaftGlyph.bookmark,
          ),
        ),
        // Translating… while the request is pending.
        if (translate != null)
          RaftMessageContextMenuItem(
            key: const ValueKey('message-menu-translate'),
            label: raftText(
              menuContext,
              translate ? 'Translating…' : 'Translate',
            ),
            icon: raftMessageMenuIcon(RaftGlyph.languages),
            onPressed: translate ? null : () => pick('translate'),
          ),
        if (targets.markConversation != null)
          item(
            'mark-conversation-unread',
            targets.dm ? 'Mark DM as unread' : 'Mark channel as unread',
            unreadIcon,
          ),
      ],
    ],
  );
}
