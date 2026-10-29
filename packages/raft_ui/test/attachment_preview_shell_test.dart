import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  testWidgets('wide shell: comments toggle opens the 320px aside', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: packForThemeId(elegantThemePackId)),
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
  }, skip: raftLookSkip(raftLookElegant));

  testWidgets('narrow shell: the sheet starts collapsed', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    RaftCommentsSheetControls? seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: packForThemeId(elegantThemePackId)),
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
  }, skip: raftLookSkip(raftLookElegant));

  for (final dark in [false, true]) {
    for (final scale in [1.0, 3.1]) {
      testWidgets('toolbar file label stays compact at ${scale}x dark=$dark', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(raftThemePackId), dark: dark),
            builder: (_, child) => MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: RaftLightboxHeader(
                  title: 'research.md',
                  leading: const RaftFileTypeBadge(
                    filename: 'research.md',
                    headerLabel: true,
                  ),
                  onClose: () {},
                ),
              ),
            ),
          ),
        );
        final label = tester.getRect(find.byType(RaftFileTypeBadge));
        final header = tester.getRect(find.byType(RaftLightboxHeader));
        final text = tester.getRect(find.text('MD'));
        // Web headerLabel is h-[22px], centred within a 56px toolbar.
        // Larger text grows the label, without stretching its fill to the bar.
        if (scale == 1) expect(label.height, 22);
        if (scale > 1) expect(label.height, greaterThan(22));
        expect(label.top, greaterThan(header.top));
        expect(label.bottom, lessThan(header.bottom));
        expect(label.contains(text.topLeft), isTrue);
        expect(
          label.contains(text.bottomRight - const Offset(.01, .01)),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  // Android edge-to-edge: the collapsed comments bar ("Comments · file" and
  // its expand button) must sit entirely above the gesture / navigation bar,
  // for the page and the full-bleed dialog form, at every text scale.
  for (final page in [true, false]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('${page ? 'page' : 'dialog'} ${scale}x: collapsed comments '
          'bar clears a 34px bottom inset', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const inset = 34.0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(elegantThemePackId)),
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
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
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
      }, skip: raftLookSkip(raftLookElegant));
    }
  }
}
