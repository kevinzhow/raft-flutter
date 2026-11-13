// The message menu's task action under server v1.24.0 task v2 (Web
// MessageItem `handleConvertToTask` / `openCreateFromMessage`). With the
// per-server flag `task_v2_conversations_v0` on, a task is created FROM a
// message (CreateTaskDialog with `sourceMessageId`, it hangs under the
// message) and never converted: POST /tasks/convert-message answers 409
// `task_v2_use_create` there.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/feature_flag_client_facts.dart';
import '../data/server_error_code.dart';
import '../data/workspace_controller.dart';
import 'create_task_dialog.dart';

const taskV2ConversationsFlag = 'task_v2_conversations_v0';

/// Web `useServerFeatureFlag(TASK_V2_CONVERSATIONS_FLAG_KEY)` for the
/// selected server: off until evaluated, off on failure (a missing row
/// evaluates off), re-read when the account or server changes.
class TaskV2ConversationsFlag {
  TaskV2ConversationsFlag._(this.w);
  static final _flags = Expando<TaskV2ConversationsFlag>('task v2 flag');
  static TaskV2ConversationsFlag of(WorkspaceController w) {
    final source = w.presentationSource ?? w;
    return _flags[source] ??= TaskV2ConversationsFlag._(source);
  }

  final WorkspaceController w;
  String? _scope, _requested;
  bool _enabled = false;

  String get _current =>
      '${w.client.origin}|${w.client.generation}|${w.client.user?.id}|'
      '${w.client.serverId}';

  /// The value evaluated for the current scope; false until [ensure] ran
  /// (building a menu never sends a request).
  bool get enabled => _scope == _current && _enabled;

  /// Evaluates the flag once per account / server scope; the answer is
  /// remembered for the next menus. Off on failure.
  Future<bool> ensure() async {
    final scope = _current;
    if (_scope != scope) {
      _enabled = false;
      await _evaluate(scope);
      _scope = scope;
    }
    return enabled;
  }

  /// The server answered `task_v2_use_create`: the flag is on here.
  void markEnabled() {
    _scope = _current;
    _enabled = true;
  }

  Future<void> _evaluate(String scope) async {
    final serverId = w.client.serverId;
    if (serverId == null || _requested == scope) return;
    _requested = scope;
    try {
      final result = await w.client.post(
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(
          keys: const [taskV2ConversationsFlag],
          serverId: serverId,
        ),
      );
      if (_current != scope) return;
      _enabled =
          result is Map &&
          (result['evaluations'] as List? ?? const []).whereType<Map>().any(
            (f) => f['key'] == taskV2ConversationsFlag && f['enabled'] == true,
          );
    } catch (_) {
      // Unknown stays off: convert still works, and its 409 opens create.
    } finally {
      if (_requested == scope) _requested = null;
    }
  }
}

/// The menu entry for a message without a task: "Create task from message"
/// with task v2, else "Convert to task".
RaftMessageContextMenuItem messageTaskMenuItem(
  WorkspaceController w,
  RaftMessageContextMenuItem Function(String, String, Widget) item,
) => TaskV2ConversationsFlag.of(w).enabled
    ? item(
        'task-from-message',
        'Create task from message',
        raftMessageMenuIcon(RaftGlyph.plus),
      )
    : item(
        'task',
        'Convert to task',
        raftMessageMenuIcon(RaftGlyph.clipboardCheck),
      );

/// Runs the picked task entry. Converting on a server that turned task v2
/// on after the flag was read answers 409 `task_v2_use_create`: the task is
/// then created from the message, as Web's task v2 menu does.
Future<void> runMessageTaskAction(
  BuildContext context,
  WorkspaceController w,
  RaftMessage message,
  String choice,
) async {
  // Web reads the server flag before offering the action: on a task v2
  // server the task is created from the message, convert is never sent.
  if (choice == 'task' && !await TaskV2ConversationsFlag.of(w).ensure()) {
    try {
      await w.command(
        'POST',
        '/tasks/convert-message',
        data: {'messageId': message.id},
      );
      return;
    } catch (e) {
      if (serverErrorCode(e) != 'task_v2_use_create' || !context.mounted) {
        rethrow;
      }
      TaskV2ConversationsFlag.of(w).markEnabled();
    }
  }
  if (!context.mounted) return;
  await CreateTaskDialog.show(
    context,
    controller: w,
    channelId: message.channelId.isEmpty
        ? (w.channel?.id ?? '')
        : message.channelId,
    sourceMessage: (
      id: message.id,
      senderName: message.author,
      text: message.content,
    ),
  );
}
