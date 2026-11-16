// The Activity tab's task refs in the real app host: `AgentDetailPanel` passes
// the task opener to the pane, so a pill (`#channel:#7`) opens that task like a
// task reference in a message (Web RefText -> useRefNavigation().openTask).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';

import 'support/agent_panel_fixture.dart';

final _t0 = DateTime.utc(2026, 11, 14, 9, 0).millisecondsSinceEpoch;

List<Map<String, dynamic>> _log() => [
  {
    'timestamp': _t0,
    'entry': {
      'kind': 'system',
      'title': 'Note',
      'text': 'Picked up #general:#7 now',
    },
  },
];

void main() {
  for (final (label, size, platform) in [
    ('fold 856x944', const Size(856, 944), TargetPlatform.android),
    ('fold 944x856', const Size(944, 856), TargetPlatform.android),
    ('narrow desktop 390x844', const Size(390, 844), TargetPlatform.linux),
  ]) {
    testWidgets('a task pill in the raw log opens that task ($label)', (
      tester,
    ) async {
      final (w, _) = await pumpAgentPanel(
        tester,
        tab: AgentDetailTab.activity,
        size: size,
        platform: platform,
        routes: {
          '/agents/a/activity-log': _log,
          '/tasks/channel/c-general/number/7': () => {
            'task': {
              'id': 't7',
              'channelId': 'c-general',
              'number': 7,
              'messageId': 'm7',
              'title': 'Seven',
            },
          },
        },
      );
      w.channels = [
        RaftChannel({'id': 'c-general', 'type': 'channel', 'name': 'general'}),
      ];
      await tester.tap(find.byKey(const ValueKey('activity-view-raw')));
      await tester.pumpAndSettle();
      final pill = find.text('#general:#7');
      expect(pill, findsOneWidget);
      expect(w.location.task, isNull);
      await tester.tap(pill);
      await tester.pumpAndSettle();
      expect(
        w.queries.map((q) => q.$1),
        contains('/tasks/channel/c-general/number/7'),
      );
      expect('${w.location.task}', 'c-general:m7');
    });
  }
}
