import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'avatar_content.dart';
import 'components.dart' show RaftAvatar, RaftAvatarKind;
import 'design_primitives.dart';
import 'interaction.dart';
import 'icons.dart';
import 'localization.dart';
import 'mounted_avatar_recipe.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/checkbox.dart';
import 'raft/ui_tokens.dart';
import 'space.dart';
import 'task.dart' show raftTaskStatusLabel;
import 'task_status_badge.dart';
import 'theme.dart';
import 'tokens/tokens.dart';
import 'viewport_breakpoints.dart' show raftBreakpointWidth;

part 'task_chip_page.dart';

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
    this.assigneeAvatarPixelKey,
    this.ref,
    this.channelName,
    this.time,
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
  final String? assigneeAvatarUrl, assigneeAvatarPixelKey;

  /// The Tasks page across channels: the task's conversation ref
  /// (`#design:#25`, `dm:@peer:#25`), shown instead of `#25` where the list is
  /// wide. Null: the bare number.
  final String? ref;

  /// The Tasks page across channels: the channel's name, shown in the
  /// trailing group (`#design`) where the list is narrow. Null: none.
  final String? channelName;

  /// The page variant's last slot, after the status (the app's relative time).
  final Widget? time;
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

/// The `plain` variant of Web v1.24 `TaskChipList`: the rows of the channel
/// Tasks card (ChannelTasksPanel's CompactStatusGroup). Full width with no
/// box of its own, hairlines inset like the content (`--compact-row-inset`:
/// 20px, 16px on a phone), no status badge (the lane names it) and a chevron
/// at the end of each row.
class RaftTaskCardList extends StatelessWidget {
  const RaftTaskCardList({
    super.key,
    required this.tasks,
    required this.onOpen,
  });
  final List<RaftTaskChipRow> tasks;
  final ValueChanged<RaftTaskChipRow>? onOpen;

  /// `--compact-row-inset`: `1rem` on a phone, `md:1.25rem`.
  static double insetOf(BuildContext context) =>
      raftBreakpointWidth(context) >= 768 ? 20 : 16;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    final inset = insetOf(context);
    return Column(
      key: const ValueKey('channel-tasks-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < tasks.length; i++)
          _TaskChipListRow(
            key: ValueKey('message-task-chip-${tasks[i].id}'),
            task: tasks[i],
            divider: i > 0,
            inset: inset,
            plain: true,
            onOpen: onOpen == null ? null : () => onOpen!(tasks[i]),
          ),
      ],
    );
  }
}

class _TaskChipListRow extends StatelessWidget {
  const _TaskChipListRow({
    super.key,
    required this.task,
    required this.divider,
    required this.onOpen,
    this.inset = 12,
    this.plain = false,
  });
  final RaftTaskChipRow task;
  final bool divider;
  final VoidCallback? onOpen;

  /// The row's inline padding; the hairline of a plain row starts and ends
  /// where the content does.
  final double inset;

  /// The Tasks card's row: no status badge, a chevron at the end.
  final bool plain;

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
            top: divider && !plain
                ? BorderSide(color: t.ui.lineHairline)
                : BorderSide.none,
          ),
        ),
        child: ExcludeSemantics(
          child: _InsetDivider(
            show: divider && plain,
            inset: inset,
            color: t.ui.lineHairline,
            child: ConstrainedBox(
              // `min-h-11` (44) by touch, the 36px row with a fine pointer.
              constraints: BoxConstraints(minHeight: touch ? 44 : 36),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: inset, vertical: 6),
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
                            RaftTaskReplyCount(task: task, style: mono),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (task.assigneeName != null) RaftTaskAssignee(task: task),
                    if (plain)
                      RaftIcon(
                        RaftGlyph.chevronRight,
                        size: 14,
                        color: t.ui.foregroundHint,
                      )
                    else
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
      ),
    );
  }
}

/// The hairline above a row, inset from both edges (a side card's list has
/// no edge of its own: its lines run where the content does).
class _InsetDivider extends StatelessWidget {
  const _InsetDivider({
    required this.show,
    required this.inset,
    required this.color,
    required this.child,
  });
  final bool show;
  final double inset;
  final Color color;
  final Widget child;
  @override
  Widget build(BuildContext context) => !show
      ? child
      : Stack(
          fit: StackFit.passthrough,
          children: [
            child,
            Positioned(
              top: 0,
              left: inset,
              right: inset,
              child: IgnorePointer(
                child: SizedBox(height: 1, child: ColoredBox(color: color)),
              ),
            ),
          ],
        );
}

/// Web `TaskReplyCount`: the unread pixel and the number of messages in a
/// task's conversation, after a title (a list row, a board card).
class RaftTaskReplyCount extends StatelessWidget {
  const RaftTaskReplyCount({super.key, required this.task, this.style});
  final RaftTaskChipRow task;

  /// The number's style; null is the compact rows' hint-ink mono.
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style =
        this.style ??
        t
            .scale(
              RaftTypeScale.monoMeta,
              mono: true,
              color: t.ui.foregroundHint,
            )
            .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
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

/// Web `TaskAssignee`: the assignee's avatar and name (You for the viewer),
/// as the compact task rows and a board card's foot show them.
class RaftTaskAssignee extends StatelessWidget {
  const RaftTaskAssignee({super.key, required this.task});
  final RaftTaskChipRow task;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final name = task.assigneeIsViewer
        ? raftText(context, 'You')
        : task.assigneeName!;
    final avatar = RaftAvatar(
      name: task.assigneeName!,
      kind: task.assigneeIsAgent ? RaftAvatarKind.agent : RaftAvatarKind.human,
      imageUrl: task.assigneeAvatarUrl,
      mountedContext: RaftMountedAvatarContext.compactList,
      content: task.assigneeAvatarPixelKey == null
          ? null
          : RaftAvatarContent(
              name: task.assigneeName!,
              kind: task.assigneeIsAgent
                  ? RaftAvatarContentKind.agent
                  : RaftAvatarContentKind.human,
              pixelKey: task.assigneeAvatarPixelKey,
            ),
    );
    final label = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: t.scale(
        RaftTypeScale.caption,
        weight: task.assigneeIsViewer ? FontWeight.w600 : FontWeight.w400,
        color: task.assigneeIsViewer ? t.ui.foreground : t.ui.foregroundMuted,
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 192),
      // A box with no room for the gap after the avatar drops the gap (the
      // name truncates into whatever is left, as Web's `truncate` does).
      child: LayoutBuilder(
        builder: (context, box) => Row(
          key: const ValueKey('message-task-chip-assignee'),
          mainAxisSize: MainAxisSize.min,
          spacing: box.maxWidth < _avatarAndGap ? 0 : 6,
          children: [
            avatar,
            Flexible(child: label),
          ],
        ),
      ),
    );
  }

  /// The avatar slot (20) and the gap after it (6).
  static const _avatarAndGap = 26.0;
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
