import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_ui/raft_ui.dart';

import '../support/artifact_fake_client.dart';

const _path = '/artifacts/$artifactId/comments';

Map<String, Object?> comment(
  String id,
  String text, {
  String? replyTo,
  bool resolved = false,
}) => {
  'id': id,
  'createdAt': '2026-11-19T03:00:00Z',
  'resolvedAt': resolved ? '2026-11-19T03:00:01Z' : null,
  'author': artifactActor(),
  'body': [
    {'type': 'text', 'text': text},
  ],
  'target': {'scope': 'artifact'},
  'version': 1,
  'replyTo': replyTo,
};

void main() {
  late ArtifactFakeClient client;
  late WorkspaceController workspace;
  late List<Map<String, Object?>> comments;

  setUp(() {
    comments = [comment('root', 'Initial comment')];
    client = ArtifactFakeClient();
    workspace = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'});
    client.answers['GET /artifacts/$artifactId'] = (_) => {
      ...artifactViewerJson(),
      'capabilities': {'comment': true, 'delete': true},
    };
    client.answers['GET $_path'] = (_) => {
      'comments': comments,
      'olderCursor': null,
    };
  });

  tearDown(() async {
    workspace.dispose();
    await client.dispose();
  });

  Future<void> open(
    WidgetTester tester,
    Size size,
    TargetPlatform platform,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: platform),
        home: Scaffold(
          body: ArtifactWorkspaceViewer(
            session: ArtifactSession.of(workspace),
            target: const ArtifactLinkTarget(artifactId),
            page: size.width < 768,
            onClose: () {},
            operatingSystem: 'linux',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final openComments = find.byKey(const ValueKey('artifact-comments-trigger'));
  final composer = find.byKey(const ValueKey('artifact-comment-input'));
  final send = find.byKey(const ValueKey('artifact-comment-send'));

  for (final (size, platform) in [
    (const Size(390, 844), TargetPlatform.linux),
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
  ]) {
    testWidgets('opens, replies and closes on ${size.width} × ${size.height}', (
      tester,
    ) async {
      client.answers['POST $_path'] = (_) => {
        'comment': comment('reply', 'My reply', replyTo: 'root'),
        'notified': [],
      };
      await open(tester, size, platform);
      await tester.tap(openComments);
      await tester.pumpAndSettle();
      expect(find.text('Initial comment'), findsOneWidget);
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();
      await tester.enterText(composer, 'My reply');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.text('My reply'), findsOneWidget);
      expect(client.bodies['POST $_path'], containsPair('replyTo', 'root'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('My reply'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('applies peer activity and resolves or reopens a thread', (
    tester,
  ) async {
    client.answers['POST $_path/root/resolve'] = (_) => {
      'comment': comment('root', 'Initial comment', resolved: true),
      'note': null,
      'changed': true,
    };
    client.answers['POST $_path/root/reopen'] = (_) => {
      'comment': comments.first,
      'note': null,
      'changed': true,
    };
    await open(tester, const Size(1200, 850), TargetPlatform.linux);
    await tester.tap(openComments);
    await tester.pumpAndSettle();
    comments = [...comments, comment('peer', 'Peer reply', replyTo: 'root')];
    client.ingress.add(RaftEvent('activity:changed', {'serverId': 's1'}));
    await tester.pumpAndSettle();
    expect(find.text('Peer reply'), findsOneWidget);
    await tester.tap(find.text('Resolve'));
    await tester.pumpAndSettle();
    expect(find.text('Peer reply'), findsNothing);
    await tester.tap(find.text('Resolved (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Peer reply'), findsOneWidget);
    await tester.tap(find.text('Reopen'));
    await tester.pumpAndSettle();
    expect(find.text('Resolved (1)'), findsNothing);
  });
  testWidgets('retains a typed mention and retries a refused send', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'unrelated-previous-format': 'keep',
    });
    await DevicePreferences.load();
    client.answers['POST /mentions/audience'] = (_) => {
      'candidates': [
        {
          'id': 'a1',
          'type': 'agent',
          'name': 'helper',
          'displayName': 'Helper',
        },
      ],
    };
    client.answers['GET /artifacts/$artifactId/will-notify'] = (_) => {
      'recipients': [],
    };
    client.answers['POST $_path'] = (_) => RaftApiException.response(
      'Failed',
      status: 503,
      body: {'code': 'UNAVAILABLE'},
    );
    await open(tester, const Size(1000, 850), TargetPlatform.linux);
    await tester.tap(openComments);
    await tester.pumpAndSettle();
    await tester.enterText(composer, '@help');
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('artifact-mention-a1')));
    await tester.pumpAndSettle();
    expect(find.text('Will notify: Helper'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('artifact-comments-close')));
    await tester.pumpAndSettle();
    await tester.tap(openComments);
    await tester.pumpAndSettle();
    expect(find.text('@helper '), findsOneWidget);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text("Couldn't send the comment. Try again."), findsOneWidget);
    expect(
      client.bodies['POST $_path'],
      containsPair('body', [
        {
          'type': 'mention',
          'actor': {'type': 'agent', 'id': 'a1'},
        },
        {'type': 'text', 'text': ' '},
      ]),
    );
    expect(
      client.bodies['POST /mentions/audience'],
      containsPair('audience', {
        'kind': 'object',
        'app': 'artifacts',
        'objectKind': 'artifact',
        'objectId': artifactId,
      }),
    );
    client.answers['POST $_path'] = (_) => {
      'comment': comment('sent', 'Delivered'),
      'notified': [],
    };
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text("Couldn't send the comment. Try again."), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await open(tester, const Size(1000, 850), TargetPlatform.linux);
    await tester.tap(openComments);
    await tester.pumpAndSettle();
    expect(find.text('@helper '), findsNothing);
    expect(
      DevicePreferences.current!.getString('unrelated-previous-format'),
      'keep',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('flag off hides the discussion and skips its reads', (
    tester,
  ) async {
    client.enabled = false;
    await open(tester, const Size(1000, 850), TargetPlatform.linux);
    expect(openComments, findsNothing);
    expect(client.requests, isNot(contains('GET $_path')));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
