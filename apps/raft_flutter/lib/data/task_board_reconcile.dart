import 'resource_row_reconcile.dart' show stabilizeRows;

/// Source taskStore mergeTaskFields: a field absent from the incoming task
/// (a summary projection or a partial event) never clobbers a known value;
/// present values, including null, win.
Map<String, dynamic> mergeTaskFields(
  Map<String, dynamic> existing,
  Map incoming,
) {
  final merged = <String, dynamic>{...existing};
  for (final MapEntry(:key, :value) in incoming.entries) {
    if (key is String) merged[key] = value;
  }
  // A full task's description supersedes an older summary preview.
  if (incoming.containsKey('description') &&
      !incoming.containsKey('descriptionPreview')) {
    merged.remove('descriptionPreview');
  }
  return merged;
}

/// Source TasksPanel sortTasks within a status: newest task number first.
int compareTaskNumbers(Map a, Map b) =>
    (b['taskNumber'] as num? ?? 0).compareTo(a['taskNumber'] as num? ?? 0);

/// Insert [task] into an ordered lane at its task-number position. A task
/// that sorts past the loaded window of a lane with more pages is left to
/// that page (null), so paging neither skips nor duplicates it.
List<Map<String, dynamic>>? insertTask(
  List<Map<String, dynamic>> lane,
  Map<String, dynamic> task, {
  required bool more,
}) {
  final index = lane.indexWhere((row) => compareTaskNumbers(task, row) < 0);
  if (index < 0) return more ? null : [...lane, task];
  return [...lane]..insert(index, task);
}

/// Background revalidation of one loaded task window (a board lane or the
/// list). The fetched first window replaces the loaded prefix and unchanged
/// rows keep their objects. Loaded rows past the last row the window still
/// contains (those pushed out of it, and every later page) stay with their
/// cursor unless a fetched window now holds them, so pages are not reset.
({List<Map<String, dynamic>> rows, String? cursor}) reconcileTaskWindow({
  required List<Map<String, dynamic>> fetched,
  required List<Map<String, dynamic>> current,
  required String? fetchedCursor,
  required String? currentCursor,
  required int window,
  required Set<Object?> fetchedIds,
}) {
  final rows = stabilizeRows(fetched, current, taskKey);
  if (current.length <= window || fetchedCursor == null) {
    return (rows: rows, cursor: fetchedCursor);
  }
  final own = {for (final row in fetched) row['id']};
  final shared = current.lastIndexWhere((row) => own.contains(row['id']));
  final tail = current
      .skip(shared < 0 ? window : shared + 1)
      .where((row) => !fetchedIds.contains(row['id']));
  return (rows: [...rows, ...tail], cursor: currentCursor);
}

String? taskKey(Map row) => row['id'] is String ? 'task:${row['id']}' : null;
