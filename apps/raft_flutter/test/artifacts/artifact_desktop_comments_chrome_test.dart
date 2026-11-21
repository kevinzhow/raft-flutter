import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity/parity_harness.dart' show loadParityFonts;
import '../support/artifact_fake_client.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'desktop Comments paints the card, seam and counted toggle ($dark)',
      (tester) async {
        await tester.runAsync(loadParityFonts);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1280, 900);
        addTearDown(tester.view.reset);
        final client = ArtifactFakeClient();
        final workspace = WorkspaceController(client)
          ..server = RaftRecord({'id': 's1', 'role': 'owner'});
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          workspace.dispose();
          await client.dispose();
        });
        const artifact = '/artifacts/$artifactId';
        client.answers.addAll({
          'GET $artifact': (_) => artifactViewerJson(
            card: artifactCardJson(kind: 'text', comments: 4),
            frame: false,
            files: [
              {'path': 'notes.txt', 'kind': 'text', 'entry': true},
            ],
          ),
          'GET $artifact/files/notes.txt?version=1': (_) => 'Artifact contents',
          'GET $artifact/comments': (_) => {
            'comments': [
              for (var i = 0; i < 4; i++)
                {
                  'id': 'comment-$i',
                  'version': 1,
                  'author': artifactActor(),
                  'body': [
                    {'type': 'text', 'text': 'Review note $i'},
                  ],
                  'target': {'scope': 'artifact'},
                },
            ],
          },
          'GET $artifact/will-notify': (_) => {'recipients': []},
          'GET $artifact/review/drafts': (_) => {'drafts': []},
        });
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(
              dark: dark,
              pack: packForThemeId('elegant'),
            ).copyWith(platform: TargetPlatform.linux),
            home: Scaffold(
              body: RepaintBoundary(
                key: boundaryKey,
                child: ArtifactWorkspaceViewer(
                  session: ArtifactSession.of(workspace),
                  target: ArtifactLinkTarget(artifactId),
                  page: false,
                  inCollection: true,
                  onClose: () {},
                  operatingSystem: 'linux',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final toggle = find.byKey(const Key('artifact-comments-trigger'));
        final picker = tester.widget<RaftButton>(toggle);
        expect(picker.semanticLabel, 'Comments (4)');
        expect(picker.toggled, isFalse);
        await tester.tap(toggle, kind: ui.PointerDeviceKind.mouse);
        await tester.pumpAndSettle();

        final panel = find.byKey(const Key('artifact-comments-panel'));
        final active = tester.widget<RaftButton>(toggle);
        final toggleBox = tester.getRect(toggle);
        final icon = find.descendant(
          of: toggle,
          matching: find.byType(RaftIcon),
        );
        final iconBox = tester.getRect(icon.first);
        final count = find.byKey(const Key('artifact-comment-count'));
        final countBox = tester.getRect(count);
        final overflowBox = tester.getRect(
          find.byKey(const Key('artifact-viewer-menu-trigger')),
        );
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        final (seam, fill) = (await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final pixels = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            int rgb(int x, int y) => pixels.getUint32((y * 1280 + x) * 4) >> 8;
            return (rgb(940, 700), rgb(950, 700));
          } finally {
            image.dispose();
          }
        }))!;
        final expectedSeam = dark ? 0x555552 : 0x959494;
        final seamMatches = [0, 8, 16].every(
          (shift) =>
              (((seam >> shift) & 0xff) - ((expectedSeam >> shift) & 0xff))
                  .abs() <=
              1,
        );
        // From the mounted Web v1.24 DOM and its unoccupied pane interior.
        expect(
          (
            tester.getRect(panel),
            seamMatches,
            fill,
            active.glyph,
            active.semanticLabel,
            active.toggled,
            (toggleBox.width - 40.36).abs() <= 0.8,
            toggleBox.height,
            (toggleBox.right - 1205).abs() <= 1,
            iconBox.width,
            countBox.height,
          ),
          (
            Rect.fromLTRB(941, 44, 1280, 900),
            true,
            dark ? 0x242422 : 0xffffff,
            RaftGlyph.comment,
            'Comments (4)',
            true,
            true,
            28.0,
            true,
            18.0,
            18.0,
          ),
          reason:
              'Seam=${seam.toRadixString(16)}, fill=${fill.toRadixString(16)}, '
              'toggle=$toggleBox, icon=$iconBox, count=$countBox, overflow=$overflowBox',
        );

        await tester.tap(find.byKey(const Key('artifact-comments-close')));
        await tester.pumpAndSettle();
        expect(panel, findsNothing);
        expect(active.focusNode!.hasFocus, isTrue);
        expect(
          client.requests.where(
            (request) => request.startsWith('POST /artifacts/'),
          ),
          isEmpty,
        );
      },
    );
  }
}
