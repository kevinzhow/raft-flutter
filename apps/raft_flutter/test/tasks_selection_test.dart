import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_model.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_store.dart';
import 'package:raft_flutter/features/tasks_page/tasks_selection.dart';

const order = ['a', 'b', 'c', 'd', 'e'];

Map<String, dynamic> task(String id) => {
  'id': id,
  'status': 'todo',
  'channelId': 'c1',
  'updatedAt': '2026-11-17T10:00:00Z',
};

final lane = LaneSpec(
  const ServerTaskFilters(statuses: ['todo']),
  ServerTaskSort.activity,
  LaneDetail.summary,
);

void main() {
  group('selectionRun', () {
    test('both included, either order', () {
      expect(selectionRun(order, 'b', 'd'), ['b', 'c', 'd']);
      expect(selectionRun(order, 'd', 'b'), ['b', 'c', 'd']);
      expect(selectionRun(order, 'c', 'c'), ['c']);
    });

    test('just the target without a start or when either is not shown', () {
      expect(selectionRun(order, null, 'c'), ['c']);
      expect(selectionRun(order, 'x', 'c'), ['c']);
      expect(selectionRun(order, 'a', 'x'), ['x']);
    });
  });

  group('TaskSelection', () {
    test('a pick toggles; a Shift pick adds the run from the last pick', () {
      final s = TaskSelection(scope: 'mine');
      s.select('b', order: order);
      expect(s.selected, {'b'});
      expect(s.selecting, isTrue);
      s.select('d', range: true, order: order);
      expect(s.selected, {'b', 'c', 'd'});
      expect(s.lastPicked, 'd');
      // The run starts at the last pick: d to a.
      s.select('a', range: true, order: order);
      expect(s.selected, {'a', 'b', 'c', 'd'});
      s.select('c', order: order);
      expect(s.selected, {'a', 'b', 'd'});
    });

    test('a Shift pick without an earlier one toggles', () {
      final s = TaskSelection(scope: 'mine');
      s.select('c', range: true, order: order);
      expect(s.selected, {'c'});
      s.select('c', order: order);
      expect(s.selected, isEmpty);
    });

    test('a change of scope ends the selection and the run start', () {
      final s = TaskSelection(scope: 'mine|list');
      s.select('b', order: order);
      var heard = 0;
      s.addListener(() => heard += 1);
      s.setScope('mine|list');
      expect(heard, 0);
      s.setScope('all|list');
      expect(heard, 1);
      expect(s.selected, isEmpty);
      expect(s.lastPicked, isNull);
      // No start: a Shift pick is a plain pick.
      s.select('d', range: true, order: order);
      expect(s.selected, {'d'});
    });

    test('clear ends the run but keeps where focus goes back to', () {
      final s = TaskSelection(scope: 's');
      s.select('b', order: order);
      s.clear();
      expect(s.selected, isEmpty);
      expect(s.lastPicked, 'b');
      s.select('d', range: true, order: order);
      expect(s.selected, {'d'});
    });

    test(
      'setAll replaces, add adds, remove drops; no notification when unchanged',
      () {
        final s = TaskSelection(scope: 's');
        var heard = 0;
        s.addListener(() => heard += 1);
        s.setAll(['a', 'b']);
        s.add(['b', 'c']);
        s.remove(['a', 'x']);
        expect(s.selected, {'b', 'c'});
        expect(heard, 3);
        s.add(['b']);
        s.remove(['x']);
        expect(heard, 3);
      },
    );
  });

  group('readAllLaneTaskIds', () {
    late List<Map<String, String>> asked;
    late TasksPageStore store;
    void serve(FutureOr<dynamic> Function(Map<String, String> q) answer) {
      asked = [];
      store = TasksPageStore(
        query: (path, query) async {
          final q = {for (final e in query.entries) e.key: '${e.value}'};
          asked.add(q);
          return answer(q);
        },
        viewerId: () => 'me',
      );
    }

    test(
      'reads each lane to its end, 500 summaries a page, rows kept in the store',
      () async {
        serve(
          (q) => q['cursor'] == null
              ? {
                  'tasks': [task('a'), task('b')],
                  'next_cursor': 'p2',
                }
              : {
                  'tasks': [task('c')],
                  'next_cursor': null,
                },
        );
        final other = LaneSpec(
          const ServerTaskFilters(statuses: ['done']),
          ServerTaskSort.activity,
          LaneDetail.full,
        );
        final read = await readAllLaneTaskIds(store, [lane, other]);
        expect(read.ids, ['a', 'b', 'c']);
        expect(read.complete, isTrue);
        expect(read.capped, isFalse);
        expect(asked.first, {
          'status': 'todo',
          'sort': 'activity',
          'limit': '500',
          'detail': 'summary',
        });
        expect(asked[1]['cursor'], 'p2');
        // The other lane is a full lane but Select all reads summaries.
        expect(asked[2]['detail'], 'summary');
        expect(store.knownById.keys, containsAll(['a', 'b', 'c']));
      },
    );

    test('a task in two lanes is counted once', () async {
      serve(
        (_) => {
          'tasks': [task('a'), task('b')],
        },
      );
      final other = LaneSpec(
        const ServerTaskFilters(statuses: ['done']),
        ServerTaskSort.activity,
        LaneDetail.summary,
      );
      final read = await readAllLaneTaskIds(store, [lane, other]);
      expect(read.ids, ['a', 'b']);
    });

    test('stops at the cap, saying so', () async {
      serve(
        (q) => {
          'tasks': [
            for (var i = 0; i < 500; i++) task('${q['cursor'] ?? 'p0'}-$i'),
          ],
          'next_cursor': 'p${asked.length}',
        },
      );
      final read = await readAllLaneTaskIds(store, [lane]);
      expect(read.ids, hasLength(selectAllMax));
      expect(read.complete, isFalse);
      expect(read.capped, isTrue);
      expect(asked, hasLength(5));
    });

    test('exactly the cap with nothing more is complete', () async {
      serve(
        (_) => {
          'tasks': [for (var i = 0; i < 3; i++) task('t$i')],
        },
      );
      final read = await readAllLaneTaskIds(store, [lane], max: 3);
      expect(read.ids, hasLength(3));
      expect(read.complete, isTrue);
    });

    test(
      'a failed read stops short, not capped, keeping what it had',
      () async {
        serve((q) {
          if (q['cursor'] != null) {
            throw const RaftApiException('x', status: 500);
          }
          return {
            'tasks': [task('a')],
            'next_cursor': 'p2',
          };
        });
        final read = await readAllLaneTaskIds(store, [lane]);
        expect(read.ids, ['a']);
        expect(read.complete, isFalse);
        expect(read.capped, isFalse);
      },
    );

    test('a connection that dropped meanwhile stops short', () async {
      final gate = Completer<dynamic>();
      serve((_) => gate.future);
      final run = readAllLaneTaskIds(store, [lane]);
      await pumpEventQueue();
      store.reset();
      gate.complete({
        'tasks': [task('a')],
      });
      final read = await run;
      expect(read.complete, isFalse);
      expect(read.capped, isFalse);
      expect(read.ids, isEmpty);
    });

    test('an empty page ends the lane even with a cursor', () async {
      serve((_) => {'tasks': [], 'next_cursor': 'again'});
      final read = await readAllLaneTaskIds(store, [lane]);
      expect(read.complete, isTrue);
      expect(asked, hasLength(1));
    });
  });
}
