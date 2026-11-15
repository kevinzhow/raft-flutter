// Web v1.24 features/agent/AgentStatusBadge.tsx: the tool-stuck notice sits
// under the status chip on the agent profile, its "Stop current turn" link is
// the only stop control (the overflow menu no longer has one), and it shows
// only while the agent is online and not blocked.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_flutter/features/agent_tool_stuck_notice.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;
import 'panel_revisit_cache_test.dart' show settle;

Map<String, dynamic> _stuck() => {
  'toolName': 'bash',
  'quietSinceMs': DateTime.now().millisecondsSinceEpoch - 4 * 60000,
  'thresholdMs': 180000,
  'queuedMessages': 2,
};

Map<String, dynamic> _agent({
  Map<String, dynamic>? toolStuck,
  String status = 'active',
  String? blockedReason,
}) => {
  'id': 'a1',
  'name': 'bot',
  'displayName': 'Bot',
  'status': status,
  'runtime': 'claude',
  'model': 'sonnet',
  'toolStuck': ?toolStuck,
  'blockedReason': ?blockedReason,
};

const _live = {'activity': 'working', 'detailKind': 'other', 'detail': ''};
const _notice = 'Stuck on bash';

Future<void> _pump(
  WidgetTester t,
  Map<String, dynamic> agent, {
  VoidCallback? onStop,
  Map<String, dynamic>? live = _live,
}) async {
  final (w, _) = (await t.runAsync(() => fixture('owner')))!;
  addTearDown(w.dispose);
  t.view.physicalSize = const Size(1280, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: AgentDetailPanel(
          controller: w,
          agent: agent,
          machines: const [],
          liveActivity: live,
          canManage: true,
          canViewPrivate: true,
          canControlRuntime: true,
          actions: AgentDetailActions(onStopHostedTurn: onStop),
        ),
      ),
    ),
  );
  await settle(t);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('shows under the status chip and its link stops the turn', (
    t,
  ) async {
    var stops = 0;
    await _pump(t, _agent(toolStuck: _stuck()), onStop: () => stops++);
    expect(find.textContaining(_notice), findsOneWidget);
    expect(find.byType(AgentToolStuckNotice), findsOneWidget);
    final chip = t.getRect(find.byKey(const ValueKey('agent-status-a1')));
    final notice = t.getRect(find.byType(AgentToolStuckNotice));
    expect(notice.top, greaterThanOrEqualTo(chip.bottom - 0.5));
    await t.tap(find.text('Stop current turn'));
    expect(stops, 1);
  });

  testWidgets('without a stop callback the notice has no link', (t) async {
    await _pump(t, _agent(toolStuck: _stuck()));
    expect(find.textContaining(_notice), findsOneWidget);
    expect(find.text('Stop current turn'), findsNothing);
  });

  testWidgets('absent when not stuck, offline or blocked', (t) async {
    await _pump(t, _agent(), onStop: () {});
    expect(find.byType(AgentToolStuckNotice), findsNothing);
    await _pump(
      t,
      _agent(toolStuck: _stuck(), status: 'offline'),
      onStop: () {},
      live: null,
    );
    expect(find.byType(AgentToolStuckNotice), findsNothing);
    await _pump(
      t,
      _agent(toolStuck: _stuck(), blockedReason: 'computer_access_revoked'),
      onStop: () {},
    );
    expect(find.byType(AgentToolStuckNotice), findsNothing);
  });

  testWidgets(
    'a live frame carrying toolStuck shows it, one without clears it',
    (t) async {
      await _pump(
        t,
        _agent(),
        onStop: () {},
        live: {..._live, 'toolStuck': _stuck()},
      );
      expect(find.textContaining(_notice), findsOneWidget);
      await _pump(
        t,
        _agent(toolStuck: _stuck()),
        onStop: () {},
        live: _live,
      );
      expect(find.textContaining(_notice), findsOneWidget);
      await _pump(
        t,
        _agent(toolStuck: _stuck()),
        onStop: () {},
        live: {..._live, 'toolStuck': null},
      );
      expect(find.byType(AgentToolStuckNotice), findsNothing);
    },
  );

  testWidgets('the overflow menu no longer offers Stop current turn', (
    t,
  ) async {
    await _pump(t, _agent(toolStuck: _stuck()), onStop: () {});
    expect(
      find.byKey(const Key('agent-profile-inline-stop-hosted-turn')),
      findsNothing,
    );
    final more = find.byKey(const Key('agent-profile-more'));
    if (more.evaluate().isNotEmpty) {
      await t.tap(more);
      await t.pumpAndSettle();
    }
    // Only the notice's own link carries the words.
    expect(find.text('Stop current turn'), findsOneWidget);
  });
}
