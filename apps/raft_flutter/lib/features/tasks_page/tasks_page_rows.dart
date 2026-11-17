// What the Tasks page prints for a task row, from the row the store holds: the
// chip row of the list (number, title, assignee, status, time), the last
// activity time, and the page's counted copy.
//
// Source: Web v1.24 components/task/tasksPage/TasksPageRowParts.tsx and the
// page-variant TaskChipList.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/workspace_controller.dart';
import '../message_task_list.dart' show messageTaskChipRow;
import '../task_v2_mode.dart' show formatTaskConversationRef;
import 'tasks_page_model.dart';

/// Web `formatShortRelativeTime`: as short as it gets ("9d ago"), in minutes
/// under an hour, hours under a day, then days; a clock a little behind the
/// server's reads as just now. Null when [value] is not an instant.
String? shortRelativeTime(BuildContext context, String value, DateTime now) {
  final at = DateTime.tryParse(value);
  if (at == null) return null;
  final age = now.difference(at);
  final ms = age.isNegative ? 0 : age.inMilliseconds;
  const minute = 60 * 1000, hour = 60 * minute, day = 24 * hour;
  if (ms < hour) {
    return raftFormat(context, '{count}m ago', {
      'count': (ms / minute).round(),
    });
  }
  if (ms < day) {
    return raftFormat(context, '{count}h ago', {'count': (ms / hour).round()});
  }
  return raftFormat(context, '{count}d ago', {'count': (ms / day).round()});
}

/// A count as the message says it: English's `#` groups thousands
/// (`2,000`), the Chinese `{count}` does not.
String _counted(BuildContext context, int count) {
  if (Localizations.maybeLocaleOf(context)?.languageCode == 'zh') {
    return '$count';
  }
  return '$count'.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

/// Counted copy with Web's one / other plural arms: the English source of
/// each arm is its own catalog key.
String tasksPlural(
  BuildContext context,
  int count,
  String one,
  String other, [
  Map<String, Object?> values = const {},
]) => raftFormat(context, count == 1 ? one : other, {
  'count': _counted(context, count),
  ...values,
});

/// The ", skipped N" a batch toast ends with, when any were skipped.
String tasksSkipped(BuildContext context, int skipped) => skipped <= 0
    ? ''
    : raftFormat(context, ', skipped {skipped}', {'skipped': skipped});

/// A row's last-activity time: short, in mono, the full date in its tooltip;
/// an open task nobody updated for three days shows it in the warning ink
/// with a screen reader's "no update for 3 days" after it.
class TaskActivityTime extends StatelessWidget {
  const TaskActivityTime({super.key, required this.task, this.now});
  final Map<String, dynamic> task;

  /// The clock (tests move it).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final at = taskActivityAt(task);
    final clock = now ?? DateTime.now();
    final short = shortRelativeTime(context, at, clock);
    if (short == null) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    final stale = isStaleTask(task, clock);
    final style = t
        .scale(
          RaftTypeScale.monoMeta,
          mono: true,
          color: stale
              ? (t.colors['warning-strong'] ?? t.ui.foregroundHint)
              : t.ui.foregroundHint,
        )
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final days = staleAfter.inDays;
    final full = DateTime.tryParse(at)?.toLocal();
    return RaftTooltip(
      message: full == null
          ? short
          : '${full.year}-${_two(full.month)}-${_two(full.day)} '
                '${_two(full.hour)}:${_two(full.minute)}',
      child: Semantics(
        container: true,
        label: stale
            ? '$short ${raftFormat(context, 'no update for {days} days', {'days': days})}'
            : short,
        child: ExcludeSemantics(
          child: Text(
            short,
            key: const ValueKey('tasks-page-activity-time'),
            maxLines: 1,
            softWrap: false,
            style: style,
          ),
        ),
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

/// The page row of [task] (the page variant of the task chip list): the
/// message task chip's facts plus the channel's ref, name and the time.
RaftTaskChipRow tasksPageChipRow(
  WorkspaceController w,
  Map<String, dynamic> task, {
  DateTime? now,
}) {
  final base = messageTaskChipRow(w, task);
  final channel = task['channelName'];
  return RaftTaskChipRow(
    id: base.id,
    number: base.number,
    title: base.title,
    status: base.status,
    replyCount: base.replyCount,
    unread: base.unread,
    assigneeName: base.assigneeName,
    assigneeIsAgent: base.assigneeIsAgent,
    assigneeIsViewer: base.assigneeIsViewer,
    assigneeAvatarUrl: base.assigneeAvatarUrl,
    ref: formatTaskConversationRef(task, dmPeerName: _dmPeer(w, task)),
    channelName: channel is String && channel.isNotEmpty ? channel : null,
    time: TaskActivityTime(task: task, now: now),
  );
}

String? _dmPeer(WorkspaceController w, Map<String, dynamic> task) {
  if (task['channelType'] != 'dm') return null;
  final id = task['channelId'];
  for (final dm in w.dms) {
    if (dm.id == id) {
      final name = dm.name;
      return name.isEmpty ? null : name;
    }
  }
  return null;
}
