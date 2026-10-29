import 'package:raft_client/raft_client.dart';

import 'resource_row_reconcile.dart';
import 'resource_snapshot_cache.dart';
import 'server_page_window.dart';
import 'task_board_reconcile.dart';

/// What one task event does to an accepted board.
sealed class TaskEventEffect {
  const TaskEventEffect();
}

/// Another server's event: the board stays, and nothing is revalidated.
class TaskEventIgnored extends TaskEventEffect {
  const TaskEventIgnored();
}

/// A task event that does not name one task, or a reconnect: revalidate.
class TaskEventUnrecognized extends TaskEventEffect {
  const TaskEventUnrecognized();
}

/// One task, patched by id. Null deletes it.
class TaskEventPatch extends TaskEventEffect {
  const TaskEventPatch(this.patches);
  final Map<String, Map<String, dynamic>?> patches;
}

/// Mutable lanes or list that [patchTaskBoard] updates in place.
class TaskBoardSlice {
  TaskBoardSlice({
    required this.lanes,
    required this.laneCursors,
    required this.rows,
    required this.totalCount,
    required this.board,
  });

  final Map<String, List<Map<String, dynamic>>> lanes;
  final Map<String, String?> laneCursors;
  List<Map<String, dynamic>> rows;
  int? totalCount;
  final bool board;
}

Map<String, dynamic>? _taskRecord(Object? raw) =>
    raw is Map && raw['id'] is String ? Map<String, dynamic>.from(raw) : null;

/// Same classification the mounted page uses: another server is ignored,
/// a named task is patched, and anything else asks for a revalidation.
TaskEventEffect classifyTaskEvent(
  RaftEvent event, {
  required String? serverId,
}) {
  final payload = event.payload;
  if (payload is! Map) return const TaskEventUnrecognized();
  if (payload['serverId'] is String && payload['serverId'] != serverId) {
    return const TaskEventIgnored();
  }
  final patches = <String, Map<String, dynamic>?>{};
  switch (event.name) {
    case 'task:created':
      final list = payload['tasks'] is List
          ? payload['tasks'] as List
          : [payload['task']];
      for (final raw in list) {
        final next = _taskRecord(raw);
        if (next == null) return const TaskEventUnrecognized();
        patches[next['id'] as String] = next;
      }
      break;
    case 'task:updated':
      final next =
          _taskRecord(payload['task']) ??
          (payload['status'] is String ? _taskRecord(payload) : null);
      if (next == null) return const TaskEventUnrecognized();
      patches[next['id'] as String] = next;
      break;
    case 'task:deleted':
      final id =
          payload['taskId'] ??
          _taskRecord(payload['task'])?['id'] ??
          payload['id'];
      if (id is! String) return const TaskEventUnrecognized();
      patches[id] = null;
      break;
    default:
      return const TaskEventUnrecognized();
  }
  if (patches.isEmpty) return const TaskEventUnrecognized();
  return TaskEventPatch(patches);
}

/// Apply live task facts (null = deleted) to the board lanes or the list.
/// Unchanged rows keep their objects. Returns whether the board changed.
bool patchTaskBoard(
  Map<String, Map<String, dynamic>?> patches,
  TaskBoardSlice slice, {
  required bool Function(Map<String, dynamic> task) belongs,
  required String? Function(Object? channelId) channelName,
}) {
  if (patches.isEmpty) return false;
  var changed = false;
  for (final MapEntry(key: id, value: incoming) in patches.entries) {
    String? from;
    var index = -1;
    Map<String, dynamic>? existing;
    if (slice.board) {
      for (final MapEntry(key: status, value: lane) in slice.lanes.entries) {
        index = lane.indexWhere((row) => row['id'] == id);
        if (index >= 0) {
          from = status;
          existing = lane[index];
          break;
        }
      }
    } else {
      index = slice.rows.indexWhere((row) => row['id'] == id);
      if (index >= 0) existing = slice.rows[index];
    }
    var next = incoming == null
        ? null
        : existing == null
        ? incoming
        : mergeTaskFields(existing, incoming);
    if (next != null && next['channelName'] == null) {
      final name = channelName(next['channelId']);
      if (name != null) next = {...next, 'channelName': name};
    }
    if (next != null && !belongs(next)) next = null;
    if (existing != null && next != null && rowDeepEquals(existing, next)) {
      continue;
    }
    if (slice.board) {
      final to = next?['status'] as String?;
      if (from != null && from == to) {
        slice.lanes[from] = [...slice.lanes[from]!]..[index] = next!;
      } else {
        if (from != null) {
          slice.lanes[from] = [...slice.lanes[from]!]..removeAt(index);
        }
        if (to != null) {
          final placed = insertTask(
            slice.lanes[to] ?? const [],
            next!,
            more: slice.laneCursors[to] != null,
          );
          if (placed != null) slice.lanes[to] = placed;
        }
      }
      changed = true;
    } else if (existing != null) {
      slice.rows = next == null
          ? ([...slice.rows]..removeAt(index))
          : ([...slice.rows]..[index] = next);
      if (next == null && slice.totalCount != null) {
        slice.totalCount = slice.totalCount! - 1;
      }
      changed = true;
    } else if (next != null) {
      slice.rows = [next, ...slice.rows];
      if (slice.totalCount != null) slice.totalCount = slice.totalCount! + 1;
      changed = true;
    }
  }
  if (!changed) return false;
  if (slice.board) {
    slice.rows = slice.lanes.values.expand((rows) => rows).toList();
  }
  return true;
}

/// The one accepted workspace Tasks window. While a page is attached it only
/// stores the board; while none is, it patches by id and never fetches.
class ServerTaskWindow extends ServerPageWindow {
  ServerTaskWindow({
    required super.client,
    required super.events,
    required super.snapshot,
    required super.serverId,
    required super.identity,
    required this.belongs,
    required this.channelName,
  });

  bool Function(Map<String, dynamic> task) belongs;
  String? Function(Object? channelId) channelName;

  @override
  TaskSnapshot get snapshot => super.snapshot as TaskSnapshot;

  @override
  void adoptWindow(ServerPageWindow fresh) {
    super.adoptWindow(fresh);
    final next = fresh as ServerTaskWindow;
    belongs = next.belongs;
    channelName = next.channelName;
  }

  @override
  void onSessionEvent(RaftEvent event) {
    if (event.name != 'connected' && !event.name.startsWith('task:')) return;
    switch (classifyTaskEvent(event, serverId: serverId())) {
      case TaskEventIgnored():
        return;
      case TaskEventUnrecognized():
        needsRevalidate = true;
        return;
      case TaskEventPatch(:final patches):
        final slice = TaskBoardSlice(
          lanes: snapshot.lanes,
          laneCursors: snapshot.laneCursors,
          rows: snapshot.rows,
          totalCount: snapshot.totalCount,
          board: true,
        );
        if (!patchTaskBoard(
          patches,
          slice,
          belongs: belongs,
          channelName: channelName,
        )) {
          return;
        }
        snapshot = snapshot.withRows(slice.rows, slice.totalCount);
    }
  }
}

/// Keeps [current] when the account and client are the same window.
ServerTaskWindow holdServerTaskWindow(
  ResourceSnapshotCache cache, {
  required Object client,
  required Stream<RaftEvent> events,
  required TaskSnapshot snapshot,
  required bool Function(Map<String, dynamic> task) belongs,
  required String? Function(Object? channelId) channelName,
  required String? Function() serverId,
  required String Function() identity,
}) {
  return holdServerPage(
    cache,
    serverTasksPage,
    ServerTaskWindow(
      client: client,
      events: events,
      snapshot: snapshot,
      belongs: belongs,
      channelName: channelName,
      serverId: serverId,
      identity: identity,
    ),
  );
}
