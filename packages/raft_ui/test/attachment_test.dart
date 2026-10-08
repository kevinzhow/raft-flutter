import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '${family.name} dark=$dark attachment has separate accessible open/download actions',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          var opened = 0, downloaded = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: Scaffold(
                body: RaftAttachmentCard(
                  filename: '日本語.png',
                  mimeType: 'image/png',
                  sizeBytes: 2048,
                  onOpen: () => opened++,
                  onDownload: () => downloaded++,
                ),
              ),
            ),
          );
          expect(find.byTooltip('Preview 日本語.png'), findsOneWidget);
          await tester.tap(find.byTooltip('Preview 日本語.png'));
          await tester.tap(find.byTooltip('Download 日本語.png'));
          expect(opened, 1);
          expect(downloaded, 1);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
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
            onDownload: () {},
            onShare: () {},
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
