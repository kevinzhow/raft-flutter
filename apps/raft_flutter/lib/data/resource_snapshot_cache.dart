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

/// An accepted list window of one request shape (path and filters, without
/// the window). Pages keep one per recently visited filter/query so switching
/// back shows it at once and revalidates it in place.
class ResourceViewWindow {
  const ResourceViewWindow({
    required this.rows,
    required this.hasMore,
    required this.totalCount,
    required this.totalUnreadCount,
  });

  final List<Map<String, dynamic>> rows;
  final bool hasMore;
  final int? totalCount, totalUnreadCount;
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
    this.viewWindows = const {},
    this.sectionScrollOffsets = const {},
    this.inboxSerial = 0,
  });

  /// Id of the newest shared-inbox window already presented in [rows].
  final int inboxSerial;
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
  final Map<String, double> sectionScrollOffsets;

  /// Other recently accepted filter/query windows, by request shape.
  final Map<String, ResourceViewWindow> viewWindows;

  /// Rows and view windows changed. Every other accepted field stays.
  ResourceSnapshot replaceRows({
    required List<Map<String, dynamic>> rows,
    required int? totalCount,
    required Map<String, ResourceViewWindow> viewWindows,
  }) => ResourceSnapshot(
    identity: identity,
    enabledActivity: enabledActivity,
    view: view,
    rows: rows,
    hasMore: hasMore,
    filter: filter,
    activeActivityFilter: activeActivityFilter,
    query: query,
    channelId: channelId,
    direction: direction,
    totalCount: totalCount,
    totalUnreadCount: totalUnreadCount,
    activityAllCount: activityAllCount,
    savedActivityTotal: savedActivityTotal,
    activityGroups: activityGroups,
    acceptedActivityItems: acceptedActivityItems,
    savedActivityItems: savedActivityItems,
    doneActivityItems: doneActivityItems,
    channelAccess: channelAccess,
    scrollOffset: scrollOffset,
    viewWindows: viewWindows,
    sectionScrollOffsets: sectionScrollOffsets,
    inboxSerial: inboxSerial,
  );
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

  TaskSnapshot withRows(List<Map<String, dynamic>> rows, int? totalCount) =>
      TaskSnapshot(
        identity: identity,
        layout: layout,
        view: view,
        filter: filter,
        rows: rows,
        cursor: cursor,
        hasMore: hasMore,
        totalCount: totalCount,
        lanes: lanes,
        laneCursors: laneCursors,
        channels: channels,
        creators: creators,
        assignees: assignees,
        collapsed: collapsed,
        channelAccess: channelAccess,
        listOffset: listOffset,
        boardOffset: boardOffset,
      );
}

/// One workspace page window on the session cache, keyed by page.
///
/// The concrete window lives in another library. Tasks and Saved share this
/// slot. It is not the snapshot map.
abstract interface class ServerPageSlot {
  PageSnapshot get snapshot;
  bool get needsRevalidate;
  set needsRevalidate(bool value);
  int get attached;
  void attach();
  void detach();
}

/// Page keys for the session windows. Not snapshot slots.
const serverTasksPage = 'tasks';
const serverSavedPage = 'saved';

class ResourceSnapshotCache {
  final _snapshots = <String, PageSnapshot>{};
  final _pages = <String, ({ServerPageSlot slot, void Function() release})>{};

  /// The window for [key], if the session still holds one.
  ServerPageSlot? serverPage(String key) => _pages[key]?.slot;

  /// [release] runs when this window is replaced or the cache is cleared.
  void keepServerPage(
    String key,
    ServerPageSlot window,
    void Function() release,
  ) {
    final current = _pages[key];
    if (!identical(current?.slot, window)) current?.release();
    _pages[key] = (slot: window, release: release);
  }

  void dropServerPage(String key) {
    final current = _pages.remove(key);
    current?.release();
  }

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
  void clear() {
    final held = _pages.values.toList();
    _pages.clear();
    for (final page in held) {
      page.release();
    }
    _snapshots.clear();
  }
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
