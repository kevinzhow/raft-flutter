// The server Tasks page (task v2) as data: which sections, lists and board
// columns it shows, what each asks the server for, and how the rows the
// client already holds are placed in them between reads.
//
// Source: Web v1.24 components/task/tasksPage/tasksPageModel.ts and
// tasksPageApi.ts. A "lane" is a filtered, sorted read of GET /tasks/server,
// paged on demand. What a lane shows is every task the client holds that
// matches it, in the lane's order, down to the last row the server sent for
// it (its frontier) while more pages remain. Totals never come from here:
// they are the server's counts.
//
// Rows stay `Map<String, dynamic>`, the app's task row everywhere.
import 'package:flutter/foundation.dart';

enum TasksPageTab { mine, all }

enum TasksPageView { list, board }

/// How the page orders a list (the sort menu, in its order).
enum ServerTaskSort {
  activity('activity'),
  activityAsc('activity_asc'),
  created('created');

  const ServerTaskSort(this.wire);
  final String wire;
}

/// The person's relation to a task (exclusive on the server, in this order).
enum TaskRelation {
  assignedToMe('assigned_to_me'),
  createdByMe('created_by_me'),
  fromMyMessage('from_my_message');

  const TaskRelation(this.wire);
  final String wire;
}

/// 我的's two sections: 分配给你 and 你发起的.
enum MineSection { assigned, started }

enum LaneDetail { summary, full }

/// The board statuses the page shows (no In review column: its rows count as
/// In progress).
const boardStatuses = ['backlog', 'todo', 'in_progress', 'done', 'closed'];

/// What 我的 lists without a status filter: everything not finished.
const unfinishedStatuses = ['backlog', 'todo', 'in_progress'];

/// First page of a lane, and each page after it.
const lanePageSize = 20;

const mineRelations = TaskRelation.values;
const startedRelations = [TaskRelation.createdByMe, TaskRelation.fromMyMessage];

/// 你发起的 also keeps a task done this recently.
const recentDoneWindow = Duration(hours: 24);

/// No update for this long and an open task's time shows in the warning ink.
const staleAfter = Duration(days: 3);

/// The server takes a search this long at most (`q`).
const taskSearchMaxLength = 200;

String recentDoneSince([DateTime? now]) => (now ?? DateTime.now())
    .toUtc()
    .subtract(recentDoneWindow)
    .toIso8601String();

bool _same(List<String> a, List<String> b) => listEquals(a, b);

/// The toolbar's filters and the search, as the page holds them.
@immutable
class PageFilters {
  const PageFilters({
    this.channelIds = const [],
    this.statuses = const [],
    this.creators = const [],
    this.assignees = const [],
    this.query = '',
  });

  final List<String> channelIds, statuses, creators, assignees;

  /// The search field, trimmed.
  final String query;

  static const none = PageFilters();

  /// A toolbar filter is set (Clear filters shows). The search is not one.
  bool get hasToolbarFilter =>
      channelIds.length + statuses.length + creators.length + assignees.length >
      0;

  /// The page shows less than the tab holds: a filter or a search.
  bool get isNarrowed => hasToolbarFilter || query.isNotEmpty;

  PageFilters copyWith({
    List<String>? channelIds,
    List<String>? statuses,
    List<String>? creators,
    List<String>? assignees,
    String? query,
  }) => PageFilters(
    channelIds: channelIds ?? this.channelIds,
    statuses: statuses ?? this.statuses,
    creators: creators ?? this.creators,
    assignees: assignees ?? this.assignees,
    query: query ?? this.query,
  );

  @override
  bool operator ==(Object other) =>
      other is PageFilters &&
      _same(channelIds, other.channelIds) &&
      _same(statuses, other.statuses) &&
      _same(creators, other.creators) &&
      _same(assignees, other.assignees) &&
      query == other.query;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(channelIds),
    Object.hashAll(statuses),
    Object.hashAll(creators),
    Object.hashAll(assignees),
    query,
  );
}

/// What one read of /tasks/server (or its counts) filters by.
@immutable
class ServerTaskFilters {
  const ServerTaskFilters({
    this.statuses = const [],
    this.channelIds = const [],
    this.assignees = const [],
    this.creators = const [],
    this.relation,
    this.completedSince,
    this.createdSince,
    this.query = '',
  });

  final List<String> statuses, channelIds, assignees, creators;

  /// `assignees` and `creators` are `user:<id>` / `agent:<id>`; assignees
  /// also takes `unassigned`.
  final TaskRelation? relation;

  /// An instant (ISO with offset): done tasks completed before it are left out.
  final String? completedSince;

  /// An instant (ISO with offset): tasks created before it are left out.
  final String? createdSince;
  final String query;

  ServerTaskFilters copyWith({
    List<String>? statuses,
    TaskRelation? relation,
    String? completedSince,
  }) => ServerTaskFilters(
    statuses: statuses ?? this.statuses,
    channelIds: channelIds,
    assignees: assignees,
    creators: creators,
    relation: relation ?? this.relation,
    completedSince: completedSince ?? this.completedSince,
    createdSince: createdSince,
    query: query,
  );

  /// The wire params in a stable order (lists sorted). In progress names the
  /// stored In review rows too, said outright: a lone `status=` with no other
  /// filter is the legacy exact match.
  Map<String, String> filterParams() {
    final params = <String, String>{};
    void list(String key, List<String> values) {
      if (values.isNotEmpty) params[key] = ([...values]..sort()).join(',');
    }

    list(
      'status',
      statuses.contains('in_progress') ? [...statuses, 'in_review'] : statuses,
    );
    list('channel', channelIds);
    list('assignee', assignees);
    list('creator', creators);
    if (relation != null) params['relation'] = relation!.wire;
    if (completedSince != null && completedSince!.isNotEmpty) {
      params['completed_since'] = completedSince!;
    }
    if (createdSince != null && createdSince!.isNotEmpty) {
      params['created_since'] = createdSince!;
    }
    if (query.isNotEmpty) params['q'] = query;
    return params;
  }

  /// The encoded query string: a lane's and a counts read's cache key.
  String get key => filterParams().entries
      .map(
        (e) =>
            '${Uri.encodeQueryComponent(e.key)}='
            '${Uri.encodeQueryComponent(e.value)}',
      )
      .join('&');

  /// The query of one page read: the filters, `sort`, `limit`, `detail`
  /// (summary only) and `cursor`.
  Map<String, String> pageParams({
    required ServerTaskSort sort,
    required int limit,
    required LaneDetail detail,
    String? cursor,
  }) => {
    ...filterParams(),
    'sort': sort.wire,
    'limit': '$limit',
    if (detail == LaneDetail.summary) 'detail': 'summary',
    if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
  };

  @override
  bool operator ==(Object other) =>
      other is ServerTaskFilters &&
      _same(statuses, other.statuses) &&
      _same(channelIds, other.channelIds) &&
      _same(assignees, other.assignees) &&
      _same(creators, other.creators) &&
      relation == other.relation &&
      completedSince == other.completedSince &&
      createdSince == other.createdSince &&
      query == other.query;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(statuses),
    Object.hashAll(channelIds),
    Object.hashAll(assignees),
    Object.hashAll(creators),
    relation,
    completedSince,
    createdSince,
    query,
  );
}

/// One lane: what it reads. [key] is stable for the same read.
@immutable
class LaneSpec {
  LaneSpec(this.filters, this.sort, this.detail)
    : key = '${detail.name}|${sort.wire}|${filters.key}';

  final ServerTaskFilters filters;
  final ServerTaskSort sort;
  final LaneDetail detail;
  final String key;

  @override
  bool operator ==(Object other) => other is LaneSpec && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// What a lane has read so far.
@immutable
class LaneRead {
  const LaneRead({
    this.ids = const [],
    this.keys = const {},
    this.frontier,
    this.nextCursor,
    this.loaded = false,
    this.loading = false,
    this.failed = false,
    this.readSequence = 0,
    this.checkedIds = const [],
    this.syncedCount,
  });

  /// Task ids in the order the server sent them.
  final List<String> ids;

  /// Each listed row's sort key as read: a row whose key moved since is
  /// placed again.
  final Map<String, int> keys;

  /// The last row of the last page as it was read: where the shown rows end
  /// while more pages remain.
  final Map<String, dynamic>? frontier;
  final String? nextCursor;
  final bool loaded;
  final bool loading;

  /// The last read failed; the lane offers Try again.
  final bool failed;

  /// The live-change counter when the first page was asked for: changes after
  /// it are the lane's to place.
  final int readSequence;

  /// Live tasks of unknown relation the lane has read again for (once each).
  final List<String> checkedIds;

  /// The server count the lane last read again to agree with (once per count).
  final int? syncedCount;

  LaneRead copyWith({
    bool? loading,
    bool? failed,
    List<String>? checkedIds,
    int? syncedCount,
  }) => LaneRead(
    ids: ids,
    keys: keys,
    frontier: frontier,
    nextCursor: nextCursor,
    loaded: loaded,
    loading: loading ?? this.loading,
    failed: failed ?? this.failed,
    readSequence: readSequence,
    checkedIds: checkedIds ?? this.checkedIds,
    syncedCount: syncedCount ?? this.syncedCount,
  );

  @override
  bool operator ==(Object other) =>
      other is LaneRead &&
      listEquals(ids, other.ids) &&
      mapEquals(keys, other.keys) &&
      mapEquals(frontier, other.frontier) &&
      nextCursor == other.nextCursor &&
      loaded == other.loaded &&
      loading == other.loading &&
      failed == other.failed &&
      readSequence == other.readSequence &&
      listEquals(checkedIds, other.checkedIds) &&
      syncedCount == other.syncedCount;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(ids),
    nextCursor,
    loaded,
    loading,
    failed,
    readSequence,
    syncedCount,
  );
}

/// GET /tasks/server/counts: per status, and per relation (open work).
@immutable
class ServerTaskCounts {
  const ServerTaskCounts({required this.statuses, required this.relations});

  final Map<String, int> statuses;
  final Map<String, int> relations;

  /// Every task the filters match.
  int get total => boardStatuses.fold(0, (sum, s) => sum + (statuses[s] ?? 0));

  @override
  bool operator ==(Object other) =>
      other is ServerTaskCounts &&
      mapEquals(statuses, other.statuses) &&
      mapEquals(relations, other.relations);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(statuses.entries.map((e) => Object.hash(e.key, e.value))),
    Object.hashAll(relations.entries.map((e) => Object.hash(e.key, e.value))),
  );
}

int _count(Object? value) =>
    value is num && value.isFinite && value > 0 ? value.toInt() : 0;

/// The counts response, read field by field (a missing number is 0).
ServerTaskCounts readServerTaskCounts(Object? data) {
  final body = data is Map ? data : const {};
  final statuses = body['counts'] is Map ? body['counts'] as Map : const {};
  final relations = body['relations'] is Map
      ? body['relations'] as Map
      : const {};
  return ServerTaskCounts(
    statuses: {for (final s in boardStatuses) s: _count(statuses[s])},
    relations: {
      for (final r in TaskRelation.values) r.wire: _count(relations[r.wire]),
    },
  );
}

// ---------------------------------------------------------------- lanes

/// The board filters of the page's filters, statuses included.
ServerTaskFilters serverFiltersOf(PageFilters f) => ServerTaskFilters(
  channelIds: f.channelIds,
  statuses: f.statuses,
  creators: f.creators,
  assignees: f.assignees,
  query: f.query,
);

/// 分配给你: assigned to me; without a status filter, not finished.
ServerTaskFilters assignedSectionFilters(PageFilters f) =>
    serverFiltersOf(f).copyWith(
      relation: TaskRelation.assignedToMe,
      statuses: f.statuses.isNotEmpty ? f.statuses : unfinishedStatuses,
    );

/// 你发起的, one filter set per relation: created by me, or from my message,
/// and not assigned to me; without a status filter, not finished, plus what
/// was done since [doneSince].
List<ServerTaskFilters> startedSectionFilters(PageFilters f, String doneSince) {
  final chosen = f.statuses.isNotEmpty;
  return [
    for (final relation in startedRelations)
      serverFiltersOf(f).copyWith(
        relation: relation,
        statuses: chosen ? f.statuses : [...unfinishedStatuses, 'done'],
        completedSince: chosen ? null : doneSince,
      ),
  ];
}

LaneSpec _summary(ServerTaskFilters f, ServerTaskSort sort) =>
    LaneSpec(f, sort, LaneDetail.summary);

/// The lanes of one 我的 section (rows: summaries).
List<LaneSpec> mineSectionLanes(
  MineSection section,
  PageFilters f,
  ServerTaskSort sort,
  String doneSince,
) => section == MineSection.assigned
    ? [_summary(assignedSectionFilters(f), sort)]
    : [for (final s in startedSectionFilters(f, doneSince)) _summary(s, sort)];

/// 全部 as a list: every task the person can see, one lane.
LaneSpec allListLane(PageFilters f, ServerTaskSort sort) =>
    _summary(serverFiltersOf(f), sort);

/// The board's columns: the statuses filtered to, in the board's order, else
/// all five.
List<String> boardColumns(PageFilters f) => f.statuses.isNotEmpty
    ? [
        for (final s in boardStatuses)
          if (f.statuses.contains(s)) s,
      ]
    : boardStatuses;

/// The filter sets one board column reads: 全部 one, 我的 one per relation.
List<ServerTaskFilters> boardColumnFilters(
  TasksPageTab tab,
  PageFilters f,
  String status,
) {
  final base = serverFiltersOf(f).copyWith(statuses: [status]);
  return tab == TasksPageTab.all
      ? [base]
      : [for (final r in mineRelations) base.copyWith(relation: r)];
}

List<LaneSpec> boardColumnLanes(
  TasksPageTab tab,
  PageFilters f,
  String status,
  ServerTaskSort sort,
) => [
  for (final c in boardColumnFilters(tab, f, status))
    LaneSpec(c, sort, LaneDetail.full),
];

/// The counts behind the board's columns: 全部 one set, 我的 one per
/// relation. Statuses are left to the columns.
List<ServerTaskFilters> boardCountsFilters(TasksPageTab tab, PageFilters f) {
  final base = serverFiltersOf(f.copyWith(statuses: const []));
  return tab == TasksPageTab.all
      ? [base]
      : [for (final r in mineRelations) base.copyWith(relation: r)];
}

/// Board columns that start folded: what is still moving is what people come
/// for.
const boardFoldedByDefault = {'closed'};

/// The name a board column's fold is kept under.
String boardFoldKey(String status) => 'board:$status';

/// Whether a board column is folded: by hand, else by default, unless the
/// status filter asks for it.
bool boardColumnFolded(
  String status,
  PageFilters f,
  Map<String, bool> collapsed,
) =>
    collapsed[boardFoldKey(status)] ??
    (boardFoldedByDefault.contains(status) && !f.statuses.contains(status));

/// Every lane the current view shows, in its order: what Select all reads to
/// its end. A folded board column shows none of its tasks.
List<LaneSpec> viewLanes(
  TasksPageTab tab,
  TasksPageView view,
  PageFilters f,
  ServerTaskSort sort,
  String doneSince, [
  Map<String, bool> collapsed = const {},
]) {
  if (view == TasksPageView.board) {
    return [
      for (final status in boardColumns(f))
        if (!boardColumnFolded(status, f, collapsed))
          ...boardColumnLanes(tab, f, status, sort),
    ];
  }
  if (tab == TasksPageTab.all) return [allListLane(f, sort)];
  return [
    for (final section in MineSection.values)
      ...mineSectionLanes(section, f, sort, doneSince),
  ];
}

// ----------------------------------------------------------------- rows

String? _str(Map<String, dynamic> row, String key) {
  final v = row[key];
  return v is String ? v : null;
}

/// When a task last moved, as the page shows and sorts it.
String taskActivityAt(Map<String, dynamic> task) =>
    _str(task, 'activityAt') ??
    _str(task, 'lastActivityAt') ??
    _str(task, 'updatedAt') ??
    '';

int _timeOf(String? value) =>
    (value == null ? null : DateTime.tryParse(value))?.millisecondsSinceEpoch ??
    0;

/// The status a task shows under on the page: In review is In progress.
String boardStatusOf(Map<String, dynamic> task) {
  final status = _str(task, 'status') ?? '';
  return status == 'in_review' ? 'in_progress' : status;
}

/// An open task nobody has updated for [staleAfter]: its time shows in the
/// warning ink.
bool isStaleTask(Map<String, dynamic> task, [DateTime? now]) {
  final status = task['status'];
  if (status != 'todo' && status != 'in_progress' && status != 'in_review') {
    return false;
  }
  final at = DateTime.tryParse(taskActivityAt(task));
  if (at == null) return false;
  return (now ?? DateTime.now()).difference(at) > staleAfter;
}

/// Whether a task matches the search as the server reads it: every word in
/// its title, case-insensitively, or one word that is its number (`12`, `#12`).
bool matchesQuery(Map<String, dynamic> task, String query) {
  final words = query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return true;
  final title = (_str(task, 'title') ?? '').toLowerCase();
  if (words.every(title.contains)) return true;
  if (words.length != 1) return false;
  final number = RegExp(r'^#?(\d{1,9})$').firstMatch(words.first);
  return number != null &&
      task['taskNumber'] is num &&
      (task['taskNumber'] as num) == int.parse(number.group(1)!);
}

String? _actorKey(Object? type, Object? id) =>
    type is String && type.isNotEmpty && id is String && id.isNotEmpty
    ? '$type:$id'
    : null;

bool _claimedBy(Map<String, dynamic> t, String viewer) =>
    t['claimedByType'] == 'user' && t['claimedById'] == viewer;

bool _createdBy(Map<String, dynamic> t, String viewer) =>
    t['createdByType'] == 'user' && t['createdById'] == viewer;

/// Whether the task belongs to the relation, as the server decides it
/// (exclusive, in this order: assigned to me, created by me, from my
/// message). `from_my_message` reads the source message's sender, which only
/// summary rows carry: unknown (null) when the row did not say, unless the
/// task has no source message at all, which can't be from my message.
bool? matchesRelation(
  Map<String, dynamic> task,
  TaskRelation relation,
  String viewer,
) {
  switch (relation) {
    case TaskRelation.assignedToMe:
      return _claimedBy(task, viewer);
    case TaskRelation.createdByMe:
      return _createdBy(task, viewer) && !_claimedBy(task, viewer);
    case TaskRelation.fromMyMessage:
      if (_claimedBy(task, viewer) || _createdBy(task, viewer)) return false;
      if (task.containsKey('sourceMessageId') &&
          task['sourceMessageId'] == null) {
        return false;
      }
      if (!task.containsKey('sourceSenderType') ||
          !task.containsKey('sourceSenderId')) {
        return null;
      }
      return task['sourceSenderType'] == 'user' &&
          task['sourceSenderId'] == viewer;
  }
}

bool _since(Object? value, String bound) {
  final at = value is String ? DateTime.tryParse(value) : null;
  final from = DateTime.tryParse(bound);
  return at != null && from != null && !at.isBefore(from);
}

/// Whether a task belongs in a lane as far as the client can tell: true,
/// false, or null when it hinges on a fact the row did not carry.
bool? matchLane(
  Map<String, dynamic> task,
  ServerTaskFilters f,
  String? viewerId,
) {
  if (f.statuses.isNotEmpty && !f.statuses.contains(boardStatusOf(task))) {
    return false;
  }
  if (f.channelIds.isNotEmpty && !f.channelIds.contains(task['channelId'])) {
    return false;
  }
  if (f.creators.isNotEmpty) {
    final creator = _actorKey(task['createdByType'], task['createdById']);
    if (creator == null || !f.creators.contains(creator)) return false;
  }
  if (f.assignees.isNotEmpty) {
    final assignee = _actorKey(task['claimedByType'], task['claimedById']);
    final ok = assignee != null
        ? f.assignees.contains(assignee)
        : f.assignees.contains('unassigned');
    if (!ok) return false;
  }
  if (f.createdSince != null &&
      f.createdSince!.isNotEmpty &&
      !_since(task['createdAt'], f.createdSince!)) {
    return false;
  }
  if (f.completedSince != null &&
      f.completedSince!.isNotEmpty &&
      task['status'] == 'done' &&
      !_since(task['completedAt'], f.completedSince!)) {
    return false;
  }
  if (f.query.isNotEmpty && !matchesQuery(task, f.query)) return false;
  if (f.relation != null) {
    if (viewerId == null) return false;
    return matchesRelation(task, f.relation!, viewerId);
  }
  return true;
}

/// Whether a task the client holds belongs in a lane. An unknown fact reads
/// as a match for a row the server put in the lane ([listed]) and as no
/// match for any other: the server's word stands until the client knows
/// better.
bool matchesLane(
  Map<String, dynamic> task,
  ServerTaskFilters f,
  String? viewerId,
  bool listed,
) => matchLane(task, f, viewerId) ?? listed;

/// The value a sort orders by (ms for the instants).
int sortKeyOf(ServerTaskSort sort, Map<String, dynamic> task) =>
    sort == ServerTaskSort.created
    ? _timeOf(_str(task, 'createdAt'))
    : _timeOf(taskActivityAt(task));

int _descending(String a, String b) => b.compareTo(a).sign;

/// The lane's order, as the server's: newest first by activityAt or by
/// creation, ties by task id, then channel id, all descending; activity_asc
/// exactly the reverse of activity.
int compareTasks(
  ServerTaskSort sort,
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  var newestFirst = sortKeyOf(sort, b).compareTo(sortKeyOf(sort, a));
  if (newestFirst == 0) {
    newestFirst = _descending(_str(a, 'id') ?? '', _str(b, 'id') ?? '');
  }
  if (newestFirst == 0) {
    newestFirst = _descending(
      _str(a, 'channelId') ?? '',
      _str(b, 'channelId') ?? '',
    );
  }
  return sort == ServerTaskSort.activityAsc ? -newestFirst : newestFirst;
}

/// The rows a group of lanes of one sort shows (a lane alone, 你发起的, a 我的
/// board column): each lane's listed rows that still match, in the server's
/// order; then, placed by the sort among them, the rows that changed live
/// since the read and match now, all cut at the earliest frontier of the
/// lanes with more to read, so no row of a page still to come could belong
/// above a row shown. Nothing shows until every lane has read its first page.
/// A row the client holds from elsewhere is not placed.
List<Map<String, dynamic>> mergedLaneTasks(
  List<LaneSpec> lanes,
  List<LaneRead?> reads,
  Map<String, Map<String, dynamic>> knownById,
  String? viewerId,
  int Function(String taskId) liveChangeOf,
) {
  if (lanes.isEmpty || reads.any((r) => r == null || !r.loaded)) {
    return const [];
  }
  final sort = lanes.first.sort;
  int compare(Map<String, dynamic> a, Map<String, dynamic> b) =>
      compareTasks(sort, a, b);
  Map<String, dynamic>? cut;
  var frontierLane = -1;
  for (var i = 0; i < reads.length; i++) {
    final read = reads[i]!;
    final frontier = read.frontier;
    if (read.nextCursor == null || frontier == null) continue;
    if (cut == null || compare(frontier, cut) < 0) {
      cut = frontier;
      frontierLane = i;
    }
  }
  bool withinCut(Map<String, dynamic> t) => cut == null || compare(t, cut) <= 0;
  final placed = <String>{};
  var ordered = <Map<String, dynamic>>[];
  for (var i = 0; i < lanes.length; i++) {
    final read = reads[i]!;
    final rows = <Map<String, dynamic>>[];
    for (final id in read.ids) {
      final task = knownById[id];
      if (task == null ||
          placed.contains(id) ||
          read.keys[id] != sortKeyOf(sort, task)) {
        continue;
      }
      if (!matchesLane(task, lanes[i].filters, viewerId, true)) continue;
      if (i != frontierLane && !withinCut(task)) continue;
      placed.add(id);
      rows.add(task);
    }
    ordered = i == 0 ? rows : _mergeOrdered(ordered, rows, compare);
  }
  final listedSets = [for (final r in reads) r!.ids.toSet()];
  final extras = <Map<String, dynamic>>[];
  for (final task in knownById.values) {
    final id = task['id'] as String;
    if (placed.contains(id) || !withinCut(task)) continue;
    var joins = false;
    for (var i = 0; i < lanes.length && !joins; i++) {
      final listed = listedSets[i].contains(id);
      if (!listed && liveChangeOf(id) <= reads[i]!.readSequence) continue;
      joins = matchesLane(task, lanes[i].filters, viewerId, listed);
    }
    if (joins) extras.add(task);
  }
  extras.sort(compare);
  return _mergeOrdered(ordered, extras, compare);
}

/// Two lists each in order, merged; ties keep the first list's row first.
List<Map<String, dynamic>> _mergeOrdered(
  List<Map<String, dynamic>> a,
  List<Map<String, dynamic>> b,
  int Function(Map<String, dynamic>, Map<String, dynamic>) compare,
) {
  final out = <Map<String, dynamic>>[];
  var i = 0, j = 0;
  while (i < a.length && j < b.length) {
    out.add(compare(b[j], a[i]) < 0 ? b[j++] : a[i++]);
  }
  while (i < a.length) {
    out.add(a[i++]);
  }
  while (j < b.length) {
    out.add(b[j++]);
  }
  return out;
}

/// Tasks that changed live since a lane's read and may belong in it, but
/// hinge on a fact the client lacks (a socket row has no source-message
/// sender): the lane reads its first page again to learn, once per task.
List<String> laneUnknownIds(
  List<LaneSpec> lanes,
  List<LaneRead?> reads,
  Map<String, Map<String, dynamic>> knownById,
  String? viewerId,
  int Function(String taskId) liveChangeOf,
) {
  final unknown = <String>[];
  for (var i = 0; i < lanes.length; i++) {
    final read = reads[i];
    if (read == null || !read.loaded) continue;
    final listed = read.ids.toSet();
    for (final task in knownById.values) {
      final id = task['id'] as String;
      if (listed.contains(id) || liveChangeOf(id) <= read.readSequence) {
        continue;
      }
      if (matchLane(task, lanes[i].filters, viewerId) == null) unknown.add(id);
    }
  }
  return unknown;
}

TasksPageTab? parseTasksPageTab(String? value) => switch (value) {
  'mine' => TasksPageTab.mine,
  'all' => TasksPageTab.all,
  _ => null,
};

ServerTaskSort? parseServerTaskSort(String? value) {
  for (final s in ServerTaskSort.values) {
    if (s.wire == value) return s;
  }
  return null;
}

/// A `?status=` value the page knows.
String? parseBoardStatus(String value) =>
    boardStatuses.contains(value) ? value : null;
