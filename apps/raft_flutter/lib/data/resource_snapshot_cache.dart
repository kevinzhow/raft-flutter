/// Last accepted presentation of a workspace page.
///
/// Source keeps its inbox and task stores across navigation and only fetches
/// when the store is empty. Returning to a page shows its snapshot at once and
/// revalidates it in the background. Snapshots are bound to the
/// principal/server/role identity that accepted them and never cross it.
abstract class PageSnapshot {
  const PageSnapshot({required this.identity});
  final String identity;
}

/// Activity and Saved list snapshot.
class ResourceSnapshot extends PageSnapshot {
  const ResourceSnapshot({
    required super.identity,
    required this.enabledActivity,
    required this.view,
    required this.rows,
    required this.hasMore,
    required this.filter,
    required this.activeActivityFilter,
    required this.query,
    required this.channelId,
    required this.direction,
    required this.totalCount,
    required this.totalUnreadCount,
    required this.activityAllCount,
    required this.savedActivityTotal,
    required this.activityGroups,
    required this.acceptedActivityItems,
    required this.savedActivityItems,
    required this.doneActivityItems,
    required this.channelAccess,
    required this.scrollOffset,
  });

  final bool enabledActivity;
  final String? view;
  final List<Map<String, dynamic>> rows;
  final bool hasMore;
  final String filter, activeActivityFilter, query, direction;
  final String? channelId;
  final int? totalCount, totalUnreadCount, activityAllCount;
  final int savedActivityTotal;
  final List<Map<String, dynamic>> activityGroups,
      acceptedActivityItems,
      savedActivityItems,
      doneActivityItems;
  final Map<String, Map<String, dynamic>> channelAccess;
  final double scrollOffset;
}

/// Tasks page snapshot (Source taskStore serverTasks + serverTaskPages):
/// board lanes with their loaded pages and cursors, the list window, the
/// user's layout and filters, and where each was scrolled.
class TaskSnapshot extends PageSnapshot {
  const TaskSnapshot({
    required super.identity,
    required this.layout,
    required this.view,
    required this.filter,
    required this.rows,
    required this.cursor,
    required this.hasMore,
    required this.totalCount,
    required this.lanes,
    required this.laneCursors,
    required this.channels,
    required this.creators,
    required this.assignees,
    required this.collapsed,
    required this.channelAccess,
    required this.listOffset,
    required this.boardOffset,
  });

  final String layout, filter;
  final String? view, cursor;
  final List<Map<String, dynamic>> rows;
  final bool hasMore;
  final int? totalCount;
  final Map<String, List<Map<String, dynamic>>> lanes;
  final Map<String, String?> laneCursors;
  final Set<String> channels, creators, assignees, collapsed;
  final Map<String, Map<String, dynamic>> channelAccess;
  final double listOffset, boardOffset;
}

class ResourceSnapshotCache {
  final _snapshots = <String, PageSnapshot>{};

  /// The [T] snapshot of [section] accepted under exactly [identity], if any.
  T? read<T extends PageSnapshot>(String section, String identity) {
    final snapshot = _snapshots[section];
    if (snapshot == null) return null;
    if (snapshot.identity == identity && snapshot is T) return snapshot;
    _snapshots.remove(section);
    return null;
  }

  void write(String section, PageSnapshot snapshot) =>
      _snapshots[section] = snapshot;

  void remove(String section) => _snapshots.remove(section);

  /// Server or account switch: no page snapshot survives.
  void clear() => _snapshots.clear();
}

/// A management or settings page's accepted projection (the page's own data
/// fields by name). In memory only: the cache lives on the WorkspaceController
/// and is never persisted, and pages keep one-time credentials out of it.
class FieldSnapshot extends PageSnapshot {
  FieldSnapshot({required super.identity, required Map<String, Object?> fields})
    : fields = Map.unmodifiable(fields);
  final Map<String, Object?> fields;
}

/// [next] with every subtree that equals [old] replaced by the [old] object,
/// so a background refresh that changed nothing keeps the accepted rows (and
/// whatever identity-based state hangs off them). JSON maps and lists are
/// rebuilt with their element types; list rows with an `id` match by id.
/// Anything else is reused only when `==`.
Object? stableValue(Object? old, Object? next) {
  if (identical(old, next) || old == null || next == null) return next;
  if (old is Map<String, dynamic> && next is Map<String, dynamic>) {
    var same = old.length == next.length;
    final out = <String, dynamic>{};
    for (final entry in next.entries) {
      final value = stableValue(old[entry.key], entry.value);
      out[entry.key] = value;
      if (same &&
          (!old.containsKey(entry.key) || !identical(value, old[entry.key]))) {
        same = false;
      }
    }
    return same ? old : out;
  }
  if (old is List && next is List) {
    final List<dynamic> out;
    if (next is List<Map<String, dynamic>>) {
      out = <Map<String, dynamic>>[];
    } else if (next.runtimeType == <dynamic>[].runtimeType) {
      out = <dynamic>[];
    } else {
      return _deepEquals(old, next) ? old : next;
    }
    final byId = <Object, Object?>{
      for (final row in old)
        if (row is Map && row['id'] != null) row['id']: row,
    };
    var same = old.length == next.length;
    for (var i = 0; i < next.length; i++) {
      final row = next[i];
      final prior =
          row is Map && row['id'] != null && byId.containsKey(row['id'])
          ? byId[row['id']]
          : i < old.length
          ? old[i]
          : null;
      final value = stableValue(prior, row);
      out.add(value);
      if (same && !identical(value, old[i])) same = false;
    }
    return same ? old : out;
  }
  return _deepEquals(old, next) ? old : next;
}

bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _deepEquals(a[k], b[k]));
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Set && b is Set) return a.length == b.length && a.containsAll(b);
  return a == b;
}

/// Field-wise [stableValue] over two page captures.
Map<String, Object?> stableFields(
  Map<String, Object?> old,
  Map<String, Object?> next,
) => {
  for (final entry in next.entries)
    entry.key: stableValue(old[entry.key], entry.value),
};
