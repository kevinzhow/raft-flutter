import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_forward_dialog.dart';
import 'package:raft_flutter/features/artifacts/artifact_manage_dialogs.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_sharing_api.dart';
import 'package:raft_ui/raft_ui.dart';

import '../support/artifact_fake_client.dart';

void main() {
  testWidgets('Chinese visibility uses the Web conversation fallback', (
    tester,
  ) async {
    final client = ArtifactFakeClient();
    addTearDown(client.dispose);
    final data = ArtifactViewerData.fromJson({
      ...artifactViewerJson(),
      'card': {
        ...artifactCardJson(),
        'home': {'kind': 'public'},
      },
      'originalHome': {'conversationId': 'source'},
      'capabilities': {'narrowHome': true},
    })!;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: raftTheme(),
        home: Scaffold(
          body: ArtifactManageDialog(
            api: ArtifactSharingApi(client),
            data: data,
            action: ArtifactManageAction.visibility,
            current: () => true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('某个会话'), findsOneWidget);
  });

  testWidgets('forward retry clears the error and keeps the same client key', (
    tester,
  ) async {
    final client = ArtifactFakeClient();
    final workspace = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'})
      ..channels = [
        RaftChannel({'id': 'c2', 'name': 'destination', 'joined': true}),
      ];
    addTearDown(workspace.dispose);
    addTearDown(client.ingress.close);
    final card = ArtifactViewerData.fromJson(artifactViewerJson())!.card;
    const audience =
        'GET /artifacts/$artifactId/share-audience?conversationId=c2';
    const send = 'POST /artifacts/$artifactId/share';
    client.answers[audience] = (_) => {'cannotSee': 0};
    final keys = <String>[];
    client.answers[send] = (body) {
      keys.add((body as Map)['clientKey'] as String);
      if (keys.length == 1) return const RaftApiException('Temporary failure');
      return {'messageId': 'm1'};
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: RaftButton(
              label: 'Forward',
              onPressed: () => unawaited(
                showArtifactForwardDialog(
                  context,
                  workspace: workspace,
                  card: card,
                  current: () => true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Forward'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('destination'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't send it. Try again."), findsOneWidget);
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.byType(ArtifactForwardDialog), findsNothing);
    expect(find.text("Couldn't send it. Try again."), findsNothing);
    expect(client.requests, [audience, send, send]);
    expect(keys, [keys.first, keys.first]);
  });

  testWidgets('widen to server applies without another confirmation', (
    tester,
  ) async {
    final client = ArtifactFakeClient();
    addTearDown(client.ingress.close);
    final data = ArtifactViewerData.fromJson({
      ...artifactViewerJson(),
      'capabilities': {'changeHome': true},
    })!;
    const move = 'POST /artifacts/$artifactId/home';
    client.answers[move] = (_) => {
      'card': {
        ...artifactCardJson(),
        'home': {'kind': 'server'},
      },
    };
    ArtifactViewerData? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: RaftButton(
              label: 'Visibility',
              onPressed: () => unawaited(
                showArtifactManageDialog(
                  context,
                  api: ArtifactSharingApi(client),
                  data: data,
                  action: ArtifactManageAction.visibility,
                  current: () => true,
                ).then((value) => result = value),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Visibility'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Everyone in this server'));
    await tester.pumpAndSettle();
    expect(client.requests, [move]);
    expect(client.bodies[move], {'to': 'server'});
    expect(result?.card.home.kind, 'server');
    expect(find.byType(ArtifactManageDialog), findsNothing);
  });

  test(
    'rename and unpublish accept the returned card without reading it',
    () async {
      final client = ArtifactFakeClient();
      addTearDown(client.ingress.close);
      client.answers['PATCH /artifacts/$artifactId/title'] = (_) => {
        'card': {'id': artifactId, 'title': 'New title'},
      };
      client.answers['POST /artifacts/$artifactId/unpublish'] = (_) => {
        'card': {
          'id': artifactId,
          'title': 'New title',
          'home': {'kind': 'server'},
        },
      };
      final api = ArtifactSharingApi(client);
      expect(
        (await api.rename(artifactId, 'New title')).card.title,
        'New title',
      );
      expect((await api.unpublish(artifactId)).card.home.kind, 'server');
      expect(client.requests, [
        'PATCH /artifacts/$artifactId/title',
        'POST /artifacts/$artifactId/unpublish',
      ]);
    },
  );

  testWidgets(
    'turning off link sharing previews loss when narrowing is allowed',
    (tester) async {
      final client = ArtifactFakeClient();
      addTearDown(client.ingress.close);
      final data = ArtifactViewerData.fromJson({
        ...artifactViewerJson(),
        'card': {
          ...artifactCardJson(),
          'home': {'kind': 'public'},
        },
        'capabilities': {'narrowHome': true, 'unpublish': true},
      })!;
      const preview = 'GET /artifacts/$artifactId/home-change?to=server';
      const move = 'POST /artifacts/$artifactId/home';
      client.answers[preview] = (_) => {
        'peopleLosingAccess': 2,
        'agentsLosingAccess': 1,
        'leavesPublic': true,
      };
      client.answers[move] = (_) => {
        'card': {
          ...artifactCardJson(),
          'home': {'kind': 'server'},
        },
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: ArtifactManageDialog(
              api: ArtifactSharingApi(client),
              data: data,
              action: ArtifactManageAction.visibility,
              current: () => true,
            ),
          ),
        ),
      );
      try {
        await tester.tap(find.text('Everyone in this server'));
        await tester.pumpAndSettle();
        expect(
          find.text('2 people and 1 agents will lose access.'),
          findsOneWidget,
        );
        expect(client.requests, [preview]);
        await tester.tap(find.text('Turn off link sharing'));
        await tester.pumpAndSettle();
        expect(client.requests, [preview, move]);
        expect(client.bodies[move], {'to': 'server', 'expectedLost': 3});
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  test('narrowing confirms the sum of the displayed loss counts', () async {
    final client = ArtifactFakeClient();
    addTearDown(client.ingress.close);
    const preview =
        'GET /artifacts/$artifactId/home-change?to=conversation&conversationId=c1';
    client.answers[preview] = (_) => {
      'peopleLosingAccess': 2,
      'agentsLosingAccess': 3,
      'leavesPublic': true,
    };
    client.answers['POST /artifacts/$artifactId/home'] = (_) => {
      'card': {
        'id': artifactId,
        'home': {
          'kind': 'conversation',
          'conversation': {'id': 'c1'},
        },
      },
    };
    final api = ArtifactSharingApi(client);
    const target = ArtifactHomeTarget.conversation('c1');
    final loss = await api.preview(artifactId, target);
    expect(loss.leavesPublic, isTrue);
    await api.move(artifactId, target, loss: loss);
    expect(client.bodies['POST /artifacts/$artifactId/home'], {
      'to': 'conversation',
      'conversationId': 'c1',
      'expectedLost': 5,
    });
  });

  test('forward posts the link through the Artifact share contract', () async {
    final client = ArtifactFakeClient();
    addTearDown(client.ingress.close);
    final send = 'POST /artifacts/$artifactId/share';
    client.answers[send] = (_) => {'messageId': 'm1', 'home': null};
    final result = await ArtifactSharingApi(client).share(
      artifactId,
      conversation: 'c2',
      note: 'Read this',
      widenTo: null,
      clientKey: 'attempt-1',
    );
    expect(result.messageId, 'm1');
    expect(client.bodies[send], {
      'conversationId': 'c2',
      'threadRootId': null,
      'note': 'Read this',
      'widenTo': null,
      'clientKey': 'attempt-1',
    });
  });
}
