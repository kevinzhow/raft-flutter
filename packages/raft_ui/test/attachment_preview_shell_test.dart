import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final family in RaftFamily.values) {
    testWidgets('$family wide shell: comments toggle opens the 320px aside', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family),
          home: RaftAttachmentPreviewShell(
            filename: 'notes.txt',
            onClose: () {},
            copyText: 'hello',
            commentsBuilder: (_, sheet) {
              expect(sheet, isNull);
              return const Text('panel');
            },
            child: const Text('body'),
          ),
        ),
      );
      expect(find.text('notes.txt'), findsOneWidget);
      expect(find.text('TXT'), findsOneWidget);
      expect(find.text('panel'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('attachment-preview-mode')));
      await tester.pumpAndSettle();
      expect(find.text('panel'), findsOneWidget);
      expect(
        tester
            .getSize(
              find.ancestor(
                of: find.text('panel'),
                matching: find.byType(RaftLightboxAside),
              ),
            )
            .width,
        raftLightboxAsideWidth,
      );
    });

    testWidgets('$family narrow shell: the sheet starts collapsed', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      RaftCommentsSheetControls? seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family),
          home: RaftAttachmentPreviewShell(
            filename: 'notes.txt',
            onClose: () {},
            commentsBuilder: (_, sheet) {
              seen = sheet;
              return const SizedBox();
            },
            child: const Text('body'),
          ),
        ),
      );
      expect(seen, isNotNull);
      expect(seen!.expanded, isFalse);
    });
  }

  // Android edge-to-edge: the collapsed comments bar ("Comments · file" and
  // its expand button) must sit entirely above the gesture / navigation bar,
  // for the page and the full-bleed dialog form, at every text scale.
  for (final family in RaftFamily.values) {
    for (final page in [true, false]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '$family ${page ? 'page' : 'dialog'} ${scale}x: collapsed comments '
          'bar clears a 34px bottom inset',
          (tester) async {
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            const inset = 34.0;
            await tester.pumpWidget(
              MaterialApp(
                theme: raftTheme(family),
                builder: (context, child) => MediaQuery(
                  data: MediaQueryData(
                    size: const Size(390, 844),
                    padding: const EdgeInsets.only(top: 24, bottom: inset),
                    viewPadding: const EdgeInsets.only(top: 24, bottom: inset),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: child!,
                ),
                home: const SizedBox(),
              ),
            );
            Widget shell() => RaftAttachmentPreviewShell(
              page: page,
              filename: 'report.html',
              onClose: () {},
              commentsBuilder: (_, sheet) => RaftAttachmentCommentsPanel(
                filename: 'report.html',
                comments: const [],
                composer: const SizedBox(),
                sheet: sheet,
                collapsedBody: !sheet!.expanded,
              ),
              child: const Text('body'),
            );
            final navigator = tester.state<NavigatorState>(
              find.byType(Navigator),
            );
            navigator.push(
              page
                  ? RaftPreviewPageRoute<void>(
                      builder: (_) => Scaffold(body: shell()),
                    )
                  : RaftFullBleedDialogRoute<void>(
                      context: tester.element(find.byType(SizedBox).first),
                      builder: (_) => shell(),
                    ),
            );
            await tester.pumpAndSettle();
            const limit = 844 - inset;
            final toggle = tester.getRect(
              find.byKey(const ValueKey('attachment-comments-sheet-toggle')),
            );
            final title = tester.getRect(find.text('Comments · report.html'));
            // The bar's own 8px padding below its content also stays clear.
            expect(toggle.bottom + 8, lessThanOrEqualTo(limit));
            expect(title.bottom + 8, lessThanOrEqualTo(limit));
            expect(toggle.top, greaterThan(0));
          },
        );
      }
    }
  }
}
