// Web v1.24 store/agentErrorRecordRefresh.ts: the server pushes only the error
// activity, and before it writes the agent's record. A pushed error the held
// record does not describe re-reads that record once the burst settles, so the
// own-billing state and the banner update. Bounded: once per distinct detail.
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/agent_error_record_refresh.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';

import 'workspace_entity_directory_test.dart' show agent, scope;

const _detail = 'The model provider rejected the request: balance too low.';

Map<String, dynamic> _record(String? message) => {
  ...agent,
  'lastRuntimeError': ?(message == null
      ? null
      : {
          'message': message,
          'errorClass': 'billing',
          'requiredAction': 'top_up',
        }),
};

Map<String, dynamic> _frame(
  String detail, {
  int seq = 1,
  bool heartbeat = false,
}) => {
  'agentId': 'a',
  'activity': 'error',
  'detail': detail,
  'detailKind': 'error',
  'serverSeq': seq,
  if (heartbeat) 'isHeartbeat': true,
};

void main() {
  group('stale', () {
    test('only an error the record does not describe is stale', () {
      expect(
        AgentErrorRecordRefresh.stale(
          lastRuntimeError: null,
          activity: 'error',
          detail: 'x',
        ),
        isTrue,
      );
      expect(
        AgentErrorRecordRefresh.stale(
          lastRuntimeError: {'message': 'x'},
          activity: 'error',
          detail: 'x',
        ),
        isFalse,
      );
      expect(
        AgentErrorRecordRefresh.stale(
          lastRuntimeError: {'message': 'old'},
          activity: 'error',
          detail: 'x',
        ),
        isTrue,
      );
      expect(
        AgentErrorRecordRefresh.stale(
          lastRuntimeError: null,
          activity: 'working',
          detail: 'x',
        ),
        isFalse,
      );
    });
  });

  group('directory', () {
    testWidgets(
      'a live error the record lacks re-reads the record once, keeping the live activity',
      (tester) async {
        final reads = <String>[];
        Map<String, dynamic> served = _record(null);
        final directory = WorkspaceEntityDirectory(
          scope: () => scope(),
          query: (path) async {
            reads.add(path);
            return path == '/agents' ? [agent] : served;
          },
        );
        addTearDown(directory.dispose);
        await directory.refresh(WorkspaceEntityKind.agents);
        reads.clear();
        expect(directory.agent('a')!['lastRuntimeError'], isNull);

        // The server stores the error after it pushes the activity.
        directory.receive(RaftEvent('agent:activity', _frame(_detail)));
        served = _record(_detail);
        // Nothing yet: it waits for the burst to settle.
        await tester.pump(const Duration(milliseconds: 1000));
        expect(reads, isEmpty);
        await tester.pump(const Duration(milliseconds: 600));
        expect(reads, ['/agents/a']);
        final row = directory.agent('a')!;
        expect((row['lastRuntimeError'] as Map)['requiredAction'], 'top_up');
        // The live activity (the socket's is newer) is not overwritten by the
        // record's own.
        expect(row['activity'], 'error');
        expect(row['activityDetail'], _detail);
      },
    );

    testWidgets(
      'the same error restated costs no further read; a different one asks again',
      (tester) async {
        final reads = <String>[];
        final directory = WorkspaceEntityDirectory(
          scope: () => scope(),
          query: (path) async {
            reads.add(path);
            // The record never lands the error (another error path).
            return path == '/agents' ? [agent] : _record(null);
          },
        );
        addTearDown(directory.dispose);
        await directory.refresh(WorkspaceEntityKind.agents);
        reads.clear();
        directory.receive(RaftEvent('agent:activity', _frame(_detail, seq: 1)));
        await tester.pump(const Duration(seconds: 2));
        expect(reads, ['/agents/a']);
        directory.receive(RaftEvent('agent:activity', _frame(_detail, seq: 2)));
        await tester.pump(const Duration(seconds: 2));
        expect(reads, ['/agents/a']);
        directory.receive(
          RaftEvent('agent:activity', _frame('Another failure.', seq: 3)),
        );
        await tester.pump(const Duration(seconds: 2));
        expect(reads, ['/agents/a', '/agents/a']);
      },
    );

    testWidgets(
      'a heartbeat, an error the record already holds, or a working state reads nothing',
      (tester) async {
        final reads = <String>[];
        final directory = WorkspaceEntityDirectory(
          scope: () => scope(),
          query: (path) async {
            reads.add(path);
            return path == '/agents' ? [_record(_detail)] : _record(_detail);
          },
        );
        addTearDown(directory.dispose);
        await directory.refresh(WorkspaceEntityKind.agents);
        reads.clear();
        directory.receive(RaftEvent('agent:activity', _frame(_detail, seq: 1)));
        directory.receive(
          RaftEvent('agent:activity', {
            ..._frame('Other.', seq: 2),
            'isHeartbeat': true,
          }),
        );
        directory.receive(
          const RaftEvent('agent:activity', {
            'agentId': 'a',
            'activity': 'working',
            'detail': 'Running tests',
            'serverSeq': 3,
          }),
        );
        await tester.pump(const Duration(seconds: 3));
        expect(reads, isEmpty);
      },
    );
  });
}
