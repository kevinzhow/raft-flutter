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
  }) : task = {...row} {
    events = parent.client.events.listen((event) {
      final data = event.payload;
      if (event.name == 'task:updated' &&
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
  bool get joined => [...parent.channels, ...parent.dms].any(
    (c) =>
        c.id == task['channelId'] &&
        c.joined &&
        !c.archived &&
        parent.can('viewChannel', resource: c),
  );
  bool get canViewParent => [...parent.channels, ...parent.dms].any(
    (c) =>
        c.id == task['channelId'] &&
        !c.archived &&
        parent.can('viewChannel', resource: c),
  );
  bool get cleanup =>
      !legacy &&
      ![
        ...parent.channels,
        ...parent.dms,
      ].any((c) => c.id == task['channelId']) &&
      task['readOnlyReason'] == null &&
      parent.server?.string('role') != 'guest';
  bool get canStatus =>
      current &&
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

  Future<void> start() async {
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
        task['messageId'] is! String ||
        !canViewParent) {
      return;
    }
    final c = WorkspaceController(
      parent.client,
      cache: parent.cache,
      ownsClient: false,
      entityDirectory: parent.entityDirectory,
    );
    c.server = parent.server;
    c.servers = [...parent.servers];
    c.channels = [...parent.channels];
    c.dms = [...parent.dms];
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
    unawaited(events.cancel());
    discussion?.dispose();
    super.dispose();
  }
}
