// Mounts the Activity overview, the Now card and the profile's Recent
// activity card against a fixture workspace whose reads answer from routes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/agent_activity_overview.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'agent_panel_fixture.dart';

final turnsT0 = DateTime.utc(2026, 10, 24, 2, 0).millisecondsSinceEpoch;

/// The wall clock the cards read: ten minutes after the newest turn of the
/// default fixture, the same UTC day.
DateTime fixtureNow() =>
    DateTime.fromMillisecondsSinceEpoch(turnsT0 + 600 * 60000, isUtc: true);

/// One `ActivityTurnSummary` as the server returns it.
Map<String, dynamic> turnJson(
  String id, {
  int minutes = 0,
  int lengthMinutes = 4,
  String outcome = 'completed',
  int toolCalls = 3,
  int sent = 1,
  String? reply,
  Object? trigger,
  List<Map<String, dynamic>> actions = const [],
  List<Map<String, dynamic>> problems = const [],
  int? problemCount,
  String? lastText,
  Map<String, dynamic>? usageLimit,
  List<String> sentMessageIds = const [],
}) => {
  'id': id,
  'startedAt': turnsT0 + minutes * 60000,
  'endedAt': turnsT0 + (minutes + lengthMinutes) * 60000,
  'outcome': outcome,
  'problemCount': problemCount ?? problems.length,
  'problems': problems,
  'actions': actions,
  'toolCalls': toolCalls,
  'messagesSent': sent,
  'trigger': ?trigger,
  'lastReplyMessageId': ?reply,
  'lastText': ?lastText,
  'usageLimit': ?usageLimit,
  if (sentMessageIds.isNotEmpty) 'sentMessageIds': sentMessageIds,
};

/// `GET /agents/a/activity-summaries`, one page per entry (newest page first),
/// `next` naming the following page; [current] is the running turn.
Map<String, Object? Function(Map<String, dynamic>? q)> summaryRoutes(
  List<List<Map<String, dynamic>>> Function() pages, {
  Map<String, dynamic>? Function()? current,
  Object? Function(Map<String, dynamic>? q)? onOperatorEvents,
}) => {
  '/agents/a/activity-summaries': (q) {
    final all = pages();
    final index = q?['before'] == null ? 0 : int.parse('${q!['before']}');
    final running = index == 0 ? current?.call() : null;
    return {
      'summaries': all[index],
      if (index + 1 < all.length) 'next': '${index + 1}',
      'current': ?running,
    };
  },
  '/agents/a/operator-events': ?onOperatorEvents,
};

class OverviewHarness {
  OverviewHarness(this.w, this.client);
  final AgentPanelWorkspace w;
  final AgentPanelClient client;
}

/// A workspace whose reads answer from [queryRoutes] (others answer `[]`).
Future<OverviewHarness> overviewWorkspace(
  WidgetTester tester, {
  Map<String, Object? Function(Map<String, dynamic>? q)> queryRoutes = const {},
  Size size = const Size(420, 700),
  TargetPlatform platform = TargetPlatform.android,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final client = AgentPanelClient()..selectServer('s');
  final w = AgentPanelWorkspace(client, queryRoutes: queryRoutes)
    ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
  addTearDown(() async {
    w.dispose();
    await client.stream.close();
  });
  return OverviewHarness(w, client);
}

Future<void> pumpOverview(
  WidgetTester tester,
  OverviewHarness h, {
  String activity = 'online',
  String activityText = 'Online',
  bool hasRaw = true,
  bool settle = true,
  String? machineId = 'm1',
  DateTime Function()? clock,
  Widget Function(Widget child)? wrap,
}) async {
  final overview = AgentActivityOverview(
    key: const ValueKey('agent-overview-a'),
    controller: h.w,
    agentId: 'a',
    machineId: machineId,
    activity: activity,
    activityText: activityText,
    hasRawActivity: hasRaw,
    onShowRaw: () {},
    onOpenComputer: (_) {},
    clock: clock ?? fixtureNow,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: TargetPlatform.android),
      home: Scaffold(body: wrap == null ? overview : wrap(overview)),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Scrolls the overview's scroller to the very top (the oldest turn).
Future<void> scrollOverviewToTop(WidgetTester tester) async {
  final scroller = find.byKey(const ValueKey('activity-overview-scroll'));
  for (var i = 0; i < 8; i++) {
    await tester.drag(scroller, const Offset(0, 1500));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Pushes a status frame without trajectory entries for agent `a`.
void pushActivityFrame(OverviewHarness h, {Map<String, dynamic>? extra}) {
  h.client.stream.add(RaftEvent('agent:activity', {'agentId': 'a', ...?extra}));
}

double turnTop(WidgetTester tester, String id) =>
    tester.getTopLeft(find.byKey(ValueKey('turn-$id'))).dy;
