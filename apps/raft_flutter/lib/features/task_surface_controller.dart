import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

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
  }) : task = {...row} {
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
  }
  final WorkspaceController parent;
  final bool Function() valid;
  final void Function(Object)? onFailure;
  final Future<void> Function()? onMutationAccepted;
  final Future<Map<String, dynamic>?> Function(RaftChannel?)? resolveTask;

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
  int revision = 0, historyRevision = 0;
  WorkspaceController? discussion;
  late final StreamSubscription<RaftEvent> events;
  final presentationOwner = Object();
  bool get current => !closed && valid();
  bool get legacy => task['isLegacy'] == true;
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
  List<String> get statusOptions => cleanup
      ? ['done', 'closed']
      : parent.can('deleteAnyTask')
      ? raftTaskStatuses
      : ['${task['status']}', ...?raftTaskTransitions[task['status']]];
  void changed() {
    if (current) notifyListeners();
  }

  void retireResolvedParent(Object? failure) {
    ++parentRevision;
    ++startRevision;
    ++revision;
    ++historyRevision;
    resolvedParent = null;
    parentError = failure;
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
    if (!current ||
        discussion != null ||
        legacy ||
        task['messageId'] is! String ||
        '${task['messageId']}'.isEmpty ||
        !canViewParent) {
      return;
    }
    final c = WorkspaceController(
      parent.client,
      cache: parent.cache,
      ownsClient: false,
      entityDirectory: parent.entityDirectory,
      followedThreads: parent.followedThreads,
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
    c.ledger.switchServer(parent.server!.id);
    c.foreground = false;
    c.setConversationPresentation(
      presentationOwner,
      main: false,
      thread: false,
    );
    discussion = c;
    unawaited(
      c.openThreadIdentity(
        parentChannelId: '${task['channelId']}',
        parentMessageId: task['messageId'],
        initialThreadChannelId: task['threadChannelId'] as String?,
        navigate: false,
      ),
    );
    changed();
  }

  Future<void> refresh() async {
    if (!parentReady) return;
    final request = ++revision;
    bool accepts() => current && request == revision;
    loading = true;
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
      openDiscussion();
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
    historyLoading = true;
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
    } catch (e) {
      if (!current || request != historyRevision) return;
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

  Future<void> update(String field, dynamic value) async {
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
      final data = await parent.client.request(
        'PATCH',
        '/tasks/${task['id']}/$field',
        data: {
          field == 'status' ? 'status' : 'assignee': value,
          if (field == 'assignee' && task['revision'] is num)
            'expectedRevision': task['revision'],
        },
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

  @override
  void dispose() {
    closed = true;
    revision++;
    historyRevision++;
    parentRevision++;
    startRevision++;
    unawaited(events.cancel());
    discussion?.dispose();
    super.dispose();
  }
}
