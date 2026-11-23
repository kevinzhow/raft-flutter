import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:raft_client/raft_client.dart';

import '../data/personal_presentation.dart';
import '../data/source_time_formatter.dart';
import '../data/workspace_controller.dart';
import 'saved_sidebar_entry.dart';
import 'timeline_row_reuse.dart';
import 'chat_body_preparation.dart';
import 'channel_activity_session.dart';
import 'agent_read_badge.dart';
import 'agent_read_progress.dart';
import 'system_message_grouping.dart';
import 'timeline_boundary_change.dart';
import 'timeline_row_trace.dart';

/// Mounted timeline keys and the revision of local row-affecting UI state.
/// Workspace notifications can repaint chrome without invalidating message
/// subtrees; actual message versions are compared by their lazy row elements.
class ChatTimelinePresentation {
  ChannelActivityPresentation? activity;
  final progress = AgentReadProgressPresentation();
  final bodies = ChatBodyPreparation();
  Object? _clockSettings;
  SourceTimeFormatter? _clock;

  SourceTimeFormatter timeFormatter(BuildContext context, RaftRecord? user) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final zone = user?.string('preferredTimezone') ?? user?.string('timezone');
    final format = sourceTimeFormatPreference(
      user?.string('preferredTimeFormat') ?? user?.string('timeFormat'),
    );
    final system = MediaQuery.alwaysUse24HourFormatOf(context)
        ? SourceTimeFormat.twentyFourHour
        : null;
    final today = raftText(context, 'Today');
    final yesterday = raftText(context, 'Yesterday');
    final settings = (locale, zone, format, system, today, yesterday);
    if (_clockSettings == settings) return _clock!;
    final formatter = SourceTimeFormatter(
      locale: locale,
      preferredTimezone: zone,
      preferredTimeFormat: format,
      systemTimeFormat: system,
      todayLabel: today,
      yesterdayLabel: yesterday,
    );
    _clockSettings = settings;
    return _clock = formatter;
  }

  final expandedSystemGroups = <String>{};
  ({List<chat.Message> rows, int revision, Locale locale})? _systemStateKey;
  List<SystemGroupState?> _systemStates = const [];
  ({List<chat.Message> messages, int revision})? _windowIndexKey;
  Map<String, int> _windowIndices = const {};
  ({
    List<chat.Message> previous,
    List<chat.Message> current,
    TimelineBoundaryChange change,
  })?
  _acceptedWindow;

  void acceptWindow(
    List<chat.Message> previous,
    List<chat.Message> current,
    TimelineBoundaryChange change,
  ) {
    _acceptedWindow = (previous: previous, current: current, change: change);
  }

  void discardBoundary() => _acceptedWindow = null;

  TimelineBoundaryChange? boundaryFrom(
    List<chat.Message> previous,
    List<chat.Message> current,
  ) {
    final accepted = _acceptedWindow;
    return identical(accepted?.previous, previous) &&
            identical(accepted?.current, current)
        ? accepted!.change
        : null;
  }

  int? windowIndexOf(String id, List<chat.Message> messages, int revision) {
    if (!identical(messages, _windowIndexKey?.messages) ||
        revision != _windowIndexKey?.revision) {
      final previous = _windowIndexKey?.messages;
      final boundary = previous == null
          ? null
          : boundaryFrom(previous, messages);
      if (boundary?.before == 0) {
        for (var index = previous!.length; index < messages.length; index++) {
          _windowIndices[messages[index].id] = index;
        }
      } else {
        _windowIndices = {
          for (var index = 0; index < messages.length; index++)
            messages[index].id: index,
        };
      }
      _windowIndexKey = (messages: messages, revision: revision);
    }
    return _windowIndices[id];
  }

  List<SystemGroupState?> systemStates(
    BuildContext context,
    List<chat.Message> messages,
    int revision,
    RaftMessage Function(chat.Message) source,
  ) {
    final locale = Localizations.localeOf(context);
    final key = (rows: messages, revision: revision, locale: locale);
    final held = _systemStateKey;
    if (held != key) {
      final previous = held?.rows;
      final boundary = previous == null || held?.locale != locale
          ? null
          : boundaryFrom(previous, messages);
      bool system(chat.Message message) =>
          source(message).string('messageType') == 'system';
      if (boundary != null &&
          boundary.before == 0 &&
          boundary.edits.every(
            (index) => !system(previous![index]) && !system(messages[index]),
          ) &&
          !messages.skip(previous!.length).any(system)) {
        for (var index = 0; index < boundary.after; index++) {
          _systemStates.add(null);
        }
      } else {
        _systemStates = buildSystemGroupStates([
          for (final message in messages) source(message),
        ], (text, values) => raftFormat(context, text, values));
      }
      _systemStateKey = key;
    }
    return _systemStates;
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
  Object? _styleInputs;
  Object _styleRevision = Object();
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

  bool get preparesNearbyRows =>
      !kDebugMode &&
      switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.linux ||
        TargetPlatform.macOS => true,
        _ => false,
      };

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
    final reacted = w.reactionViewer.reacted(id);
    final pending = w.pendingReactionTargets(id);
    return (
      agentMentionReadRevision(w, message),
      SavedCountStore.of(w).isSaved(id),
      highlighted,
      (w.drafts['thread:$id'] ?? '').trim().isNotEmpty,
      threadSummary == null ? null : jsonEncode(threadSummary),
      reacted == null && pending == null
          ? null
          : _ReactionRevision(reacted, pending),
    );
  }

  Object rowStyle(
    BuildContext context, {
    required Object authority,
    required Object? user,
    required bool interactive,
    required Object day,
  }) {
    final inputs = (
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
    if (inputs != _styleInputs) {
      _styleInputs = inputs;
      _styleRevision = Object();
    }
    return _styleRevision;
  }
}

class _ReactionRevision {
  const _ReactionRevision(this.reacted, this.pending);

  final Set<String>? reacted;
  final Map<String, bool>? pending;

  @override
  bool operator ==(Object other) =>
      other is _ReactionRevision &&
      setEquals(reacted, other.reacted) &&
      mapEquals(pending, other.pending);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(reacted ?? const <String>{}),
    Object.hashAllUnordered(
      pending?.entries.map((entry) => Object.hash(entry.key, entry.value)) ??
          const <int>[],
    ),
  );
}
