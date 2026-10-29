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

/// Mounted timeline keys and the revision of local row-affecting UI state.
/// Workspace notifications can repaint chrome without invalidating message
/// subtrees; actual message versions are compared by their lazy row elements.
class ChatTimelinePresentation {
  final bodies = ChatBodyPreparation();
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

  GlobalKey keyFor(int window) => _keys.putIfAbsent(window, GlobalKey.new);
  void invalidateRows() => _rows = Object();

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
    final id = source(messages[index]).id;
    return (
      style,
      messageState(
        w,
        id,
        threadSummary: summaries[id],
        highlighted: highlighted == id,
      ),
      index > 0 && summaries[source(messages[index - 1]).id] != null,
      index + 1 < messages.length &&
          summaries[source(messages[index + 1]).id] != null,
    );
  }

  // These facts live outside the immutable message ledger. Capture their
  // values, not mutable collection identities, when a mounted row is checked.
  Object messageState(
    WorkspaceController w,
    String id, {
    required Object? threadSummary,
    required bool highlighted,
  }) => (
    SavedCountStore.of(w).isSaved(id),
    highlighted,
    (w.drafts['thread:$id'] ?? '').trim().isNotEmpty,
    jsonEncode(threadSummary),
    jsonEncode([
      w.reactionViewer.reacted(id)?.toList(),
      w.pendingReactionTargets(id),
    ]),
  );

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
