import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import 'private_route_guard.dart';

class SelectedMessageRow {
  const SelectedMessageRow(this.message, {this.parentId});
  final RaftMessage message;
  final String? parentId;
  bool get isThreadChild => parentId != null;
}

/// Only retained messages from the selected channel/thread are selectable.
/// Channel-mode parent selection includes its already-loaded descendants.
class MessageSelection extends ChangeNotifier {
  MessageSelection(this.w, {required this.thread}) {
    w.addListener(changed);
    changed();
  }
  static const limit = 30;
  final WorkspaceController w;
  final bool thread;
  final Set<String> ids = {};
  bool active = false;
  String? _scope, error;
  Map<String, dynamic>? _channelAuthority;
  String get scope => jsonEncode([
    w.client.generation,
    w.client.user?.id,
    w.server?.id,
    w.server?.string('role'),
    w.channel?.id,
    if (thread) w.threadParent?.id,
    if (thread) w.threadChannelId,
  ]);
  List<SelectedMessageRow> get available {
    final roots = thread
        ? [if (w.threadParent != null) w.threadParent!]
        : w.messages;
    final result = <SelectedMessageRow>[];
    for (final root in roots) {
      result.add(SelectedMessageRow(root));
      final replies = thread
          ? w.replies
          : root.threadId == null
          ? <RaftMessage>[]
          : [
              for (final row in w.ledger.messages(root.threadId!))
                RaftMessage(row),
              if (w.threadParent?.id == root.id) ...w.replies,
            ];
      final unique = {for (final m in replies) m.id: m}.values.toList()
        ..sort((a, b) => a.seq.compareTo(b.seq));
      for (final m in unique) {
        result.add(SelectedMessageRow(m, parentId: root.id));
      }
    }
    return result;
  }

  List<SelectedMessageRow> get selected =>
      available.where((r) => ids.contains(r.message.id)).toList();
  void changed() {
    final next = scope;
    final authority = w.channel == null
        ? null
        : {
            'joined': w.channel!.joined,
            'channelCapabilities': w.channel!.json['channelCapabilities'],
          };
    if (_scope != null &&
        (_scope != next ||
            channelAuthorityReduced(_channelAuthority, authority))) {
      active = false;
      ids.clear();
      error = null;
    }
    _scope = next;
    _channelAuthority = authority;
    final visible = available.map((r) => r.message.id).toSet();
    ids.removeWhere((id) => !visible.contains(id));
    if (active && ids.isEmpty) active = false;
    notifyListeners();
  }

  void enter(String id) {
    active = true;
    ids.clear();
    toggle(id);
  }

  void exit() {
    active = false;
    ids.clear();
    error = null;
    notifyListeners();
  }

  void toggle(String id) {
    if (!active) return;
    final group = thread
        ? [id]
        : [
            for (final r in available)
              if (r.message.id == id || r.parentId == id) r.message.id,
          ];
    if (ids.contains(id)) {
      ids.removeAll(group);
    } else if (ids.length + group.where((v) => !ids.contains(v)).length >
        limit) {
      error = 'Select up to 30 messages.';
    } else {
      ids.addAll(group);
      error = null;
    }
    notifyListeners();
  }

  void selectAll() {
    final all = available.map((r) => r.message.id).toSet();
    if (all.length > limit) {
      error = 'Select up to 30 messages.';
      notifyListeners();
      return;
    }
    ids
      ..clear()
      ..addAll(all);
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    w.removeListener(changed);
    ids.clear();
    super.dispose();
  }
}

String selectedMessageFingerprint(RaftMessage m) => jsonEncode({
  for (final key in const [
    'id',
    'channelId',
    'content',
    'attachments',
    'actionMetadata',
    'mentions',
    'senderType',
    'senderName',
    'senderDisplayName',
    'sourceServerId',
  ])
    key: m.json[key],
});

String selectedMessagesMarkdown(List<SelectedMessageRow> rows) => rows
    .map((r) {
      final m = r.message,
          stamp = m.createdAt?.toLocal().toIso8601String() ?? '';
      final text =
          '**${m.author}**${stamp.isEmpty ? '' : ' · $stamp'}\n\n${m.content}${m.attachments.isEmpty ? '' : '\n\n${m.attachments.map((a) => "📎 ${a['filename'] ?? 'Attachment'}").join('\n')}'}';
      return r.isThreadChild
          ? text.split('\n').map((line) => '> $line').join('\n')
          : text;
    })
    .join('\n\n---\n\n');

/// UI-only handoff lets the adaptive shell consume Back/Escape before closing
/// the thread or application. It does not store message/domain state.
class ChatSelectionHandle extends ChangeNotifier {
  bool active = false, closed = false;
  VoidCallback? _dismiss;
  void update(bool value, VoidCallback? dismiss) {
    if (closed) return;
    _dismiss = dismiss;
    if (active == value) return;
    active = value;
    notifyListeners();
  }

  bool dismiss() {
    if (!active) return false;
    _dismiss?.call();
    return true;
  }

  @override
  void dispose() {
    closed = true;
    _dismiss = null;
    active = false;
    super.dispose();
  }
}
