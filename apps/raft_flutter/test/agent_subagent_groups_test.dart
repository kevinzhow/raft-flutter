// Web v1.24 components/agent/subagentGroups.ts and stopSubagent.ts
// (`canStopSubagentsOf`): grouping the activity into subagent runs by lineage.
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_profile_rules.dart';
import 'package:raft_flutter/features/agent_subagent_groups.dart';

Map<String, dynamic> row(
  num at,
  Map<String, dynamic> entry, {
  Map<String, dynamic>? lineage,
}) => {
  'timestamp': at,
  'entry': {...entry, 'subagent': ?lineage},
};

Map<String, dynamic> lifecycle(
  num at,
  Map<String, dynamic> lineage, {
  String kind = 'status',
}) => row(
  at,
  kind == 'status'
      ? {
          'kind': 'status',
          'activity': 'working',
          'detail': 'x',
          'detailKind': 'subagent_activity',
        }
      : {'kind': 'system', 'title': 'Subagent', 'text': 'x'},
  lineage: lineage,
);

Map<String, dynamic> tool(
  num at,
  String name, {
  Map<String, dynamic>? lineage,
  String? callId,
  String input = '',
}) => row(at, {
  'kind': 'tool_start',
  'toolName': name,
  'toolInput': input,
  'callId': ?callId,
}, lineage: lineage);

void main() {
  group('groupSubagents', () {
    test(
      'a Codex run: title from the spawn call, steps, outcome, duration',
      () {
        final groups = groupSubagents([
          tool(
            900,
            'spawnAgent',
            callId: 'call-1',
            input: 'spawnAgent: Audit the parser',
          ),
          lifecycle(1000, {
            'parentToolUseId': 'call-1',
            'taskId': 'task-1',
            'subagentType': 'explorer',
            'phase': 'started',
          }),
          tool(
            2000,
            'Read',
            lineage: {'parentToolUseId': 'call-1', 'taskId': 'task-1'},
          ),
          tool(
            3000,
            'Grep',
            lineage: {'parentToolUseId': 'call-1', 'taskId': 'task-1'},
          ),
          lifecycle(4000, {
            'parentToolUseId': 'call-1',
            'taskId': 'task-1',
            'phase': 'notification',
            'outcome': 'done',
          }),
        ]);
        expect(groups, hasLength(1));
        final g = groups.single;
        expect(g.key, 'call-1\u0000task-1');
        expect(g.title, 'Audit the parser');
        expect(g.subagentType, 'explorer');
        expect(g.taskId, 'task-1');
        expect(g.state, SubagentState.done);
        expect(g.steps, 2);
        expect(g.lastToolName, 'Grep');
        // The spawn row opens the run, so it starts there.
        expect(g.startedAt, 900);
        expect(g.endedAt, 4000);
        // Its own rows only: no lifecycle row, no lineage marker.
        expect(g.items, hasLength(2));
        expect(
          g.items.every((i) => !(i['entry'] as Map).containsKey('subagent')),
          true,
        );
      },
    );

    test('every outcome is its own state; without one it reads as ended', () {
      SubagentState of(String? outcome) => groupSubagents([
        lifecycle(1, {'taskId': 't', 'phase': 'started'}),
        lifecycle(2, {'taskId': 't', 'phase': 'ended', 'outcome': ?outcome}),
      ]).single.state;
      expect(of('done'), SubagentState.done);
      expect(of('failed'), SubagentState.failed);
      expect(of('ceiling'), SubagentState.ceiling);
      expect(of('stopped'), SubagentState.stopped);
      expect(of(null), SubagentState.ended);
    });

    test('a start again (a follow-up turn) reopens a finished run', () {
      final g = groupSubagents([
        lifecycle(1, {'taskId': 't', 'phase': 'started'}),
        lifecycle(2, {
          'taskId': 't',
          'phase': 'notification',
          'outcome': 'done',
        }),
        lifecycle(3, {'taskId': 't', 'phase': 'progress'}),
      ]).single;
      expect(g.state, SubagentState.running);
      expect(g.endedAt, isNull);
    });

    test('a run whose start scrolled out reads as ended at its last row', () {
      final g = groupSubagents([
        tool(5, 'Read', lineage: {'taskId': 't'}),
        tool(9, 'Read', lineage: {'taskId': 't'}),
      ]).single;
      expect(g.state, SubagentState.ended);
      expect(g.endedAt, 9);
      expect(g.steps, 2);
    });

    test(
      'only lifecycle rows open or close: a tool end saying active is a step',
      () {
        final g = groupSubagents([
          lifecycle(1, {'taskId': 't', 'phase': 'started'}),
          row(
            2,
            {
              'kind': 'status',
              'activity': 'working',
              'detail': 'Tool finished',
              'detailKind': 'tool_end',
            },
            lineage: {'taskId': 't', 'phase': 'ended', 'outcome': 'failed'},
          ),
        ]).single;
        expect(g.state, SubagentState.running);
        expect(g.items, hasLength(1));
      },
    );

    test('a hosted agent system row is a lifecycle row too', () {
      final g = groupSubagents([
        lifecycle(1, {'taskId': 't', 'phase': 'started'}, kind: 'system'),
        lifecycle(2, {
          'taskId': 't',
          'phase': 'ended',
          'outcome': 'failed',
        }, kind: 'system'),
      ]).single;
      expect(g.state, SubagentState.failed);
    });

    test('rows without lineage never make a group', () {
      expect(
        groupSubagents([
          tool(1, 'Read'),
          row(2, {'kind': 'text', 'text': 'hello'}),
        ]),
        isEmpty,
      );
    });

    test('running first, then the most recent', () {
      final groups = groupSubagents([
        lifecycle(10, {'taskId': 'old-running', 'phase': 'started'}),
        lifecycle(20, {'taskId': 'done-new', 'phase': 'started'}),
        lifecycle(30, {
          'taskId': 'done-new',
          'phase': 'ended',
          'outcome': 'done',
        }),
        lifecycle(15, {'taskId': 'done-old', 'phase': 'started'}),
        lifecycle(16, {
          'taskId': 'done-old',
          'phase': 'ended',
          'outcome': 'done',
        }),
      ]);
      expect(
        [for (final g in groups) g.taskId],
        ['old-running', 'done-new', 'done-old'],
      );
    });

    test('Claude rows carry only the call and join that call\'s one task', () {
      final log = [
        lifecycle(1, {
          'parentToolUseId': 'call',
          'taskId': 'task',
          'phase': 'started',
        }),
        tool(2, 'Read', lineage: {'parentToolUseId': 'call'}),
      ];
      final g = groupSubagents(log).single;
      expect(g.key, 'call\u0000task');
      expect(g.steps, 1);
      expect(subagentKeyResolver(log)({'parentToolUseId': 'call'}), g.key);
    });

    test('one call that started several subagents keeps them apart', () {
      final log = [
        lifecycle(1, {
          'parentToolUseId': 'swarm',
          'taskId': 'a',
          'phase': 'started',
        }),
        lifecycle(2, {
          'parentToolUseId': 'swarm',
          'taskId': 'b',
          'phase': 'started',
        }),
      ];
      expect(groupSubagents(log), hasLength(2));
      // A row naming only the call is ambiguous: it keys by the call.
      expect(subagentKeyResolver(log)({'parentToolUseId': 'swarm'}), 'swarm');
    });

    test(
      'a resume under a new call keeps the task: one run per call and task',
      () {
        final log = [
          lifecycle(1, {
            'parentToolUseId': 'c1',
            'taskId': 't',
            'phase': 'started',
          }),
          lifecycle(2, {
            'parentToolUseId': 'c2',
            'taskId': 't',
            'phase': 'started',
          }),
        ];
        expect(groupSubagents(log), hasLength(2));
      },
    );
  });

  test('subagentRowPresence: a lifecycle reads as the subagent state', () {
    expect(subagentRowPresence({'phase': 'started'}), SubagentPresence.busy);
    expect(subagentRowPresence({'phase': 'progress'}), SubagentPresence.busy);
    expect(
      subagentRowPresence({'phase': 'ended', 'outcome': 'done'}),
      SubagentPresence.online,
    );
    expect(
      subagentRowPresence({'phase': 'notification'}),
      SubagentPresence.online,
    );
    expect(
      subagentRowPresence({'phase': 'ended', 'outcome': 'failed'}),
      SubagentPresence.error,
    );
    expect(subagentRowPresence({'phase': 'active'}), isNull);
    expect(subagentRowPresence(null), isNull);
  });

  test('canStopSubagentsOf: authority, a live agent, a runtime that can', () {
    bool can(Map agent, {bool control = true}) =>
        canStopSubagentsOf(agent: agent, controlAgentRuntime: control);
    for (final runtime in ['codex', 'claude', 'kimi-sdk', 'qoder']) {
      expect(can({'runtime': runtime}), true, reason: runtime);
    }
    expect(can({'runtime': 'codex'}, control: false), false);
    expect(can({'runtime': 'codex', 'deletedAt': '2026-01-01'}), false);
    expect(can({'runtime': 'hermes'}), false);
    expect(can({}), false);
  });
}
