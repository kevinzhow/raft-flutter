// The readiness branch of the profile's status chip (Web v1.24.0
// AgentStatusBadge.tsx + utils/readinessCopy.ts): an agent that cannot work
// now reads the server's readiness in words, in the light Web gives it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_flutter/features/agent_status_state.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/agent_panel_fixture.dart';

Finder chip() => find.byKey(const ValueKey('agent-status-chip'));
Finder retry() => find.byKey(const ValueKey('agent-status-retry'));
Finder link() => find.byKey(const ValueKey('agent-readiness-link'));
Finder detail() => find.byKey(const ValueKey('agent-readiness-detail'));

Map<String, dynamic> _readiness(
  String state,
  String code, {
  String? scope = 'computer',
  String? actor = 'computer_owner',
  Map<String, dynamic> extra = const {},
}) => {
  'state': state,
  'primary': {
    'resource': {'kind': 'computer', 'id': 'm1'},
    'code': code,
    'behaviour': state,
    ...extra,
  },
  'scope': scope,
  'actor': actor,
};

Map<String, dynamic> _agent(Map<String, dynamic>? readiness) => {
  ...agentPanelAgent,
  'activity': 'online',
  'readiness': ?readiness,
};

const _verification =
    "The Codex CLI account signed in here can't receive replies until it is verified. The account holder must finish the step in the Anthropic Verification Portal, then choose Retry. Messages are kept and will be delivered. The computer's owner can fix it.";

void main() {
  group('the light', () {
    test('a Computer offline is stone, a block or a limit wait orange', () {
      final offline = readinessLight(_readiness('blocked', 'computer_offline'));
      expect(offline.tone, AgentChipTone.muted);
      expect(offline.light, AgentChipLight.offline);
      final blocked = readinessLight(_readiness('blocked', 'runtime_missing'));
      expect(blocked.tone, AgentChipTone.warning);
      expect(blocked.light, AgentChipLight.error);
      final limit = readinessLight(_readiness('waiting', 'rate_limited'));
      expect(limit.tone, AgentChipTone.warning);
      final restarting = readinessLight(
        _readiness('waiting', 'computer_restarting'),
      );
      expect(restarting.tone, AgentChipTone.busy);
      expect(restarting.light, AgentChipLight.busy);
    });

    test('only blocked and waiting hold the agent', () {
      expect(readinessHolds(_readiness('blocked', 'x')), isTrue);
      expect(readinessHolds(_readiness('waiting', 'x')), isTrue);
      expect(readinessHolds({'state': 'ready'}), isFalse);
      expect(readinessHolds({'state': 'advisory'}), isFalse);
      expect(readinessHolds(null), isFalse);
    });
  });

  testWidgets('verification: title, scoped tooltip, sentence, link, Retry', (
    tester,
  ) async {
    final (w, _) = await pumpAgentPanel(
      tester,
      agent: _agent(
        _readiness(
          'blocked',
          'verification_required',
          extra: {
            'resource': {'kind': 'runtime', 'runtime': 'codex'},
          },
        ),
      ),
    );
    expect(
      find.descendant(
        of: chip(),
        matching: find.text('Account needs verification'),
      ),
      findsOneWidget,
    );
    expect(
      find.text("This Computer's problem: $_verification"),
      findsOneWidget,
    );
    expect(link(), findsOneWidget);
    expect(find.text('Open the Anthropic verification portal'), findsOneWidget);
    expect(retry(), findsOneWidget);
    await tester.tap(retry());
    await tester.pump();
    expect(w.calls.last.$2, '/agents/a/reset');
  });

  testWidgets('Retry is the way out: the notice is gone once it resolves', (
    tester,
  ) async {
    final agent = ValueNotifier<Map<String, dynamic>>(
      _agent(
        _readiness(
          'blocked',
          'verification_required',
          extra: {
            'resource': {'kind': 'runtime', 'runtime': 'codex'},
          },
        ),
      ),
    );
    addTearDown(agent.dispose);
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = AgentPanelClient()..selectServer('s');
    final w = AgentPanelWorkspace(client);
    addTearDown(() async {
      w.dispose();
      await client.stream.close();
    });
    final pending = Completer<dynamic>();
    w.onCommand = (m, p, d) => pending.future;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: agent,
            builder: (_, row, _) => AgentDetailPanel(
              controller: w,
              agent: row,
              machines: agentPanelMachines,
              actions: const AgentDetailActions(),
              canManage: true,
              canViewPrivate: true,
              canControlRuntime: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(retry(), findsOneWidget);
    await tester.tap(retry());
    await tester.pump();
    expect(find.text('Restarting…'), findsOneWidget);
    // The restart clears the readiness: the server's list update arrives.
    pending.complete({});
    agent.value = _agent(null);
    await tester.pumpAndSettle();
    expect(detail(), findsNothing);
    expect(link(), findsNothing);
    expect(find.text('Account needs verification'), findsNothing);
    // Reopened with no readiness: nothing to show.
    expect(retry(), findsNothing);
  });

  testWidgets('a viewer who may not see details gets the title only', (
    tester,
  ) async {
    await pumpAgentPanel(
      tester,
      agent: _agent(
        _readiness(
          'blocked',
          'verification_required',
          extra: {
            'resource': {'kind': 'runtime', 'runtime': 'codex'},
          },
        ),
      ),
      canViewPrivate: false,
      canManage: false,
    );
    expect(chip(), findsOneWidget);
    expect(detail(), findsNothing);
    expect(link(), findsNothing);
    expect(retry(), findsNothing);
  });

  testWidgets('other codes: no link, no Retry', (tester) async {
    await pumpAgentPanel(
      tester,
      agent: _agent(_readiness('blocked', 'computer_too_old')),
    );
    expect(
      find.descendant(of: chip(), matching: find.text('Computer too old')),
      findsOneWidget,
    );
    expect(detail(), findsOneWidget);
    expect(link(), findsNothing);
    expect(retry(), findsNothing);
  });

  testWidgets('a restarting Computer says so on the agent', (tester) async {
    await pumpAgentPanel(
      tester,
      agent: _agent(_readiness('waiting', 'computer_restarting')),
    );
    expect(
      find.descendant(of: chip(), matching: find.text('Computer restarting')),
      findsOneWidget,
    );
  });

  testWidgets('a limit wait says when it is back', (tester) async {
    final until = DateTime.now()
        .add(const Duration(days: 6, hours: 2))
        .millisecondsSinceEpoch;
    await pumpAgentPanel(
      tester,
      agent: _agent(
        _readiness(
          'waiting',
          'rate_limited',
          scope: null,
          actor: null,
          extra: {'until': until},
        ),
      ),
    );
    expect(
      find.descendant(of: chip(), matching: find.text('Back in 6d')),
      findsOneWidget,
    );
  });

  testWidgets('an unknown code reads the generic sentence', (tester) async {
    await pumpAgentPanel(
      tester,
      agent: _agent(_readiness('blocked', 'something_new')),
    );
    expect(
      find.descendant(of: chip(), matching: find.text("Can't reply right now")),
      findsOneWidget,
    );
  });

  testWidgets('a Computer shown offline keeps its own chip', (tester) async {
    await pumpAgentPanel(
      tester,
      agent: _agent(_readiness('blocked', 'runtime_missing')),
      machines: const [
        {
          'id': 'm1',
          'name': 'Studio Mac',
          'status': 'offline',
          'isComputer': true,
        },
      ],
    );
    expect(
      find.descendant(of: chip(), matching: find.text('Computer offline')),
      findsOneWidget,
    );
    expect(detail(), findsNothing);
  });

  testWidgets('without readiness the old paths decide', (tester) async {
    await pumpAgentPanel(tester, agent: _agent(null));
    expect(detail(), findsNothing);
    expect(
      find.descendant(of: chip(), matching: find.text('Online')),
      findsOneWidget,
    );
  });

  for (final (name, platform, size) in [
    ('fold 856x944 (Android)', TargetPlatform.android, const Size(856, 944)),
    ('fold 944x856 (Android)', TargetPlatform.android, const Size(944, 856)),
    (
      'narrow desktop 390x844 (Linux)',
      TargetPlatform.linux,
      const Size(390, 844),
    ),
  ]) {
    testWidgets('Retry on a verification is a tap target on $name', (
      tester,
    ) async {
      final (w, _) = await pumpAgentPanel(
        tester,
        agent: _agent(
          _readiness(
            'blocked',
            'verification_required',
            extra: {
              'resource': {'kind': 'runtime', 'runtime': 'codex'},
            },
          ),
        ),
        platform: platform,
        size: size,
      );
      await tester.tap(retry());
      await tester.pump();
      expect(w.calls.last.$2, '/agents/a/reset');
      expect(
        RaftInteraction.of(tester.element(retry())).touch,
        platform == TargetPlatform.android,
      );
    });
  }
}
