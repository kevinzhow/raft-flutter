// Web v1.24 features/agent/AgentRecentActivity.tsx: the profile's "Recent
// activity" card holds the status chip (Retry, Change model, the tool-stuck
// notice), the agent's last three turns one line each, and a heading that opens
// the Activity tab; without an Activity tab the chip stays under the handle.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/agent_overview_fixture.dart';
import 'support/agent_panel_fixture.dart';

const _holdDetail =
    'Codex CLI is not logged in on this computer. Sign in again, then restart the agent.';

final _held = {
  ...agentPanelAgent,
  'activity': 'online',
  'activityDetail': _holdDetail,
  'activityDetailKind': 'idle',
  'credentialHold': {'reason': 'user_reauth'},
};

Finder card() => find.byKey(const ValueKey('agent-now-card'));
Finder inCard(Finder f) => find.descendant(of: card(), matching: f);

List<Map<String, dynamic>> _four() => [
  turnJson(
    't4',
    minutes: 90,
    reply: 'm4',
    actions: [
      {'kind': 'run_command', 'count': 3},
    ],
    trigger: {
      'display': {'kind': 'dm', 'senderName': 'xxchan'},
    },
  ),
  turnJson('t3', minutes: 60, outcome: 'failed', reply: 'm3'),
  turnJson('t2', minutes: 30, outcome: 'interrupted'),
  turnJson('t1', minutes: 0, reply: 'm1'),
];

void main() {
  testWidgets(
    'the status chip, Retry and the stuck notice live in the Recent activity card',
    (tester) async {
      await pumpAgentPanel(
        tester,
        agent: _held,
        queryRoutes: summaryRoutes(() => [_four()]),
      );
      expect(card(), findsOneWidget);
      expect(inCard(find.text('Recent activity')), findsOneWidget);
      expect(
        inCard(find.byKey(const ValueKey('agent-status-chip'))),
        findsOneWidget,
      );
      expect(
        inCard(find.byKey(const ValueKey('agent-status-retry'))),
        findsOneWidget,
      );
      // Not under the handle any more.
      expect(
        find.descendant(
          of: find.byType(RaftProfileIdentity),
          matching: find.byKey(const ValueKey('agent-status-chip')),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'it lists the last three finished turns one line each, with their badges',
    (tester) async {
      await pumpAgentPanel(
        tester,
        agent: {...agentPanelAgent, 'activity': 'online'},
        queryRoutes: summaryRoutes(() => [_four()]),
      );
      // The newest is the card's own "Last turn" line, not a row; three follow.
      expect(find.byKey(const ValueKey('agent-now-row-t4')), findsNothing);
      for (final id in ['t3', 't2', 't1']) {
        expect(find.byKey(ValueKey('agent-now-row-$id')), findsOneWidget);
      }
      expect(find.textContaining('Last turn: @xxchan'), findsNothing);
      expect(find.textContaining('Last turn: DM from @xxchan'), findsOneWidget);
      expect(inCard(find.text('Ended with an error')), findsOneWidget);
      expect(inCard(find.text('Stopped')), findsOneWidget);
      // t2 sent nothing; t3 and t1 did.
      expect(inCard(find.text('No message sent')), findsOneWidget);
    },
  );

  testWidgets('the heading opens the Activity tab', (tester) async {
    await pumpAgentPanel(tester, queryRoutes: summaryRoutes(() => [_four()]));
    expect(find.byKey(const ValueKey('activity-overview')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('agent-now-open-activity')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('activity-overview')), findsOneWidget);
    expect(card(), findsOneWidget);
  });

  testWidgets(
    'a viewer with no Activity tab keeps the chip under the handle, with no card',
    (tester) async {
      await pumpAgentPanel(
        tester,
        agent: _held,
        canManage: false,
        canViewPrivate: false,
        queryRoutes: summaryRoutes(() => [_four()]),
      );
      expect(card(), findsNothing);
      expect(
        find.descendant(
          of: find.byType(RaftProfileIdentity),
          matching: find.byKey(const ValueKey('agent-status-chip')),
        ),
        findsOneWidget,
      );
      expect(
        tester.widgetList(find.byKey(const ValueKey('agent-status-retry'))),
        isEmpty,
      );
    },
  );

  testWidgets('an archived agent has no card either', (tester) async {
    await pumpAgentPanel(
      tester,
      agent: {...agentPanelAgent, 'deletedAt': '2026-10-01T00:00:00.000Z'},
      queryRoutes: summaryRoutes(() => [_four()]),
    );
    expect(card(), findsNothing);
  });

  testWidgets('the card shows from the start: the status needs no turns', (
    tester,
  ) async {
    await pumpAgentPanel(
      tester,
      agent: _held,
      queryRoutes: {
        '/agents/a/activity-summaries': (_) async {
          await Future<void>.delayed(const Duration(seconds: 5));
          return {'summaries': _four()};
        },
      },
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      inCard(find.byKey(const ValueKey('agent-status-chip'))),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('agent-now-row-t3')), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    expect(find.byKey(const ValueKey('agent-now-row-t3')), findsOneWidget);
  });

  testWidgets(
    'a revisit shows the last turns at the first frame, then refreshes',
    (tester) async {
      final (w, _) = await pumpAgentPanel(
        tester,
        queryRoutes: summaryRoutes(() => [_four()]),
      );
      expect(find.byKey(const ValueKey('agent-now-row-t3')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      w.queryRoutes['/agents/a/activity-summaries'] = (_) async {
        await Future<void>.delayed(const Duration(seconds: 5));
        return {'summaries': _four()};
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: AgentDetailPanel(
              controller: w,
              agent: agentPanelAgent,
              machines: agentPanelMachines,
              actions: const AgentDetailActions(),
              initialTab: AgentDetailTab.profile,
              canManage: true,
              canViewPrivate: true,
              canControlRuntime: true,
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('agent-now-row-t3')), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    },
  );

  testWidgets('it follows the agent: a status push reloads the turns', (
    tester,
  ) async {
    var pages = [_four().sublist(1)];
    final (_, client) = await pumpAgentPanel(
      tester,
      queryRoutes: summaryRoutes(() => pages),
    );
    expect(find.byKey(const ValueKey('agent-now-row-t1')), findsOneWidget);
    pages = [_four()];
    client.stream.add(const RaftEvent('agent:activity', {'agentId': 'a'}));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.textContaining('Last turn: DM from @xxchan'), findsOneWidget);
  });
}
