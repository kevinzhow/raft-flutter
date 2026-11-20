import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/external_identity.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('shows the verified bot identity and its source', (tester) async {
    final controller = WorkspaceController(
      RaftClient(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      ),
    );
    addTearDown(controller.dispose);
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ExternalIdentityDetailPanel(
            controller: controller,
            profile: const {
              'actorKind': 'bot',
              'provider': 'slack',
              'displayName': 'Deploy hook',
              'profileDisplayName': 'Deployments',
              'profileAvatarUrl': null,
              'appName': 'Build Desk',
              'workspaceName': 'Engineering',
              'avatarUrl': '/api/external-avatars/original.webp',
            },
            onClose: () => closed = true,
          ),
        ),
      ),
    );

    expect(find.text('Deployments'), findsNWidgets(2));
    expect(find.text('Posted as Deploy hook'), findsOneWidget);
    expect(find.text('From Slack · Build Desk'), findsOneWidget);
    expect(find.text('Slack · Bot'), findsNothing);
    expect(find.text('Engineering'), findsNothing);
    for (final avatar in tester.widgetList<RaftAvatarContent>(
      find.byType(RaftAvatarContent),
    )) {
      expect(avatar.name, 'Deployments');
      expect(avatar.uploadedUrl, isNull);
    }
    await tester.tap(find.bySemanticsLabel('Close'));
    expect(closed, isTrue);
  });
}
