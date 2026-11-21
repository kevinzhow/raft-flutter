import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_dashboard.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity/parity_harness.dart' show loadParityFonts;
import '../support/artifact_fake_client.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'desktop display report paints its seam and active toggle ($dark)',
      (tester) async {
        await tester.runAsync(loadParityFonts);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1280, 900);
        addTearDown(tester.view.reset);
        final boundaryKey = GlobalKey();
        final client = ArtifactFakeClient();
        final workspace = WorkspaceController(client)
          ..server = RaftRecord({'id': 's1', 'role': 'owner'});
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          workspace.dispose();
          await client.dispose();
        });

        final card = artifactCardJson(title: 'Release checklist', kind: 'text');
        client.answers.addAll({
          'GET /artifacts/dashboard/all?sort=opened': (_) => {
            'rows': [
              {'card': card},
            ],
          },
          'GET /artifacts/$artifactId': (_) => artifactViewerJson(
            card: card,
            frame: false,
            files: [
              {'path': 'notes.txt', 'kind': 'text', 'entry': true},
            ],
          ),
          'GET /artifacts/$artifactId/files/notes.txt?version=1': (_) =>
              'Gather screenshots.',
          'GET /artifacts/$artifactId/comments': (_) => {'comments': []},
          'GET /artifacts/$artifactId/will-notify': (_) => {'recipients': []},
          'GET /artifacts/$artifactId/review/drafts': (_) => {'drafts': []},
        });

        final theme = raftTheme(
          dark: dark,
          pack: packForThemeId(dark ? 'elegant' : 'brutal'),
        ).copyWith(platform: TargetPlatform.linux);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: RepaintBoundary(
                key: boundaryKey,
                child: Padding(
                  padding: const EdgeInsets.only(left: 49, top: 44),
                  child: ArtifactDashboard(workspace: workspace),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Release checklist').hitTestable());
        await tester.pumpAndSettle();

        final toggle = find.byKey(const Key('artifact-comments-trigger'));
        final idle = tester.widget<RaftButton>(toggle);
        expect(idle.semanticLabel, 'Comments (0)');
        expect(idle.toggled, isNot(true));

        await tester.tap(
          find.byKey(const Key('artifact-viewer-menu-trigger')),
          kind: ui.PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text("Doesn't display well here").hitTestable(),
          kind: ui.PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        final panel = find.byKey(const Key('artifact-comments-panel'));
        expect(panel.hitTestable(), findsOneWidget);

        final panelLeft = tester.getRect(panel).left;
        final toggleBounds = tester.getRect(toggle);
        // The dashboard's own 20px column margin stays in effect when the
        // Viewer uses the 28px desktop PanelToggleAction box.
        expect(toggleBounds, const Rect.fromLTRB(1173, 51.5, 1201, 79.5));
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        final (seam, yellowPixels) = (await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            int rgb(int x, int y) =>
                data.getUint32((y * image.width + x) * 4) >> 8;
            var yellow = 0;
            for (
              var y = toggleBounds.top.ceil();
              y < toggleBounds.bottom;
              y++
            ) {
              for (
                var x = toggleBounds.left.ceil();
                x < toggleBounds.right;
                x++
              ) {
                if (rgb(x, y) == 0xffd440) yellow++;
              }
            }
            return (rgb(940, 400), yellow);
          } finally {
            image.dispose();
          }
        }))!;

        final active = tester.widget<RaftButton>(toggle);
        expect(active.semanticLabel, 'Comments (0)');
        // Pinned Web 1.24 paints x940 before the 339px panel content and fills
        // the pressed button with --accent. Reading the raster catches a border
        // occluded by the opaque Comments panel even when its widget is present.
        final expectedSeam = dark ? 0x555552 : 0x959494;
        final seamMatches = [0, 8, 16].every(
          (shift) =>
              (((seam >> shift) & 0xff) - ((expectedSeam >> shift) & 0xff))
                  .abs() <=
              1,
        );
        expect(
          (panelLeft, seamMatches, yellowPixels > 400, active.toggled),
          (941.0, true, true, true),
          reason:
              'Seam rgb=${seam.toRadixString(16)}, '
              'yellow pixels=$yellowPixels in $toggleBounds',
        );

        final input = find.byKey(const Key('artifact-comment-input'));
        final editable = find.descendant(
          of: input,
          matching: find.byType(EditableText),
        );
        final editor = tester.state<EditableTextState>(editable).renderEditable;
        final field = tester.widget<EditableText>(editable);
        final initial = field.controller.text;
        final firstLine = TextSelection(
          baseOffset: 0,
          extentOffset: initial.indexOf('\n'),
        );
        final first = editor.getBoxesForSelection(firstLine).first;
        final initialInk = await _lineInk(tester, boundary, editor, first);
        final scroll = tester
            .state<ScrollableState>(
              find
                  .descendant(of: editable, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        final originalOffset = scroll.pixels;
        scroll.jumpTo(scroll.minScrollExtent);
        await tester.pump();
        final full = editor.getBoxesForSelection(firstLine).first;
        final fullInk = await _lineInk(tester, boundary, editor, full);
        scroll.jumpTo(originalOffset);
        await tester.pump();
        final frame = find.byKey(const Key('artifact-comment-frame'));
        expect(field.focusNode.hasFocus, isTrue);
        expect(
          field.controller.selection,
          TextSelection.collapsed(offset: initial.length),
        );
        expect(
          (
            field.style.fontSize,
            editor.preferredLineHeight,
            initialInk > 0 && initialInk == fullInk,
            tester.widget<RaftRecipeBox>(frame).style.boxShadow.isEmpty,
          ),
          (14.0, 22.0, true, true),
          reason:
              'The Web fine-pointer report has a visible first line '
              'and a focused editor without a keyboard-only ring. First-line ink $initialInk/$fullInk at $first.',
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(field.focusNode.hasFocus, isFalse);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(field.focusNode.hasFocus, isTrue);
        expect(tester.widget<RaftRecipeBox>(frame).style.boxShadow, isNotEmpty);
        await tester.enterText(input, '${initial}Details');
        expect(field.controller.text, endsWith('Details'));

        await tester.tap(find.byKey(const Key('artifact-comments-close')));
        await tester.pumpAndSettle();
        expect(panel, findsNothing);
        final closed = tester.widget<RaftButton>(toggle);
        expect(closed.semanticLabel, 'Comments (0)');
        expect(closed.toggled, isNot(true));
        expect(closed.focusNode!.hasFocus, isTrue);
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

Future<int> _lineInk(
  WidgetTester tester,
  RenderRepaintBoundary boundary,
  RenderEditable editor,
  ui.TextBox row,
) async {
  final line = row.toRect().intersect(Offset.zero & editor.size);
  if (line.isEmpty) return 0;
  final bounds = line.shift(editor.localToGlobal(Offset.zero));
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      int pixel(int x, int y) => bytes.getUint32((y * image.width + x) * 4);
      var paint = 0;
      for (var y = bounds.top.ceil(); y < bounds.bottom; y++) {
        final background = pixel(bounds.right.ceil() + 1, y);
        for (var x = bounds.left.ceil(); x < bounds.right; x++) {
          if (pixel(x, y) != background) paint++;
        }
      }
      return paint;
    } finally {
      image.dispose();
    }
  }))!;
}
