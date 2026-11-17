import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/tasks_page/tasks_batch.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_store.dart';

const viewer = BatchViewer(userId: 'me', canAssign: true, canDeleteAny: false);

Map<String, dynamic> task(String id, [Map<String, dynamic> extra = const {}]) =>
    {
      'id': id,
      'status': 'todo',
      'channelId': 'c1',
      'claimedByType': 'user',
      'claimedById': 'other',
      'createdByType': 'user',
      'createdById': 'other',
      'updatedAt': '2026-11-17T10:00:00Z',
      ...extra,
    };

/// The requests a writer sent, answered by [answer].
class Server {
  final requests = <String>[];
  final bodies = <Object?>[];
  FutureOr<dynamic> Function(String method, String path)? answer;

  Future<dynamic> call(String method, String path, {dynamic data}) async {
    requests.add('$method $path');
    bodies.add(data);
    return answer?.call(method, path);
  }
}

TasksPageStore storeOf() =>
    TasksPageStore(query: (_, _) async => {}, viewerId: () => 'me');

void main() {
  group('canApplyBatchAction', () {
    bool can(BatchAction a, Map<String, dynamic> t, [BatchViewer v = viewer]) =>
        canApplyBatchAction(a, t, v);

    test('never a legacy task', () {
      final legacy = task('a', {'isLegacy': true});
      for (final action in const <BatchAction>[
        BatchStatus('done'),
        BatchAssignee(null),
        BatchFollow(),
        BatchDelete(),
      ]) {
        expect(
          can(
            action,
            legacy,
            const BatchViewer(
              userId: 'other',
              canAssign: true,
              canDeleteAny: true,
            ),
          ),
          isFalse,
        );
      }
    });

    test(
      'status: any writable task, but no todo to in_progress without an assignee',
      () {
        expect(can(const BatchStatus('done'), task('a')), isTrue);
        expect(
          can(
            const BatchStatus('done'),
            task('a', {'readOnlyReason': 'archived'}),
          ),
          isFalse,
        );
        expect(can(const BatchStatus('in_progress'), task('a')), isTrue);
        final unassigned = task('a', {
          'claimedById': null,
          'claimedByType': null,
        });
        expect(can(const BatchStatus('in_progress'), unassigned), isFalse);
        expect(
          can(const BatchStatus('in_progress'), {
            ...unassigned,
            'claimedById': '',
          }),
          isFalse,
        );
        expect(can(const BatchStatus('done'), unassigned), isTrue);
        expect(
          can(const BatchStatus('in_progress'), {
            ...unassigned,
            'status': 'backlog',
          }),
          isTrue,
        );
      },
    );

    test('assignee: the capability, not done, writable', () {
      expect(can(const BatchAssignee(null), task('a')), isTrue);
      expect(
        can(const BatchAssignee(null), task('a', {'status': 'done'})),
        isFalse,
      );
      expect(
        can(const BatchAssignee(null), task('a', {'readOnlyReason': 'x'})),
        isFalse,
      );
      const noAssign = BatchViewer(
        userId: 'me',
        canAssign: false,
        canDeleteAny: true,
      );
      expect(can(const BatchAssignee(null), task('a'), noAssign), isFalse);
    });

    test('delete: its creator, or deleteAnyTask; writable', () {
      expect(can(const BatchDelete(), task('a')), isFalse);
      expect(
        can(const BatchDelete(), task('a', {'createdById': 'me'})),
        isTrue,
      );
      expect(
        can(
          const BatchDelete(),
          task('a', {'createdById': 'me', 'createdByType': 'agent'}),
        ),
        isFalse,
      );
      expect(
        can(
          const BatchDelete(),
          task('a', {'createdById': 'me', 'readOnlyReason': 'x'}),
        ),
        isFalse,
      );
      const admin = BatchViewer(
        userId: 'me',
        canAssign: true,
        canDeleteAny: true,
      );
      expect(can(const BatchDelete(), task('a'), admin), isTrue);
      const anonymous = BatchViewer(
        userId: null,
        canAssign: true,
        canDeleteAny: false,
      );
      expect(
        can(const BatchDelete(), task('a', {'createdById': null}), anonymous),
        isFalse,
      );
    });

    test('follow: anyone who sees it', () {
      expect(
        can(const BatchFollow(), task('a', {'readOnlyReason': 'x'})),
        isTrue,
      );
    });
  });

  group('isBatchNoop', () {
    test('status and assignee that already are so', () {
      expect(isBatchNoop(const BatchStatus('todo'), task('a')), isTrue);
      expect(isBatchNoop(const BatchStatus('done'), task('a')), isFalse);
      expect(
        isBatchNoop(
          const BatchAssignee(TaskAssigneeRef('user', 'other')),
          task('a'),
        ),
        isTrue,
      );
      expect(
        isBatchNoop(
          const BatchAssignee(TaskAssigneeRef('agent', 'other')),
          task('a'),
        ),
        isFalse,
      );
      expect(isBatchNoop(const BatchAssignee(null), task('a')), isFalse);
      expect(
        isBatchNoop(
          const BatchAssignee(null),
          task('a', {'claimedById': null}),
        ),
        isTrue,
      );
      expect(isBatchNoop(const BatchFollow(), task('a')), isFalse);
      expect(isBatchNoop(const BatchDelete(), task('a')), isFalse);
    });
  });

  group('runTaskBatch', () {
    test(
      'a no-op counts as done without a request; the unpermitted are skipped',
      () async {
        final sent = <String>[];
        final outcome = await runTaskBatch(
          const BatchStatus('todo'),
          [
            task('a'),
            task('b', {'status': 'done'}),
            task('c', {'readOnlyReason': 'x'}),
          ],
          viewer,
          perform: (_, t) async => sent.add('${t['id']}'),
        );
        expect(sent, ['b']);
        expect(outcome.done, 2);
        expect(outcome.skipped, 1);
        expect(outcome.failedIds, isEmpty);
      },
    );

    test('at most four writes in flight', () async {
      var inFlight = 0, peak = 0;
      final gates = <Completer<void>>[];
      final run = runTaskBatch(
        const BatchStatus('done'),
        [for (var i = 0; i < 10; i++) task('t$i')],
        viewer,
        perform: (_, _) {
          inFlight += 1;
          if (inFlight > peak) peak = inFlight;
          final gate = Completer<void>();
          gates.add(gate);
          return gate.future.whenComplete(() => inFlight -= 1);
        },
      );
      await pumpEventQueue();
      expect(inFlight, 4);
      var released = 0;
      while (released < 10) {
        await pumpEventQueue();
        gates[released++].complete();
      }
      final outcome = await run;
      expect(peak, 4);
      expect(outcome.done, 10);
    });

    test(
      'a refused task is skipped and stays selected; the rest go on',
      () async {
        final outcome = await runTaskBatch(
          const BatchStatus('done'),
          [for (var i = 0; i < 6; i++) task('t$i')],
          viewer,
          perform: (_, t) async {
            if (t['id'] == 't1' || t['id'] == 't4') {
              throw StateError('refused ${t['id']}');
            }
          },
        );
        expect(outcome.done, 4);
        expect(outcome.skipped, 2);
        expect(outcome.failedIds..sort(), ['t1', 't4']);
        expect(outcome.firstError, isA<StateError>());
      },
    );

    test('skipped adds the unpermitted and the failed', () async {
      final outcome = await runTaskBatch(
        const BatchDelete(),
        [
          task('a', {'createdById': 'me'}),
          task('b', {'createdById': 'me'}),
          task('c'),
        ],
        viewer,
        perform: (_, t) async {
          if (t['id'] == 'b') throw Exception('no');
        },
      );
      expect(
        outcome,
        const BatchOutcome(done: 1, skipped: 2, failedIds: ['b']),
      );
    });

    test('nothing to do sends nothing', () async {
      final outcome = await runTaskBatch(
        const BatchDelete(),
        [task('a')],
        viewer,
        perform: (_, _) => fail('not permitted'),
      );
      expect(outcome, const BatchOutcome(done: 0, skipped: 1));
      expect(
        await runTaskBatch(
          const BatchFollow(),
          [],
          viewer,
          perform: (_, _) => fail('none'),
        ),
        const BatchOutcome(done: 0, skipped: 0),
      );
    });

    test(
      'follow reads the followed threads again once, when it reached any',
      () async {
        var refreshed = 0;
        Future<void> refresh() async => refreshed += 1;
        await runTaskBatch(
          const BatchFollow(),
          [task('a'), task('b')],
          viewer,
          perform: (_, _) async {},
          afterFollow: refresh,
        );
        expect(refreshed, 1);
        await runTaskBatch(
          const BatchFollow(),
          [task('a')],
          viewer,
          perform: (_, _) async => throw 'x',
          afterFollow: refresh,
        );
        expect(refreshed, 1);
        await runTaskBatch(
          const BatchStatus('done'),
          [task('a')],
          viewer,
          perform: (_, _) async {},
          afterFollow: refresh,
        );
        expect(refreshed, 1);
        // Its failure is not the batch's.
        final outcome = await runTaskBatch(
          const BatchFollow(),
          [task('a')],
          viewer,
          perform: (_, _) async {},
          afterFollow: () async => throw StateError('refresh'),
        );
        await pumpEventQueue();
        expect(outcome.done, 1);
      },
    );
  });

  group('the requests of each action', () {
    late Server server;
    late TasksPageStore store;
    late Future<void> Function(BatchAction, Map<String, dynamic>) writer;
    setUp(() {
      server = Server();
      store = storeOf();
      writer = taskBatchWriter(store, server.call);
    });

    test(
      'status: PATCH /tasks/:id/status {status}, never claim; the task is applied',
      () async {
        server.answer = (_, _) => {
          'task': task('a', {'status': 'done'}),
        };
        await runTaskBatch(
          const BatchStatus('done'),
          [task('a'), task('b')],
          viewer,
          perform: writer,
        );
        expect(server.requests..sort(), [
          'PATCH /tasks/a/status',
          'PATCH /tasks/b/status',
        ]);
        expect(server.bodies, everyElement({'status': 'done'}));
        expect(store.knownById['a']!['status'], 'done');
        // Into Backlog: still no reason, one status only.
        server.requests.clear();
        server.bodies.clear();
        await runTaskBatch(
          const BatchStatus('backlog'),
          [task('c')],
          viewer,
          perform: writer,
        );
        expect(server.bodies.single, {'status': 'backlog'});
      },
    );

    test('the unassigned todo is not moved to in_progress at all', () async {
      final outcome = await runTaskBatch(
        const BatchStatus('in_progress'),
        [
          task('a', {'claimedById': null}),
        ],
        viewer,
        perform: writer,
      );
      expect(server.requests, isEmpty);
      expect(outcome.skipped, 1);
    });

    test(
      'assignee: PATCH /tasks/:id/assignee {assignee: {type,id}} or null',
      () async {
        server.answer = (_, _) => {
          'task': task('a', {'claimedById': 'u9'}),
        };
        await runTaskBatch(
          const BatchAssignee(TaskAssigneeRef('agent', 'g1')),
          [task('a')],
          viewer,
          perform: writer,
        );
        expect(server.requests, ['PATCH /tasks/a/assignee']);
        expect(server.bodies.single, {
          'assignee': {'type': 'agent', 'id': 'g1'},
        });
        expect(store.knownById['a']!['claimedById'], 'u9');
        server.requests.clear();
        server.bodies.clear();
        await runTaskBatch(
          const BatchAssignee(null),
          [task('b')],
          viewer,
          perform: writer,
        );
        expect(server.requests, ['PATCH /tasks/b/assignee']);
        expect(server.bodies.single, {'assignee': null});
      },
    );

    test(
      'follow with a conversation: only POST /channels/threads/follow',
      () async {
        await runTaskBatch(
          const BatchFollow(),
          [
            task('a', {'conversationChannelId': 'conv-a'}),
          ],
          viewer,
          perform: writer,
        );
        expect(server.requests, ['POST /channels/threads/follow']);
        expect(server.bodies.single, {'threadChannelId': 'conv-a'});
        store.applyLive({
          'a': task('a', {'conversationChannelId': 'conv-a'}),
        });
        await writer(
          const BatchFollow(),
          task('a', {'conversationChannelId': 'conv-a'}),
        );
        expect(store.knownById['a']!['conversationFollowed'], isTrue);
      },
    );

    test(
      'follow without one creates it first, then follows what it answered',
      () async {
        server.answer = (method, path) => path.endsWith('/conversation')
            ? {'conversationChannelId': 'new-conv'}
            : {};
        await runTaskBatch(
          const BatchFollow(),
          [task('a')],
          viewer,
          perform: writer,
        );
        expect(server.requests, [
          'POST /tasks/a/conversation',
          'POST /channels/threads/follow',
        ]);
        expect(server.bodies.last, {'threadChannelId': 'new-conv'});
      },
    );

    test(
      'a joint task has no direct conversation: the server answers its local one',
      () async {
        server.answer = (method, path) => path.endsWith('/conversation')
            ? {'conversationChannelId': 'local'}
            : {};
        await runTaskBatch(
          const BatchFollow(),
          [
            task('a', {
              'channelType': 'joint',
              'conversationChannelId': 'remote',
            }),
          ],
          viewer,
          perform: writer,
        );
        expect(server.requests.first, 'POST /tasks/a/conversation');
        expect(server.bodies.last, {'threadChannelId': 'local'});
      },
    );

    test(
      'follow fails visibly when the conversation has no channel id',
      () async {
        server.answer = (_, _) => {};
        final outcome = await runTaskBatch(
          const BatchFollow(),
          [task('a')],
          viewer,
          perform: writer,
        );
        expect(server.requests, ['POST /tasks/a/conversation']);
        expect(outcome.failedIds, ['a']);
        expect(outcome.done, 0);
      },
    );

    test('delete: DELETE /tasks/:id, the task leaves the store', () async {
      store.applyLive({
        'a': task('a', {'createdById': 'me'}),
      });
      await runTaskBatch(
        const BatchDelete(),
        [
          task('a', {'createdById': 'me'}),
        ],
        viewer,
        perform: writer,
      );
      expect(server.requests, ['DELETE /tasks/a']);
      expect(store.knownById, isEmpty);
    });

    test('a failed write changes nothing in the store', () async {
      store.applyLive({'a': task('a')});
      server.answer = (_, _) => throw StateError('409');
      final outcome = await runTaskBatch(
        const BatchStatus('done'),
        [task('a')],
        viewer,
        perform: writer,
      );
      expect(outcome.failedIds, ['a']);
      expect(store.knownById['a']!['status'], 'todo');
    });
  });
}
