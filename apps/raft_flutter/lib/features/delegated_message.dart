import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

// RFC 077 (Web 1.24 components/message/delegatedMessage.ts): a message a
// person's assistant sent for them ("sent by Friday"). The server puts
// `delegatedBy: { id, name, displayName, avatarUrl, deleted } | null` and
// `deletedAt` (the owner retracted it, else null) on every message row.

/// The assistant that sent a message for its sender.
typedef DelegatedBy = ({
  String id,
  String name,
  String? avatarUrl,
  bool deleted,
});

/// The assistant that sent [message] (a person's message only), or null.
DelegatedBy? delegatedByOf(RaftMessage message) {
  if (message.string('senderType') != 'user') return null;
  return readDelegatedBy(message.json['delegatedBy']);
}

DelegatedBy? readDelegatedBy(Object? value) {
  if (value is! Map) return null;
  final id = value['id'];
  if (id is! String || id.isEmpty) return null;
  final display = value['displayName'];
  final name = display is String && display.trim().isNotEmpty
      ? display
      : value['name'] is String
      ? value['name'] as String
      : '';
  return (
    id: id,
    name: name,
    avatarUrl: value['avatarUrl'] is String
        ? value['avatarUrl'] as String
        : null,
    // No name left to show reads as deleted too, so the words never go blank.
    deleted: value['deleted'] == true || name.isEmpty,
  );
}

/// Grouping key: a delegated message never continues the sender's own run.
String delegatedGroupKey(RaftMessage message) =>
    readDelegatedBy(message.json['delegatedBy'])?.id ?? '';

/// "sent by Friday" after the sender, or "(sent by Friday)" at the end of a
/// continuation; "sent by a deleted assistant" once it is gone.
String? delegatedByLabel(
  BuildContext context,
  RaftMessage message, {
  required bool continuation,
}) {
  final by = delegatedByOf(message);
  if (by == null) return null;
  if (by.deleted) {
    return raftText(
      context,
      continuation
          ? '(sent by a deleted assistant)'
          : 'sent by a deleted assistant',
    );
  }
  return raftFormat(
    context,
    continuation ? '(sent by {name})' : 'sent by {name}',
    {'name': by.name},
  );
}

/// What a retracted message still shows: its place, sender and time; no
/// reactions or attachments (Web MessageItem `actionable` false).
RaftMessage withoutRetractedParts(RaftMessage message) => message.retracted
    ? RaftMessage({
        ...message.json,
        'reactions': const [],
        'attachments': const [],
      })
    : message;
