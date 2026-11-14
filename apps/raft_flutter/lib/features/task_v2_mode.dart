// Task v2 per-task mode, the Web v1.24 utils/taskConversation.ts helpers.
// A task made the v2 way owns its discussion (a `channels.type = 'task'`
// sub-conversation keyed by the task, not a message's thread) and hangs under
// the message it was created from (`sourceMessageId`). Such a task keeps
// working the v2 way whatever the `task_v2_conversations_v0` flag says now.

/// Web `isTaskV2Task`: the task's discussion is its own conversation (it
/// exists, or the task was created to have one). A DTO with none of the v2
/// fields (an older server) is pre-v2.
bool isTaskV2Task(Map<String, dynamic> task) {
  if (task['isLegacy'] == true) return false;
  if (task['conversationAnchored'] == true) return true;
  final conversation = task['conversationChannelId'];
  if (conversation is String && conversation.isNotEmpty) return true;
  return task.containsKey('hostMessageId') && task['hostMessageId'] == null;
}

/// Web `opensAsTaskConversation`: with the flag on every non-legacy task opens
/// its own dialog; off, only a task made the v2 way does.
bool opensAsTaskConversation(Map<String, dynamic> task, bool taskV2Enabled) {
  if (task['isLegacy'] == true) return false;
  return taskV2Enabled || isTaskV2Task(task);
}

/// Web `directTaskConversationChannelId`: the conversation this server can use
/// directly. A joint channel's local conversation is answered by
/// `POST /tasks/:id/conversation` instead.
String? directTaskConversationChannelId(Map<String, dynamic> task) {
  final id = task['conversationChannelId'];
  if (id is! String || id.isEmpty) return null;
  return task['channelType'] == 'joint' ? null : id;
}

/// The message a task hangs under: its source (task v2), else a pre-v2 task's
/// host message (Web ChatPanel `tasksByMessageId`). Null for a task created
/// without one (a channel-only task).
String? taskAnchorMessageId(Map<String, dynamic> task, bool taskV2Enabled) {
  if ((taskV2Enabled || isTaskV2Task(task)) &&
      task.containsKey('sourceMessageId')) {
    final source = task['sourceMessageId'];
    return source is String && source.isNotEmpty ? source : null;
  }
  final message = task['messageId'];
  return message is String && message.isNotEmpty ? message : null;
}

/// `task:<taskId>`, the item of a task-keyed `task=<channelId>:task:<taskId>`
/// URL (Web formatTaskConversationParam).
const taskConversationItemPrefix = 'task:';

/// The task id of a task-keyed URL item, else null (message-keyed).
String? taskIdOfTaskItem(String itemId) =>
    itemId.startsWith(taskConversationItemPrefix) &&
        itemId.length > taskConversationItemPrefix.length
    ? itemId.substring(taskConversationItemPrefix.length)
    : null;

/// The URL item a task opens with: task-keyed for a task that opens as its
/// own conversation, its message for a pre-v2 task, its id for a legacy one.
String? taskSurfaceItemId(Map<String, dynamic> row, bool taskV2Enabled) {
  if (row['isLegacy'] == true) return row['id'] as String?;
  if (opensAsTaskConversation(row, taskV2Enabled) && row['id'] is String) {
    return '$taskConversationItemPrefix${row['id']}';
  }
  return row['messageId'] as String?;
}

/// What a task's Source property shows (Web `taskSourceDisplay`).
sealed class TaskSourceDisplay {
  const TaskSourceDisplay();
}

class TaskSourceMessage extends TaskSourceDisplay {
  const TaskSourceMessage(this.id);
  final String id;
}

class TaskSourceNotRecorded extends TaskSourceDisplay {
  const TaskSourceNotRecorded();
}

TaskSourceDisplay? taskSourceDisplay(Map<String, dynamic> task) {
  final source = task['sourceMessageId'];
  final sourceId = source is String && source.isNotEmpty ? source : null;
  final recorded = task['sourceRecorded'];
  if (recorded is bool) {
    return recorded && sourceId != null
        ? TaskSourceMessage(sourceId)
        : const TaskSourceNotRecorded();
  }
  final host = task.containsKey('hostMessageId')
      ? task['hostMessageId']
      : task['messageId'];
  if (sourceId == null || sourceId == host) return null;
  return TaskSourceMessage(sourceId);
}

/// Web `formatTaskConversationRef`: `#channel:#7`, `dm:@peer:#7`, else `#7`.
String formatTaskConversationRef(
  Map<String, dynamic> task, {
  String? dmPeerName,
}) {
  final number = task['taskNumber'];
  if (task['channelType'] == 'dm') {
    return dmPeerName != null && dmPeerName.isNotEmpty
        ? 'dm:@$dmPeerName:#$number'
        : '#$number';
  }
  final name = '${task['channelName'] ?? ''}'.replaceFirst(RegExp('^#'), '');
  return name.isEmpty ? '#$number' : '#$name:#$number';
}

/// Web `getTaskStatusOptions`: every status from any status (the server has
/// no transition table), without `in_review` on a v2 task (retired) and
/// without `backlog` on a pre-v2 one (refused there); a task already in one
/// keeps it as its current option.
List<String> taskV2StatusOptions(
  Map<String, dynamic> task,
  bool taskV2Enabled,
) {
  final current = task['status'];
  final v2 = opensAsTaskConversation(task, taskV2Enabled);
  return [
    for (final status in const [
      'backlog',
      'todo',
      'in_progress',
      'in_review',
      'done',
      'closed',
    ])
      if (!(v2 && status == 'in_review' && current != 'in_review') &&
          !(!v2 && status == 'backlog' && current != 'backlog'))
        status,
  ];
}
