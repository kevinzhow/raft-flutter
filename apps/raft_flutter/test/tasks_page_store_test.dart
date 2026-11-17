import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_model.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_store.dart';

const me = 'u-me';

Map<String, dynamic> task(
  String id, {
  String status = 'todo',
  String activityAt = '2026-11-17T10:00:00.000Z',
  Map<String, dynamic> extra = const {},
}) => {
  'id': id,
  'status': status,
  'channelId': 'c1',
  'title': 'Task $id',
  'createdAt': '2026-11-01T00:00:00.000Z',
  'updatedAt': activityAt,
  'activityAt': activityAt,
  ...extra,
};

Map<String, String> asStrings(Map<String, dynamic> q) => {
  for (final e in q.entries) e.key: '${e.value}',
};

/// A scripted server: each call is recorded; [handler] answers it.
class FakeApi {
  final calls = <(String, Map<String, String>)>[];
  FutureOr<dynamic> Function(String path, Map<String, String> query)? handler;

  Future<dynamic> call(String path, Map<String, dynamic> query) async {
    final q = asStrings(query);
    calls.add((path, q));
    return handler!(path, q);
  }

  Iterable<Map<String, String>> pages() =>
      calls.where((c) => c.$1 == '/tasks/server').map((c) => c.$2);
  int get countReads =>
      calls.where((c) => c.$1 == '/tasks/server/counts').length;
}

Map<String, dynamic> page(List<Map<String, dynamic>> tasks, [String? next]) => {
  'tasks': tasks,
  'next_cursor': next,
};

final todoLane = LaneSpec(
  const ServerTaskFilters(statuses: ['todo']),
  ServerTaskSort.activity,
  LaneDetail.summary,
);

TasksPageStore storeOf(
  FakeApi api, {
  DateTime Function()? now,
  bool Function(Map<String, dynamic>)? belongs,
}) => TasksPageStore(
  query: api.call,
  viewerId: () => me,
  belongs: belongs,
  now: now,
);

List<String> shown(TasksPageStore s, LaneSpec lane) => [
  for (final t in s.laneView([lane]).tasks) t['id'] as String,
];

const counts = {
  'counts': {'backlog': 1, 'todo': 2, 'in_progress': 3, 'done': 4, 'closed': 5},
  'relations': {'assigned_to_me': 2, 'created_by_me': 1, 'from_my_message': 0},
};

void main() {
  group('lane reads', () {
    test('first page, then the next by cursor, ids in server order', () async {
      final api = FakeApi();
      final s = storeOf(api);
      api.handler = (path, q) => q['cursor'] == null
          ? page([task('a'), task('b')], 'c1')
          : page([task('c')]);
      await s.loadLanePage(todoLane);
      expect(api.pages().single, {
        'status': 'todo',
        'sort': 'activity',
        'limit': '20',
        'detail': 'summary',
      });
      expect(shown(s, todoLane), ['a', 'b']);
      expect(s.laneView([todoLane]).hasMore, isTrue);
      await s.loadLanePage(todoLane);
      expect(api.pages().last['cursor'], 'c1');
      expect(shown(s, todoLane), ['a', 'b', 'c']);
      expect(s.laneView([todoLane]).hasMore, isFalse);
      // Complete: no further read.
      await s.loadLanePage(todoLane);
      expect(api.pages(), hasLength(2));
    });

    test('no read while one is in flight', () async {
      final api = FakeApi();
      final s = storeOf(api);
      final gate = Completer<dynamic>();
      api.handler = (_, _) => gate.future;
      final first = s.loadLanePage(todoLane);
      await s.loadLanePage(todoLane);
      expect(api.pages(), hasLength(1));
      expect(s.laneView([todoLane]).loading, isTrue);
      gate.complete(page([task('a')]));
      await first;
      expect(shown(s, todoLane), ['a']);
    });

    test('a failed first page is failed, not retried on its own', () async {
      final api = FakeApi();
      final s = storeOf(api);
      api.handler = (_, _) => throw const RaftApiException('boom', status: 500);
      await s.loadLanePage(todoLane);
      expect(s.laneView([todoLane]).failed, isTrue);
      expect(s.laneView([todoLane]).loaded, isFalse);
      api.handler = (_, _) => page([task('a')]);
      await s.loadLanePage(todoLane);
      expect(shown(s, todoLane), ['a']);
      expect(s.laneView([todoLane]).failed, isFalse);
    });

    test(
      'a 400 on a later page restarts the lane, keeping its marks',
      () async {
        final api = FakeApi();
        final s = storeOf(api);
        api.handler = (_, _) => page([task('a')], 'c1');
        await s.loadLanePage(todoLane, checkedIds: ['x'], syncedCount: 4);
        api.handler = (_, _) =>
            throw const RaftApiException('cursor', status: 400);
        await s.loadLanePage(todoLane);
        final read = s.lanes[todoLane.key]!;
        expect(read.loaded, isFalse);
        expect(read.failed, isFalse);
        expect(read.ids, isEmpty);
        expect(read.checkedIds, ['x']);
        expect(read.syncedCount, 4);
        api.handler = (_, _) => page([task('a')]);
        await s.loadLanePage(todoLane);
        expect(s.lanes[todoLane.key]!.loaded, isTrue);
        expect(api.pages().last.containsKey('cursor'), isFalse);
      },
    );

    test('a 400 on the first page is failed', () async {
      final api = FakeApi();
      final s = storeOf(api);
      api.handler = (_, _) => throw const RaftApiException('bad', status: 400);
      await s.loadLanePage(todoLane);
      expect(s.laneView([todoLane]).failed, isTrue);
    });

    test(
      'restart reads as many rows as the lane shows, up to the cap',
      () async {
        final api = FakeApi();
        final s = storeOf(api);
        api.handler = (_, q) => page([
          for (var i = 0; i < 20; i++) task('${q['cursor'] ?? 'p'}$i'),
        ], q['cursor'] == null ? 'n' : null);
        await s.loadLanePage(todoLane);
        await s.loadLanePage(todoLane);
        expect(s.lanes[todoLane.key]!.ids, hasLength(40));
        await s.loadLanePage(todoLane, restart: true);
        expect(api.pages().last['limit'], '40');
        expect(api.pages().last.containsKey('cursor'), isFalse);
        // A restart replaces what was read.
        expect(s.lanes[todoLane.key]!.ids, hasLength(20));
      },
    );

    test(
      'rows are merged by field: a summary row keeps what it lacks',
      () async {
        final api = FakeApi();
        final s = storeOf(api);
        s.applyLive({
          'a': task('a', extra: {'description': 'long text'}),
        });
        api.handler = (_, _) => page([task('a')]);
        await s.loadLanePage(todoLane);
        expect(s.knownById['a']!['description'], 'long text');
      },
    );

    test('activity only moves forward when a read lands', () async {
      final api = FakeApi();
      final s = storeOf(api);
      s.applyLive({'a': task('a', activityAt: '2026-11-17T12:00:00.000Z')});
      api.handler = (_, _) =>
          page([task('a', activityAt: '2026-11-17T10:00:00.000Z')]);
      await s.readPage(todoLane, limit: 20);
      expect(s.knownById['a']!['activityAt'], '2026-11-17T12:00:00.000Z');
    });

    test(
      'a task changed live while a page is in flight keeps its live row',
      () async {
        final api = FakeApi();
        final s = storeOf(api);
        final gate = Completer<dynamic>();
        api.handler = (_, _) => gate.future;
        final read = s.loadLanePage(todoLane);
        s.applyLive({'a': task('a', status: 'done')});
        s.applyLive({'gone': null});
        gate.complete(page([task('a'), task('gone'), task('b')]));
        await read;
        expect(s.knownById['a']!['status'], 'done');
        expect(s.knownById.containsKey('gone'), isFalse);
        expect(s.knownById.containsKey('b'), isTrue);
      },
    );

    test('a read that started before reset does not land after it', () async {
      final api = FakeApi();
      final s = storeOf(api);
      final gate = Completer<dynamic>();
      api.handler = (_, _) => gate.future;
      final read = s.loadLanePage(todoLane);
      s.reset();
      gate.complete(page([task('a')]));
      await read;
      expect(s.lanes, isEmpty);
      expect(s.knownById, isEmpty);
    });
  });

  group('live rows', () {
    test(
      'a row that changed after the read joins; a deleted one leaves',
      () async {
        final api = FakeApi();
        final s = storeOf(api);
        api.handler = (_, _) => page([
          task('a', activityAt: '2026-11-17T10:00:00Z'),
          task('b', activityAt: '2026-11-17T08:00:00Z'),
        ]);
        await s.loadLanePage(todoLane);
        expect(shown(s, todoLane), ['a', 'b']);
        s.applyLive({'n': task('n', activityAt: '2026-11-17T09:00:00Z')});
        expect(shown(s, todoLane), ['a', 'n', 'b']);
        s.applyLive({'a': task('a', status: 'done')});
        expect(shown(s, todoLane), ['n', 'b']);
        s.applyLive({'b': null});
        expect(shown(s, todoLane), ['n']);
      },
    );

    test('a written task is applied at once as a live change', () async {
      final api = FakeApi();
      final s = storeOf(api);
      api.handler = (_, _) => page([task('a')]);
      await s.loadLanePage(todoLane);
      final before = s.liveRevision;
      s.applyWritten(task('a', status: 'done'));
      expect(shown(s, todoLane), isEmpty);
      expect(s.liveRevision, before + 1);
      s.removeTask('a');
      expect(s.knownById, isEmpty);
    });

    test('a row that no longer belongs on the page is dropped', () {
      final s = storeOf(FakeApi(), belongs: (t) => t['channelType'] != 'dm');
      s.applyLive({
        'a': task('a'),
        'd': task('d', extra: {'channelType': 'dm'}),
      });
      expect(s.knownById.keys, ['a']);
    });

    test('an unchanged live row keeps its object', () {
      final s = storeOf(FakeApi());
      s.applyLive({'a': task('a')});
      final held = s.knownById['a'];
      s.applyLive({'a': task('a')});
      expect(identical(s.knownById['a'], held), isTrue);
    });

    test('live changes the reads cover are forgotten', () async {
      final api = FakeApi();
      final s = storeOf(api);
      s.applyLive({'a': task('a')});
      expect(s.liveChangeOf('a'), 1);
      api.handler = (_, _) => page([task('b')]);
      await s.loadLanePage(todoLane);
      expect(s.liveChangeOf('a'), 0);
    });
  });

  group('settle: reads the lanes need', () {
    test(
      'an open lane never read reads at once; a count of 0 needs none',
      () async {
        final api = FakeApi();
        final s = storeOf(api);
        api.handler = (_, _) => page([task('a')]);
        s.settleLanes([todoLane], count: 0);
        await pumpEventQueue();
        expect(api.pages(), isEmpty);
        s.settleLanes([todoLane], folded: true);
        await pumpEventQueue();
        expect(api.pages(), isEmpty);
        s.setShown(false);
        s.settleLanes([todoLane]);
        await pumpEventQueue();
        expect(api.pages(), isEmpty);
        s.setShown(true);
        s.settleLanes([todoLane], count: 1);
        await pumpEventQueue();
        expect(api.pages(), hasLength(1));
        expect(shown(s, todoLane), ['a']);
      },
    );

    test(
      'a count that disagrees reads the lane again, once per count',
      () async {
        final api = FakeApi();
        final s = storeOf(api);
        api.handler = (_, _) => page([task('a')]);
        await s.loadLanePage(todoLane);
        s.settleLanes([todoLane], count: 1);
        await pumpEventQueue();
        expect(api.pages(), hasLength(1));
        // The server says 2 but the lane holds one: read again...
        s.settleLanes([todoLane], count: 2);
        await pumpEventQueue();
        expect(api.pages(), hasLength(2));
        // ...once: the same count again is no loop.
        s.settleLanes([todoLane], count: 2);
        await pumpEventQueue();
        expect(api.pages(), hasLength(2));
        // A different count reads again.
        s.settleLanes([todoLane], count: 3);
        await pumpEventQueue();
        expect(api.pages(), hasLength(3));
      },
    );

    test(
      'a live row of unknown relation reads the lane again, once per task',
      () async {
        final lane = LaneSpec(
          const ServerTaskFilters(relation: TaskRelation.fromMyMessage),
          ServerTaskSort.activity,
          LaneDetail.summary,
        );
        final api = FakeApi();
        final s = storeOf(api);
        api.handler = (_, _) => page([]);
        await s.loadLanePage(lane);
        s.applyLive({
          'u': task('u', extra: {'sourceMessageId': 'm'}),
        });
        s.settleLanes([lane]);
        await pumpEventQueue();
        expect(api.pages(), hasLength(2));
        expect(s.lanes[lane.key]!.checkedIds, ['u']);
        // The re-read learned nothing new about u: no second read for it.
        s.settleLanes([lane]);
        await pumpEventQueue();
        expect(api.pages(), hasLength(2));
      },
    );
  });

  group('counts', () {
    const all = ServerTaskFilters();

    test('read once, parsed, shared by key', () async {
      final api = FakeApi();
      final s = storeOf(api);
      api.handler = (_, _) => counts;
      await Future.wait([s.loadCounts(all), s.loadCounts(all)]);
      expect(api.countReads, 1);
      expect(s.counts[all.key]!.data!.total, 15);
      expect(s.countsCurrent(all), isTrue);
      await s.loadCounts(all);
      expect(api.countReads, 1);
    });

    test('three attempts with 1 s and 2 s backoff, then failed', () {
      fakeAsync((async) {
        final api = FakeApi();
        final s = storeOf(api);
        api.handler = (_, _) => throw const RaftApiException('x', status: 500);
        unawaited(s.loadCounts(all));
        async.flushMicrotasks();
        expect(api.countReads, 1);
        async.elapse(const Duration(milliseconds: 999));
        expect(api.countReads, 1);
        async.elapse(const Duration(milliseconds: 1));
        expect(api.countReads, 2);
        async.elapse(const Duration(milliseconds: 1999));
        expect(api.countReads, 2);
        async.elapse(const Duration(milliseconds: 1));
        expect(api.countReads, 3);
        expect(s.counts[all.key]!.failed, isTrue);
        expect(s.counts[all.key]!.data, isNull);
        async.elapse(const Duration(minutes: 1));
        expect(api.countReads, 3);
      });
    });

    test('retry after giving up starts over; numbers already shown stay', () {
      fakeAsync((async) {
        final api = FakeApi();
        final s = storeOf(api);
        api.handler = (_, _) => throw const RaftApiException('x', status: 500);
        unawaited(s.loadCounts(all));
        async.elapse(const Duration(seconds: 4));
        expect(s.counts[all.key]!.failed, isTrue);
        api.handler = (_, _) => counts;
        unawaited(s.retryCounts(all));
        async.flushMicrotasks();
        expect(s.counts[all.key]!.failed, isFalse);
        expect(s.counts[all.key]!.data!.total, 15);
        // Later reads that fail leave the numbers.
        api.handler = (_, _) => throw const RaftApiException('x', status: 500);
        s.applyLive({'a': task('a')});
        unawaited(s.loadCounts(all));
        async.elapse(const Duration(seconds: 4));
        expect(s.counts[all.key]!.failed, isFalse);
        expect(s.counts[all.key]!.data!.total, 15);
      });
    });

    test('after live changes the counts refresh at most every 10 s', () {
      fakeAsync((async) {
        final start = DateTime.utc(2026, 11, 17);
        final api = FakeApi();
        final s = storeOf(api, now: () => start.add(async.elapsed));
        api.handler = (_, _) => counts;
        s.watchCounts([all]);
        async.flushMicrotasks();
        expect(api.countReads, 1);
        async.elapse(const Duration(seconds: 3));
        s.applyLive({'a': task('a')});
        async.elapse(const Duration(seconds: 3));
        s.applyLive({'b': task('b')});
        async.elapse(const Duration(milliseconds: 3999));
        expect(api.countReads, 1);
        async.elapse(const Duration(milliseconds: 1));
        expect(api.countReads, 2);
        // Nothing changed since: no more reads.
        async.elapse(const Duration(minutes: 1));
        expect(api.countReads, 2);
        // A change long after reads at once.
        s.applyLive({'c': task('c')});
        async.flushMicrotasks();
        expect(api.countReads, 3);
      });
    });

    test('not while the page is hidden; they are when it shows again', () {
      fakeAsync((async) {
        final api = FakeApi();
        final s = storeOf(api);
        api.handler = (_, _) => counts;
        s.setShown(false);
        s.watchCounts([all]);
        async.elapse(const Duration(minutes: 1));
        expect(api.countReads, 0);
        s.setShown(true);
        async.flushMicrotasks();
        expect(api.countReads, 1);
      });
    });

    test('a set no longer watched is not scheduled', () {
      fakeAsync((async) {
        final start = DateTime.utc(2026, 11, 17);
        final api = FakeApi();
        final s = storeOf(api, now: () => start.add(async.elapsed));
        api.handler = (_, _) => counts;
        s.watchCounts([all]);
        async.flushMicrotasks();
        s.applyLive({'a': task('a')});
        s.watchCounts(const []);
        async.elapse(const Duration(minutes: 1));
        expect(api.countReads, 1);
      });
    });

    test('evicting a done-since drops its lanes and counts', () async {
      final api = FakeApi();
      final s = storeOf(api);
      api.handler = (path, _) => path.endsWith('counts') ? counts : page([]);
      final f = const ServerTaskFilters(
        statuses: ['done'],
        completedSince: '2026-11-16T00:00:00.000Z',
      );
      final lane = LaneSpec(f, ServerTaskSort.activity, LaneDetail.summary);
      await s.loadLanePage(lane);
      await s.loadCounts(f);
      await s.loadLanePage(todoLane);
      s.evictCompletedSince('2026-11-16T00:00:00.000Z');
      expect(s.lanes.keys, [todoLane.key]);
      expect(s.counts, isEmpty);
    });
  });

  group('counts of a view', () {
    Future<TasksPageStore> loaded(TasksCountsPlan plan, FakeApi api) async {
      final s = storeOf(api);
      s.watchCounts(plan.wanted);
      await pumpEventQueue();
      return s;
    }

    test('mine list: tabs, sections and the head total', () async {
      final api = FakeApi();
      api.handler = (_, q) {
        final relation = q['relation'];
        final n = switch (relation) {
          'assigned_to_me' => 1,
          'created_by_me' => 2,
          'from_my_message' => 4,
          _ => 100,
        };
        return {
          'counts': {'todo': n},
        };
      };
      final plan = TasksCountsPlan(
        TasksPageTab.mine,
        TasksPageView.list,
        PageFilters.none,
        '2026-11-16T00:00:00.000Z',
      );
      final s = await loaded(plan, api);
      final c = s.countsOf(plan);
      expect(c.tabs[TasksPageTab.mine], 7);
      expect(c.tabs[TasksPageTab.all], 100);
      expect(c.sections, {MineSection.assigned: 1, MineSection.started: 6});
      expect(c.shown, 7);
      expect(c.current, isTrue);
      expect(c.failed, isFalse);
      // 3 tab sets + all + the view's three sets are the same sets: 4 reads.
      expect(api.countReads, 4);
    });

    test('board: columns are the sum over relations; a search reads none of the view', () async {
      final api = FakeApi();
      api.handler = (_, q) => {
        'counts': {'todo': 1, 'done': q['relation'] == 'created_by_me' ? 5 : 0},
      };
      final plan = TasksCountsPlan(
        TasksPageTab.mine,
        TasksPageView.board,
        PageFilters.none,
        '2026-11-16T00:00:00.000Z',
      );
      final s = await loaded(plan, api);
      final c = s.countsOf(plan);
      expect(c.columns, {
        'backlog': 0,
        'todo': 3,
        'in_progress': 0,
        'done': 5,
        'closed': 0,
      });
      expect(c.shown, 8);
      final searching = TasksCountsPlan(
        TasksPageTab.all,
        TasksPageView.list,
        const PageFilters(query: 'x'),
        '2026-11-16T00:00:00.000Z',
      );
      expect(searching.viewSets, isEmpty);
      final read = s.countsOf(searching);
      expect(read.searching, isTrue);
      expect(read.shown, isNull);
      expect(read.sections, isNull);
    });

    test('failed only when a view set has nothing to show', () {
      fakeAsync((async) {
        final api = FakeApi();
        final s = storeOf(api);
        api.handler = (_, _) => throw const RaftApiException('x', status: 500);
        final plan = TasksCountsPlan(
          TasksPageTab.all,
          TasksPageView.list,
          const PageFilters(channelIds: ['c1']),
          '2026-11-16T00:00:00.000Z',
        );
        s.watchCounts(plan.wanted);
        async.elapse(const Duration(seconds: 10));
        expect(s.countsOf(plan).failed, isTrue);
        api.handler = (_, _) => counts;
        s.retryFailedCounts(plan);
        async.flushMicrotasks();
        expect(s.countsOf(plan).failed, isFalse);
        expect(s.countsOf(plan).shown, 15);
      });
    });
  });
}
