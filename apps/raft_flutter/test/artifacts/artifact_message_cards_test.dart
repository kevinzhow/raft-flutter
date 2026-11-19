import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_message_card.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../support/artifact_fake_client.dart';
import '../support/fake_artifact_webview.dart';

/// The cards under a message for the Artifacts its text links to, and a link
/// click that opens the viewer (WP-ART1, Web ArtifactMessageRefs).
void main() {
  const link = 'https://app.raft.build/artifacts/$artifactShort';
  late ArtifactFakeClient client;
  late WorkspaceController w;
  late List<String> external;

  setUp(() {
    FakeArtifactWebView.reset();
    WebViewPlatform.instance = FakeArtifactWebView();
    client = ArtifactFakeClient();
    w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner', 'name': 'Dev'});
    external = [];
  });

  tearDown(() => w.dispose());

  void summaries(List<Map<String, Object?>> answers) =>
      client.answers['POST /objects/summaries'] = (_) => {
        'kind': 'artifact',
        'summaries': answers,
      };

  Future<void> show(WidgetTester tester, String content) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: MessagePresentation(
            controller: w,
            message: RaftMessage({
              'id': 'm1',
              'channelId': 'c1',
              'content': content,
            }),
            onExternalLink: external.add,
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('a linked Artifact gets its card: title, version, facts line, '
      'where it lives, who updated it, new marks', (tester) async {
    summaries([
      {
        'ref': {'id': artifactId},
        'ok': true,
        'summary': artifactCardJson(
          kind: 'csv',
          title: 'Q3 numbers',
          version: 3,
          latest: 3,
          comments: 4,
          facts: {'sizeBytes': 100, 'fileCount': 1, 'rows': 5, 'columns': 4},
          unseen: {'newerVersion': true, 'newComments': 2},
        ),
      },
    ]);
    await show(tester, 'Here it is: $link');
    expect(
      client.requests.where((r) => r == 'POST /objects/summaries').length,
      1,
    );
    expect(find.byKey(const ValueKey('artifact-card-title')), findsOneWidget);
    expect(find.text('Q3 numbers'), findsOneWidget);
    expect(find.text('v3'), findsOneWidget);
    expect(find.text('5 rows × 4 columns'), findsOneWidget);
    expect(find.text('general'), findsOneWidget);
    expect(find.text('Updated · 2 new comments'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('artifact-card-comments')),
      findsOneWidget,
    );
  });

  testWidgets('a remounted versioned Artifact card stays visible during '
      'refresh and is replaced when deleted', (tester) async {
    const target = ArtifactLinkTarget(artifactId, 2);
    final refresh = Completer<List<Object?>>();
    var posts = 0;
    final loader = ObjectSummaryLoader(
      now: tester.binding.clock.now,
      post: (_) async {
        if (++posts == 1) {
          return [
            {
              'ref': {'id': artifactId, 'version': 2},
              'ok': true,
              'summary': artifactCardJson(
                title: 'Versioned report',
                version: 2,
                latest: 3,
                unseen: {'newerVersion': true},
              ),
            },
          ];
        }
        return refresh.future;
      },
    );
    addTearDown(loader.dispose);

    Future<void> mountCard() => tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Builder(
            builder: (_) => ArtifactMessageRefs(
              links: [loader.stateOf(target)],
              onOpen: (_, _) {},
            ),
          ),
        ),
      ),
    );

    await mountCard();
    await tester.pump(loader.batchWindow);
    await mountCard();
    expect(find.text('Versioned report'), findsOneWidget);
    expect(find.text('Updated'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 61));
    await mountCard();
    expect(find.text('Versioned report'), findsOneWidget);

    await tester.pump(loader.batchWindow);
    expect(posts, 2);
    await mountCard();
    expect(find.byType(ArtifactMessageCardLoading), findsNothing);
    expect(find.text('Versioned report'), findsOneWidget);
    expect(find.text('Updated'), findsOneWidget);

    refresh.complete([
      {
        'ref': {'id': artifactId, 'version': 2},
        'ok': false,
        'reason': 'deleted',
        'deleted': {'status': 'deleted', 'title': 'Removed report'},
      },
    ]);
    await tester.pump();
    await mountCard();
    expect(find.byType(ArtifactDeletedCard), findsOneWidget);
    expect(find.text('Removed report'), findsOneWidget);
    expect(find.text('Versioned report'), findsNothing);
    expect(find.text('Updated'), findsNothing);
  });

  testWidgets('a deleted Artifact is the gray card; one this reader can\'t '
      'see adds nothing', (tester) async {
    summaries([
      {
        'ref': {'id': artifactId},
        'ok': false,
        'reason': 'deleted',
        'deleted': {
          'status': 'deleted',
          'title': 'Old report',
          'deletedBy': artifactActor('Remy'),
          'deletedAt': '2026-11-01T00:00:00.000Z',
        },
      },
      {
        'ref': {'id': artifactId, 'version': 2},
        'ok': false,
        'reason': 'unavailable',
      },
    ]);
    await show(tester, '$link and $link/v/2');
    expect(find.byKey(const ValueKey('artifact-card-deleted')), findsOneWidget);
    expect(find.text('Old report'), findsOneWidget);
    expect(find.byKey(const ValueKey('artifact-card-title')), findsNothing);
  });

  testWidgets('with workspace_artifacts_v0 off the link stays a plain link', (
    tester,
  ) async {
    client.enabled = false;
    await show(tester, 'Here it is: $link');
    expect(client.requests.contains('POST /objects/summaries'), isFalse);
    expect(find.byKey(const ValueKey('artifact-message-refs')), findsNothing);
  });

  testWidgets('pressing the card opens the viewer on its Artifact', (
    tester,
  ) async {
    summaries([
      {
        'ref': {'id': artifactId},
        'ok': true,
        'summary': artifactCardJson(),
      },
    ]);
    client.answers['GET /artifacts/$artifactId'] = (_) => artifactViewerJson();
    await show(tester, link);
    await tester.tap(find.byKey(const ValueKey('artifact-card-title')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(ArtifactWorkspaceViewer), findsOneWidget);
    expect(client.requests, contains('GET /artifacts/$artifactId'));
    expect(external, isEmpty);
  });

  testWidgets('a click on the link in the text opens the viewer, not the '
      'browser', (tester) async {
    summaries([
      {
        'ref': {'id': artifactId},
        'ok': true,
        'summary': artifactCardJson(),
      },
    ]);
    client.answers['GET /artifacts/$artifactId'] = (_) => artifactViewerJson();
    await show(tester, link);
    final presentation = tester.widget<MessagePresentation>(
      find.byType(MessagePresentation),
    );
    await presentation.open(tester.element(find.byType(Scaffold)), link);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(ArtifactWorkspaceViewer), findsOneWidget);
    expect(external, isEmpty);
    await presentation.open(
      tester.element(find.byType(Scaffold).first),
      'https://example.com/',
    );
    expect(external, ['https://example.com/']);
  });
}
