import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/pending_mention_actions.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/thread_composer/fake_workspace.dart';

void main() {
  for (final (size, platform) in [
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
    (const Size(390, 844), TargetPlatform.linux),
  ]) {
    testWidgets('Lounge explains and dismisses a read-only mention at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = ParityFakeClient(
        user: {'id': 'reader'},
        routes: {
          'POST /v2/messages': {
            'message': {
              'id': 'sent',
              'channelId': 'lounge',
              'seq': '1',
              'messageType': 'chat',
              'senderType': 'user',
              'senderId': 'reader',
              'content': 'Hello @helper',
              'createdAt': '2026-11-22T00:00:00Z',
            },
            'pendingMentionActions': [
              {
                'resolutionId': 'excluded',
                'targetType': 'agent',
                'targetHandle': 'helper',
                'reason': 'lounge_agent_excluded',
                'availableActions': ['add', 'notify'],
              },
            ],
          },
        },
      );
      final workspace = WorkspaceController(client)
        ..server = RaftRecord({'id': 'visual-server'})
        ..channel = RaftChannel({
          'id': 'lounge',
          'name': 'Lounge',
          'type': 'dm',
        });
      addTearDown(() async {
        workspace.dispose();
        await client.stream.close();
        await client.dispose();
      });
      final host = MaterialApp(
        theme: raftTheme().copyWith(platform: platform),
        home: Scaffold(body: PendingMentionActions(controller: workspace)),
      );
      final strip = find.byType(RaftPendingMentionActionStrip);
      final status = find.text(
        "@helper won't be notified: other agents can only read this chat.",
      );
      await tester.pumpWidget(host);
      expect(strip, findsNothing);

      try {
        expect(await workspace.send('Hello @helper'), isTrue);
        await tester.pump();
        expect(status, findsOneWidget);
        expect(find.text('Add'), findsNothing);
        expect(find.text('Notify'), findsNothing);
        await tester.tap(find.text('Ignore'));
        await tester.pump();
        expect(strip, findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(host);
        expect(strip, findsNothing);
        expect(
          client.requests,
          isNot(contains('POST /messages/mention-actions/execute')),
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    });
  }
}
