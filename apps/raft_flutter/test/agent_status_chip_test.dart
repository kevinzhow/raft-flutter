// The profile header's status chip (Web v1.24.0 AgentStatusBadge.tsx), through
// the real AgentDetailPanel.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/agent_panel_fixture.dart';

Finder chip() => find.byKey(const ValueKey('agent-status-chip'));
Finder chipText(String text) =>
    find.descendant(of: chip(), matching: find.text(text));
Finder retry() => find.byKey(const ValueKey('agent-status-retry'));
Finder changeModel() => find.byKey(const ValueKey('agent-status-change-model'));

const _holdDetail =
    'Codex CLI is not logged in on this computer. Sign in again, then restart the agent.';

Map<String, dynamic> _held({Map<String, dynamic> extra = const {}}) => {
  ...agentPanelAgent,
  'activity': 'online',
  'activityDetail': _holdDetail,
  'activityDetailKind': 'idle',
  'credentialHold': {'reason': 'user_reauth'},
  ...extra,
};

void main() {
  testWidgets('a Computer that is too old: the chip opens that Computer', (
    tester,
  ) async {
    final opened = <String>[];
    await pumpAgentPanel(
      tester,
      agent: {...agentPanelAgent, 'blockedReason': 'computer_version_unknown'},
      actions: AgentDetailActions(onOpenComputer: opened.add),
    );
    expect(chipText('Computer update required'), findsOneWidget);
    await tester.tap(chip());
    await tester.pump();
    expect(opened, ['m1']);
    expect(retry(), findsNothing);
  });

  testWidgets('an offline Computer reads Computer offline and opens it', (
    tester,
  ) async {
    final opened = <String>[];
    await pumpAgentPanel(
      tester,
      agent: {...agentPanelAgent, 'activity': 'online'},
      machines: const [
        {
          'id': 'm1',
          'name': 'Studio Mac',
          'status': 'offline',
          'isComputer': true,
        },
      ],
      actions: AgentDetailActions(onOpenComputer: opened.add),
    );
    expect(chipText('Computer offline'), findsOneWidget);
    await tester.tap(chip());
    expect(opened, ['m1']);
  });

  testWidgets('revoked access reads as a sentence and is not a button', (
    tester,
  ) async {
    final opened = <String>[];
    await pumpAgentPanel(
      tester,
      agent: {...agentPanelAgent, 'blockedReason': 'computer_access_revoked'},
      actions: AgentDetailActions(onOpenComputer: opened.add),
      size: const Size(390, 844),
    );
    expect(
      find.textContaining('Computer access revoked: move the agent'),
      findsOneWidget,
    );
    await tester.tap(chip());
    expect(opened, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no activity state on an active agent reads Likely online', (
    tester,
  ) async {
    final row = {...agentPanelAgent}..remove('activity');
    await pumpAgentPanel(tester, agent: row);
    expect(chipText('Likely online'), findsOneWidget);
    expect(retry(), findsNothing);
  });

  testWidgets('held for another agent: the reason, and Retry restarts', (
    tester,
  ) async {
    final (w, _) = await pumpAgentPanel(tester, agent: _held());
    expect(chipText('Sign-in needed for Codex CLI'), findsOneWidget);
    final pending = Completer<dynamic>();
    w.onCommand = (m, p, d) => pending.future;
    await tester.tap(retry());
    await tester.pump();
    expect(w.calls.last.$1, 'POST');
    expect(w.calls.last.$2, '/agents/a/reset');
    expect(w.calls.last.$3, {'mode': 'restart'});
    // "Restarting…" and the link is spent while the request runs.
    expect(find.text('Restarting…'), findsOneWidget);
    expect(retry(), findsOneWidget);
    await tester.tap(retry());
    await tester.pump();
    expect(w.calls.where((c) => c.$2 == '/agents/a/reset'), hasLength(1));
    pending.complete({});
    await tester.pump();
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a failed restart says so in a toast and offers Retry again', (
    tester,
  ) async {
    final (w, _) = await pumpAgentPanel(
      tester,
      agent: _held(),
      toastHost: true,
    );
    w.onCommand = (m, p, d) async => throw StateError('no');
    await tester.tap(retry());
    await tester.pump();
    await tester.pump();
    expect(find.text('Failed to reset agent'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Retry is not offered while the Computer is offline', (
    tester,
  ) async {
    await pumpAgentPanel(
      tester,
      agent: _held(),
      machines: const [
        {
          'id': 'm1',
          'name': 'Studio Mac',
          'status': 'offline',
          'isComputer': true,
        },
      ],
    );
    expect(retry(), findsNothing);
  });

  testWidgets('member view: a generic Error with Retry, no reason', (
    tester,
  ) async {
    await pumpAgentPanel(
      tester,
      agent: _held(),
      canManage: false,
      canViewPrivate: false,
      canControlRuntime: true,
    );
    expect(chipText('Sign-in needed for Codex CLI'), findsNothing);
    expect(chipText('Error'), findsOneWidget);
    expect(retry(), findsOneWidget);
  });

  testWidgets('the error code is the chip title for a viewer without detail', (
    tester,
  ) async {
    await pumpAgentPanel(
      tester,
      agent: {
        ...agentPanelAgent,
        'activity': 'error',
        'activityDetailKind': 'runtime_error',
        'activityDetail': 'Agent encountered an error',
        'activityErrorCode': 'usage_limit',
      },
      canManage: false,
      canViewPrivate: false,
    );
    expect(chipText('Usage limit reached'), findsOneWidget);
  });

  testWidgets('Change model opens the runtime editor action', (tester) async {
    var edits = 0;
    await pumpAgentPanel(
      tester,
      agent: {
        ...agentPanelAgent,
        'activity': 'offline',
        'activityDetailKind': 'runtime_unavailable',
        'activityDetail': 'daemon text',
        'spawnFailure': {
          'reason': 'model_unsupported',
          'model': 'gpt-x',
          'autoRestartPaused': true,
        },
      },
      actions: AgentDetailActions(onEditRuntime: () => edits++),
    );
    expect(find.textContaining('''doesn't include "gpt-x"'''), findsWidgets);
    await tester.tap(changeModel());
    expect(edits, 1);
    expect(retry(), findsOneWidget);
  });

  testWidgets('delivery_unconsumed shows its counts after the chip', (
    tester,
  ) async {
    await pumpAgentPanel(
      tester,
      agent: {
        ...agentPanelAgent,
        'activity': 'working',
        'activityDetailKind': 'delivery_unconsumed',
        'activityDetail': '',
        'deliveryConsumption': {
          'unconsumedDeliveries': 3,
          'episode': 2,
          'lastDeliveryPath': 'stdin_idle_delivery',
        },
      },
    );
    expect(
      chipText('Messages delivered, runtime not responding'),
      findsOneWidget,
    );
    expect(
      find.text(
        '3 deliveries written since the runtime last responded (episode 2, last via stdin_idle_delivery)',
      ),
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
    testWidgets('Retry is a tap target on $name', (tester) async {
      final (w, _) = await pumpAgentPanel(
        tester,
        agent: _held(),
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
