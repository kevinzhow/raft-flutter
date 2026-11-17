// The Tasks page's selection: ids, and the last one picked (a Shift-click's
// run starts there). It belongs to what the page shows (the scope: tab,
// view, sort, filters and search): when that changes, the selection is empty
// and a Shift-click's run has no start.
//
// Source: Web v1.24 components/task/tasksPage/useTaskSelection.ts.
import 'package:flutter/foundation.dart';

import 'tasks_page_model.dart';
import 'tasks_page_store.dart';

/// Select all reads its lanes to their end this many rows at a time (the
/// server's page cap)...
const selectAllPage = 500;

/// ...up to this many tasks: past it the selection stops there, and the page
/// says how many it holds.
const selectAllMax = 2000;

/// The ids from [from] to [to] (either order) in [order], both included; just
/// [to] when [from] is not there.
List<String> selectionRun(List<String> order, String? from, String to) {
  final end = order.indexOf(to);
  final start = from == null ? -1 : order.indexOf(from);
  if (start < 0 || end < 0) return [to];
  return order.sublist(
    start < end ? start : end,
    (start < end ? end : start) + 1,
  );
}

class TaskSelection extends ChangeNotifier {
  // ignore: prefer_initializing_formals
  TaskSelection({String scope = ''}) : _scope = scope;

  String _scope;
  Set<String> _ids = const {};
  String? _anchor, _lastPicked;

  String get scope => _scope;
  Set<String> get selected => _ids;
  bool get selecting => _ids.isNotEmpty;
  bool isSelected(String id) => _ids.contains(id);

  /// The task picked last by hand (a click or a Shift-click), kept after the
  /// selection ends: where focus goes back to.
  String? get lastPicked => _lastPicked;

  /// What the page shows changed: the selection ends, and a run has no start.
  void setScope(String scope) {
    if (scope == _scope) return;
    _scope = scope;
    final had = _ids.isNotEmpty;
    _ids = const {};
    _anchor = _lastPicked = null;
    if (had) notifyListeners();
  }

  /// A click on a row's check (or its long press) toggles [id]; with [range]
  /// (Shift) and a task picked before, the run from there to [id] is added.
  /// [order] is the ids as the page shows them, rows top to bottom and board
  /// columns left to right.
  void select(String id, {bool range = false, List<String> order = const []}) {
    final anchor = _anchor;
    if (range && anchor != null) {
      _ids = {..._ids, ...selectionRun(order, anchor, id)};
    } else {
      _ids = _ids.contains(id) ? ({..._ids}..remove(id)) : {..._ids, id};
    }
    _anchor = _lastPicked = id;
    notifyListeners();
  }

  void clear() {
    _anchor = null;
    _set(const {});
  }

  /// Replace the selection (Select all).
  void setAll(Iterable<String> ids) => _set({...ids});

  /// Add [ids] (more of Select all, as it reads).
  void add(Iterable<String> ids) => _set({..._ids, ...ids});

  /// Drop ids that left (deleted).
  void remove(Iterable<String> ids) => _set({..._ids}..removeAll(ids));

  void _set(Set<String> next) {
    if (setEquals(next, _ids)) return;
    _ids = next;
    notifyListeners();
  }
}

/// What Select all read: [complete] is false when it stopped short, at the
/// cap ([capped]) or because a read failed or the connection dropped
/// meanwhile (not capped).
@immutable
class SelectAllRead {
  const SelectAllRead({
    required this.ids,
    required this.complete,
    required this.capped,
  });

  final List<String> ids;
  final bool complete;
  final bool capped;
}

/// Every task the [lanes] hold, read to their end (summaries, kept in the
/// store so the batch actions know them), at most [max].
Future<SelectAllRead> readAllLaneTaskIds(
  TasksPageStore store,
  List<LaneSpec> lanes, {
  int max = selectAllMax,
}) async {
  final ids = <String>[];
  final seen = <String>{};
  SelectAllRead stopped({bool capped = false}) =>
      SelectAllRead(ids: ids, complete: false, capped: capped);
  for (final lane in lanes) {
    String? cursor;
    do {
      final ServerTaskPage? page;
      try {
        page = await store.readPage(
          lane,
          limit: selectAllPage,
          cursor: cursor,
          detail: LaneDetail.summary,
        );
      } catch (_) {
        return stopped();
      }
      if (page == null) return stopped();
      for (final task in page.tasks) {
        final id = task['id'] as String;
        if (seen.contains(id)) continue;
        if (ids.length >= max) return stopped(capped: true);
        seen.add(id);
        ids.add(id);
      }
      cursor = page.tasks.isNotEmpty ? page.nextCursor : null;
    } while (cursor != null);
  }
  return SelectAllRead(ids: ids, complete: true, capped: false);
}
