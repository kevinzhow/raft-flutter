import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';

import 'message_context_transition_test.dart' show row;
import 'task_content_slot_test.dart' show v2Task;
import 'task_surface_test.dart' show taskRoutes;
import 'workspace_source_location_contract_test.dart'
    show mountPage, pageFixture, waitForPainted;

void main() {
  testWidgets(
    'A task location loads its reply from the local joint projection',
    (t) async {
      final (w, api) = await pageFixture(t, section: 'search');
      final task = {
        ...v2Task,
        'channelType': 'joint',
        'conversationChannelId': 'task-canonical',
      };
      taskRoutes(api, task);
      api.routes['GET /tasks/channel/c1'] = (_) => {
        'tasks': [task],
      };
      api.routes['POST /tasks/task-1/conversation'] = (_) => {
        'conversationChannelId': 'task-local',
        'canonicalConversationChannelId': 'task-canonical',
        'created': false,
      };
      api.routes['GET /messages/channel/task-local'] = (_) => {'messages': []};
      api.routes['GET /messages/context/focused-reply'] = (call) => {
        'messages': [
          row('focused-reply', call.queryParameters['channelId'] as String, 7),
        ],
      };
      w.navigation.navigate(
        RaftLocation.parse(
          '/s/demo/search?open=task:task-1&task=c1:task:task-1&taskMsg=task-1:focused-reply',
        ),
        kind: RaftNavigationKind.replace,
      );
      await mountPage(t, w, false);
      await waitForPainted(t, 'focused-reply');
      final context = api.calls.singleWhere(
        (call) => call.path == '/messages/context/focused-reply',
      );
      expect(context.queryParameters['channelId'], 'task-local');
      await t.tap(find.byKey(const ValueKey('task-modal-close')));
      await t.pumpAndSettle();
      expect(w.location.query('task'), isNull);
      expect(w.location.query('taskMsg'), isNull);
    },
  );
}
