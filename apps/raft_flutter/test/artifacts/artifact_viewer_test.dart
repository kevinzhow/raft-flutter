import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_image_store.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_frame_view.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../support/artifact_fake_client.dart';
import '../support/fake_artifact_webview.dart';

/// The Artifact viewer (WP-ART1) against a fake server: the viewer route's
/// answer, its frame for the first mount, version history, files, download,
/// follow and the browser fallbacks.
void main() {
  late ArtifactFakeClient client;
  late WorkspaceController w;
  late List<(String, String, int)> saved;
  late List<Uri> opened;
  late _MemoryStore store;

  setUp(() {
    FakeArtifactWebView.reset();
    WebViewPlatform.instance = FakeArtifactWebView();
    client = ArtifactFakeClient();
    store = _MemoryStore();
    w = WorkspaceController(client, attachmentImageStore: store)
      ..server = RaftRecord({'id': 's1', 'role': 'owner', 'name': 'Dev'});
    saved = [];
    opened = [];
  });

  tearDown(() => w.dispose());

  ValueNotifier<bool> notifier(bool on) {
    final value = ValueNotifier(on);
    addTearDown(value.dispose);
    return value;
  }

  Future<void> open(
    WidgetTester tester, {
    String os = 'android',
    ValueListenable<bool>? voiceOver,
    ArtifactLinkTarget target = const ArtifactLinkTarget(artifactId),
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ArtifactWorkspaceViewer(
            session: ArtifactSession.of(w),
            target: target,
            page: size.width < 768,
            onClose: () {},
            operatingSystem: os,
            voiceOver: voiceOver ?? notifier(false),
            hostScript: () async => '/* host */',
            save: (bytes, name, mime) async {
              saved.add((name, mime, bytes.length));
              return '/tmp/$name';
            },
            openExternal: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  void answerViewer(Map<String, Object?> json, {int? version}) =>
      client.answers['GET /artifacts/$artifactId${version == null ? '' : '?version=$version'}'] =
          (_) => json;

  testWidgets('opens the version the viewer route answers and mounts its own '
      'frame first', (tester) async {
    answerViewer(artifactViewerJson());
    await open(tester);
    expect(find.text('probe'), findsOneWidget);
    expect(find.text('general'), findsOneWidget, reason: 'where it lives');
    expect(
      find.byKey(const ValueKey('artifact-version-badge')),
      findsOneWidget,
    );
    expect(FakeArtifactWebView.baseUrl, 'https://app.raft.build');
    expect(
      client.requests.where((r) => r.contains('/frame')),
      isEmpty,
      reason: 'the viewer answer\'s ticket is spent first',
    );
    expect(
      find.byKey(const ValueKey('artifact-splash-starting')),
      findsOneWidget,
    );
  });

  testWidgets('an embedded frame offers display report in the comment menu', (
    tester,
  ) async {
    answerViewer(artifactViewerJson());
    final path = '/artifacts/$artifactId';
    client.answers['GET $path/comments'] = (_) => {'comments': []};
    client.answers['GET $path/will-notify'] = (_) => {'recipients': []};
    client.answers['GET $path/review/drafts'] = (_) => {'drafts': []};
    await open(tester);
    await tester.tap(find.byKey(const Key('artifact-viewer-menu-trigger')));
    await tester.pumpAndSettle();
    final report = find.text("Doesn't display well here");
    expect(report, findsNothing);
    await tester.tapAt(const Offset(10, 500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('artifact-comment-menu-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(report);
    await tester.pumpAndSettle();
    expect(find.byType(RaftSheet), findsOneWidget);
    final composer = find.byKey(const Key('artifact-comment-input'));
    final field = tester.widget<EditableText>(
      find.descendant(of: composer, matching: find.byType(EditableText)),
    );
    expect(field.controller.text, contains('Version: v1'));
    expect(client.requests, isNot(contains('POST $path/comments')));
  });

  testWidgets('an Artifact this reader can\'t see is the one "can\'t open" '
      'state', (tester) async {
    client.answers['GET /artifacts/$artifactId'] = (_) =>
        RaftApiException.response(
          'Not visible',
          status: 404,
          body: {'error': 'Not visible', 'code': 'NOT_VISIBLE'},
        );
    await open(tester);
    expect(find.text('Can\'t open this Artifact'), findsOneWidget);
    expect(
      find.text('It doesn\'t exist, or you don\'t have access to it.'),
      findsOneWidget,
    );
  });

  testWidgets('Linux opens Raft Web\'s page for it in the browser', (
    tester,
  ) async {
    answerViewer(artifactViewerJson());
    await open(tester, os: 'linux');
    expect(FakeArtifactWebView.html, isNull);
    await tester.tap(find.byKey(const ValueKey('artifact-open-in-browser')));
    await tester.pump();
    expect(opened, [
      Uri.parse('https://app.raft.build/artifacts/$artifactShort'),
    ]);
  });

  testWidgets('macOS with VoiceOver on falls back to the browser', (
    tester,
  ) async {
    answerViewer(artifactViewerJson());
    await open(tester, os: 'macos', voiceOver: notifier(true));
    expect(FakeArtifactWebView.html, isNull);
    expect(
      find.byKey(const ValueKey('artifact-open-in-browser')),
      findsOneWidget,
    );
  });

  testWidgets('macOS with another accessibility client (semantics on, '
      'VoiceOver off) frames the Artifact in the app', (tester) async {
    final semantics = tester.ensureSemantics();
    answerViewer(artifactViewerJson());
    await open(tester, os: 'macos', voiceOver: notifier(false));
    expect(SemanticsBinding.instance.semanticsEnabled, isTrue);
    expect(FakeArtifactWebView.html, isNotNull);
    expect(find.byType(ArtifactFrameView), findsOneWidget);
    expect(
      find.byKey(const ValueKey('artifact-open-in-browser')),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets('VoiceOver turning on while a frame is mounted unmounts it in '
      'the next frame, and turning off frames it again', (tester) async {
    final semantics = tester.ensureSemantics();
    final voiceOver = notifier(false);
    answerViewer(artifactViewerJson());
    await open(tester, os: 'macos', voiceOver: voiceOver);
    expect(find.byType(ArtifactFrameView), findsOneWidget);

    voiceOver.value = true;
    // One frame: build runs before that frame's semantics flush, so the platform view is gone
    // from the tree the flush sends.
    await tester.pump();
    expect(find.byType(ArtifactFrameView), findsNothing);
    expect(
      find.byKey(const ValueKey('artifact-open-in-browser')),
      findsOneWidget,
    );

    // Mounting again spends a new frame ticket: the first one was spent.
    final frames = client.requests.where((r) => r.contains('/frame')).length;
    client.answers['POST /artifacts/$artifactId/frame'] = (_) =>
        artifactFrameJson('w');
    voiceOver.value = false;
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(find.byType(ArtifactFrameView), findsOneWidget);
    expect(
      find.byKey(const ValueKey('artifact-open-in-browser')),
      findsNothing,
    );
    expect(
      client.requests.where((r) => r.contains('/frame')).length,
      frames + 1,
    );
    semantics.dispose();
  });

  testWidgets('version history: a pinned version, then Back to latest', (
    tester,
  ) async {
    answerViewer(
      artifactViewerJson(
        card: artifactCardJson(version: 2, latest: 2),
        versions: [1, 2],
      ),
    );
    answerViewer(
      artifactViewerJson(
        card: artifactCardJson(version: 1, latest: 2, pinned: true),
        versions: [1, 2],
      ),
      version: 1,
    );
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('artifact-version-badge')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('artifact-version-sheet')),
      findsOneWidget,
    );
    expect(find.text('v2 · Latest'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('artifact-version-row-1')));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(client.requests, contains('GET /artifacts/$artifactId?version=1'));
    expect(find.text('Viewing v1'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('artifact-viewer-back-to-latest')),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(find.text('Viewing v1'), findsNothing);
    expect(
      client.requests.where((r) => r == 'GET /artifacts/$artifactId').length,
      2,
    );
  });

  testWidgets('Download all saves the version\'s zip; Follow follows', (
    tester,
  ) async {
    answerViewer(
      artifactViewerJson(
        files: [
          {
            'path': 'index.html',
            'kind': 'html',
            'sizeBytes': 10,
            'entry': true,
          },
          {
            'path': 'data/rows.csv',
            'kind': 'csv',
            'sizeBytes': 20,
            'entry': false,
          },
        ],
      ),
    );
    client.answers['GET /artifacts/$artifactId/download.zip?version=1'] = (_) =>
        Uint8List.fromList([80, 75, 3, 4]);
    client.answers['PUT /artifacts/$artifactId/subscription'] = (_) => {
      'following': true,
    };
    await open(tester);
    await tester.tap(
      find.byKey(const ValueKey('artifact-viewer-menu-trigger')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download all'));
    await tester.pumpAndSettle();
    expect(saved, [('probe v1.zip', 'application/zip', 4)]);
    await tester.tap(
      find.byKey(const ValueKey('artifact-viewer-menu-trigger')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();
    expect(
      client.requests,
      contains('PUT /artifacts/$artifactId/subscription'),
    );
    await tester.tap(
      find.byKey(const ValueKey('artifact-viewer-menu-trigger')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unfollow'), findsOneWidget);
  });

  testWidgets('Files: a csv file opens drawn in the viewer, a file downloads', (
    tester,
  ) async {
    answerViewer(
      artifactViewerJson(
        files: [
          {
            'path': 'index.html',
            'kind': 'html',
            'sizeBytes': 10,
            'entry': true,
          },
          {
            'path': 'data/rows.csv',
            'kind': 'csv',
            'sizeBytes': 20,
            'entry': false,
          },
        ],
      ),
    );
    client.answers['GET /artifacts/$artifactId/files/data%2Frows.csv?version=1'] =
        (_) => 'name,count\nalpha,1\nbeta,2\n';
    await open(tester);
    await tester.tap(
      find.byKey(const ValueKey('artifact-viewer-menu-trigger')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('artifact-files-panel')), findsOneWidget);
    expect(find.text('2 files · 30 B'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('artifact-files-row-data/rows.csv')),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('artifact-viewer-csv')), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
  });

  testWidgets('a text Artifact is drawn by the app, no frame', (tester) async {
    answerViewer(
      artifactViewerJson(
        card: artifactCardJson(kind: 'text', title: 'notes.txt'),
        files: [
          {'path': 'notes.txt', 'kind': 'text', 'sizeBytes': 12, 'entry': true},
        ],
        frame: false,
      ),
    );
    client.answers['GET /artifacts/$artifactId/files/notes.txt?version=1'] = (
      _,
    ) => 'line one\nline two\n';
    await open(tester);
    expect(FakeArtifactWebView.html, isNull);
    expect(find.text('line one\nline two'), findsOneWidget);
  });

  group('a drawn file version is kept on the device', () {
    const text = 'line one\nline two';
    void answerText({int version = 1}) {
      answerViewer(
        artifactViewerJson(
          card: artifactCardJson(
            kind: 'text',
            title: 'notes.txt',
            version: version,
            latest: version,
          ),
          files: [
            {
              'path': 'notes.txt',
              'kind': 'text',
              'sizeBytes': 18,
              'entry': true,
            },
          ],
          frame: false,
        ),
        version: version == 1 ? null : version,
      );
      client.answers['GET /artifacts/$artifactId/files/notes.txt?version=$version'] =
          (_) => '$text\n';
    }

    int fileGets(int version) => client.requests
        .where(
          (r) =>
              r ==
              'GET /artifacts/$artifactId/files/notes.txt?version=$version',
        )
        .length;

    Future<void> reopen(
      WidgetTester tester, {
      ArtifactLinkTarget target = const ArtifactLinkTarget(artifactId),
    }) async {
      await tester.pumpWidget(const SizedBox());
      await open(tester, target: target);
    }

    testWidgets('opening the same version again does not download its file '
        'again; the viewer route is still asked', (tester) async {
      answerText();
      await open(tester);
      expect(find.text(text), findsOneWidget);
      await reopen(tester);
      expect(find.text(text), findsOneWidget);
      expect(fileGets(1), 1);
      expect(
        client.requests.where((r) => r == 'GET /artifacts/$artifactId').length,
        2,
        reason: 'the server still checks access on every open',
      );
    });

    testWidgets('another version or another account downloads its own copy', (
      tester,
    ) async {
      answerText();
      answerText(version: 2);
      await open(tester);
      await reopen(tester, target: const ArtifactLinkTarget(artifactId, 2));
      expect(find.text(text), findsOneWidget);
      expect((fileGets(1), fileGets(2)), (1, 1));

      await tester.pumpWidget(const SizedBox());
      w.dispose();
      client = ArtifactFakeClient()
        ..user = RaftRecord({'id': 'u2', 'name': 'other'});
      w = WorkspaceController(client, attachmentImageStore: store)
        ..server = RaftRecord({'id': 's1', 'role': 'owner', 'name': 'Dev'});
      answerText();
      await open(tester);
      expect(find.text(text), findsOneWidget);
      expect(fileGets(1), 1, reason: 'u2 has no copy of u1\'s');
    });

    testWidgets('a failing device cache reads from the server instead', (
      tester,
    ) async {
      store.fails = true;
      answerText();
      await open(tester);
      await reopen(tester);
      expect(find.text(text), findsOneWidget);
      expect(fileGets(1), 2);
    });
  });
}

/// The attachment byte store in memory; [fails] makes every call throw.
class _MemoryStore implements AttachmentImageByteStore {
  final entries = <String, Uint8List>{};
  bool fails = false;

  String _name(AttachmentImageStoreKey key) =>
      jsonEncode([key.identity, key.channelId, key.entry]);

  void _check() {
    if (fails) throw const FileSystemException('disk gone');
  }

  @override
  Future<Uint8List?> read(AttachmentImageStoreKey key) async {
    _check();
    return entries[_name(key)];
  }

  @override
  Future<void> write(AttachmentImageStoreKey key, Uint8List bytes) async {
    _check();
    entries[_name(key)] = bytes;
  }

  @override
  Future<void> remove(AttachmentImageStoreKey key) async =>
      entries.remove(_name(key));

  @override
  Future<void> purgeChannel(String identity, String channelId) async {}

  @override
  Future<void> purgeIdentity(String identity) async {}
}
