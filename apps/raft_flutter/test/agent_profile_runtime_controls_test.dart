import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/agent_computer_offline_card.dart';
import 'package:raft_flutter/features/agent_profile_rules.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/agent_panel_fixture.dart';

const _offlineMachines = <Map<String, dynamic>>[
  {
    'id': 'm1',
    'name': 'Studio Mac',
    'status': 'offline',
    'isComputer': true,
    'userId': 'u2',
    'lastHeartbeat': '2026-10-20T09:30:00.000Z',
    'creator': {
      'id': 'u2',
      'type': 'human',
      'name': 'bea',
      'displayName': 'Bea',
    },
  },
];

/// Web v1.24 `agentRuntimePermissions` / `agentRuntimeControls`
/// (utils/agentVisibility.ts, utils/agentBlockedState.ts): no Start and no
/// Restart / Reset while the agent's Computer is offline, Stop stays unless a
/// person stopped it, and Stop also needs `stopAgents` (or the creator).
void main() {
  group('rules', () {
    const agent = {'creatorType': 'user', 'creatorId': 'alice'};
    ({
      bool canControlAgentRuntime,
      bool canStopAgent,
      bool canResetAgentWorkspace,
    })
    permissions({
      String user = 'bob',
      bool control = true,
      bool stop = false,
      bool reset = false,
      bool external = false,
      bool bounded = false,
    }) => agentRuntimePermissions(
      agent: agent,
      currentUserId: user,
      controlAgentRuntime: control,
      stopAgents: stop,
      resetAgentWorkspace: reset,
      external: external,
      boundedPublic: bounded,
    );

    test('Stop needs stopAgents or the creator on top of runtime control', () {
      expect(permissions().canControlAgentRuntime, isTrue);
      expect(permissions().canStopAgent, isFalse);
      expect(permissions(stop: true).canStopAgent, isTrue);
      expect(
        permissions(user: 'alice', control: false).canControlAgentRuntime,
        isTrue,
      );
      expect(permissions(user: 'alice', control: false).canStopAgent, isTrue);
      // stopAgents alone is not runtime control.
      expect(permissions(control: false, stop: true).canStopAgent, isFalse);
    });

    test('an external agent or a bounded projection gets none', () {
      for (final p in [
        permissions(external: true, stop: true, reset: true),
        permissions(bounded: true, stop: true, reset: true),
      ]) {
        expect(p.canControlAgentRuntime, isFalse);
        expect(p.canStopAgent, isFalse);
        expect(p.canResetAgentWorkspace, isFalse);
      }
      expect(permissions(reset: true).canResetAgentWorkspace, isTrue);
    });

    test(
      'Start and Stop never both hold; the Computer gates Start and Restart',
      () {
        ({bool start, bool stop, bool restartReset}) controls({
          bool online = false,
          bool offline = false,
          bool stopped = false,
          bool canStop = true,
        }) => agentRuntimeControls(
          canControl: true,
          canStop: canStop,
          isOnline: online,
          computerOffline: offline,
          stoppedByPerson: stopped,
        );
        expect(controls(), (start: true, stop: false, restartReset: true));
        expect(controls(online: true), (
          start: false,
          stop: true,
          restartReset: true,
        ));
        // Waiting on its offline Computer: Stop, no Start, no Restart.
        expect(controls(offline: true), (
          start: false,
          stop: true,
          restartReset: false,
        ));
        // A person stopped it: nothing to offer while the Computer is offline.
        expect(controls(offline: true, stopped: true), (
          start: false,
          stop: false,
          restartReset: false,
        ));
        expect(controls(online: true, canStop: false).stop, isFalse);
        expect(
          isAgentComputerOffline({'machineId': 'm1'}, _offlineMachines),
          isTrue,
        );
        expect(
          isAgentComputerOffline({'machineId': 'zz'}, _offlineMachines),
          isFalse,
        );
        expect(isAgentComputerOffline({'machineId': 'm1'}, null), isFalse);
      },
    );
  });

  group('profile', () {
    Future<void> pump(
      WidgetTester tester, {
      List<Map<String, dynamic>> machines = agentPanelMachines,
      Map<String, dynamic> agent = agentPanelAgent,
      Map<String, dynamic>? live,
      bool? canStop,
      Size size = const Size(900, 1600),
      TargetPlatform platform = TargetPlatform.linux,
    }) async {
      await pumpAgentPanel(
        tester,
        agent: agent,
        machines: machines,
        liveActivity: live,
        size: size,
        platform: platform,
      );
    }

    Finder text(String s) => find.text(s, skipOffstage: false);

    for (final (label, size, platform) in [
      ('fold 856x944', const Size(856, 944), TargetPlatform.android),
      ('fold 944x856', const Size(944, 856), TargetPlatform.android),
      ('narrow desktop 390x844', const Size(390, 844), TargetPlatform.linux),
    ]) {
      testWidgets('an offline Computer takes Start and Restart away ($label)', (
        tester,
      ) async {
        await pump(
          tester,
          machines: _offlineMachines,
          size: size,
          platform: platform,
        );
        expect(text('Start agent'), findsNothing);
        expect(text('Restart / reset'), findsNothing);
        // The offline card stands in for Start.
        expect(
          find.byKey(
            const ValueKey('agent-computer-offline-card'),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('an online Computer offers Start and Restart / reset', (
      tester,
    ) async {
      await pump(tester);
      expect(text('Start agent'), findsOneWidget);
      expect(text('Restart / reset'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('agent-computer-offline-card'),
          skipOffstage: false,
        ),
        findsNothing,
      );
    });

    testWidgets('an agent waiting on its offline Computer offers Stop only', (
      tester,
    ) async {
      await pump(tester, machines: _offlineMachines);
      // `activity: offline` + status active = not stopped by a person.
      expect(text('Stop agent'), findsOneWidget);
      expect(text('Start agent'), findsNothing);
    });

    testWidgets('an agent a person stopped offers nothing while offline', (
      tester,
    ) async {
      await pump(
        tester,
        machines: _offlineMachines,
        agent: {...agentPanelAgent, 'status': 'stopped'},
      );
      expect(text('Stop agent'), findsNothing);
      expect(text('Start agent'), findsNothing);
      expect(text('Restart / reset'), findsNothing);
    });
  });

  group('offline card', () {
    Future<WorkspaceEntityDirectory> mount(
      WidgetTester tester,
      Map<String, dynamic> machine, {
      void Function(WorkspaceEntityDirectory)? before,
      VoidCallback? onOpen,
    }) async {
      final client = AgentPanelClient()..selectServer('s');
      final w = AgentPanelWorkspace(client)
        ..server = RaftRecord({
          'id': 's',
          'name': 'Fixture',
          'role': 'owner',
          'slug': 'acme',
        });
      addTearDown(() async {
        w.dispose();
        await client.stream.close();
      });
      before?.call(w.services.entityDirectory);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: AgentComputerOfflineCard(
              controller: w,
              machine: machine,
              formatter: SourceTimeFormatter(),
              onOpenComputer: onOpen,
            ),
          ),
        ),
      );
      return w.services.entityDirectory;
    }

    testWidgets('names the Computer, its owner and the restart command', (
      tester,
    ) async {
      var opened = 0;
      await mount(tester, _offlineMachines.single, onOpen: () => opened++);
      expect(find.textContaining('has been offline since'), findsOneWidget);
      expect(find.text('Studio Mac'), findsOneWidget);
      expect(
        find.textContaining("Turn on Bea's computer Studio Mac and keep it"),
        findsOneWidget,
      );
      expect(
        find.text('On that computer, open Raft Desktop or run:'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data ?? '').replaceAll('\u200b', '') ==
                  'raft-computer restart /acme',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-computer-offline-card-computer')),
      );
      expect(opened, 1);
    });

    testWidgets('an unknown owner names no one', (tester) async {
      await mount(tester, {
        ..._offlineMachines.single,
        'userId': null,
        'creator': null,
      });
      expect(
        find.text('Turn on the computer Studio Mac and keep it from sleeping'),
        findsOneWidget,
      );
    });

    testWidgets('an online Computer draws nothing', (tester) async {
      await mount(tester, {..._offlineMachines.single, 'status': 'online'});
      expect(
        find.byKey(const ValueKey('agent-computer-offline-card')),
        findsNothing,
      );
    });

    testWidgets('a Computer offline only on a refused Start has no time', (
      tester,
    ) async {
      final client = AgentPanelClient()..selectServer('s');
      final w =
          AgentPanelWorkspace(
              client,
              routes: {
                '/servers/s/machines': () => {
                  'machines': [
                    {..._offlineMachines.single, 'status': 'online'},
                  ],
                },
              },
            )
            ..server = RaftRecord({
              'id': 's',
              'name': 'F',
              'role': 'owner',
              'slug': 'acme',
            });
      addTearDown(() async {
        w.dispose();
        await client.stream.close();
      });
      final directory = w.services.entityDirectory;
      await tester.runAsync(() async {
        directory.ensure([WorkspaceEntityKind.computers]);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      final row = directory.rows(WorkspaceEntityKind.computers);
      expect(row, isNotEmpty);
      directory.markComputerOfflineFromRefusal('m1');
      expect(directory.computerOfflineFromRefusal('m1'), isTrue);
      expect(
        directory.rows(WorkspaceEntityKind.computers).single['status'],
        'offline',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: AgentComputerOfflineCard(
              controller: w,
              machine: directory.rows(WorkspaceEntityKind.computers).single,
              formatter: SourceTimeFormatter(),
            ),
          ),
        ),
      );
      expect(find.text('is offline'), findsNothing);
      expect(find.textContaining('has been offline since'), findsNothing);
      expect(find.textContaining(' is offline'), findsOneWidget);
      // The Web recovery: the list is read again and replaces the guess.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(directory.computerOfflineFromRefusal('m1'), isFalse);
    });
  });
}
