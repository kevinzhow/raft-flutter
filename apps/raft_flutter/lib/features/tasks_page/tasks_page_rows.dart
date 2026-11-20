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
import '../task_conversation_facts.dart' show taskAssigneeAvatarProjection;
import '../task_v2_mode.dart' show formatTaskConversationRef;
import 'task_card_facts.dart' show TaskActivityTime;

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

/// The page row of [task] (the page variant of the task chip list): the
/// message task chip's facts plus the channel's ref, name and the time.
RaftTaskChipRow tasksPageChipRow(
  WorkspaceController w,
  Map<String, dynamic> task, {
  DateTime? now,
}) {
  final base = messageTaskChipRow(w, task);
  final channel = task['channelName'];
  final avatar = taskAssigneeAvatarProjection(w, task);

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
    assigneeAvatarUrl: avatar?.uploadedUrl,
    assigneeAvatarPixelKey: avatar?.pixelKey,
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
