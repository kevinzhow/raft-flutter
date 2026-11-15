// Web v1.24 components/agent/AgentToolStuckNotice.tsx: the "Stuck on {tool}"
// line (minutes, queued messages, hint tooltip, minute re-render, Stop current
// turn), the `toolStuck` carrier on the live activity frame, and the
// `canStopThisTurn` gate.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/agent_profile_rules.dart'
    show canStopThisAgentTurn;
import 'package:raft_flutter/features/agent_tool_stuck_notice.dart';
import 'package:raft_ui/raft_ui.dart';

import 'workspace_entity_directory_test.dart' show agent, scope;

const _start = 1700000000000;

AgentToolStuck _stuck({int queued = 2, int quietAgoMs = 240000}) =>
    AgentToolStuck(
      toolName: 'bash',
      quietSinceMs: _start - quietAgoMs,
      thresholdMs: 180000,
      queuedMessages: queued,
    );

Future<void> _pump(
  WidgetTester t,
  AgentToolStuck stuck, {
  VoidCallback? onStop,
  int Function()? nowMs,
  double width = 600,
}) => t.pumpWidget(
  MaterialApp(
    theme: raftTheme(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: AgentToolStuckNotice(
            toolStuck: stuck,
            onStop: onStop,
            nowMs: nowMs ?? () => _start,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  group('parse', () {
    test('reads the carrier and rejects anything else', () {
      final ok = AgentToolStuck.parse({
        'toolName': 'bash',
        'toolDetailKind': 'running_command',
        'startedAtMs': 1,
        'quietSinceMs': 5,
        'thresholdMs': 180000,
        'queuedMessages': 3,
      });
      expect(
        ok,
        AgentToolStuck(
          toolName: 'bash',
          quietSinceMs: 5,
          thresholdMs: 180000,
          queuedMessages: 3,
        ),
      );
      expect(AgentToolStuck.parse(null), isNull);
      expect(AgentToolStuck.parse('bash'), isNull);
      expect(
        AgentToolStuck.parse({
          'toolName': '',
          'quietSinceMs': 1,
          'thresholdMs': 1,
        }),
        isNull,
      );
      expect(
        AgentToolStuck.parse({
          'toolName': 'x',
          'quietSinceMs': 'soon',
          'thresholdMs': 1,
        }),
        isNull,
      );
      expect(
        AgentToolStuck.parse({
          'toolName': 'x',
          'quietSinceMs': 1,
          'thresholdMs': 1,
        })?.queuedMessages,
        0,
      );
    });

    test('minutes: whole minutes, never below the threshold, at least 1', () {
      final s = AgentToolStuck(
        toolName: 't',
        quietSinceMs: 1000,
        thresholdMs: 180000,
        queuedMessages: 0,
      );
      expect(toolStuckMinutes(s, 1000 + 4 * 60000 + 59000), 4);
      // Clock skew (the Computer's clock ahead): the threshold is the floor.
      expect(toolStuckMinutes(s, 0), 3);
      final tiny = AgentToolStuck(
        toolName: 't',
        quietSinceMs: 0,
        thresholdMs: 1000,
        queuedMessages: 0,
      );
      expect(toolStuckMinutes(tiny, 500), 1);
    });

    test('only an online, unblocked agent shows it', () {
      final s = _stuck();
      expect(visibleToolStuck(s, isOnline: true, blocked: null), s);
      expect(visibleToolStuck(s, isOnline: false, blocked: null), isNull);
      expect(
        visibleToolStuck(s, isOnline: true, blocked: 'computer_offline'),
        isNull,
      );
      expect(visibleToolStuck(null, isOnline: true, blocked: null), isNull);
    });
  });

  group('canStopThisAgentTurn', () {
    const agentRow = {'id': 'a', 'creatorType': 'user', 'creatorId': 'alice'};
    bool can({
      Map row = agentRow,
      String? user = 'bob',
      bool control = true,
      bool bounded = false,
      bool external = false,
      bool assistant = false,
      bool owner = false,
      bool admin = false,
    }) => canStopThisAgentTurn(
      agent: row,
      currentUserId: user,
      controlAgentRuntime: control,
      boundedPublic: bounded,
      external: external,
      isAssistant: assistant,
      isAssistantOwner: owner,
      isServerAdmin: admin,
    );

    test('a Computer agent: capability or creator', () {
      expect(can(), isTrue);
      expect(can(control: false), isFalse);
      expect(can(control: false, user: 'alice'), isTrue);
    });
    test(
      'a bounded projection never',
      () => expect(can(bounded: true), isFalse),
    );
    test('an external agent only while its hosted runtime is active', () {
      expect(can(external: true), isFalse);
      expect(
        can(
          external: true,
          row: {
            ...agentRow,
            'hostedRuntime': {'state': 'provisioning'},
          },
        ),
        isFalse,
      );
      expect(
        can(
          external: true,
          row: {
            ...agentRow,
            'hostedRuntime': {'state': 'active'},
          },
        ),
        isTrue,
      );
    });
    test('a personal assistant: its owner or a server admin', () {
      expect(can(assistant: true), isFalse);
      expect(can(assistant: true, owner: true), isTrue);
      expect(can(assistant: true, admin: true), isTrue);
    });
  });

  group('notice', () {
    testWidgets('says the tool, the minutes and what is waiting', (t) async {
      await _pump(t, _stuck());
      expect(
        find.text('Stuck on bash · no output for 4 min · 2 messages waiting'),
        findsOneWidget,
      );
      await _pump(t, _stuck(queued: 1));
      expect(
        find.text('Stuck on bash · no output for 4 min · 1 message waiting'),
        findsOneWidget,
      );
      await _pump(t, _stuck(queued: 0));
      expect(find.text('Stuck on bash · no output for 4 min'), findsOneWidget);
    });

    testWidgets('the tooltip explains it', (t) async {
      await _pump(t, _stuck());
      expect(
        t.widget<RaftTooltip>(find.byType(RaftTooltip)).message,
        'A command started by this agent has produced no output for a while. New messages wait until it ends or this turn is stopped.',
      );
    });

    testWidgets('re-renders once a minute, with no other timer', (t) async {
      var now = _start;
      await _pump(t, _stuck(), nowMs: () => now);
      expect(find.textContaining('no output for 4 min'), findsOneWidget);
      now += 60000;
      await t.pump(const Duration(seconds: 59));
      expect(find.textContaining('no output for 4 min'), findsOneWidget);
      await t.pump(const Duration(seconds: 1));
      expect(find.textContaining('no output for 5 min'), findsOneWidget);
      // Gone: the periodic timer is cancelled with the widget.
      await t.pumpWidget(const SizedBox.shrink());
      expect(t.hasRunningAnimations, isFalse);
    });

    testWidgets('Stop current turn only for whoever can stop it', (t) async {
      await _pump(t, _stuck());
      expect(find.text('Stop current turn'), findsNothing);
      var stops = 0;
      await _pump(t, _stuck(), onStop: () => stops++);
      await t.tap(find.text('Stop current turn'));
      expect(stops, 1);
    });

    testWidgets(
      'the text truncates and the link wraps below in a narrow column',
      (t) async {
        await _pump(t, _stuck(), onStop: () {}, width: 220);
        expect(t.takeException(), isNull);
        expect(find.text('Stop current turn'), findsOneWidget);
      },
    );
  });

  group('live carrier', () {
    test(
      'agent:activity keeps toolStuck, and a frame without it clears it',
      () async {
        final directory = WorkspaceEntityDirectory(
          scope: () => scope(),
          query: (_) async => [agent],
        );
        addTearDown(directory.dispose);
        await directory.refresh(WorkspaceEntityKind.agents);
        AgentToolStuck? held() => agentRowToolStuck(directory.agent('a')!);
        expect(held(), isNull);
        final frame = {
          'agentId': 'a',
          'activity': 'working',
          'toolStuck': {
            'toolName': 'bash',
            'toolDetailKind': 'running_command',
            'startedAtMs': 1,
            'quietSinceMs': 5,
            'thresholdMs': 180000,
            'queuedMessages': 2,
          },
        };
        directory.receive(
          RaftEvent('agent:activity', {...frame, 'serverSeq': 10}),
        );
        expect(held()?.toolName, 'bash');
        expect(held()?.queuedMessages, 2);
        var notified = 0;
        directory.addListener(() => notified++);
        // A heartbeat repeating the same carrier changes nothing.
        directory.receive(
          RaftEvent('agent:activity', {...frame, 'serverSeq': 11}),
        );
        expect(notified, 0);
        // The queue grew: that is a change.
        directory.receive(
          RaftEvent('agent:activity', {
            ...frame,
            'serverSeq': 12,
            'toolStuck': {...(frame['toolStuck']! as Map), 'queuedMessages': 3},
          }),
        );
        expect(held()?.queuedMessages, 3);
        expect(notified, 1);
        // The tool finished: the next frame carries none.
        directory.receive(
          const RaftEvent('agent:activity', {
            'agentId': 'a',
            'activity': 'working',
            'serverSeq': 13,
          }),
        );
        expect(held(), isNull);
      },
    );
  });
}
