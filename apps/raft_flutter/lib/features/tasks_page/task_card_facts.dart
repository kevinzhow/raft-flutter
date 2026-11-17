// What a Tasks page card says after its title and its status: the number of
// messages in the task's conversation, who has it (or Unassigned), and when it
// was last updated. Web v1.24 components/task/tasksPage/TasksPageRowParts.tsx
// (TaskActivityTime, TaskCardReplies, TaskCardFacts).

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/workspace_controller.dart';
import '../message_task_list.dart';
import 'tasks_page_model.dart';

/// "12m ago" / "12 分钟前": as short as it gets, in steps of minutes under an
/// hour, hours under a day, then days (Web `formatShortRelativeTime`: `style:
/// narrow`, `numeric: always`; a clock a little behind reads as just now, and
/// the zh output gets a space between the digits and the CJK). Null for a time
/// that is not one.
String? shortRelativeTime(String? at, DateTime now, {required bool zh}) {
  final date = at == null || at.isEmpty ? null : DateTime.tryParse(at);
  if (date == null) return null;
  final age = now.difference(date);
  final ms = age.isNegative ? 0 : age.inMilliseconds;
  const minute = 60000, hour = 60 * minute, day = 24 * hour;
  final (unit, step) = ms < hour
      ? ('m', minute)
      : ms < day
      ? ('h', hour)
      : ('d', day);
  final count = (ms / step).round();
  if (!zh) return '$count$unit ago';
  return '$count ${switch (unit) {
    'm' => '分钟前',
    'h' => '小时前',
    _ => '天前',
  }}';
}

/// The days an open task has gone without an update before it turns stale
/// (what a screen reader hears after the time).
final staleDays = staleAfter.inDays;

/// Web `TaskActivityTime`: when the task was last updated, short and in the
/// mono face, the full date and time in its tooltip. An open task nobody has
/// updated for three days shows it in the warning ink, with no words on
/// screen; a screen reader hears "no update for 3 days" after the time.
class TaskActivityTime extends StatelessWidget {
  const TaskActivityTime({super.key, required this.task, this.now});
  final Map<String, dynamic> task;

  /// Test seam: the clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final at = taskActivityAt(task);
    final clock = now ?? DateTime.now();
    final locale = Localizations.maybeLocaleOf(context);
    final zh = locale?.languageCode == 'zh';
    final short = shortRelativeTime(at, clock, zh: zh);
    if (short == null) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    final stale = isStaleTask(task, clock);
    final full = DateFormat.yMMMd(
      locale?.toLanguageTag(),
    ).add_jm().format(DateTime.parse(at).toLocal());
    final style = t
        .scale(
          RaftTypeScale.monoMeta,
          mono: true,
          color: stale ? t.colors['warning-strong'] : t.ui.foregroundHint,
        )
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final label = stale
        ? '$short ${raftFormat(context, 'no update for {days} days', {'days': staleDays})}'
        : short;
    return RaftTooltip(
      message: full,
      excludeFromSemantics: true,
      child: Semantics(
        label: label,
        excludeSemantics: true,
        child: Text(
          short,
          key: ValueKey(
            stale
                ? 'tasks-page-activity-time-stale'
                : 'tasks-page-activity-time',
          ),
          maxLines: 1,
          softWrap: false,
          style: style,
        ),
      ),
    );
  }
}

/// Web `TaskCardReplies`: the unread pixel and the number of messages in the
/// task's discussion, inline after a card's title; nothing when there is
/// neither.
Widget? taskCardReplies(WorkspaceController w, Map<String, dynamic> task) {
  final row = messageTaskChipRow(w, task);
  if (row.replyCount <= 0 && !row.unread) return null;
  return RaftTaskReplyCount(task: row);
}

/// Web `TaskCardFacts`: a card's read-only facts after its status: who has it
/// (or Unassigned), and when it was last updated.
class TaskCardFacts extends StatelessWidget {
  const TaskCardFacts({
    super.key,
    required this.controller,
    required this.task,
    this.now,
  });
  final WorkspaceController controller;
  final Map<String, dynamic> task;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final row = messageTaskChipRow(controller, task);
    final assigned = row.assigneeName != null;
    // The time keeps its room; the assignee takes what is left and goes when
    // it cannot show an avatar and a letter.
    final who = assigned
        ? RaftTaskAssignee(task: row)
        : Text(
            raftTextZh(context, 'Unassigned', '未分配'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.scale(RaftTypeScale.caption, color: t.ui.foregroundHint),
          );
    return LayoutBuilder(
      builder: (context, box) => Row(
        key: const ValueKey('tasks-page-card-facts'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: LayoutBuilder(
              builder: (context, room) => room.maxWidth < 30
                  ? const SizedBox.shrink()
                  : Padding(
                      // ds-allow: Web TaskCardFacts `gap-2`
                      padding: const EdgeInsets.only(right: 8),
                      child: who,
                    ),
            ),
          ),
          // The time is never wider than the facts' own room (a card too
          // narrow for it clips the time rather than overflowing).
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth),
            child: TaskActivityTime(task: task, now: now),
          ),
        ],
      ),
    );
  }
}
