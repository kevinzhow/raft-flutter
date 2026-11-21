import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity/parity_harness.dart' show loadParityFonts;
import '../support/artifact_fake_client.dart';

const _path = '/artifacts/$artifactId/comments';

class _Images extends FileSelectorPlatform {
  int opens = 0;

  @override
  Future<List<XFile>> openFiles({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    opens++;
    return [
      XFile.fromData(
        Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        path: 'fixture.png',
      ),
    ];
  }
}

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

  setUpAll(loadParityFonts);

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
    TargetPlatform platform, {
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: RaftTextScaling(child: child!),
        ),
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

  for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
    testWidgets('narrow comment controls share the editor frame on $platform', (
      tester,
    ) async {
      const draftsPath = '/artifacts/$artifactId/review/drafts';
      client.answers['GET $draftsPath'] = (_) => {'drafts': []};
      client.answers['POST $draftsPath'] = (input) => {
        'draft': {
          ...input! as Map<String, Object?>,
          'id': 'private-draft',
          'createdAt': '2026-11-19T03:00:00Z',
        },
      };
      client.answers['POST $_path'] = (_) => {
        'comment': comment('sent', 'Published comment'),
        'notified': [],
      };
      await open(tester, const Size(390, 844), platform);
      await tester.tap(openComments);
      await tester.pumpAndSettle();

      final attach = find.byKey(const ValueKey('artifact-comment-attach'));
      final save = find.byKey(const ValueKey('artifact-comment-save-draft'));
      final send = find.byKey(const ValueKey('artifact-comment-send'));
      final frame = find.byKey(const ValueKey('artifact-comment-frame'));
      expect(
        tester.getCenter(attach).dx,
        lessThan(tester.getCenter(composer).dx),
      );
      expect(find.descendant(of: frame, matching: composer), findsOneWidget);
      for (final control in [attach, save, send]) {
        expect(find.descendant(of: frame, matching: control), findsOneWidget);
        expect(
          tester.getRect(control).top,
          greaterThanOrEqualTo(tester.getRect(composer).bottom),
        );
        expect(control.hitTestable(), findsOneWidget);
      }
      expect(tester.getRect(save).right, lessThan(tester.getRect(send).left));
      expect(tester.getCenter(attach).dy, tester.getCenter(send).dy);
      expect(
        find.descendant(of: send, matching: find.text('Send')),
        findsOneWidget,
      );

      await tester.enterText(composer, 'Private draft');
      await tester.pump();
      if (platform == TargetPlatform.linux) {
        final original = FileSelectorPlatform.instance;
        addTearDown(() => FileSelectorPlatform.instance = original);
        final images = _Images();
        FileSelectorPlatform.instance = images;
        client.answers['POST /artifacts/$artifactId/comment-images'] = (_) => {
          'fileId': 'image-fixture',
        };
        await tester.tap(attach);
        await tester.pumpAndSettle();
        expect(images.opens, 1);
        expect(find.text('fixture.png'), findsOneWidget);
        expect(find.text('Private draft'), findsOneWidget);
      }
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Your drafts'), findsOneWidget);
      expect(
        client.requests.where((r) => r == 'POST $draftsPath'),
        hasLength(1),
      );
      expect(client.requests, isNot(contains('POST $_path')));
      expect(
        client.bodies['POST $draftsPath'],
        containsPair('body', [
          {'type': 'text', 'text': 'Private draft'},
        ]),
      );
      if (platform == TargetPlatform.linux) {
        expect(
          client.bodies['POST $draftsPath'],
          containsPair('images', ['image-fixture']),
        );
      }

      await tester.enterText(composer, 'Published comment');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(client.requests, isNot(contains('POST $_path')));
      final text = tester.widget<TextField>(composer).controller!.text;
      expect(text.trim(), 'Published comment');
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(client.requests.where((r) => r == 'POST $_path'), hasLength(1));
      expect(
        client.bodies['POST $_path'],
        containsPair('body', [
          {'type': 'text', 'text': text},
        ]),
      );
      expect(find.text('Published comment'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant({platform}));
  }

  testWidgets('narrow comment controls remain reachable at 3.1x', (
    tester,
  ) async {
    const draftsPath = '/artifacts/$artifactId/review/drafts';
    client.answers['GET $draftsPath'] = (_) => {'drafts': []};
    await open(
      tester,
      const Size(390, 844),
      TargetPlatform.linux,
      textScaler: const TextScaler.linear(3.1),
    );
    await tester.tap(openComments);
    await tester.pumpAndSettle();
    await tester.enterText(composer, 'A draft at the largest text size');
    await tester.pumpAndSettle();
    final bounds = tester.getRect(
      find.byKey(const ValueKey('artifact-comment-frame')),
    );
    for (final key in ['attach', 'save-draft', 'send']) {
      final control = find.byKey(ValueKey('artifact-comment-$key'));
      final rect = tester.getRect(control);
      expect(rect.left, greaterThanOrEqualTo(bounds.left));
      expect(rect.right, lessThanOrEqualTo(bounds.right));
      expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
      expect(control.hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

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
