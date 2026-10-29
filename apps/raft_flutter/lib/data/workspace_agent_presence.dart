import 'package:flutter/foundation.dart';

/// Immutable scalar fields used by message sender identity and presence.
/// Never borrows a directory row's mutable config, credentials or collections.
@immutable
class WorkspaceAgentPresence {
  WorkspaceAgentPresence(Map<String, dynamic> row)
    : id = row['id'] as String,
      status = row['status'] is String ? row['status'] as String : 'offline',
      runtime = row['runtime'] as String?,
      machineId = row['machineId'] as String?,
      model = row['model'] as String?,
      description = row['description'] as String?,
      external = row['external'] == true || row['runtime'] == 'external',
      deleted = row['deletedAt'] != null,
      hosted = row['hostedRuntime'] != null,
      lastSeenAt = row['lastSeenAt'] is String
          ? DateTime.tryParse(row['lastSeenAt'] as String)
          : null,
      activity = row['activity'] as String?,
      activityKind = row['activityKind'] as String?,
      detailKind = (row['activityDetailKind'] ?? row['detailKind']) as String?,
      detail = row['activityDetail'] is String
          ? row['activityDetail'] as String
          : '';

  final String id, status, detail;
  final String? runtime, machineId, model, description;
  final String? activity, activityKind, detailKind;
  final bool external, deleted, hosted;
  final DateTime? lastSeenAt;
}

/// Owned and fenced by WorkspaceEntityDirectory. A patch invalidates one
/// sender; a catalog/authority replacement invalidates all borrowed snapshots.
class WorkspaceAgentPresenceCache {
  final _rows = <String, WorkspaceAgentPresence>{};
  int _revision = 0;
  String? _changedId;

  ({int revision, String? id}) get change =>
      (revision: _revision, id: _changedId);

  WorkspaceAgentPresence read(String id, Map<String, dynamic> row) =>
      _rows.putIfAbsent(id, () => WorkspaceAgentPresence(row));

  void invalidate([String? id]) {
    if (id == null) {
      _rows.clear();
    } else {
      _rows.remove(id);
    }
    _changedId = id;
    _revision++;
  }
}
