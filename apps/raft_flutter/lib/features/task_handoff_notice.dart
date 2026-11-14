// Source: Web v1.24 task/taskHandoffNotice.ts + TaskHandoffCard.tsx.
// A task handed to someone with a reason is an assignment line whose
// `actionMetadata` is `{kind: task-assignment, actor, assignee, reason}`; the
// conversation draws it as a card (the line's text stays the record).
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_reference_directory.dart';
import 'sender_avatar_projection.dart';

typedef HandoffParty = ({
  String type,
  String id,
  String? name,
  String? displayName,
});

typedef HandoffNotice = ({
  int taskNumber,
  HandoffParty actor,
  HandoffParty? assignee,
  String? reason,
});

HandoffParty? _party(Object? value) {
  if (value is! Map) return null;
  final type = value['type'], id = value['id'];
  if ((type != 'user' && type != 'agent') || id is! String || id.isEmpty) {
    return null;
  }
  String? text(Object? v) => v is String && v.isNotEmpty ? v : null;
  return (
    type: type as String,
    id: id,
    name: text(value['name']),
    displayName: text(value['displayName']),
  );
}

bool sameParty(HandoffParty? a, HandoffParty b) =>
    a != null && a.type == b.type && a.id == b.id;

/// shared readTaskAssignmentNotice: null for any other message.
HandoffNotice? readTaskAssignmentNotice(RaftMessage message) {
  if (message.string('messageType') != 'system') return null;
  final meta = message.json['actionMetadata'];
  if (meta is! Map || meta['kind'] != 'task-assignment') return null;
  final number = meta['taskNumber'];
  final actor = _party(meta['actor']);
  if (number is! num || actor == null) return null;
  final assignee = meta['assignee'] == null ? null : _party(meta['assignee']);
  if (meta['assignee'] != null && assignee == null) return null;
  final reason = meta['reason'];
  return (
    taskNumber: number.toInt(),
    actor: actor,
    assignee: assignee,
    reason: reason is String && reason.trim().isNotEmpty ? reason : null,
  );
}

/// shared isTaskHandoffWithReason: to someone other than the actor, saying why.
HandoffNotice? readTaskHandoffNotice(RaftMessage message) {
  final notice = readTaskAssignmentNotice(message);
  final to = notice?.assignee;
  if (notice == null ||
      notice.reason == null ||
      to == null ||
      sameParty(to, notice.actor)) {
    return null;
  }
  return notice;
}

/// The first later assignment line that gives the task back to whoever
/// handed it off (they took it, or someone assigned it to them), as who made
/// that change and when. A hand-off another one replaced before it came back
/// stays open. [rows] are in timeline order.
({HandoffParty by, DateTime? at})? taskHandoffReturn(
  RaftMessage handoff,
  Iterable<RaftMessage> rows,
) {
  final notice = readTaskHandoffNotice(handoff);
  if (notice == null) return null;
  var seen = false;
  for (final row in rows) {
    if (!seen) {
      seen = row.id == handoff.id;
      continue;
    }
    final later = readTaskAssignmentNotice(row);
    if (later == null) continue;
    if (sameParty(later.assignee, notice.actor)) {
      return (by: later.actor, at: row.createdAt);
    }
  }
  return null;
}

/// A system line in the timeline: the hand-off card when it is a hand-off
/// with a reason, else the one-line notice. [key] is the row's message key.
Widget systemTile(
  BuildContext context,
  RaftMessage message,
  Iterable<RaftMessage> rows,
  MessageReferenceDirectory directory,
  String Function(DateTime) clock,
  String key,
) =>
    _handoffCard(context, message, rows, directory, clock, key) ??
    RaftSystemMessage(
      key: ValueKey('message-$key'),
      content: message.content,
      timestamp: message.createdAt == null ? '' : clock(message.createdAt!),
    );

Widget? _handoffCard(
  BuildContext context,
  RaftMessage message,
  Iterable<RaftMessage> rows,
  MessageReferenceDirectory directory,
  String Function(DateTime) clock,
  String key,
) {
  final origin = directory.w.client.origin;
  final notice = readTaskHandoffNotice(message);
  if (notice == null) return null;
  final to = notice.assignee!;
  ({String name, SenderAvatarProjection source}) identity(HandoffParty p) {
    final agent = p.type == 'agent';
    final rows = agent ? directory.agents : directory.members;
    final row = rows
        .where((r) => (agent ? r['id'] : r['userId'] ?? r['id']) == p.id)
        .firstOrNull;
    final name =
        '${row?['displayName'] ?? row?['name'] ?? p.displayName ?? p.name ?? ''}';
    return (
      name: name,
      source: projectSenderAvatar(
        origin: origin,
        senderId: p.id,
        senderType: p.type,
        agents: directory.agents,
        members: directory.members,
      ),
    );
  }

  String handle(HandoffParty p, String name) =>
      p.name != null ? '@${p.name}' : name;
  Widget avatar(
    HandoffParty p,
    ({String name, SenderAvatarProjection source}) i,
  ) {
    final agent = p.type == 'agent';
    final kind = agent ? RaftAvatarKind.agent : RaftAvatarKind.human;
    return RaftAvatar(
      name: i.name,
      kind: kind,
      mountedContext: RaftMountedAvatarContext.compactList,
      content: RaftAvatarContent(
        name: i.name,
        kind: agent ? RaftAvatarContentKind.agent : RaftAvatarContentKind.human,
        uploadedUrl: i.source.uploadedUrl,
        pixelKey: i.source.pixelKey,
      ),
    );
  }

  final from = identity(notice.actor), target = identity(to);
  final fromHandle = handle(notice.actor, from.name);
  final toHandle = handle(to, target.name);
  final back = taskHandoffReturn(message, rows);
  String? returnedLabel;
  if (back != null) {
    final time = back.at == null ? '' : clock(back.at!);
    final byOther = !sameParty(back.by, notice.actor);
    returnedLabel = byOther
        ? raftFormat(context, '{by} handed it back to {name} · {time}', {
            'by': identity(back.by).name,
            'name': from.name,
            'time': time,
          })
        : raftFormat(context, '{name} took it back · {time}', {
            'name': from.name,
            'time': time,
          });
  }
  return Padding(
    key: ValueKey('message-$key'),
    padding: const RaftTimelineCompositionRecipe().messageInsetFor(
      MediaQuery.sizeOf(context).width,
    ),
    child: RaftTaskHandoffCard(
      from: fromHandle,
      to: toHandle,
      fromAvatar: avatar(notice.actor, from),
      toAvatar: avatar(to, target),
      reason: notice.reason!,
      time: message.createdAt == null ? '' : clock(message.createdAt!),
      returnedLabel: returnedLabel,
      semanticLabel: raftFormat(
        context,
        '{from} handed #{taskNumber} to {to}',
        {'from': fromHandle, 'to': toHandle, 'taskNumber': notice.taskNumber},
      ),
    ),
  );
}
