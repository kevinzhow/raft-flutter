import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:raft_client/raft_client.dart';

import '../data/personal_presentation.dart';
import '../data/workspace_controller.dart';
import 'saved_sidebar_entry.dart';
import 'timeline_row_reuse.dart';
import 'chat_body_preparation.dart';
import 'channel_activity_session.dart';
import 'agent_read_badge.dart';
import 'agent_read_progress.dart';
import 'system_message_grouping.dart';
import 'timeline_row_trace.dart';

/// Mounted timeline keys and the revision of local row-affecting UI state.
/// Workspace notifications can repaint chrome without invalidating message
/// subtrees; actual message versions are compared by their lazy row elements.
class ChatTimelinePresentation {
  ChannelActivityPresentation? activity;
  final progress = AgentReadProgressPresentation();
  final bodies = ChatBodyPreparation();
  final expandedSystemGroups = <String>{};
  Object? _systemStateKey;
  List<SystemGroupState?> _systemStates = const [];
  ({List<chat.Message> messages, int revision})? _windowIndexKey;
  Map<String, int> _windowIndices = const {};

  int? windowIndexOf(String id, List<chat.Message> messages, int revision) {
    if (!identical(messages, _windowIndexKey?.messages) ||
        revision != _windowIndexKey?.revision) {
      _windowIndices = {
        for (var index = 0; index < messages.length; index++)
          messages[index].id: index,
      };
      _windowIndexKey = (messages: messages, revision: revision);
    }
    return _windowIndices[id];
  }

  SystemGroupState? systemStateAt(
    BuildContext context,
    int index,
    List<chat.Message> messages,
    int revision,
    RaftMessage Function(chat.Message) source,
  ) {
    final key = (messages, revision, Localizations.localeOf(context));
    if (_systemStateKey != key) {
      _systemStates = buildSystemGroupStates([
        for (final message in messages) source(message),
      ], (text, values) => raftFormat(context, text, values));
      _systemStateKey = key;
    }
    return index < _systemStates.length ? _systemStates[index] : null;
  }

  bool _syncQueued = false;
  Future<void> updates = Future.value();
  Future<void> synchronize(VoidCallback apply) {
    if (_syncQueued) return updates;
    _syncQueued = true;
    return updates = updates.then((_) {
      _syncQueued = false;
      apply();
    });
  }

  final _keys = <int, GlobalKey>{};
  Object _rows = Object();
  ({RaftMessage message, Object revision, Widget child})? _parent;

  GlobalKey keyFor(int window) => _keys.putIfAbsent(window, GlobalKey.new);
  void invalidateRows() => _rows = Object();

  Widget? threadParent(
    WorkspaceController w,
    RaftMessage? message, {
    required Object Function() style,
    required int windowRevision,
    required Widget Function(RaftMessage) build,
  }) {
    if (message == null) {
      _parent = null;
      return null;
    }
    final messages = w.messageDomain;
    final id = message.id;
    final key = (
      style(),
      message.string('messageType') == 'system' ? windowRevision : null,
      progress.revision(id),
      _messageState(
        w,
        message,
        threadSummary: messages.threadSummaries[id],
        highlighted: messages.state.highlightedMessageId == id,
      ),
    );
    final cached = _parent;
    if (cached != null &&
        identical(cached.message, message) &&
        cached.revision == key) {
      return cached.child;
    }
    final child = timelineRowTrace('parent', id, () => build(message));
    _parent = (message: message, revision: key, child: child);
    return child;
  }

  bool Function(int)? retainRows(
    List<chat.Message> messages,
    RaftMessage Function(chat.Message) source,
  ) => defaultTargetPlatform == TargetPlatform.macOS
      ? (i) => retainTimelineProse(source(messages[i]))
      : null;

  Object rowState(
    WorkspaceController w,
    List<chat.Message> messages,
    int index, {
    required Object style,
    required RaftMessage Function(chat.Message) source,
    required Map<String, dynamic> summaries,
    required String? highlighted,
  }) {
    final message = source(messages[index]);
    final id = message.id;
    return (
      style,
      _messageState(
        w,
        message,
        threadSummary: summaries[id],
        highlighted: highlighted == id,
      ),
    );
  }

  // These facts live outside the immutable message ledger. Capture their
  // values, not mutable collection identities, when a mounted row is checked.
  Object _messageState(
    WorkspaceController w,
    RaftMessage message, {
    required Object? threadSummary,
    required bool highlighted,
  }) {
    final id = message.id;
    return (
      agentMentionReadRevision(w, message),
      SavedCountStore.of(w).isSaved(id),
      highlighted,
      (w.drafts['thread:$id'] ?? '').trim().isNotEmpty,
      jsonEncode(threadSummary),
      jsonEncode([
        w.reactionViewer.reacted(id)?.toList(),
        w.pendingReactionTargets(id),
      ]),
    );
  }

  Object rowStyle(
    BuildContext context, {
    required Object authority,
    required Object? user,
    required bool interactive,
    required Object day,
  }) => (
    _rows,
    authority,
    user,
    interactive,
    day,
    Theme.of(context),
    MediaQuery.textScalerOf(context),
    MediaQuery.sizeOf(context).width,
    Localizations.localeOf(context),
    Directionality.of(context),
    RaftInteraction.of(context),
    PersonalPresentationScope.maybeOf(context)?.value,
  );
}
