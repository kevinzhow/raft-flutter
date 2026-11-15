// Web v1.24 AgentActivityLog.tsx: the Activity view switch with its Subagents
// segment, the Subagents list and detail, the raw log's Subagent badge as a
// button, and Stop subagent (stopSubagent.ts).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';

import 'support/agent_panel_fixture.dart';

final _t0 = DateTime.utc(2026, 11, 14, 9, 0).millisecondsSinceEpoch;

Map<String, dynamic> _row(int at, Map<String, dynamic> entry) => {
  'timestamp': _t0 + at,
  'entry': entry,
};

Map<String, dynamic> _lineage(
  String task, {
  String call = 'call-1',
  String? type,
  String? phase,
  String? outcome,
}) => {
  'parentToolUseId': call,
  'taskId': task,
  'subagentType': ?type,
  'phase': ?phase,
  'outcome': ?outcome,
};

Map<String, dynamic> _status(int at, Map<String, dynamic> lineage) => _row(at, {
  'kind': 'status',
  'activity': 'working',
  'detail': 'Subagent activity',
  'detailKind': 'subagent_activity',
  'subagent': lineage,
});

Map<String, dynamic> _tool(
  int at,
  String name, {
  Map<String, dynamic>? lineage,
  String? callId,
  String input = '',
}) => _row(at, {
  'kind': 'tool_start',
  'toolName': name,
  'toolInput': input,
  'callId': ?callId,
  'subagent': ?lineage,
});

/// One running Codex subagent (task-run) and one that finished (task-done).
List<Map<String, dynamic>> _log() => [
  _tool(
    0,
    'spawnAgent',
    callId: 'call-done',
    input: 'spawnAgent: Audit the parser',
  ),
  _status(
    1000,
    _lineage(
      'task-done',
      call: 'call-done',
      type: 'explorer',
      phase: 'started',
    ),
  ),
  _tool(2000, 'Read', lineage: _lineage('task-done', call: 'call-done')),
  _status(
    3000,
    _lineage(
      'task-done',
      call: 'call-done',
      phase: 'notification',
      outcome: 'done',
    ),
  ),
  _tool(
    10000,
    'spawnAgent',
    callId: 'call-run',
    input: 'spawnAgent: Write the tests',
  ),
  _status(
    11000,
    _lineage('task-run', call: 'call-run', type: 'worker', phase: 'started'),
  ),
  _tool(12000, 'Bash', lineage: _lineage('task-run', call: 'call-run')),
];

Future<(AgentPanelWorkspace, AgentPanelClient)> _open(
  WidgetTester tester, {
  List<Map<String, dynamic>>? log,
  bool canControlRuntime = true,
  Map<String, dynamic> agent = agentPanelAgent,
  List<Map<String, dynamic>> Function()? read,
}) => pumpAgentPanel(
  tester,
  agent: agent,
  tab: AgentDetailTab.activity,
  toastHost: true,
  canControlRuntime: canControlRuntime,
  routes: {'/agents/a/activity-log': () => read?.call() ?? log ?? _log()},
);

Finder _segment(String name) => find.byKey(ValueKey('activity-view-$name'));

Future<void> _openSubagents(WidgetTester t) async {
  await t.tap(_segment('subagents'));
  await t.pumpAndSettle();
}

RaftApiException _refused(String code) => RaftApiException.response(
  'refused',
  status: 409,
  body: {'error': 'refused', 'code': code},
);

void main() {
  group('the Subagents segment', () {
    testWidgets('is shown once the activity holds a subagent, with its count', (
      t,
    ) async {
      await _open(t);
      expect(_segment('subagents'), findsOneWidget);
      expect(
        find.descendant(of: _segment('subagents'), matching: find.text('2')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _segment('subagents'),
          matching: find.text('Subagents'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('is absent while no row carries a lineage', (t) async {
      await _open(
        t,
        log: [
          _tool(0, 'Read'),
          _row(1, {'kind': 'text', 'text': 'hello'}),
        ],
      );
      expect(_segment('overview'), findsOneWidget);
      expect(_segment('raw'), findsOneWidget);
      expect(_segment('subagents'), findsNothing);
    });
  });

  group('the list', () {
    testWidgets(
      'running first, then the most recent; Running and Ended groups',
      (t) async {
        await _open(t);
        await _openSubagents(t);
        expect(find.text('Running'), findsOneWidget);
        expect(find.text('Ended'), findsOneWidget);
        final rows = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('subagent-row-'),
        );
        expect(rows, findsNWidgets(2));
        final first = t.getTopLeft(find.text('Write the tests')).dy;
        final second = t.getTopLeft(find.text('Audit the parser')).dy;
        expect(first < second, true, reason: 'the running one is listed first');
        // State chips use Web's words.
        expect(find.text('Working'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(
          find.text("Lists the subagents in this agent's recent activity."),
          findsOneWidget,
        );
      },
    );

    testWidgets('a row says its steps and, running, the tool it uses now', (
      t,
    ) async {
      await _open(t);
      await _openSubagents(t);
      // worker: 1 step, now: Bash -> "Running command".
      expect(
        find.textContaining('worker · 1 step · now: Running command'),
        findsOneWidget,
      );
      // explorer: ended, took ...
      expect(find.textContaining('explorer · 1 step · took'), findsOneWidget);
    });

    testWidgets('no subagents reads as the empty state', (t) async {
      var rows = _log();
      final (w, _) = await _open(t, read: () => rows);
      await _openSubagents(t);
      // The viewer's authority changed: the window of the new scope is empty.
      rows = [];
      w.server = RaftRecord({'id': 's2', 'role': 'owner'});
      w.notifyListeners();
      await t.pumpAndSettle();
      expect(find.text('No subagents right now'), findsOneWidget);
      expect(
        find.text("Lists the subagents in this agent's recent activity."),
        findsOneWidget,
      );
    });
  });

  group('from the raw log', () {
    testWidgets(
      'a Subagent badge opens that subagent; Back returns to the list',
      (t) async {
        await _open(t);
        await t.tap(_segment('raw'));
        await t.pumpAndSettle();
        // The first lineage row of the running worker.
        await t.tap(find.text('Subagent: worker').first);
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('subagent-detail')), findsOneWidget);
        expect(find.text('Write the tests'), findsWidgets);
        await t.tap(find.byKey(const ValueKey('subagent-back')));
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('subagent-detail')), findsNothing);
        expect(find.byKey(const ValueKey('subagents-list')), findsOneWidget);
      },
    );

    testWidgets('the spawn row links to its subagent', (t) async {
      await _open(t);
      await t.tap(_segment('raw'));
      await t.pumpAndSettle();
      expect(find.text('Open subagent'), findsNWidgets(2));
      await t.tap(find.text('Open subagent').first);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('subagent-detail')), findsOneWidget);
      expect(find.text('Audit the parser'), findsWidgets);
    });

    testWidgets('a badge of a subagent the view does not hold stays plain', (
      t,
    ) async {
      // A lineage with neither call nor task opens nothing.
      await _open(
        t,
        log: [
          ..._log(),
          _tool(20000, 'Read', lineage: {'subagentType': 'ghost'}),
        ],
      );
      await t.tap(_segment('raw'));
      await t.pumpAndSettle();
      await t.tap(find.text('Subagent: ghost'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('subagent-detail')), findsNothing);
    });
  });

  group('the detail', () {
    testWidgets('title, state, facts, and its own rows without the lineage', (
      t,
    ) async {
      await _open(t);
      await _openSubagents(t);
      await t.tap(find.text('Audit the parser'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('subagent-detail')), findsOneWidget);
      expect(find.byKey(const ValueKey('subagent-state-done')), findsOneWidget);
      expect(find.text('Type'), findsOneWidget);
      expect(find.text('explorer'), findsOneWidget);
      expect(find.text('Started'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.textContaining('took'), findsOneWidget);
      // Its step shows, without the Subagent badge (the view is already its).
      expect(find.text('Reading file'), findsOneWidget);
      expect(find.textContaining('Subagent: explorer'), findsNothing);
      // Another subagent's rows do not.
      expect(find.text('Running command'), findsNothing);
      // A finished subagent offers no Stop.
      expect(find.text('Stop subagent'), findsNothing);
    });

    testWidgets('opening the Overview or Raw log leaves the detail', (t) async {
      await _open(t);
      await _openSubagents(t);
      await t.tap(find.text('Audit the parser'));
      await t.pumpAndSettle();
      await t.tap(_segment('raw'));
      await t.pumpAndSettle();
      await t.tap(_segment('subagents'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('subagent-detail')), findsNothing);
      expect(find.byKey(const ValueKey('subagents-list')), findsOneWidget);
    });
  });

  group('Stop subagent', () {
    Future<(AgentPanelWorkspace, AgentPanelClient)> openRunning(
      WidgetTester t, {
      bool canControlRuntime = true,
      Map<String, dynamic> agent = agentPanelAgent,
      List<Map<String, dynamic>>? log,
    }) async {
      final out = await _open(
        t,
        canControlRuntime: canControlRuntime,
        agent: agent,
        log: log,
      );
      await _openSubagents(t);
      await t.tap(find.text('Write the tests'));
      await t.pumpAndSettle();
      return out;
    }

    Future<void> stop(WidgetTester t) async {
      await t.tap(find.byKey(const ValueKey('subagent-stop')));
      await t.pumpAndSettle();
    }

    testWidgets('posts the subagent interrupt and says what happened', (
      t,
    ) async {
      final (w, _) = await openRunning(t);
      w.onCommand = (m, p, d) async => {'outcome': 'interrupted'};
      await stop(t);
      expect(w.calls.single.$1, 'POST');
      expect(w.calls.single.$2, '/agents/a/subagents/task-run/interrupt');
      expect(find.text('Asked the subagent to stop.'), findsOneWidget);
    });

    testWidgets('not_running, unsupported and an unknown outcome', (t) async {
      final (w, _) = await openRunning(t);
      w.onCommand = (m, p, d) async => {'outcome': 'not_running'};
      await stop(t);
      expect(find.text("This subagent isn't running."), findsOneWidget);
      w.onCommand = (m, p, d) async => {'outcome': 'unsupported'};
      await stop(t);
      expect(
        find.text("This subagent can't be stopped on its own."),
        findsOneWidget,
      );
      w.onCommand = (m, p, d) async => {'outcome': 'something_new'};
      await stop(t);
      expect(find.text("This subagent isn't running."), findsWidgets);
    });

    testWidgets('the coded refusals say why and offer no Retry', (t) async {
      final (w, _) = await openRunning(t);
      w.onCommand = (m, p, d) async =>
          throw _refused('computer_upgrade_required');
      await stop(t);
      expect(
        find.text("Upgrade this agent's Computer to stop a single subagent."),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
      // Computer offline reuses the stop-turn copy.
      w.onCommand = (m, p, d) async => throw _refused('computer_offline');
      await stop(t);
      expect(find.text("This agent's Computer is offline."), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a plain failure offers Retry, and Retry stops the subagent', (
      t,
    ) async {
      final (w, _) = await openRunning(t);
      var calls = 0;
      w.onCommand = (m, p, d) async {
        calls++;
        if (calls == 1) throw RaftApiException('down', status: 503);
        return {'outcome': 'interrupted'};
      };
      await stop(t);
      expect(find.text("Couldn't stop the subagent."), findsOneWidget);
      await t.tap(find.text('Retry'));
      await t.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Asked the subagent to stop.'), findsOneWidget);
      expect(find.text("Couldn't stop the subagent."), findsNothing);
    });

    testWidgets('no Stop without the runtime authority', (t) async {
      await openRunning(t, canControlRuntime: false);
      expect(find.byKey(const ValueKey('subagent-detail')), findsOneWidget);
      expect(find.text('Stop subagent'), findsNothing);
    });

    testWidgets('no Stop for a runtime that cannot stop one subagent', (
      t,
    ) async {
      await openRunning(t, agent: {...agentPanelAgent, 'runtime': 'hermes'});
      expect(find.byKey(const ValueKey('subagent-detail')), findsOneWidget);
      expect(find.text('Stop subagent'), findsNothing);
    });

    testWidgets('no Stop for a running subagent that carries no task id', (
      t,
    ) async {
      // Claude's inner rows carry only the call; without a task there is
      // nothing to name in the stop request.
      await _open(
        t,
        log: [
          _tool(0, 'Task', callId: 'call-x', input: 'Do a thing'),
          _status(1000, {'parentToolUseId': 'call-x', 'phase': 'started'}),
        ],
      );
      await _openSubagents(t);
      await t.tap(find.text('Do a thing'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('subagent-detail')), findsOneWidget);
      expect(find.text('Stop subagent'), findsNothing);
    });
  });
}
