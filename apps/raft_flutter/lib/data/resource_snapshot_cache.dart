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
