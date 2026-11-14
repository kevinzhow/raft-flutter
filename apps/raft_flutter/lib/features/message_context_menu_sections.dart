import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'message_task_actions.dart';

/// The message context menu's content (Web MessageItem context menu): the
/// reaction row, then Copy Link / Copy Markdown / Translate / Select, then
/// Open Thread / Save / Follow and the task entry. [pick] receives the chosen
/// entry's id; the caller runs it after the menu closes.
///
/// [translate] is null when manual translation is not offered, else whether
/// it is pending. [follow] is null when the thread cannot be followed here,
/// else whether it is followed.
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
}) {
  RaftMessageContextMenuItem item(String value, String label, Widget icon) =>
      RaftMessageContextMenuItem(
        key: ValueKey('message-menu-$value'),
        label: raftText(menuContext, label),
        icon: icon,
        onPressed: () => pick(value),
      );
  final tasks = [
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
  ];
  return RaftMessageContextMenu(
    onDismiss: () => Navigator.of(menuContext).pop(),
    reactionLabel: (emoji) =>
        raftFormat(menuContext, 'React with {emoji}', {'emoji': emoji}),
    onReact: onReact,
    sections: [
      [
        item('copy-link', 'Copy link', raftMessageMenuIcon(RaftGlyph.link)),
        item(
          'copy-markdown',
          'Copy Markdown',
          raftMessageMenuIcon(RaftGlyph.copy),
        ),
        // Web: manual mode offers Translate (Translating… while the request
        // is pending) after Copy Markdown.
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
        if (select)
          item(
            'select',
            'Select message',
            raftMessageMenuIcon(RaftGlyph.checkCircle),
          ),
      ],
      [
        if (thread)
          item(
            'thread',
            'Open Thread',
            Builder(
              builder: (c) => RaftMessageThreadGlyph(
                size: 14,
                color: DefaultTextStyle.of(c).style.color,
              ),
            ),
          ),
        item(
          'save',
          saved ? 'Remove from Saved' : 'Save',
          raftMessageMenuIcon(RaftGlyph.bookmark),
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
        // Without the follow divider the task row joins this group.
        if (follow == null) ...tasks,
      ],
      if (follow != null) tasks,
    ],
  );
}
