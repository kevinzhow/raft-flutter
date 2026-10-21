import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final (family, dark) in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ])) {
    testWidgets(
      '${family.name} dark=$dark file opens as one accessible action',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          var opened = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: Scaffold(
                body: RaftAttachmentCard(
                  filename: '日本語.pdf',
                  mimeType: 'application/pdf',
                  sizeBytes: 2048,
                  onOpen: () => opened++,
                ),
              ),
            ),
          );
          expect(find.text('日本語.pdf'), findsOneWidget);
          await tester.tap(find.text('日本語.pdf'));
          expect(find.byTooltip('Download 日本語.pdf'), findsNothing);
          expect(opened, 1);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
    for (final density in RaftDensity.values) {
      testWidgets(
        '${family.name} dark=$dark $density image opens without share/download overlays',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            var opened = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: raftTheme(family, dark: dark),
                home: Scaffold(
                  body: RaftDensityScope(
                    density: density,
                    child: RaftAttachmentCard(
                      filename: '日本語.png',
                      mimeType: 'image/png',
                      preview: const ColoredBox(color: Colors.blue),
                      onOpen: () => opened++,
                    ),
                  ),
                ),
              ),
            );
            final card = find.byType(RaftAttachmentCard);
            void expectNoOverlay() {
              expect(find.byTooltip('Share 日本語.png'), findsNothing);
              expect(find.byTooltip('Download 日本語.png'), findsNothing);
            }

            expectNoOverlay();
            final mouse = await tester.createGesture(
              kind: PointerDeviceKind.mouse,
            );
            await mouse.addPointer(location: const Offset(700, 550));
            await mouse.moveTo(tester.getCenter(card));
            await tester.pump();
            expectNoOverlay();
            await mouse.removePointer();

            // Both former action targets now belong to the image itself.
            final bottomRight = tester.getBottomRight(card);
            await tester.tapAt(bottomRight - const Offset(28, 28));
            await tester.tapAt(bottomRight - const Offset(76, 28));
            expect(opened, 2);
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            expect(opened, 3);
            expectNoOverlay();
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
  testWidgets(
    'pending image preview reserves its final box without a spinner',
    (tester) async {
      Widget card(Widget? preview) => MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RaftAttachmentCard(
              filename: 'photo.jpg',
              mimeType: 'image/jpeg',
              imageWidth: 4000,
              imageHeight: 3000,
              previewPending: preview == null,
              preview: preview,
              onOpen: () {},
            ),
          ),
        ),
      );
      await tester.pumpWidget(card(null));
      final pending = tester.getRect(find.byType(RaftAttachmentCard));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('photo.jpg'), findsNothing);
      expect(pending.size, const Size(384, 288));
      await tester.pumpWidget(card(const ColoredBox(color: Colors.black)));
      expect(tester.getRect(find.byType(RaftAttachmentCard)), pending);
    },
  );
  testWidgets('export retains metadata while hiding every interaction', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: RaftAttachmentCard(
            filename: 'export.png',
            sizeBytes: 2048,
            mimeType: 'image/png',
            exportMode: true,
            busy: true,
            error: 'Unavailable',
            preview: const SizedBox(),
            onOpen: () {},
            onCancel: () {},
            onRetry: () {},
          ),
        ),
      ),
    );
    expect(find.byTooltip('Preview export.png'), findsOneWidget);
    expect(find.text('2.0 KB'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
  testWidgets(
    'pending file blocks send but keeps drafting and picker available',
    (tester) async {
      var sends = 0, picks = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: Scaffold(
            body: RaftComposer(
              canSend: false,
              onSend: (_) async {
                sends++;
                return true;
              },
              onAttach: () => picks++,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '你好 日本語');
      await tester.tap(find.byTooltip('Attach file'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(picks, 1);
      expect(sends, 0);
      expect(find.text('你好 日本語'), findsOneWidget);
    },
  );
}
