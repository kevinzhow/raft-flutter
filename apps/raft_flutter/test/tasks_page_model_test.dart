import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_model.dart';

const me = 'u-me';
const done0 = '2026-11-16T00:00:00.000Z';

Map<String, dynamic> task(
  String id, {
  String status = 'todo',
  String activityAt = '2026-11-17T10:00:00.000Z',
  String channelId = 'c1',
  String? claimedBy,
  String? createdBy,
  String title = 'A task',
  Map<String, dynamic> extra = const {},
}) => {
  'id': id,
  'status': status,
  'channelId': channelId,
  'title': title,
  'createdAt': '2026-11-01T00:00:00.000Z',
  'updatedAt': activityAt,
  'activityAt': activityAt,
  if (claimedBy != null) ...{'claimedByType': 'user', 'claimedById': claimedBy},
  if (createdBy != null) ...{'createdByType': 'user', 'createdById': createdBy},
  ...extra,
};

LaneRead read(
  LaneSpec lane,
  List<Map<String, dynamic>> rows, {
  String? next,
  int sequence = 0,
}) => LaneRead(
  ids: [for (final r in rows) r['id'] as String],
  keys: {for (final r in rows) r['id'] as String: sortKeyOf(lane.sort, r)},
  frontier: rows.isEmpty ? null : Map.of(rows.last),
  nextCursor: next,
  loaded: true,
  readSequence: sequence,
);

Map<String, Map<String, dynamic>> known(List<Map<String, dynamic>> rows) => {
  for (final r in rows) r['id'] as String: r,
};

List<String> ids(List<Map<String, dynamic>> rows) => [
  for (final r in rows) r['id'] as String,
];

void main() {
  group('wire params', () {
    test('lists are sorted, in_progress also sends in_review', () {
      const filters = ServerTaskFilters(
        statuses: ['todo', 'in_progress'],
        channelIds: ['b', 'a'],
        assignees: ['user:2', 'unassigned'],
        creators: ['agent:9'],
        relation: TaskRelation.fromMyMessage,
        completedSince: '2026-11-16T00:00:00.000Z',
        createdSince: '2026-11-01T00:00:00.000Z',
        query: 'hi there',
      );
      expect(filters.filterParams(), {
        'status': 'in_progress,in_review,todo',
        'channel': 'a,b',
        'assignee': 'unassigned,user:2',
        'creator': 'agent:9',
        'relation': 'from_my_message',
        'completed_since': '2026-11-16T00:00:00.000Z',
        'created_since': '2026-11-01T00:00:00.000Z',
        'q': 'hi there',
      });
      expect(filters.filterParams().keys.toList(), [
        'status',
        'channel',
        'assignee',
        'creator',
        'relation',
        'completed_since',
        'created_since',
        'q',
      ]);
    });

    test('key is the encoded query string, equal for equal reads', () {
      const a = ServerTaskFilters(
        statuses: ['todo', 'in_progress'],
        channelIds: ['b', 'a'],
        query: 'hi there',
      );
      expect(
        a.key,
        'status=in_progress%2Cin_review%2Ctodo&channel=a%2Cb&q=hi+there',
      );
      expect(const ServerTaskFilters().key, '');
      expect(
        const ServerTaskFilters(statuses: ['todo', 'in_progress']).key,
        const ServerTaskFilters(statuses: ['in_progress', 'todo']).key,
      );
    });

    test('a page read adds sort, limit, summary detail and cursor', () {
      const filters = ServerTaskFilters(statuses: ['done']);
      expect(
        filters.pageParams(
          sort: ServerTaskSort.activityAsc,
          limit: 20,
          detail: LaneDetail.summary,
          cursor: 'abc',
        ),
        {
          'status': 'done',
          'sort': 'activity_asc',
          'limit': '20',
          'detail': 'summary',
          'cursor': 'abc',
        },
      );
      expect(
        filters.pageParams(
          sort: ServerTaskSort.created,
          limit: 500,
          detail: LaneDetail.full,
        ),
        {'status': 'done', 'sort': 'created', 'limit': '500'},
      );
    });

    test('counts are read field by field, a missing number is 0', () {
      final counts = readServerTaskCounts({
        'counts': {'backlog': 1, 'todo': 2, 'in_progress': 'x', 'done': -4},
        'relations': {'assigned_to_me': 3, 'created_by_me': 1.0},
      });
      expect(counts.statuses, {
        'backlog': 1,
        'todo': 2,
        'in_progress': 0,
        'done': 0,
        'closed': 0,
      });
      expect(counts.relations, {
        'assigned_to_me': 3,
        'created_by_me': 1,
        'from_my_message': 0,
      });
      expect(counts.total, 3);
      expect(readServerTaskCounts(null).total, 0);
    });
  });

  group('lane filters per tab, view and section', () {
    const doneSince = done0;
    String q(ServerTaskFilters f) => f.filterParams().toString();

    test('mine list: assigned, then started (one lane per relation)', () {
      final assigned = mineSectionLanes(
        MineSection.assigned,
        PageFilters.none,
        ServerTaskSort.activity,
        doneSince,
      );
      expect(assigned, hasLength(1));
      expect(assigned.single.filters.filterParams(), {
        'status': 'backlog,in_progress,in_review,todo',
        'relation': 'assigned_to_me',
      });
      final started = mineSectionLanes(
        MineSection.started,
        PageFilters.none,
        ServerTaskSort.activity,
        doneSince,
      );
      expect(
        [for (final l in started) l.filters.relation],
        [TaskRelation.createdByMe, TaskRelation.fromMyMessage],
      );
      expect(started.first.filters.filterParams(), {
        'status': 'backlog,done,in_progress,in_review,todo',
        'relation': 'created_by_me',
        'completed_since': doneSince,
      });
      expect(started.every((l) => l.detail == LaneDetail.summary), isTrue);
    });

    test('a status filter replaces the defaults and drops completed_since', () {
      const f = PageFilters(statuses: ['done'], query: 'x');
      expect(assignedSectionFilters(f).statuses, ['done']);
      final started = startedSectionFilters(f, doneSince);
      expect(started.every((s) => s.completedSince == null), isTrue);
      expect(started.first.filterParams(), {
        'status': 'done',
        'relation': 'created_by_me',
        'q': 'x',
      });
    });

    test('all list: one lane under the filters, no relation', () {
      final lane = allListLane(
        const PageFilters(channelIds: ['c1']),
        ServerTaskSort.created,
      );
      expect(q(lane.filters), '{channel: c1}');
      expect(lane.sort, ServerTaskSort.created);
    });

    test('board columns: the filtered statuses in board order, else five', () {
      expect(boardColumns(PageFilters.none), boardStatuses);
      expect(boardColumns(const PageFilters(statuses: ['done', 'todo'])), [
        'todo',
        'done',
      ]);
    });

    test('board column lanes: all one, mine one per relation, full detail', () {
      final all = boardColumnLanes(
        TasksPageTab.all,
        PageFilters.none,
        'todo',
        ServerTaskSort.activity,
      );
      expect(all, hasLength(1));
      expect(all.single.filters.filterParams(), {'status': 'todo'});
      expect(all.single.detail, LaneDetail.full);
      final mine = boardColumnLanes(
        TasksPageTab.mine,
        PageFilters.none,
        'in_progress',
        ServerTaskSort.activity,
      );
      expect([for (final l in mine) l.filters.relation], TaskRelation.values);
      expect(
        mine.first.filters.filterParams()['status'],
        'in_progress,in_review',
      );
    });

    test('board counts leave statuses to the columns', () {
      final f = const PageFilters(statuses: ['done'], channelIds: ['c1']);
      expect(boardCountsFilters(TasksPageTab.all, f).single.filterParams(), {
        'channel': 'c1',
      });
      expect(boardCountsFilters(TasksPageTab.mine, f), hasLength(3));
    });

    test('closed starts folded unless the status filter asks for it', () {
      expect(boardColumnFolded('closed', PageFilters.none, {}), isTrue);
      expect(boardColumnFolded('todo', PageFilters.none, {}), isFalse);
      expect(
        boardColumnFolded(
          'closed',
          const PageFilters(statuses: ['closed']),
          {},
        ),
        isFalse,
      );
      expect(
        boardColumnFolded('closed', PageFilters.none, {
          boardFoldKey('closed'): false,
        }),
        isFalse,
      );
      expect(
        boardColumnFolded('todo', PageFilters.none, {
          boardFoldKey('todo'): true,
        }),
        isTrue,
      );
    });

    test('viewLanes: every lane of the view, folded columns left out', () {
      List<LaneSpec> lanes(
        TasksPageTab tab,
        TasksPageView view, [
        Map<String, bool> collapsed = const {},
      ]) => viewLanes(
        tab,
        view,
        PageFilters.none,
        ServerTaskSort.activity,
        doneSince,
        collapsed,
      );
      expect(lanes(TasksPageTab.all, TasksPageView.list), hasLength(1));
      // assigned + created + from message
      expect(lanes(TasksPageTab.mine, TasksPageView.list), hasLength(3));
      // four open columns (closed folded), one lane each
      expect(lanes(TasksPageTab.all, TasksPageView.board), hasLength(4));
      // four open columns x three relations
      expect(lanes(TasksPageTab.mine, TasksPageView.board), hasLength(12));
      expect(
        lanes(TasksPageTab.all, TasksPageView.board, {
          boardFoldKey('closed'): false,
          boardFoldKey('todo'): true,
        }),
        hasLength(4),
      );
    });

    test('lane key tells reads apart by filters, sort and detail', () {
      const f = ServerTaskFilters(statuses: ['todo']);
      final a = LaneSpec(f, ServerTaskSort.activity, LaneDetail.summary);
      expect(a, LaneSpec(f, ServerTaskSort.activity, LaneDetail.summary));
      expect(
        a.key,
        isNot(LaneSpec(f, ServerTaskSort.created, LaneDetail.summary).key),
      );
      expect(
        a.key,
        isNot(LaneSpec(f, ServerTaskSort.activity, LaneDetail.full).key),
      );
    });
  });

  group('row matching', () {
    test('status, channel, creator and assignee filters', () {
      final t = task('t', claimedBy: 'u2', createdBy: me, channelId: 'c1');
      bool? m(ServerTaskFilters f) => matchLane(t, f, me);
      expect(m(const ServerTaskFilters(statuses: ['todo'])), isTrue);
      expect(m(const ServerTaskFilters(statuses: ['done'])), isFalse);
      expect(m(const ServerTaskFilters(channelIds: ['c2'])), isFalse);
      expect(m(const ServerTaskFilters(creators: ['user:$me'])), isTrue);
      expect(m(const ServerTaskFilters(creators: ['user:other'])), isFalse);
      expect(m(const ServerTaskFilters(assignees: ['user:u2'])), isTrue);
      expect(m(const ServerTaskFilters(assignees: ['unassigned'])), isFalse);
      expect(
        matchLane(
          task('u'),
          const ServerTaskFilters(assignees: ['unassigned']),
          me,
        ),
        isTrue,
      );
    });

    test('in_review counts as in_progress', () {
      final t = task('t', status: 'in_review');
      expect(boardStatusOf(t), 'in_progress');
      expect(
        matchLane(t, const ServerTaskFilters(statuses: ['in_progress']), me),
        isTrue,
      );
    });

    test('completed_since only bounds done tasks', () {
      const f = ServerTaskFilters(completedSince: done0);
      expect(matchLane(task('a', status: 'todo'), f, me), isTrue);
      expect(
        matchLane(
          task(
            'b',
            status: 'done',
            extra: {'completedAt': '2026-11-15T00:00:00Z'},
          ),
          f,
          me,
        ),
        isFalse,
      );
      expect(
        matchLane(
          task(
            'c',
            status: 'done',
            extra: {'completedAt': '2026-11-16T05:00:00Z'},
          ),
          f,
          me,
        ),
        isTrue,
      );
    });

    test('relations are exclusive, in order', () {
      final mine = task('a', claimedBy: me, createdBy: me);
      expect(matchesRelation(mine, TaskRelation.assignedToMe, me), isTrue);
      expect(matchesRelation(mine, TaskRelation.createdByMe, me), isFalse);
      final created = task('b', createdBy: me, claimedBy: 'u2');
      expect(matchesRelation(created, TaskRelation.createdByMe, me), isTrue);
      expect(matchesRelation(created, TaskRelation.fromMyMessage, me), isFalse);
    });

    test(
      'from_my_message: unknown without the sender, false without a source',
      () {
        final live = task('a', extra: {'sourceMessageId': 'm1'});
        expect(matchesRelation(live, TaskRelation.fromMyMessage, me), isNull);
        final none = task('b', extra: {'sourceMessageId': null});
        expect(matchesRelation(none, TaskRelation.fromMyMessage, me), isFalse);
        final summary = task(
          'c',
          extra: {
            'sourceMessageId': 'm1',
            'sourceSenderType': 'user',
            'sourceSenderId': me,
          },
        );
        expect(
          matchesRelation(summary, TaskRelation.fromMyMessage, me),
          isTrue,
        );
        expect(
          matchLane(
            live,
            const ServerTaskFilters(relation: TaskRelation.fromMyMessage),
            null,
          ),
          isFalse,
        );
      },
    );

    test('an unknown fact reads as the server listed it', () {
      final live = task('a', extra: {'sourceMessageId': 'm1'});
      const f = ServerTaskFilters(relation: TaskRelation.fromMyMessage);
      expect(matchesLane(live, f, me, true), isTrue);
      expect(matchesLane(live, f, me, false), isFalse);
    });

    test('search: every word in the title, or one task number', () {
      final t = task('a', title: 'Fix Login Bug', extra: {'taskNumber': 12});
      expect(matchesQuery(t, 'login fix'), isTrue);
      expect(matchesQuery(t, 'login nope'), isFalse);
      expect(matchesQuery(t, '12'), isTrue);
      expect(matchesQuery(t, '#12'), isTrue);
      expect(matchesQuery(t, '#13'), isFalse);
      expect(matchesQuery(t, '12 fix'), isFalse);
      expect(matchesQuery(t, '  '), isTrue);
    });

    test('stale: open for more than three days', () {
      final now = DateTime.utc(2026, 11, 17, 12);
      expect(
        isStaleTask(task('a', activityAt: '2026-11-13T00:00:00Z'), now),
        isTrue,
      );
      expect(
        isStaleTask(task('a', activityAt: '2026-11-15T00:00:00Z'), now),
        isFalse,
      );
      expect(
        isStaleTask(
          task('a', status: 'done', activityAt: '2026-01-01T00:00:00Z'),
          now,
        ),
        isFalse,
      );
    });
  });

  group('order', () {
    test('newest activity first, ties by id then channel, descending', () {
      final a = task('a', activityAt: '2026-11-17T10:00:00Z');
      final b = task('b', activityAt: '2026-11-17T10:00:00Z');
      final c = task('c', activityAt: '2026-11-17T11:00:00Z');
      final rows = [a, b, c]
        ..sort((x, y) => compareTasks(ServerTaskSort.activity, x, y));
      expect(ids(rows), ['c', 'b', 'a']);
      final asc = [a, b, c]
        ..sort((x, y) => compareTasks(ServerTaskSort.activityAsc, x, y));
      expect(ids(asc), ['a', 'b', 'c']);
    });

    test('created sort reads createdAt', () {
      final a = task('a', extra: {'createdAt': '2026-11-02T00:00:00Z'});
      final b = task('b', extra: {'createdAt': '2026-11-03T00:00:00Z'});
      expect(compareTasks(ServerTaskSort.created, a, b), greaterThan(0));
    });
  });

  group('merged lanes', () {
    final lane = LaneSpec(
      const ServerTaskFilters(statuses: ['todo']),
      ServerTaskSort.activity,
      LaneDetail.summary,
    );
    int never(String _) => 0;

    test('nothing shows until every lane read its first page', () {
      expect(mergedLaneTasks([lane], [null], {}, me, never), isEmpty);
      expect(
        mergedLaneTasks([lane], [const LaneRead()], {}, me, never),
        isEmpty,
      );
    });

    test(
      'listed rows keep the server order; rows from elsewhere are not placed',
      () {
        final t1 = task('t1', activityAt: '2026-11-17T10:00:00Z');
        final t2 = task('t2', activityAt: '2026-11-17T09:00:00Z');
        final other = task('o', activityAt: '2026-11-17T09:30:00Z');
        final shown = mergedLaneTasks(
          [lane],
          [
            read(lane, [t1, t2]),
          ],
          known([t1, t2, other]),
          me,
          never,
        );
        expect(ids(shown), ['t1', 't2']);
      },
    );

    test('a listed row that left the lane, or whose key moved, is dropped', () {
      final t1 = task('t1', activityAt: '2026-11-17T10:00:00Z');
      final t2 = task('t2', activityAt: '2026-11-17T09:00:00Z');
      final r = read(lane, [t1, t2]);
      final moved = {...t1, 'status': 'done'};
      expect(ids(mergedLaneTasks([lane], [r], known([moved, t2]), me, never)), [
        't2',
      ]);
      // A listed row whose sort key moved is placed again, by the sort.
      final bumped = {...t2, 'activityAt': '2026-11-17T12:00:00Z'};
      expect(
        ids(mergedLaneTasks([lane], [r], known([t1, bumped]), me, never)),
        ['t2', 't1'],
      );
    });

    test(
      'live rows join in sort order, cut at the frontier while more remain',
      () {
        final t1 = task('t1', activityAt: '2026-11-17T10:00:00Z');
        final t2 = task('t2', activityAt: '2026-11-17T09:00:00Z');
        final joined = task('t4', activityAt: '2026-11-17T09:30:00Z');
        final beyond = task('t5', activityAt: '2026-11-17T08:30:00Z');
        final r = read(lane, [t1, t2], next: 'more', sequence: 2);
        int live(String id) => id == 't4' || id == 't5' ? 3 : 0;
        final shown = mergedLaneTasks(
          [lane],
          [r],
          known([t1, t2, joined, beyond]),
          me,
          live,
        );
        expect(ids(shown), ['t1', 't4', 't2']);
        // With everything read, the older live row shows too.
        final complete = read(lane, [t1, t2], sequence: 2);
        expect(
          ids(
            mergedLaneTasks(
              [lane],
              [complete],
              known([t1, t2, joined, beyond]),
              me,
              live,
            ),
          ),
          ['t1', 't4', 't2', 't5'],
        );
      },
    );

    test('a live change before the read is not placed', () {
      final t1 = task('t1', activityAt: '2026-11-17T10:00:00Z');
      final old = task('t9', activityAt: '2026-11-17T09:30:00Z');
      final r = read(lane, [t1], sequence: 5);
      expect(
        ids(
          mergedLaneTasks(
            [lane],
            [r],
            known([t1, old]),
            me,
            (id) => id == 't9' ? 4 : 0,
          ),
        ),
        ['t1'],
      );
    });

    test(
      'several lanes merge by the sort and cut at the earliest frontier',
      () {
        final l2 = LaneSpec(
          const ServerTaskFilters(statuses: ['todo'], channelIds: ['c2']),
          ServerTaskSort.activity,
          LaneDetail.summary,
        );
        final a1 = task('a1', activityAt: '2026-11-17T10:00:00Z');
        final a2 = task('a2', activityAt: '2026-11-17T06:00:00Z');
        final b1 = task(
          'b1',
          activityAt: '2026-11-17T09:00:00Z',
          channelId: 'c2',
        );
        final b2 = task(
          'b2',
          activityAt: '2026-11-17T08:00:00Z',
          channelId: 'c2',
        );
        // Lane 1 has more past a2 (06:00); lane 2 is complete.
        final reads = [
          read(lane, [a1, a2], next: 'x'),
          read(l2, [b1, b2]),
        ];
        expect(
          ids(
            mergedLaneTasks(
              [lane, l2],
              reads,
              known([a1, a2, b1, b2]),
              me,
              never,
            ),
          ),
          ['a1', 'b1', 'b2', 'a2'],
        );
        // Lane 2 has more past b2 (08:00): a2 sorts after it and is cut.
        final reads2 = [
          read(lane, [a1, a2]),
          read(l2, [b1, b2], next: 'y'),
        ];
        expect(
          ids(
            mergedLaneTasks(
              [lane, l2],
              reads2,
              known([a1, a2, b1, b2]),
              me,
              never,
            ),
          ),
          ['a1', 'b1', 'b2'],
        );
      },
    );
  });

  group('unknown relation', () {
    final lane = LaneSpec(
      const ServerTaskFilters(relation: TaskRelation.fromMyMessage),
      ServerTaskSort.activity,
      LaneDetail.summary,
    );

    test('a live row that hinges on the sender is unknown, once changed after the read', () {
      final live = task('live', extra: {'sourceMessageId': 'm1'});
      final listed = task('listed', extra: {'sourceMessageId': 'm2'});
      final r = read(lane, [listed], sequence: 1);
      List<String> unknown(int Function(String) change) =>
          laneUnknownIds([lane], [r], known([live, listed]), me, change);
      expect(unknown((_) => 0), isEmpty);
      expect(unknown((id) => id == 'live' ? 2 : 0), ['live']);
      // Not placed meanwhile: an unknown fact reads as no match for an unlisted row.
      expect(
        ids(
          mergedLaneTasks(
            [lane],
            [r],
            known([live, listed]),
            me,
            (id) => id == 'live' ? 2 : 0,
          ),
        ),
        ['listed'],
      );
    });

    test('lanes not yet read have nothing to learn', () {
      final live = task('live', extra: {'sourceMessageId': 'm1'});
      expect(
        laneUnknownIds([lane], [null], known([live]), me, (_) => 9),
        isEmpty,
      );
    });
  });
}
