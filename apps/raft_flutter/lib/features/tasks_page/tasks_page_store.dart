// The Tasks page's reads (task v2), one store per workspace session.
//
// Source: Web v1.24 store/tasksPageStore.ts, the live-change counter of
// store/serverTaskMerge.ts, components/task/tasksPage/useTasksPageData.ts and
// useTasksPageCounts.ts. Per lane (a 我的 section, the 全部 list, a board
// column) it remembers the ids and cursor read so far; per filter set, the
// server's counts. The task rows live here too (`knownById`), kept current by
// [applyLive] (the socket's task events) and [applyWritten] (the answer to the
// client's own write). Kept outside the page so leaving Tasks and coming back
// finds it read.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import '../../data/resource_row_reconcile.dart' show rowDeepEquals;
import '../../data/task_board_reconcile.dart' show mergeTaskFields;
import '../../data/workspace_controller.dart';
import '../server_task_scope.dart';
import 'tasks_page_model.dart';

/// GET [path] with [query]: the controller's `query` by default.
typedef TasksQuery =
    Future<dynamic> Function(String path, Map<String, dynamic> query);

/// After live task changes the counts are read again at most this often.
const countsRefreshMinInterval = Duration(seconds: 10);

/// Attempts at a counts read before the page says it failed; the waits
/// between them are 1 s, 2 s.
const countsAttempts = 3;
const countsRetryBase = Duration(seconds: 1);

/// Server cap on a page; a re-read asks for as many rows as the lane shows
/// (up to it), so it keeps its length.
const serverPageMax = 500;

/// A bound for a long session on the live-change map.
const _liveChangesCap = 2000;

/// What the server answered for one page.
@immutable
class ServerTaskPage {
  const ServerTaskPage(this.tasks, this.nextCursor);
  final List<Map<String, dynamic>> tasks;
  final String? nextCursor;
}

/// The server's totals for one filter set.
@immutable
class CountsEntry {
  const CountsEntry({
    this.data,
    this.loading = false,
    this.revision = -1,
    this.readAt,
    this.failures = 0,
    this.failed = false,
  });

  final ServerTaskCounts? data;
  final bool loading;

  /// The live revision the data was read at (or the read in flight began at).
  final int revision;

  /// When the last read began: a refresh waits out
  /// [countsRefreshMinInterval] from it.
  final DateTime? readAt;

  /// Failed reads in a row; retried with a growing wait up to
  /// [countsAttempts].
  final int failures;

  /// Every attempt failed and there is nothing to show.
  final bool failed;
}

/// One list, section or board column as a view: its lanes' rows merged.
@immutable
class LaneView {
  const LaneView({
    required this.tasks,
    required this.loaded,
    required this.loading,
    required this.hasMore,
    required this.failed,
  });

  final List<Map<String, dynamic>> tasks;

  /// The first page has landed (an empty lane is then really empty).
  final bool loaded;
  final bool loading;
  final bool hasMore;

  /// The last read failed: the lane offers to try again instead of reading
  /// on its own.
  final bool failed;
}

class TasksPageStore extends ChangeNotifier {
  TasksPageStore({
    required this.query,
    required this.viewerId,
    this.belongs,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static final _stores = Expando<TasksPageStore>('tasks page store');
  static final _identities = Expando<String>('tasks page identity');

  /// The store of [controller]'s workspace session. It starts over when the
  /// account, server, role or page identity changes.
  static TasksPageStore of(WorkspaceController controller) {
    final source = controller.presentationSource ?? controller;
    final store = _stores[source] ??= TasksPageStore(
      query: (path, query) => source.query(path, query: query),
      viewerId: () => source.client.user?.id,
      belongs: (task) => serverTaskBelongs(source, task),
    );
    final identity = serverTaskIdentity(source);
    final seen = _identities[source];
    if (seen != null && seen != identity) store._resetAll();
    _identities[source] = identity;
    return store;
  }

  final TasksQuery query;
  final String? Function() viewerId;

  /// Whether a live row still belongs on the page (serverTaskBelongs); a row
  /// that no longer does is dropped.
  final bool Function(Map<String, dynamic> task)? belongs;
  final DateTime Function() _now;

  /// Every task row the page holds, by id.
  final Map<String, Map<String, dynamic>> knownById = {};
  final Map<String, LaneRead> lanes = {};
  final Map<String, CountsEntry> counts = {};

  /// Groups / columns folded by hand, by name (see [boardFoldKey]).
  final Map<String, bool> collapsed = {};

  /// Moves with every live change: counts read at an older one are stale.
  int liveRevision = 0;

  /// Whether the page is on screen; its counts are not refreshed while not.
  bool get shown => _shown;
  bool _shown = true;

  int _generation = 0;
  int _liveSequence = 0;
  final Map<String, int> _liveChanges = {};
  final List<int> _firstReadsInFlight = [];
  int _pageLoads = 0;
  final Set<String> _touched = {};
  List<ServerTaskFilters> _watched = const [];
  final Map<String, Timer> _timers = {};
  final Set<Timer> _retries = {};
  bool _disposed = false;

  // ------------------------------------------------------- live changes

  /// The live-change counter now: a read records it when it starts.
  int get currentLiveSequence => _liveSequence;

  /// When the task last changed live (0: not since the app started).
  int liveChangeOf(String taskId) => _liveChanges[taskId] ?? 0;

  void _noteLive(String taskId) {
    if (_pageLoads > 0) _touched.add(taskId);
    _liveSequence += 1;
    // Re-inserted, so the map stays in order of change: the oldest go first.
    _liveChanges.remove(taskId);
    _liveChanges[taskId] = _liveSequence;
    if (_liveChanges.length > _liveChangesCap) {
      _liveChanges.remove(_liveChanges.keys.first);
    }
  }

  /// Forget the changes no read needs any more: at or before [sequence], the
  /// earliest read still held (null: all go).
  void _pruneLiveChanges(int? sequence) {
    if (sequence == null) {
      _liveChanges.clear();
      return;
    }
    _liveChanges.removeWhere((_, at) => at <= sequence);
  }

  void _pruneCovered() {
    final starts = [
      for (final read in lanes.values)
        if (read.loaded) read.readSequence,
      ..._firstReadsInFlight,
    ];
    _pruneLiveChanges(starts.isEmpty ? null : starts.reduce(_min));
  }

  static int _min(int a, int b) => a < b ? a : b;

  Map<String, dynamic> _merged(
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming,
  ) {
    final merged = mergeTaskFields(existing, incoming);
    // Activity only moves forward: a live message moves it locally at once,
    // the server stamps it at most once a minute, so a row read later may be
    // older.
    final was = DateTime.tryParse('${existing['activityAt'] ?? ''}');
    final next = DateTime.tryParse('${incoming['activityAt'] ?? ''}');
    if (was != null && next != null && was.isAfter(next)) {
      merged['activityAt'] = existing['activityAt'];
    }
    return rowDeepEquals(existing, merged) ? existing : merged;
  }

  /// Live task facts from the socket: a row (merged into what is held) or
  /// null (deleted). Each one is a live change.
  void applyLive(Map<String, Map<String, dynamic>?> patches) {
    if (patches.isEmpty) return;
    for (final MapEntry(key: id, value: incoming) in patches.entries) {
      _noteLive(id);
      liveRevision += 1;
      final existing = knownById[id];
      final next = incoming == null
          ? null
          : existing == null
          ? Map<String, dynamic>.from(incoming)
          : _merged(existing, incoming);
      if (next == null || belongs?.call(next) == false) {
        knownById.remove(id);
      } else {
        knownById[id] = next;
      }
    }
    _changed();
  }

  /// The answer to the client's own write (the `task` it returned): merged
  /// at once, as a live change (the socket's event for it follows).
  void applyWritten(Map<String, dynamic> task) {
    final id = task['id'];
    if (id is String) applyLive({id: task});
  }

  /// A task deleted (by the client's own write or the socket).
  void removeTask(String id) => applyLive({id: null});

  /// Fields of a held row that changed without the server's word being a
  /// task change (a follow done here): no live change, no counts read.
  void patchRow(String id, Map<String, dynamic> fields) {
    final existing = knownById[id];
    if (existing == null) return;
    knownById[id] = _merged(existing, fields);
    notifyListeners();
  }

  // ------------------------------------------------------------- reads

  /// One page of [lane], its rows merged into [knownById] (upsert only,
  /// field-merged, skipping tasks that changed live while it was in flight).
  /// Null when the store started over meanwhile. Throws what the read threw.
  Future<ServerTaskPage?> readPage(
    LaneSpec lane, {
    required int limit,
    String? cursor,
    LaneDetail? detail,
  }) async {
    final generation = _generation;
    _pageLoads += 1;
    try {
      final data = await query(
        '/tasks/server',
        lane.filters.pageParams(
          sort: lane.sort,
          limit: limit,
          detail: detail ?? lane.detail,
          cursor: cursor,
        ),
      );
      if (generation != _generation) return null;
      final body = data is Map ? data : const {};
      final tasks = <Map<String, dynamic>>[
        if (body['tasks'] is List)
          for (final raw in body['tasks'] as List)
            if (raw is Map && raw['id'] is String)
              Map<String, dynamic>.from(raw),
      ];
      for (final task in tasks) {
        final id = task['id'] as String;
        if (_touched.contains(id)) continue;
        final existing = knownById[id];
        knownById[id] = existing == null ? task : _merged(existing, task);
      }
      final next = body['next_cursor'];
      return ServerTaskPage(tasks, next is String ? next : null);
    } finally {
      _pageLoads -= 1;
      if (_pageLoads == 0) _touched.clear();
    }
  }

  /// Read [lane]'s next page (its first when never read, or with [restart]).
  /// No-op while reading or once complete. [restart] reads the first page
  /// again and replaces what was read (a count that disagrees, a live row of
  /// unknown relation); [checkedIds] and [syncedCount] are recorded on the
  /// lane with the read.
  Future<void> loadLanePage(
    LaneSpec lane, {
    bool restart = false,
    List<String>? checkedIds,
    int? syncedCount,
  }) async {
    final current = lanes[lane.key] ?? const LaneRead();
    if (current.loading ||
        (!restart && current.loaded && current.nextCursor == null)) {
      return;
    }
    final generation = _generation;
    final firstPage = restart || !current.loaded;
    final sequence = _liveSequence;
    if (firstPage) _firstReadsInFlight.add(sequence);
    final marked = current.copyWith(
      checkedIds: checkedIds == null
          ? null
          : {...current.checkedIds, ...checkedIds}.toList(),
      syncedCount: syncedCount,
    );
    lanes[lane.key] = marked.copyWith(loading: true, failed: false);
    _changed(counts: false);
    LaneRead startOver() => LaneRead(
      checkedIds: marked.checkedIds,
      syncedCount: marked.syncedCount,
    );
    try {
      final page = await readPage(
        lane,
        // A re-read of a lane read further than its first page reads as far
        // again, so it neither shrinks under the reader nor jumps the scroll.
        limit: restart
            ? current.ids.length.clamp(lanePageSize, serverPageMax).toInt()
            : lanePageSize,
        cursor: firstPage ? null : current.nextCursor,
      );
      if (generation != _generation) return;
      if (page == null) {
        // The connection dropped while reading: start this lane over.
        lanes[lane.key] = startOver();
        _changed(counts: false);
        return;
      }
      final previous = lanes[lane.key] ?? const LaneRead();
      // A first page replaces what was read (a restart drops rows the server
      // no longer lists).
      final ids = firstPage ? <String>[] : [...previous.ids];
      final seen = ids.toSet();
      final keys = firstPage ? <String, int>{} : {...previous.keys};
      for (final task in page.tasks) {
        final id = task['id'] as String;
        keys[id] = sortKeyOf(lane.sort, task);
        if (seen.add(id)) ids.add(id);
      }
      final last = page.tasks.isEmpty ? null : page.tasks.last;
      lanes[lane.key] = LaneRead(
        ids: ids,
        keys: keys,
        frontier: last != null
            ? Map<String, dynamic>.from(last)
            : firstPage
            ? null
            : previous.frontier,
        nextCursor: page.tasks.isNotEmpty ? page.nextCursor : null,
        loaded: true,
        readSequence: firstPage ? sequence : previous.readSequence,
        checkedIds: marked.checkedIds,
        syncedCount: marked.syncedCount,
      );
      if (firstPage) _pruneCovered();
      _changed(counts: false);
    } catch (error) {
      if (generation != _generation) return;
      // A 400 on a next page is a cursor the server no longer accepts (its
      // channel left the board): read the lane again from its start. On a
      // first page it is the request itself: failed, not retried on its own.
      final startOverNow =
          error is RaftApiException && error.status == 400 && !firstPage;
      lanes[lane.key] = startOverNow
          ? startOver()
          : (lanes[lane.key] ?? const LaneRead()).copyWith(
              loading: false,
              failed: true,
            );
      _changed(counts: false);
    } finally {
      if (firstPage) _firstReadsInFlight.remove(sequence);
    }
  }

  /// The rows of a group of lanes of one sort, as the page shows them.
  LaneView laneView(List<LaneSpec> group) {
    final reads = [for (final lane in group) lanes[lane.key]];
    final loaded = reads.every((r) => r?.loaded ?? false);
    return LaneView(
      tasks: mergedLaneTasks(group, reads, knownById, viewerId(), liveChangeOf),
      loaded: loaded,
      loading: reads.any((r) => r?.loading ?? false),
      hasMore: !loaded || reads.any((r) => r?.nextCursor != null),
      failed: reads.any((r) => r?.failed ?? false),
    );
  }

  /// Read the next page of each lane that has one (the end of the list
  /// scrolled into view, or Try again).
  void loadMore(List<LaneSpec> group) {
    for (final lane in group) {
      unawaited(loadLanePage(lane));
    }
  }

  /// Reads the lanes need to show the truth, as Web useMergedTasksLanes does
  /// on every change; call it whenever this store, [count] or [folded]
  /// changes. It is idempotent: what it starts it records first.
  /// - An open lane never read reads its first page at once (a count of 0
  ///   needs no read).
  /// - A task changed live that may belong but hinges on a fact the client
  ///   lacks reads the first page again, once per task.
  /// - Everything is read yet the server's [count] disagrees with the rows
  ///   shown: read again, once per count value.
  /// Not while folded or while the page is not [shown]: the need stays.
  void settleLanes(List<LaneSpec> group, {int? count, bool folded = false}) {
    if (group.isEmpty) return;
    final reads = [for (final lane in group) lanes[lane.key]];
    final view = laneView(group);
    final checked = {for (final r in reads) ...?r?.checkedIds};
    final unknown = laneUnknownIds(
      group,
      reads,
      knownById,
      viewerId(),
      liveChangeOf,
    ).where((id) => !checked.contains(id)).toList();
    final disagrees =
        view.loaded &&
        !view.hasMore &&
        count != null &&
        count != view.tasks.length &&
        reads.first?.syncedCount != count;
    if (!view.loading &&
        !folded &&
        _shown &&
        (unknown.isNotEmpty || disagrees)) {
      for (final lane in group) {
        unawaited(
          loadLanePage(
            lane,
            restart: true,
            checkedIds: unknown.isNotEmpty ? unknown : null,
            syncedCount: unknown.isEmpty ? count : null,
          ),
        );
      }
      return;
    }
    final neverRead = reads.every(
      (r) => r == null || (!r.loaded && !r.loading),
    );
    if (_shown && !folded && !view.failed && neverRead && count != 0) {
      loadMore(group);
    }
  }

  // ------------------------------------------------------------ counts

  /// Whether the counts of [filters] were read at the current live revision.
  bool countsCurrent(ServerTaskFilters filters) =>
      counts[filters.key]?.revision == liveRevision;

  /// Read the counts of a filter set, unless current for this live revision,
  /// being read, or given up on.
  Future<void> loadCounts(ServerTaskFilters filters) async {
    final key = filters.key;
    final revision = liveRevision;
    final current = counts[key];
    if (current != null &&
        (current.loading ||
            current.failed ||
            (current.data != null && current.revision == revision))) {
      return;
    }
    final generation = _generation;
    final failures = current?.failures ?? 0;
    final readAt = _now();
    counts[key] = CountsEntry(
      data: current?.data,
      loading: true,
      revision: revision,
      readAt: readAt,
      failures: failures,
    );
    _changed(counts: false);
    try {
      final data = await query('/tasks/server/counts', filters.filterParams());
      if (generation != _generation) return;
      counts[key] = CountsEntry(
        data: readServerTaskCounts(data),
        revision: revision,
        readAt: readAt,
      );
    } catch (_) {
      if (generation != _generation) return;
      final failed = failures + 1;
      final data = current?.data;
      // Gave up: with numbers already shown they stay (the next live change
      // reads again); with none, the page says so and offers Try again.
      final givenUp = failed >= countsAttempts;
      counts[key] = CountsEntry(
        data: data,
        revision: givenUp && data != null ? revision : -1,
        readAt: readAt,
        failures: givenUp ? 0 : failed,
        failed: givenUp && data == null,
      );
      if (!givenUp) {
        late final Timer retry;
        // ignore: raft_lints/avoid_unreleased_resource -- kept in _retries; reset() and dispose() cancel it
        retry = Timer(countsRetryBase * (1 << (failed - 1)), () {
          _retries.remove(retry);
          if (generation == _generation) unawaited(loadCounts(filters));
        });
        _retries.add(retry);
      }
    }
    _changed();
  }

  /// Try again after the counts gave up (the page's Try again).
  Future<void> retryCounts(ServerTaskFilters filters) {
    final key = filters.key;
    final current = counts[key];
    if (current != null) {
      counts[key] = CountsEntry(
        data: current.data,
        revision: -1,
        readAt: current.readAt,
      );
    }
    return loadCounts(filters);
  }

  /// The filter sets the page wants counts of (the effect of Web
  /// useTaskCounts): each is read when first wanted and again after live
  /// changes, never sooner than [countsRefreshMinInterval] after the last
  /// read of that set began (a fixed time, so a steady stream of changes
  /// can't put it off). Only while [shown].
  void watchCounts(Iterable<ServerTaskFilters> wanted) {
    _watched = wanted.toSet().toList();
    _scheduleCounts();
  }

  /// Whether the page is on screen (false on a phone while a task covers it).
  void setShown(bool value) {
    if (_shown == value) return;
    _shown = value;
    _scheduleCounts();
  }

  void _scheduleCounts() {
    final keys = {for (final f in _watched) f.key};
    for (final key in _timers.keys.toList()) {
      if (!keys.contains(key)) _timers.remove(key)?.cancel();
    }
    for (final filters in _watched.toList()) {
      final key = filters.key;
      _timers.remove(key)?.cancel();
      final entry = counts[key];
      final busy =
          entry != null &&
          (entry.loading || entry.failures > 0 || entry.failed);
      if (!_shown || busy || entry?.revision == liveRevision) continue;
      final readAt = entry?.readAt;
      final delay = entry == null || readAt == null
          ? Duration.zero
          : _later(readAt.add(countsRefreshMinInterval).difference(_now()));
      if (delay == Duration.zero) {
        unawaited(loadCounts(filters));
      } else {
        late final Timer timer;
        // ignore: raft_lints/avoid_unreleased_resource -- kept in _timers; reset(), dispose() and _scheduleCounts cancel it
        timer = Timer(delay, () {
          if (_timers[key] == timer) _timers.remove(key);
          unawaited(loadCounts(filters));
        });
        _timers[key] = timer;
      }
    }
  }

  static Duration _later(Duration d) => d.isNegative ? Duration.zero : d;

  // ------------------------------------------------------------ state

  void setCollapsed(String name, bool value) {
    collapsed[name] = value;
    notifyListeners();
  }

  /// Drop the reads made for 你发起的's done-since instant [since]: the page
  /// has moved past it.
  void evictCompletedSince(String since) {
    final marker = 'completed_since=${Uri.encodeQueryComponent(since)}';
    lanes.removeWhere((key, _) => key.contains(marker));
    counts.removeWhere((key, _) => key.contains(marker));
    _pruneCovered();
    notifyListeners();
  }

  /// Forget every read (socket gap, server switch): mounted views read again
  /// from their first page. The rows held stay.
  void reset() {
    _generation += 1;
    _firstReadsInFlight.clear();
    _pruneLiveChanges(null);
    lanes.clear();
    counts.clear();
    for (final timer in [..._timers.values, ..._retries]) {
      timer.cancel();
    }
    _timers.clear();
    _retries.clear();
    notifyListeners();
    _scheduleCounts();
  }

  /// A new account or server: nothing of the old one stays.
  void _resetAll() {
    knownById.clear();
    collapsed.clear();
    reset();
  }

  void _changed({bool counts = true}) {
    if (_disposed) return;
    notifyListeners();
    if (counts) _scheduleCounts();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final timer in [..._timers.values, ..._retries]) {
      timer.cancel();
    }
    super.dispose();
  }
}

// ------------------------------------------------------------ counts view

/// The filter sets behind the page's numbers: the tabs (no filter), the head's
/// N under the filters, the 我的 sections and the board's columns. They are
/// those of the lanes, so each number counts exactly the rows its lane pages
/// through.
@immutable
class TasksCountsPlan {
  TasksCountsPlan(this.tab, this.view, this.filters, String doneSince)
    : mineUnfiltered = [
        assignedSectionFilters(PageFilters.none),
        ...startedSectionFilters(PageFilters.none, doneSince),
      ],
      searching = filters.query.isNotEmpty,
      viewSets = filters.query.isNotEmpty
          ? const []
          : view == TasksPageView.board
          ? boardCountsFilters(tab, filters)
          : tab == TasksPageTab.all
          ? [serverFiltersOf(filters)]
          : [
              assignedSectionFilters(filters),
              ...startedSectionFilters(filters, doneSince),
            ];

  final TasksPageTab tab;
  final TasksPageView view;
  final PageFilters filters;

  /// 我的's three filter sets under no filter.
  final List<ServerTaskFilters> mineUnfiltered;

  /// A search narrows the view: the counts take no search (`q` is not sent;
  /// a count of a search is the server's costliest read), so the view's
  /// numbers are not read.
  final bool searching;

  /// Up to three filter sets (a 我的 view has one per relation).
  final List<ServerTaskFilters> viewSets;

  /// Hand to [TasksPageStore.watchCounts].
  List<ServerTaskFilters> get wanted => [
    const ServerTaskFilters(),
    ...mineUnfiltered,
    ...viewSets,
  ];
}

/// The Tasks page's numbers, every one the server's count.
@immutable
class TasksPageCounts {
  const TasksPageCounts({
    required this.tabs,
    required this.shown,
    required this.searching,
    required this.sections,
    required this.columns,
    required this.current,
    required this.failed,
  });

  /// The tabs' numbers, under no filter: 我的's two sections, and every task.
  final Map<TasksPageTab, int?> tabs;

  /// What the current view shows under its filters (the head's N); null
  /// while searching.
  final int? shown;
  final bool searching;

  /// 我的 list: each section's total.
  final Map<MineSection, int>? sections;

  /// Board: each column's total.
  final Map<String, int>? columns;

  /// The numbers are the server's for the live changes so far (a lane
  /// re-reads to agree with them).
  final bool current;

  /// The counts could not be read (after retries).
  final bool failed;
}

int? _sum(Iterable<int?> values) {
  var total = 0;
  for (final v in values) {
    if (v == null) return null;
    total += v;
  }
  return total;
}

extension TasksPageCountsRead on TasksPageStore {
  TasksPageCounts countsOf(TasksCountsPlan plan) {
    ServerTaskCounts? data(ServerTaskFilters f) => counts[f.key]?.data;
    int? total(ServerTaskFilters f) => data(f)?.total;
    final slotData = [for (final f in plan.viewSets) data(f)];
    final tabs = {
      TasksPageTab.mine: _sum([for (final f in plan.mineUnfiltered) total(f)]),
      TasksPageTab.all: total(const ServerTaskFilters()),
    };
    Map<MineSection, int>? sections;
    Map<String, int>? columns;
    int? shown;
    if (plan.view == TasksPageView.board) {
      if (!slotData.contains(null) && slotData.isNotEmpty) {
        columns = {
          for (final s in boardStatuses)
            s: slotData.fold<int>(0, (sum, d) => sum + d!.statuses[s]!),
        };
        shown = boardColumns(
          plan.filters,
        ).fold<int>(0, (t, s) => t + columns![s]!);
      }
    } else if (plan.tab == TasksPageTab.all) {
      shown = slotData.isEmpty ? null : slotData[0]?.total;
    } else if (slotData.length == 3) {
      final assigned = slotData[0]?.total;
      final started = _sum([slotData[1]?.total, slotData[2]?.total]);
      if (assigned != null && started != null) {
        sections = {
          MineSection.assigned: assigned,
          MineSection.started: started,
        };
      }
      shown = _sum([assigned, started]);
    }
    final all = [
      const ServerTaskFilters(),
      ...plan.mineUnfiltered,
      ...plan.viewSets,
    ];
    return TasksPageCounts(
      tabs: tabs,
      shown: shown,
      searching: plan.searching,
      sections: sections,
      columns: columns,
      current: all.every(countsCurrent),
      failed: plan.viewSets.any((f) {
        final e = counts[f.key];
        return e != null && e.failed && e.data == null;
      }),
    );
  }

  /// Try again for every set of [plan] that failed.
  void retryFailedCounts(TasksCountsPlan plan) {
    for (final f in plan.wanted) {
      if (counts[f.key]?.failed ?? false) unawaited(retryCounts(f));
    }
  }
}
