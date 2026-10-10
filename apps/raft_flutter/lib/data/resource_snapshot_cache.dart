/// Last accepted list presentation of a workspace page (Activity, Saved).
///
/// Source keeps its inbox store across navigation and only fetches the first
/// window when the store is empty. Returning to a page shows this snapshot at
/// once and revalidates it in the background. Snapshots are bound to the
/// principal/server/role identity that accepted them and never cross it.
class ResourceSnapshot {
  const ResourceSnapshot({
    required this.identity,
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

  final String identity;
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

class ResourceSnapshotCache {
  final _snapshots = <String, ResourceSnapshot>{};

  /// The snapshot of [section] accepted under exactly [identity], if any.
  ResourceSnapshot? read(String section, String identity) {
    final snapshot = _snapshots[section];
    if (snapshot == null) return null;
    if (snapshot.identity == identity) return snapshot;
    _snapshots.remove(section);
    return null;
  }

  void write(String section, ResourceSnapshot snapshot) =>
      _snapshots[section] = snapshot;

  void remove(String section) => _snapshots.remove(section);

  /// Server or account switch: no page snapshot survives.
  void clear() => _snapshots.clear();
}
