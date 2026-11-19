import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import 'forward_messages_dialog.dart' show messageForwardable;
import 'private_route_guard.dart';

part 'message_selection_range.dart';

class SelectedMessageRow {
  const SelectedMessageRow(this.message, {this.parentId});
  final RaftMessage message;
  final String? parentId;
  bool get isThreadChild => parentId != null;
}

/// Only retained messages from the selected channel/thread are selectable.
/// Channel mode selects only mounted timeline roots. Thread mode exposes the
/// parent and replies, with explicit Select All; a row toggle selects one row.
class MessageSelection extends ChangeNotifier {
  MessageSelection(this.w, {required this.thread}) {
    w.addListener(changed);
    changed();
  }
  static const limit = 30;
  final WorkspaceController w;
  final bool thread;
  final Set<String> ids = {};
  String? anchorId;
  bool active = false;
  int revision = 0;
  // ignore: raft_lints/avoid_imperative_notice_state -- Selection-limit notice: cleared on a successful select, a deselect, select all, exit and any scope/authority change.
  String? _scope, error;
  Map<String, dynamic>? _channelAuthority;
  String get scope => jsonEncode([
    w.client.generation,
    w.client.user?.id,
    w.server?.id,
    w.server?.string('role'),
    w.channel?.id,
    if (thread) w.messageDomain.state.threadParent?.id,
    if (thread) w.threadChannelId,
  ]);
  List<SelectedMessageRow> get available {
    final roots = thread
        ? [
            if (w.messageDomain.state.threadParent != null)
              w.messageDomain.state.threadParent!,
          ]
        : w.messageDomain.messages;
    final result = <SelectedMessageRow>[];
    for (final root in roots) {
      if (root.string('messageType') == 'system') continue;
      result.add(SelectedMessageRow(root));
      final replies = thread ? w.replies : <RaftMessage>[];
      final unique = {for (final m in replies) m.id: m}.values.toList()
        ..sort((a, b) => a.seq.compareTo(b.seq));
      for (final m in unique) {
        if (m.string('messageType') == 'system') continue;
        result.add(SelectedMessageRow(m, parentId: root.id));
      }
    }
    return result;
  }

  List<SelectedMessageRow> get selected => ids.isEmpty
      ? []
      : available.where((r) => ids.contains(r.message.id)).toList();
  void changed() {
    final previousIds = ids.toSet(), previousActive = active;
    final previousError = error;
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
      anchorId = null;
      error = null;
    }
    _scope = next;
    _channelAuthority = authority;
    // Most workspace notifications (including section changes) have no
    // selection to reconcile. Do not project the entire message window then.
    if (ids.isNotEmpty) {
      final visible = available.map((r) => r.message.id).toSet();
      ids.removeWhere((id) => !visible.contains(id));
      if (!ids.contains(anchorId)) anchorId = null;
    }
    if (active && ids.isEmpty) active = false;
    final changed = previousActive != active || !setEquals(previousIds, ids);
    if (changed) revision++;
    // Active exports also observe edits/deletions of selected messages. An
    // inactive empty selection has no row state to publish on workspace events.
    if (active || changed || previousError != error) notifyListeners();
  }

  void enter(String id) {
    if (!available.any((r) => r.message.id == id)) return;
    revision++;
    active = true;
    ids.clear();
    anchorId = null;
    toggle(id);
  }

  void exit() {
    revision++;
    active = false;
    ids.clear();
    anchorId = null;
    error = null;
    notifyListeners();
  }

  void toggle(String id) {
    if (!active) return;
    revision++;
    if (!available.any((r) => r.message.id == id)) return;
    final group = [id];
    if (ids.contains(id)) {
      ids.removeAll(group);
      if (anchorId == id) anchorId = null;
      // Dropping a row answers the "too many selected" notice.
      error = null;
    } else if (ids.length + group.where((v) => !ids.contains(v)).length >
        limit) {
      error = 'Select up to 30 messages.';
    } else {
      ids.addAll(group);
      anchorId = id;
      error = null;
    }
    notifyListeners();
  }

  MessageSelectionRange? rangeToVisible(Iterable<String> visible) {
    final anchor = anchorId;
    return active && anchor != null
        ? _messageSelectionRange(available, anchor, visible)
        : null;
  }

  void selectToVisible(Iterable<String> visible) {
    final range = rangeToVisible(visible);
    if (range == null) return;
    final next = {...ids, ...range.ids};
    if (next.length > limit) {
      error = 'Select up to 30 messages.';
    } else {
      ids.addAll(range.ids);
      anchorId = range.edge;
      revision++;
      error = null;
    }
    notifyListeners();
  }

  void selectAll() {
    if (!active) return;
    revision++;
    final all = available
        .where((r) {
          // Mounted ThreadPanel.handleSelectAllInThread uses getForwardableMessages.
          final metadata = r.message.json['actionMetadata'];
          return !thread || metadata is! Map || metadata['kind'] == null;
        })
        .map((r) => r.message.id)
        .toSet();
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
    active = false;
    revision++;
    ids.clear();
    // Retained export observers must revoke before their selection owner dies.
    notifyListeners();
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

String selectedMessagesMarkdown(
  List<SelectedMessageRow> rows, {
  String unknown = 'Unknown',
}) {
  final ordered = rows.indexed.toList()
    ..sort((a, b) {
      final first = a.$2.message, second = b.$2.message;
      final order = first.json['seq'] != null && second.json['seq'] != null
          ? first.seq.compareTo(second.seq)
          : (first.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
              second.createdAt?.millisecondsSinceEpoch ?? 0,
            );
      return order == 0 ? a.$1.compareTo(b.$1) : order;
    });
  return [
    for (final (_, row) in ordered)
      '${row.isThreadChild ? '  ↳ ' : ''}**${row.message.string('senderName', unknown)}**: ${row.message.content.trim()}',
  ].join('\n\n');
}

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
