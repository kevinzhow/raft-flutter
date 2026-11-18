import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
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

  testWidgets('stores two drafts privately and retries the same batch key', (
    tester,
  ) async {
    const draftsPath = '/artifacts/$artifactId/review/drafts';
    const submitPath = '/artifacts/$artifactId/review/submit';
    final drafts = <Map<String, Object?>>[];
    final submissions = <Object?>[];
    client.answers['GET $draftsPath'] = (_) => {'drafts': drafts};
    client.answers['POST $draftsPath'] = (input) {
      final draft = {
        ...input! as Map<String, Object?>,
        'id': 'draft-${drafts.length + 1}',
        'createdAt': '2026-11-19T03:00:00Z',
      };
      drafts.add(draft);
      return {'draft': draft};
    };
    client.answers['POST $submitPath'] = (input) {
      submissions.add(input);
      if (submissions.length == 1) {
        return RaftApiException.response('Network unavailable', status: 503);
      }
      return {
        'status': 'ok',
        'comments': [
          comment('draft-first', 'First draft'),
          comment('draft-second', 'Second draft'),
        ],
      };
    };
    await open(tester, const Size(1100, 850), TargetPlatform.linux);
    await tester.tap(openComments);
    await tester.pumpAndSettle();
    final saveDraft = find.byKey(const ValueKey('artifact-comment-save-draft'));
    for (final text in ['First draft', 'Second draft']) {
      await tester.enterText(composer, text);
      await tester.pump();
      await tester.ensureVisible(saveDraft);
      await tester.tap(saveDraft);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard all'));
      await tester.pumpAndSettle();
      final title = drafts.length == 1
          ? 'Discard 1 draft?'
          : 'Discard 2 drafts?';
      expect(find.text(title), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(client.requests, isNot(contains('DELETE $draftsPath')));
    }
    expect(
      client.requests.where((value) => value == 'POST $draftsPath'),
      hasLength(2),
    );
    expect(client.requests, isNot(contains('POST $_path')));
    expect(find.text('Your drafts'), findsOneWidget);
    expect(find.text('First draft'), findsOneWidget);
    final send = find.byKey(const ValueKey('artifact-review-submit'));
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't send. Your drafts are kept; try again."),
      findsOneWidget,
    );
    expect(find.text('Second draft'), findsOneWidget);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(submissions, hasLength(2));
    expect(submissions.last, submissions.first);
    expect(submissions.first, containsPair('summary', null));
    expect(find.text('First draft'), findsOneWidget);
    expect(find.text('Your drafts'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
