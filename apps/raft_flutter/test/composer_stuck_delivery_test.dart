import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/pending_mention_actions.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  testWidgets(
    'a stuck delivery receipt shows a distinct dismissible DM warning',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.channel = RaftChannel({
        'id': 'c1',
        'name': 'Agent',
        'type': 'dm',
        'joined': true,
      });
      w.messageDomain.ledger.switchServer('s1');
      a.routes['POST /v2/messages'] = (_) => {
        'message': {
          'id': 'sent',
          'channelId': 'c1',
          'seq': 1,
          'content': 'Body',
        },
        'deliveryWarnings': [
          {
            'targetType': 'agent',
            'targetId': 'agent-1',
            'reason': 'agent_stuck_on_tool',
          },
        ],
      };
      a.routes['GET /attachments/upload-sessions/c1/active'] = (_) => {
        'uploads': [],
      };
      expect(await tester.runAsync(() => w.send('Body')), isTrue);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: ListenableBuilder(
              listenable: w,
              builder: (context, _) =>
                  raftComposerAccessory(context, w) ?? const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final message = find.textContaining('stuck on a command with no output');
      expect(message, findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Dismiss Delivery Warning'));
      await tester.pumpAndSettle();
      expect(message, findsNothing);
    },
  );
}
