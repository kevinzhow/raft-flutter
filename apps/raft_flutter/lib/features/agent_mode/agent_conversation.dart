import 'package:raft_agent_ui/raft_agent_ui.dart';
import 'package:raft_client/raft_client.dart';

import '../../data/raft_permalink.dart';
import '../message_reaction_projection.dart';
import '../message_task_projection.dart';

/// The rows of a channel (the `messages` of `RaftClient.messagePage`, as the
/// wire gives them: unsorted, `seq` a string) as the data of a conversation,
/// oldest first.
///
///  * a `system` message is a system note, a reminder, or (when it says a
///    task was created, claimed, released, moved or deleted) a task event
///    with the task as a chip; its copy is Chinese;
///  * any other message is a bubble: `isMine` is a person's message whose
///    `senderId` is [myUserId]; an Agent's has `senderType` `agent`;
///  * a message that is a task (`taskNumber`, `taskStatus`) carries its chip;
///  * a Raft permalink in the text whose target is among [rows] becomes the
///    quote and leaves the text;
///  * edited and deleted messages say so (a deleted one keeps no words).
///
/// Times are local. A row without a time gets [now] (default: the clock).
List<HfMessageData> hfMessagesFrom(
  List<Map<String, dynamic>> rows, {
  required String? myUserId,
  DateTime? now,
}) {
  final fallback = now ?? DateTime.now();
  final sorted = [...rows]..sort(_bySeq);
  final byId = {
    for (final r in sorted)
      if (_id(r).isNotEmpty) _id(r): r,
  };
  return [
    for (final r in sorted) _message(r, byId, myUserId: myUserId, fallback: fallback),
  ];
}

String _id(Map<String, dynamic> r) => '${r['id'] ?? ''}';

BigInt? _seq(Map<String, dynamic> r) => BigInt.tryParse('${r['seq']}');

int _bySeq(Map<String, dynamic> a, Map<String, dynamic> b) {
  final x = _seq(a), y = _seq(b);
  if (x != null && y != null && x != y) return x.compareTo(y);
  final s = DateTime.tryParse('${a['createdAt']}');
  final t = DateTime.tryParse('${b['createdAt']}');
  if (s != null && t != null && s != t) return s.compareTo(t);
  return 0;
}

String _clip(String s, int max) {
  final line = s.trim().split('\n').first.trim();
  return line.length <= max ? line : '${line.substring(0, max)}…';
}

HfMessageData _message(
  Map<String, dynamic> row,
  Map<String, Map<String, dynamic>> byId, {
  required String? myUserId,
  required DateTime fallback,
}) {
  final message = RaftMessage(row);
  final time = message.createdAt?.toLocal() ?? fallback;
  final id = _id(row).isNotEmpty ? _id(row) : 'seq-${row['seq']}';
  final type = message.string('senderType');
  if (message.string('messageType') == 'system' || type == 'system') {
    return _system(id, time, message.content);
  }
  final deleted =
      row['deletedAt'] != null ||
      row['deleted'] == true ||
      row['isDeleted'] == true;
  final edited =
      row['editedAt'] != null ||
      row['edited'] == true ||
      row['isEdited'] == true;
  final agent = type == 'agent';
  final mine =
      myUserId != null &&
      myUserId.isNotEmpty &&
      !agent &&
      (type == 'user' || type == 'human') &&
      message.senderId == myUserId;
  var text = message.content;
  HfQuoteData? quote;
  if (!deleted) {
    final found = _quoteOf(text, byId, id);
    if (found != null) {
      quote = found.quote;
      text = found.rest;
    }
  }
  final task = provisionalMessageTask(message);
  final reactions = (row['reactions'] as List?) ?? const [];
  final own = projectedOwnReactions(
    principal: myUserId,
    reactions: reactions,
    completeViewer: null,
  );
  return HfMessageData(
    id: id,
    senderId: message.senderId,
    senderName: _senderName(row),
    isMine: mine,
    isAgent: agent,
    time: time,
    text: deleted ? '' : text,
    attachments: deleted
        ? const []
        : [
            for (final a in message.attachments)
              HfAttachmentData(
                id: a['id'] == null ? null : '${a['id']}',
                name: _fileName(a),
                isImage: '${a['mimeType'] ?? ''}'.startsWith('image/'),
                bytes: (a['sizeBytes'] as num?)?.toInt(),
              ),
          ],
    reactions: deleted
        ? const []
        : [
            for (final r in reactions.whereType<Map>())
              if (r['emoji'] is String && _count(r) > 0)
                HfReactionData(
                  r['emoji'] as String,
                  _count(r),
                  mine: own.contains(r['emoji']),
                ),
          ],
    replyCount: deleted ? 0 : (int.tryParse('${row['replyCount']}') ?? 0),
    quote: quote,
    task: deleted || task == null
        ? null
        : HfTaskChipData(
            number: task['taskNumber'] as int?,
            title: _clip('${task['title'] ?? ''}', 80),
            status: task['status'] as String?,
            claimant: task['claimedByName'] as String?,
          ),
    edited: edited && !deleted,
    deleted: deleted,
  );
}

int _count(Map r) {
  final n = r['count'];
  if (n is num) return n.toInt();
  final ids = r['reactorIds'];
  return ids is List ? ids.length : 0;
}

String _fileName(Map<String, dynamic> a) {
  final n = a['filename'] ?? a['name'];
  return n is String && n.trim().isNotEmpty ? n.trim() : '附件';
}

String _senderName(Map<String, dynamic> row) {
  final external = row['externalAuthor'];
  final fromExternal = external is Map ? external['name'] ?? external['displayName'] : null;
  for (final v in [
    row['senderDisplayName'],
    row['senderName'],
    fromExternal,
  ]) {
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return '未知';
}

final _link = RegExp(r'https?://[^\s<>"\x27)]+');

/// The first permalink of a message among [byId]: the quote it makes, and the
/// text without the link.
({HfQuoteData quote, String rest})? _quoteOf(
  String text,
  Map<String, Map<String, dynamic>> byId,
  String selfId,
) {
  if (!text.contains('http')) return null;
  for (final m in _link.allMatches(text)) {
    final url = m[0]!.replaceFirst(RegExp(r'[.,;:!?]+$'), '');
    final host = Uri.tryParse(url)?.host;
    if (host == null || host.isEmpty) continue;
    final link = parseRaftPermalink(url, hostnames: [host]);
    final target = link == null ? null : byId[link.messageId];
    if (target == null || _id(target) == selfId) continue;
    final t = RaftMessage(target);
    final deleted = target['deletedAt'] != null || target['deleted'] == true;
    final rest = text.replaceFirst(m[0]!, '').trim();
    return (
      quote: HfQuoteData(
        author: _senderName(target),
        text: deleted ? '此消息已删除' : _clip(t.content, 120),
        id: _id(target),
      ),
      rest: rest,
    );
  }
  return null;
}

// --- system messages ------------------------------------------------------

String _stripGlyph(String content) {
  final trimmed = content.trim();
  final space = trimmed.indexOf(' ');
  if (space <= 0) return trimmed;
  final first = trimmed.substring(0, space);
  if (RegExp(r'^[^\p{L}\p{N}@#]+$', unicode: true).hasMatch(first)) {
    return trimmed.substring(space + 1).trim();
  }
  return trimmed;
}

final _converted = RegExp(
  r'^(.+?) converted a message to task #(\d+)\s+"([^"]*)"',
  unicode: true,
);
final _claimed = RegExp(r'^(.+?) claimed #(\d+)\s+"([^"]*)"', unicode: true);
final _released = RegExp(r'^(.+?) released #(\d+)\s+"([^"]*)"', unicode: true);
final _moved = RegExp(
  r'^(.+?) moved #(\d+)\s+"([^"]*)" to (.+)$',
  unicode: true,
);
final _deletedTask = RegExp(r'^(.+?) deleted #(\d+)\s+"([^"]*)"', unicode: true);
final _created = RegExp(
  r'new tasks? created',
  caseSensitive: false,
  unicode: true,
);
final _reminder = RegExp(
  r'^(?:Reminder\s+#\w+|Reminder(?: \([^)]+\))?:|.+?\s+(?:scheduled|canceled|cancelled)\s+(?:a\s+)?reminder\b)',
  caseSensitive: false,
  unicode: true,
);

/// The status key a system message names ("In Progress", "done"), or null.
String? _statusKey(String word) {
  final key = word
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s-]+'), '_')
      .replaceAll(RegExp(r'[^a-z_]'), '');
  return agentTaskStatusLabels.containsKey(key) ? key : null;
}

HfMessageData _system(String id, DateTime time, String content) {
  final text = _stripGlyph(content);
  HfMessageData event(String sentence, HfTaskChipData task) => HfMessageData(
    id: id,
    kind: HfMessageKind.taskEvent,
    time: time,
    text: sentence,
    task: task,
  );
  HfTaskChipData chip(RegExpMatch m, {String? status, String? claimant}) =>
      HfTaskChipData(
        number: int.tryParse(m[2]!),
        title: m[3]!,
        status: status,
        claimant: claimant,
      );

  var m = _converted.firstMatch(text);
  if (m != null) return event('${m[1]} 把消息转成了任务', chip(m, status: 'todo'));
  m = _claimed.firstMatch(text);
  if (m != null) {
    return event('${m[1]} 认领了任务', chip(m, claimant: m[1]));
  }
  m = _released.firstMatch(text);
  if (m != null) return event('${m[1]} 放下了任务', chip(m));
  m = _moved.firstMatch(text);
  if (m != null) {
    final status = _statusKey(m[4]!);
    final word = status == null ? m[4]!.trim() : agentTaskStatusLabels[status]!;
    return event('${m[1]} 把任务移到了「$word」', chip(m, status: status));
  }
  m = _deletedTask.firstMatch(text);
  if (m != null) return event('${m[1]} 删除了任务', chip(m));
  if (_created.hasMatch(text)) {
    final number = RegExp(r'#(\d+)').firstMatch(text);
    final title = RegExp(r'"([^"]*)"').firstMatch(text);
    if (number != null && title != null) {
      return event(
        '新建了任务',
        HfTaskChipData(
          number: int.tryParse(number[1]!),
          title: title[1]!,
          status: 'todo',
        ),
      );
    }
  }
  return HfMessageData(
    id: id,
    kind: _reminder.hasMatch(text)
        ? HfMessageKind.reminder
        : HfMessageKind.system,
    time: time,
    text: text,
  );
}
