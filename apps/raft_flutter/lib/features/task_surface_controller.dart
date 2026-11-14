import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/panel_caches.dart';
import '../data/task_conversation_thread.dart';
import '../data/task_discussion_read.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'message_task_actions.dart' show TaskV2ConversationsFlag;
import 'task_status_request.dart';
import 'task_v2_mode.dart';

/// Source taskModal owns a separate discussion identity, never the main or
/// side-thread window. Its borrowed controller cannot tear down the session.
class TaskSurfaceController extends ChangeNotifier {
  TaskSurfaceController({
    required this.parent,
    required Map<String, dynamic> row,
    required this.valid,
    this.onFailure,
    this.onMutationAccepted,
    this.resolveTask,
    this.hydrateParent = false,
    this.taskKeyed = false,
  }) : task = {...row} {
    seedKnown();
    events = parent.client.events.listen((event) {
      final data = event.payload;
      if (hydrateParent &&
          current &&
          data is Map &&
          (data['serverId'] == null || data['serverId'] == parent.server?.id) &&
          data['channelId'] == task['channelId']) {
        if (event.name == 'channel:removed') {
          retireResolvedParent(
            const RaftApiException(
              'This channel is not available.',
              status: 403,
            ),
          );
          parentRemoved = true;
        } else if (event.name == 'channel:authority-updated' ||
            event.name == 'channel:members-updated') {
          retireResolvedParent(null);
          unawaited(start());
        }
      }
      if (current &&
          event.name == 'task:deleted' &&
          data is Map &&
          (data['taskId'] ?? data['id']) == task['id']) {
        // Its conversation is gone server-side: the dialog closes
        // (threadStore.dropDeletedTaskConversation).
        deleted = true;
        changed();
        return;
      }
      if (!legacy &&
          hydrated &&
          parentReady &&
          event.name == 'task:updated' &&
          data is Map &&
          (data['id'] == task['id'] ||
              data['taskId'] == task['id'] ||
              data['task'] is Map && data['task']['id'] == task['id'])) {
        unawaited(refresh());
      }
    });
    parent.addListener(_parentChanged);
  }
  final WorkspaceController parent;
  final bool Function() valid;
  final void Function(Object)? onFailure;
  final Future<void> Function()? onMutationAccepted;
  final Future<Map<String, dynamic>?> Function(RaftChannel?)? resolveTask;

  /// Opened by a task-keyed URL (`task=<channel>:task:<id>`): the task's own
  /// conversation, whatever the flag says.
  final bool taskKeyed;

  /// The task was deleted (here or elsewhere): the host closes the dialog.
  bool deleted = false;

  /// A follow / unfollow done here wins until the next read of the task.
  bool? followOverride;
  bool followBusy = false;

  /// After a lost edit race, the revision the server reported.
  int? retryRevision;

  /// Cold task URLs may name an authorized channel absent from the directory.
  /// A private accepted metadata projection must precede borrowed discussion.
  final bool hydrateParent;
  RaftChannel? resolvedParent;
  Object? parentError;
  int parentRevision = 0, startRevision = 0;
  bool parentRemoved = false;
  RaftChannel? get parentChannel =>
      [
        ...parent.channels,
        ...parent.dms,
      ].where((c) => c.id == task['channelId']).firstOrNull ??
      resolvedParent;
  bool get parentReady =>
      !hydrateParent ||
      parentChannel != null &&
          parent.can('viewChannel', resource: parentChannel) &&
          !parentRemoved;
  Map<String, dynamic> task;
  List<Map<String, dynamic>> history = [], assignees = [];
  Object? error, historyError;
  bool loading = true, historyLoading = true, busy = false, closed = false;

  /// History for this task is on screen (cached or read); reloads keep it.
  bool historyKnown = false;
  int revision = 0, historyRevision = 0;
  WorkspaceController? discussion;
  late final StreamSubscription<RaftEvent> events;
  final presentationOwner = Object();
  bool get current => !closed && valid();

  void _parentChanged() {
    if (current) return;
    // Retire queued editor callbacks as soon as their task visit loses its
    // authority, before the host's next frame removes the old widget tree.
    discussion?.dispose();
    discussion = null;
  }

  bool get legacy => task['isLegacy'] == true;

  TaskV2ConversationsFlag get taskV2 => TaskV2ConversationsFlag.of(parent);

  /// Task v2: the task opens on its own conversation (Web
  /// opensAsTaskConversation), not its host message's thread.
  bool get conversation =>
      !legacy && (taskKeyed || opensAsTaskConversation(task, taskV2.enabled));

  /// Whether the reader follows the task's conversation.
  bool get followed => followOverride ?? task['conversationFollowed'] == true;

  /// Web authorizeTaskAction `amend`: the head is editable unless the task is
  /// read-only here; the server stays the authority.
  bool get canAmend =>
      current &&
      conversation &&
      hydrated &&
      task['readOnlyReason'] == null &&
      parent.server?.string('role') != 'guest';

  /// Web useCanDeleteTask: its creator, or someone holding deleteAnyTask.
  bool get canDelete =>
      current &&
      hydrated &&
      !legacy &&
      task['readOnlyReason'] == null &&
      (task['createdByType'] == 'user' &&
              task['createdById'] == parent.client.user?.id ||
          parent.can('deleteAnyTask'));
  bool get hydrated => task['id'] is String;
  bool get joined =>
      parentChannel != null &&
      parentChannel!.joined &&
      !parentChannel!.archived &&
      parent.can('viewChannel', resource: parentChannel);
  bool get canViewParent =>
      parentReady &&
      parentChannel != null &&
      !parentChannel!.archived &&
      parent.can('viewChannel', resource: parentChannel);
  bool get cleanup =>
      !hydrateParent &&
      !legacy &&
      ![
        ...parent.channels,
        ...parent.dms,
      ].any((c) => c.id == task['channelId']) &&
      task['readOnlyReason'] == null &&
      parent.server?.string('role') != 'guest';
  bool get canStatus =>
      current &&
      parentReady &&
      !loading &&
      !legacy &&
      error == null &&
      parent.server?.string('role') != 'guest' &&
      task['readOnlyReason'] == null &&
      (joined ||
          cleanup &&
              !historyLoading &&
              historyError == null &&
              parent.can('deleteAnyTask'));
  bool get canAssign =>
      canStatus &&
      joined &&
      task['status'] != 'done' &&
      parent.can('assignTasks');
  bool get canCleanupDelete =>
      cleanup &&
      parent.can('deleteAnyTask') &&
      current &&
      !loading &&
      !historyLoading &&
      historyError == null &&
      error == null;

  /// Web v1.24 getTaskStatusOptions: every status from any status, for
  /// members and admins alike (the server has no transition table).
  List<String> get statusOptions =>
      cleanup ? ['done', 'closed'] : taskV2StatusOptions(task, taskV2.enabled);
  void changed() {
    if (current) notifyListeners();
  }

  /// First frame: an accepted task row is shown at once (no skeleton) and the
  /// last history read for it, when still authorized, replaces the history
  /// skeleton. [start] / [refresh] then revalidate both in place.
  void seedKnown() {
    if (hydrated) loading = false;
    if (legacy || !hydrated) return;
    final cached = parent.services.taskHistoryCache.peek('${task['id']}');
    if (cached == null) return;
    final channel = parentChannel;
    // Cold URL: the parent is not resolved yet; judge the cache on a later open.
    if (channel == null && hydrateParent) return;
    if (cached.channelId != task['channelId'] ||
        channel == null ||
        cleanup ||
        parentRemoved ||
        !parent.can('viewChannel', resource: channel)) {
      parent.services.taskHistoryCache.remove('${task['id']}');
      return;
    }
    history = cached.events;
    historyLoading = false;
    historyKnown = true;
  }

  void retireResolvedParent(Object? failure) {
    ++parentRevision;
    ++startRevision;
    ++revision;
    ++historyRevision;
    resolvedParent = null;
    parentError = failure;
    historyKnown = false;
    parent.services.taskHistoryCache.removeWhere(
      (_, value) => value.channelId == task['channelId'],
    );
    loading = historyLoading = true;
    final child = discussion;
    discussion = null;
    child?.dispose();
    changed();
  }

  Future<bool> loadParent() async {
    if (!hydrateParent || parentReady) return true;
    if (!current || parentRemoved || !parent.can('viewChannel')) return false;
    final request = ++parentRevision;
    parentError = null;
    changed();
    try {
      final id = task['channelId'] as String;
      final data = await parent.query('/channels/${Uri.encodeComponent(id)}');
      if (!current || request != parentRevision) return false;
      if (data is! Map ||
          data['id'] != id ||
          data['name'] is! String ||
          data['serverId'] != parent.server?.id ||
          data['type'] is! String ||
          !const {'channel', 'private', 'joint', 'dm'}.contains(data['type'])) {
        throw const RaftApiException('This channel is not available.');
      }
      final real = RaftChannel(Map<String, dynamic>.from(data));
      if (!parent.can('viewChannel', resource: real)) {
        throw const RaftApiException(
          'This channel is not available.',
          status: 403,
        );
      }
      resolvedParent = real;
      changed();
      return true;
    } catch (e) {
      if (!current || request != parentRevision) return false;
      parentError = e;
      loading = historyLoading = false;
      onFailure?.call(e);
      changed();
      return false;
    }
  }

  Future<void> start() async {
    final request = ++startRevision;
    bool accepts() => current && request == startRevision;
    if (hydrateParent && !parentReady) {
      if (!await loadParent() || !accepts()) return;
    }
    if (resolveTask != null && !hydrated) {
      // URL anchors are identity only. Do not invent a task number, title,
      // status or author while the real parent-channel task bucket resolves.
      openDiscussion();
      try {
        final accepted = await resolveTask!(parentChannel);
        if (!accepts()) return;
        if (accepted == null) {
          loading = historyLoading = false;
          changed();
          return;
        }
        task = {...accepted};
      } catch (e) {
        if (!accepts()) return;
        error = e;
        loading = historyLoading = false;
        onFailure?.call(e);
        changed();
        return;
      }
    }
    // LegacyTaskPanel is a read-only accepted DTO; it has no thread/history API.
    if (legacy) {
      loading = historyLoading = false;
      changed();
      return;
    }
    openDiscussion();
    await refresh();
  }

  void openDiscussion() {
    if (!current || discussion != null || legacy || !canViewParent) return;
    if (conversation
        ? task['id'] is! String
        : task['messageId'] is! String || '${task['messageId']}'.isEmpty) {
      return;
    }
    final c = WorkspaceController(
      parent.client,
      cache: parent.deviceStore.cache,
      ownsClient: false,
      entityDirectory: parent.services.entityDirectory,
      followedThreads: parent.services.followedThreads,
      // Task surfaces remount when a side panel becomes a phone page. Their
      // thread draft belongs to the session through each layout projection.
      composer: parent.composer,
    );
    c.server = parent.server;
    c.servers = [...parent.servers];
    c.channels = [...parent.channels];
    c.dms = [...parent.dms];
    final real = parentChannel!;
    if (![...c.channels, ...c.dms].any((row) => row.id == real.id)) {
      if (real.type == 'dm') {
        c.dms.add(real);
      } else {
        c.channels.add(real);
      }
    }
    c.channel = [
      ...c.channels,
      ...c.dms,
    ].where((row) => row.id == task['channelId']).firstOrNull;
    c.messageDomain.ledger.switchServer(parent.server!.id);
    c.foreground = false;
    c.setConversationPresentation(
      presentationOwner,
      main: false,
      thread: false,
    );
    admitTaskDiscussion(c);
    discussion = c;
    if (conversation) {
      openConversation(c, directTaskConversationChannelId(task));
    } else {
      unawaited(
        c.openThreadIdentity(
          parentChannelId: '${task['channelId']}',
          parentMessageId: task['messageId'],
          initialThreadChannelId: task['threadChannelId'] as String?,
          navigate: false,
        ),
      );
    }
    changed();
  }

  /// Task v2: the discussion is the task's own conversation. A joint
  /// channel's local conversation is answered by the (idempotent) ensure
  /// endpoint, run only for a task that already has one: opening never
  /// creates a conversation.
  void openConversation(WorkspaceController c, String? channelId) {
    final id = '${task['id']}';
    unawaited(
      c.messageDomain.windowReceiver.threads.openThreadLocal(
        '${task['channelId']}',
        taskConversationKey(id),
        initialThreadChannelId: channelId,
        navigate: false,
        taskId: id,
      ),
    );
    final canonical = task['conversationChannelId'];
    if (channelId == null && canonical is String && canonical.isNotEmpty) {
      unawaited(() async {
        try {
          final data = await parent.client.post(
            '/tasks/${Uri.encodeComponent(id)}/conversation',
          );
          final local = data is Map ? data['conversationChannelId'] : null;
          if (local is String && local.isNotEmpty) bindConversation(local);
        } catch (_) {
          // The conversation stays empty; a send creates or resolves it.
        }
      }());
    }
  }

  /// One created elsewhere (an agent's reply, a lifecycle line) arrives on
  /// the task (`task:updated`): the open dialog moves onto it.
  void bindConversation(String channelId) {
    final c = discussion;
    if (!current || c == null || !conversation) return;
    if (c.threadChannelId == channelId) return;
    if (c.threadChannelId != null) return;
    openConversation(c, channelId);
  }

  Future<void> refresh() async {
    if (!parentReady) return;
    final request = ++revision;
    bool accepts() => current && request == revision;
    // A known row stays on screen while the full read replaces it in place.
    loading = !hydrated;
    error = null;
    changed();
    try {
      if (task['channelId'] != null && task['taskNumber'] != null) {
        try {
          final full = await parent.query(
            '/tasks/channel/${task['channelId']}/number/${task['taskNumber']}',
          );
          if (!accepts()) return;
          task = Map<String, dynamic>.from(full['task']);
        } on RaftApiException catch (e) {
          if (!accepts()) return;
          // Deleted-channel terminal cleanup needs the independent history
          // endpoint to freshly authorize the already-known task identity.
          if (e.status != 404 || !cleanup) rethrow;
        }
      }
      if (!accepts()) return;
      loading = false;
      followOverride = null;
      openDiscussion();
      if (conversation) {
        if (directTaskConversationChannelId(task) case final id?) {
          bindConversation(id);
        }
      }
      changed();
      await loadHistory();
    } catch (e) {
      if (!accepts()) return;
      error = e;
      onFailure?.call(e);
      loading = historyLoading = false;
      changed();
    }
  }

  Future<void> loadHistory() async {
    final request = ++historyRevision;
    historyLoading = !historyKnown;
    historyError = null;
    changed();
    try {
      final data = await parent.query('/tasks/${task['id']}/history');
      if (!current || request != historyRevision) return;
      history = [
        for (final event in data['events'] as List)
          if (event is Map && event['eventType'] != 'resource_receipt_recorded')
            Map<String, dynamic>.from(event),
      ];
      historyKnown = true;
      if (!cleanup && task['id'] is String && task['channelId'] is String) {
        parent.services.taskHistoryCache.put(
          '${task['id']}',
          TaskHistorySnapshot('${task['channelId']}', history),
        );
      }
    } catch (e) {
      if (!current || request != historyRevision) return;
      historyKnown = false;
      if (task['id'] is String) {
        parent.services.taskHistoryCache.remove('${task['id']}');
      }
      historyError = e;
      onFailure?.call(e);
      if (cleanup) error = e; // Cleanup is never admitted by failed history.
    }
    if (!current || request != historyRevision) return;
    historyLoading = false;
    changed();
  }

  Future<void> loadAssignees() async {
    if (!canAssign) return;
    final data = await parent.query('/channels/${task['channelId']}/members');
    if (!canAssign) return;
    final seen = <String>{};
    assignees = [
      for (final type in ['user', 'agent'])
        for (final raw
            in data[type == 'user' ? 'humans' : 'agents'] as List? ?? [])
          if (raw is Map &&
              (raw['userId'] ?? raw['id']) is String &&
              '${raw['userId'] ?? raw['id']}'.trim().isNotEmpty &&
              seen.add('$type:${raw['userId'] ?? raw['id']}'))
            {...Map<String, dynamic>.from(raw), 'actorType': type},
    ];
    changed();
  }

  Future<void> update(String field, dynamic value, {String? reason}) async {
    if (!['status', 'assignee'].contains(field) ||
        busy ||
        (field == 'status' ? !canStatus : !canAssign)) {
      return;
    }
    if (field == 'status' && !statusOptions.contains(value)) return;
    final request = ++revision;
    bool accepts() => current && request == revision;
    busy = true;
    error = null;
    changed();
    try {
      final note = reason?.trim() ?? '';
      final move = field == 'status'
          ? taskStatusRequest(task, value, reason: note)
          : (
              path: '/tasks/${task['id']}/assignee',
              data: <String, dynamic>{
                'assignee': value,
                if (task['revision'] is num)
                  'expectedRevision': task['revision'],
                // A hand-off's "what it waits on them for" (blank: none).
                if (note.isNotEmpty) 'reason': note,
              },
            );
      final data = await parent.client.request(
        'PATCH',
        move.path,
        data: move.data,
      );
      if (!accepts()) return;
      if (data is Map && data['task'] is Map) {
        task = Map<String, dynamic>.from(data['task']);
        await loadHistory();
      } else {
        await refresh();
      }
      if (current) await onMutationAccepted?.call();
    } catch (e) {
      // A step that asked for a reason shows its own failure and stays.
      if (reason != null) rethrow;
      if (accepts()) {
        error = e;
        onFailure?.call(e);
      }
    } finally {
      if (current) {
        busy = false;
        changed();
      }
    }
  }

  /// Web taskStore.amendTask (PATCH /tasks/:id): the title, or the
  /// description (blank removes it). A 409 carrying `currentRevision` is a
  /// lost race: the editor says so and keeps the draft.
  Future<RaftTaskAmendOutcome> amend(
    RaftTaskHeadField field,
    String value,
  ) async {
    if (!canAmend) return const RaftTaskAmendFailed();
    final retry = retryRevision;
    final revision = task['revision'] is num
        ? (task['revision'] as num).toInt()
        : null;
    final expected = retry != null && (revision == null || retry > revision)
        ? retry
        : revision;
    try {
      final data = await parent.client.request(
        'PATCH',
        '/tasks/${task['id']}',
        data: {
          if (field == RaftTaskHeadField.title) 'title': value,
          if (field == RaftTaskHeadField.description && value.isNotEmpty)
            'description': value,
          if (field == RaftTaskHeadField.description && value.isEmpty)
            'clearDescription': true,
          'expectedRevision': ?expected,
        },
      );
      if (!current) return const RaftTaskAmendSaved();
      retryRevision = null;
      if (data is Map && data['task'] is Map) {
        task = Map<String, dynamic>.from(data['task']);
        changed();
        unawaited(loadHistory());
      } else {
        unawaited(refresh());
      }
      unawaited(onMutationAccepted?.call());
      return const RaftTaskAmendSaved();
    } on RaftApiException catch (e) {
      if (e.status == 409 && e.details.containsKey('currentRevision')) {
        final current = e.details['currentRevision'];
        retryRevision = current is num ? current.toInt() : null;
        return const RaftTaskAmendStale();
      }
      final shown = userErrorText(e, fallback: '', where: 'task amend');
      return RaftTaskAmendFailed(shown.isEmpty ? null : shown);
    } catch (_) {
      return const RaftTaskAmendFailed();
    }
  }

  /// Web useTaskConversationFollow: follow the task's conversation as one
  /// follows a thread. Following or unfollowing creates the conversation
  /// first (POST /tasks/:id/conversation, as the first send does).
  Future<void> toggleFollow() async {
    final c = discussion;
    if (!current || followBusy || c == null || !conversation) return;
    followBusy = true;
    changed();
    try {
      final channelId =
          c.threadChannelId ?? await c.messageDomain.threads.ensureThread();
      if (!current || channelId == null) return;
      final following = followed;
      await parent.client.post(
        following ? '/channels/threads/unfollow' : '/channels/threads/follow',
        data: {'threadChannelId': channelId},
      );
      if (!current) return;
      followOverride = !following;
      unawaited(parent.services.followedThreads.refresh());
    } catch (e) {
      onFailure?.call(e);
    } finally {
      if (current) {
        followBusy = false;
        changed();
      }
    }
  }

  /// DELETE /tasks/:id. Null once deleted (the dialog closes), else the
  /// sentence the confirmation shows.
  Future<String?> delete() async {
    if (!canDelete) return "Couldn't delete the task. Try again.";
    try {
      await parent.client.request('DELETE', '/tasks/${task['id']}');
    } on RaftApiException catch (e) {
      return userErrorText(
        e,
        fallback: "Couldn't delete the task. Try again.",
        where: 'task delete',
      );
    } catch (_) {
      return "Couldn't delete the task. Try again.";
    }
    if (current) {
      deleted = true;
      changed();
      unawaited(onMutationAccepted?.call());
    }
    return null;
  }

  @override
  void dispose() {
    closed = true;
    parent.removeListener(_parentChanged);
    revision++;
    historyRevision++;
    parentRevision++;
    startRevision++;
    unawaited(events.cancel());
    discussion?.dispose();
    super.dispose();
  }
}
