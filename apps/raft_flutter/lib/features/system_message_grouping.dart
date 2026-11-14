import 'package:raft_client/raft_client.dart';

/// Source `systemMessageGrouping.ts`: render-only grouping of adjacent system
/// messages. The message list itself is never changed; the first row of a run
/// of two or more shows a summary disclosure, the rest hide.
sealed class SystemGroupState {
  const SystemGroupState(this.groupId);
  final String groupId;
}

class SystemGroupHide extends SystemGroupState {
  const SystemGroupHide(super.groupId);
}

class SystemGroupSummary extends SystemGroupState {
  const SystemGroupSummary(
    super.groupId, {
    required this.summary,
    required this.messageIndexes,
  });
  final String summary;
  final List<int> messageIndexes;
}

enum _Category { taskUpdate, reminder, system }

String _stripLeadingStatusGlyph(String content) {
  final trimmed = content.trim();
  final firstSpace = trimmed.indexOf(' ');
  if (firstSpace <= 0) return trimmed;
  final first = trimmed.substring(0, firstSpace);
  if (RegExp(r'^[^\p{L}\p{N}@#]+$', unicode: true).hasMatch(first)) {
    return trimmed.substring(firstSpace + 1).trim();
  }
  return trimmed;
}

final _taskEvents = [
  RegExp(
    r'^(.+?) converted a message to task #(\d+)\s+"([^"]*)"',
    unicode: true,
  ),
  RegExp(r'^(.+?) claimed #(\d+)\s+"([^"]*)"', unicode: true),
  RegExp(r'^(.+?) released #(\d+)\s+"([^"]*)"', unicode: true),
  RegExp(r'^(.+?) moved #(\d+)\s+"([^"]*)" to (.+)$', unicode: true),
  RegExp(r'^(.+?) deleted #(\d+)\s+"([^"]*)"', unicode: true),
];
final _taskWords = RegExp(
  r'\b(?:new tasks? created|converted a message to task #\d+|claimed #\d+|released #\d+|moved #\d+|deleted #\d+)\b',
  caseSensitive: false,
  unicode: true,
);
final _reminder = RegExp(
  r'^(?:Reminder\s+#\w+|Reminder(?: \([^)]+\))?:|.+?\s+(?:scheduled|canceled|cancelled)\s+(?:a\s+)?reminder\b)',
  caseSensitive: false,
  unicode: true,
);

_Category? _classify(RaftMessage message) {
  if (message.string('messageType') != 'system') return null;
  // Web 1.24: these are cards of their own, never folded into a summary.
  if (_ownCard(message)) return null;
  final content = _stripLeadingStatusGlyph(message.content);
  if (_taskEvents.any((p) => p.hasMatch(content))) return _Category.taskUpdate;
  if (_taskWords.hasMatch(content)) return _Category.taskUpdate;
  if (_reminder.hasMatch(content)) return _Category.reminder;
  return _Category.system;
}

String _count(
  String Function(String, Map<String, Object?>) format,
  int count,
  String one,
  String other,
) => format(count == 1 ? one : other, {'count': count});

String _summary(
  List<_Category> categories,
  String Function(String, Map<String, Object?>) format,
) {
  final tasks = categories.where((c) => c == _Category.taskUpdate).length;
  final reminders = categories.where((c) => c == _Category.reminder).length;
  final systems = categories.where((c) => c == _Category.system).length;
  final parts = [
    if (tasks > 0)
      _count(format, tasks, '{count} task update', '{count} task updates'),
    if (reminders > 0)
      _count(
        format,
        reminders,
        '{count} reminder update',
        '{count} reminder updates',
      ),
    if (systems > 0)
      _count(
        format,
        systems,
        '{count} system message',
        '{count} system messages',
      ),
  ];
  final separator = format(', ', const {});
  if (parts.length == 1) {
    return format(
      categories.length == 1 ? 'There is {part}' : 'There are {part}',
      {'part': parts.first},
    );
  }
  if (systems == 0) {
    return format('There are {parts}', {'parts': parts.join(separator)});
  }
  return format('There are {count} system updates: {parts}', {
    'count': categories.length,
    'parts': parts.join(separator),
  });
}

/// One state per message (`null` = not part of a run). [format] localizes a
/// complete sentence (`raftFormat`).
List<SystemGroupState?> buildSystemGroupStates(
  List<RaftMessage> messages,
  String Function(String, Map<String, Object?>) format,
) {
  final categories = [for (final m in messages) _classify(m)];
  final states = List<SystemGroupState?>.filled(messages.length, null);
  for (var i = 0; i < messages.length; i++) {
    if (categories[i] == null) continue;
    var end = i + 1;
    while (end < messages.length && categories[end] != null) {
      end++;
    }
    if (end - i > 1) {
      final groupId = 'system-group:${messages[i].id}:${messages[end - 1].id}';
      states[i] = SystemGroupSummary(
        groupId,
        summary: _summary([
          for (var j = i; j < end; j++) categories[j]!,
        ], format),
        messageIndexes: [for (var j = i; j < end; j++) j],
      );
      for (var j = i + 1; j < end; j++) {
        states[j] = SystemGroupHide(groupId);
      }
    }
    i = end - 1;
  }
  return states;
}

/// Web 1.24 systemMessageGrouping `classifySystemMessage`: an RFC 077
/// delegated receipt (its Retract), the WeChat connected notice (its
/// Disconnect WeChat) and a task hand-off with a reason stay their own row.
bool _ownCard(RaftMessage message) {
  final metadata = message.json['actionMetadata'];
  if (metadata is Map && metadata['kind'] == 'delegated-receipt') return true;
  final randomId = message.json['randomId'];
  if (randomId is String && randomId.startsWith('wechat-connected:')) {
    return true;
  }
  return metadata is Map && _isHandoffWithReason(metadata);
}

/// Shared `readTaskAssignmentNotice` + `isTaskHandoffWithReason`.
bool _isHandoffWithReason(Map<dynamic, dynamic> metadata) {
  if (metadata['kind'] != 'task-assignment' || metadata['taskNumber'] is! num) {
    return false;
  }
  (String, String)? party(Object? value) =>
      value is Map &&
          (value['type'] == 'user' || value['type'] == 'agent') &&
          value['id'] is String &&
          (value['id'] as String).isNotEmpty
      ? (value['type'] as String, value['id'] as String)
      : null;
  final actor = party(metadata['actor']);
  final assignee = party(metadata['assignee']);
  final reason = metadata['reason'];
  return actor != null &&
      assignee != null &&
      reason is String &&
      reason.trim().isNotEmpty &&
      assignee != actor;
}
