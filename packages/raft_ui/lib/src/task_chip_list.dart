import 'package:flutter/material.dart';

import 'components.dart' show RaftAvatar, RaftAvatarKind;
import 'design_primitives.dart';
import 'interaction.dart';
import 'icons.dart';
import 'localization.dart';
import 'mounted_avatar_recipe.dart';
import 'raft/ui_tokens.dart';
import 'task.dart' show raftTaskStatusLabel;
import 'task_status_badge.dart';
import 'theme.dart';
import 'tokens/tokens.dart';

/// One task row of [RaftTaskChipList]: facts the app resolved (the list never
/// reads a store or requests anything).
@immutable
class RaftTaskChipRow {
  const RaftTaskChipRow({
    required this.id,
    required this.number,
    required this.title,
    required this.status,
    this.replyCount = 0,
    this.unread = false,
    this.assigneeName,
    this.assigneeIsAgent = false,
    this.assigneeIsViewer = false,
    this.assigneeAvatarUrl,
  });
  final String id;
  final int number;
  final String title;

  /// The app's status id (`in_progress`).
  final String status;

  /// The size of the task's own conversation (0: none shown).
  final int replyCount;

  /// New messages in a task conversation the reader follows.
  final bool unread;

  /// Null: unassigned (no assignee slot at all).
  final String? assigneeName;
  final bool assigneeIsAgent, assigneeIsViewer;
  final String? assigneeAvatarUrl;
}

/// Web v1.24 `TaskChipList` (components/task/TaskChipList.tsx), the boxed
/// variant under a message: the tasks created from it (task v2), one row
/// each: the number, the title on one line with its reply count right after
/// it, then the assignee and the status grouped at the right (raft-design
/// patterns/tasks.md, compactRow.ts). A box sized by its content, at least
/// 320px and at most the message column, its hairlines meeting its border.
class RaftTaskChipList extends StatelessWidget {
  const RaftTaskChipList({
    super.key,
    required this.tasks,
    required this.onOpen,
  });
  final List<RaftTaskChipRow> tasks;

  /// Null paints the rows inert (a host without a task slot).
  final ValueChanged<RaftTaskChipRow>? onOpen;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    return Padding(
      // `mt-1.5`.
      padding: const EdgeInsets.only(top: 6),
      child: LayoutBuilder(
        builder: (context, box) {
          final max = box.maxWidth.isFinite ? box.maxWidth : 560.0;
          return ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: max < 320 ? max : 320,
              maxWidth: max,
            ),
            child: IntrinsicWidth(
              child: DecoratedBox(
                key: const ValueKey('message-task-chip-list'),
                decoration: BoxDecoration(
                  color: t.ui.layerCard,
                  border: Border.all(color: t.ui.lineHairline),
                  borderRadius: BorderRadius.circular(t.radius),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(t.radius - 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < tasks.length; i++)
                        _TaskChipListRow(
                          key: ValueKey('message-task-chip-${tasks[i].id}'),
                          task: tasks[i],
                          divider: i > 0,
                          onOpen: onOpen == null
                              ? null
                              : () => onOpen!(tasks[i]),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TaskChipListRow extends StatelessWidget {
  const _TaskChipListRow({
    super.key,
    required this.task,
    required this.divider,
    required this.onOpen,
  });
  final RaftTaskChipRow task;
  final bool divider;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final touch = RaftInteraction.of(context).touch;
    final statusLabel = raftText(context, raftTaskStatusLabel(task.status));
    final opens = raftFormat(context, 'Open task #{number}: {title}', {
      'number': task.number,
      'title': task.title,
    });
    final open = task.replyCount > 0 || task.unread
        ? '$opens, ${raftTaskChipRepliesLabel(context, count: task.replyCount, unread: task.unread)}'
        : opens;
    final mono = t
        .scale(RaftTypeScale.monoMeta, mono: true, color: t.ui.foregroundHint)
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return RaftInteractive(
      semanticLabel: open,
      onPressed: onOpen,
      builder: (context, state) => DecoratedBox(
        decoration: BoxDecoration(
          color: onOpen != null && (state.hovered || state.pressed)
              ? t.ui.fillPressed.withValues(
                  alpha: t.ui.fillPressed.a * (state.pressed ? 1 : .5),
                )
              : null,
          border: Border(
            top: divider
                ? BorderSide(color: t.ui.lineHairline)
                : BorderSide.none,
          ),
        ),
        child: ExcludeSemantics(
          child: ConstrainedBox(
            // `min-h-11` (44) by touch, the 36px row with a fine pointer.
            constraints: BoxConstraints(minHeight: touch ? 44 : 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                spacing: 8,
                children: [
                  Text('#${task.number}', style: mono),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        Flexible(
                          child: Text(
                            task.title,
                            key: const ValueKey('message-task-chip-title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.scale(
                              RaftTypeScale.callout,
                              weight: FontWeight.w400,
                              color: t.ui.foreground,
                            ),
                          ),
                        ),
                        if (task.replyCount > 0 || task.unread)
                          _ReplyCount(task: task, style: mono),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (task.assigneeName != null) _Assignee(task: task),
                  RaftTaskStatusBadge(
                    status: raftTaskStatusOf(task.status),
                    label: statusLabel,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplyCount extends StatelessWidget {
  const _ReplyCount({required this.task, required this.style});
  final RaftTaskChipRow task;
  final TextStyle style;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Row(
      key: const ValueKey('message-task-chip-replies'),
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        if (task.unread)
          SizedBox.square(
            key: const ValueKey('message-task-chip-unread'),
            dimension: 6,
            child: ColoredBox(color: t.ui.attention),
          ),
        if (task.replyCount > 0) ...[
          RaftThreadIcon(size: 12, color: t.ui.foregroundHint),
          Text('${task.replyCount}', style: style),
        ],
      ],
    );
  }
}

class _Assignee extends StatelessWidget {
  const _Assignee({required this.task});
  final RaftTaskChipRow task;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final name = task.assigneeIsViewer
        ? raftText(context, 'You')
        : task.assigneeName!;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 192),
      child: Row(
        key: const ValueKey('message-task-chip-assignee'),
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          RaftAvatar(
            name: task.assigneeName!,
            kind: task.assigneeIsAgent
                ? RaftAvatarKind.agent
                : RaftAvatarKind.human,
            imageUrl: task.assigneeAvatarUrl,
            mountedContext: RaftMountedAvatarContext.compactList,
          ),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.scale(
                RaftTypeScale.caption,
                weight: task.assigneeIsViewer
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: task.assigneeIsViewer
                    ? t.ui.foreground
                    : t.ui.foregroundMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The accessible label of a row's reply count (Web `task.chip.*`).
String raftTaskChipRepliesLabel(
  BuildContext context, {
  required int count,
  required bool unread,
}) {
  if (count <= 0) {
    return raftText(context, 'New messages in this task you follow');
  }
  final one = count == 1;
  return raftFormat(
    context,
    unread
        ? (one
              ? '{count} message in this task, new ones you follow'
              : '{count} messages in this task, new ones you follow')
        : (one
              ? '{count} message in this task'
              : '{count} messages in this task'),
    {'count': count},
  );
}
