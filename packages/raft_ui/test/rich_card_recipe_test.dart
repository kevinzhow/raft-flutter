import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/message_content_tokens.dart';
import 'package:raft_ui/test_themes.dart';

Map<String, dynamic> publicSnapshot({String target = '#design'}) => {
  'kind': 'forwarded-bundle',
  'version': 1,
  'forwardedItems': [
    for (var i = 0; i < 3; i++)
      {
        'index': i,
        'contentSnapshot': i == 0
            ? List.generate(12, (line) => 'Public line $line').join('\n')
            : 'Public message $i',
        'sourceAuthorSnapshot': {'type': 'user', 'uniqueName': 'Author$i'},
        'sourceTargetSnapshot': {
          'type': 'channel',
          'label': target,
          'labelVisibility': 'public',
        },
        'provenanceState': 'available',
        'attachmentPolicy': 'excluded',
      },
  ],
};

void main() {
  for (final dark in raftThemeMatrix([false, true], full: true)) {
    testWidgets(
      'action fills review surface; success badge and committed identity keep source roles ${dark ? 'dark' : 'light'}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: const Scaffold(
              body: SizedBox(
                width: 640,
                child: RaftActionCard(
                  title: 'Create public channel #design',
                  state: 'executed',
                  completedBy: 'Alice',
                  details: [(label: 'Description', value: 'Review first')],
                ),
              ),
            ),
          ),
        );
        expect(tester.getSize(find.byType(RaftActionCard)).width, 640);
        // MessageEmbed `item`: 400 wide.
        expect(
          tester
              .getSize(
                find.descendant(
                  of: find.byType(RaftMessageEmbedFrame),
                  matching: find.byType(RaftSnappedDecoratedBox),
                ),
              )
              .width,
          closeTo(400, .1),
        );
        expect(find.text('Done'), findsOneWidget);
        expect(
          find.text('Committed by Alice', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('Description'), findsOneWidget);
        expect(find.text('Review first'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'forwarded source is right aligned; real expansion retains projected content ${dark ? 'dark' : 'light'}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 640,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [RaftForwardedBundle(metadata: publicSnapshot())],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final bundle = find.byType(RaftForwardedBundle);
        expect(tester.getSize(bundle).width, 560);
        // MessageEmbed header `px-3` inside the 1px hairline.
        const headerInset = 12.0 + 1;
        expect(
          tester.getTopRight(find.text('from #design')).dx,
          closeTo(tester.getTopRight(bundle).dx - headerInset, .1),
        );
        // The source label is intrinsic. An Expanded label can falsely make a
        // tight-parent test pass while loose production layouts leave a gap.
        expect(tester.getSize(find.text('from #design')).width, lessThan(200));
        expect(tester.getTopLeft(find.text('Forwarded')).dx, lessThan(40));
        expect(
          find.text('Public message 2', findRichText: true).hitTestable(),
          findsNothing,
        );
        await tester.tap(find.text('View All 3 Messages'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.text('Public message 2', findRichText: true),
        );
        expect(
          find.text('Public message 2', findRichText: true).hitTestable(),
          findsOneWidget,
        );
        expect(find.text('Collapse'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    for (final width in [320.0, 640.0]) {
      testWidgets(
        'long forwarded target stays within loose header at $width ${dark ? 'dark' : 'light'}',
        (tester) async {
          const target =
              '#a-very-long-public-channel-name-that-needs-truncation';
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RaftForwardedBundle(
                          metadata: publicSnapshot(target: target),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final bundle = tester.getRect(find.byType(RaftForwardedBundle));
          final source = find.text('from $target');
          final sourceRect = tester.getRect(source);
          final labelRect = tester.getRect(find.text('Forwarded'));
          // MessageEmbed header `px-3` inside the 1px hairline.
          const headerInset = 12.0 + 1;
          expect(bundle.width, width < 560 ? width : 560);
          expect(sourceRect.right, closeTo(bundle.right - headerInset, .1));
          // raft-ui `flex-wrap justify-between`: a source wider than what
          // is left of the line moves to its own line and truncates there
          // (label and count are `shrink-0`).
          expect(sourceRect.top, greaterThanOrEqualTo(labelRect.bottom));
          expect(sourceRect.width, greaterThan(0));
          final sourceText = tester.widget<Text>(source);
          expect(sourceText.maxLines, 1);
          expect(sourceText.overflow, TextOverflow.ellipsis);
          expect(
            find.text('Public message 2', findRichText: true).hitTestable(),
            findsNothing,
          );
          await tester.tap(find.text('View All 3 Messages'));
          await tester.pumpAndSettle();
          expect(find.text('Collapse'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      'footer hover and keyboard activation use source roles ${dark ? 'dark' : 'light'}',
      (tester) async {
        var presses = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: RaftDensityScope(
                density: RaftDensity.desktop,
                child: RaftShowMoreToggle(
                  label: 'Show More',
                  onPressed: () => presses++,
                ),
              ),
            ),
          ),
        );
        final context = tester.element(find.byType(RaftShowMoreToggle));
        final semantic = MessageContentSemantic(RaftTokens.of(context));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(700, 500));
        await mouse.moveTo(tester.getCenter(find.text('Show More')));
        await tester.pump();
        expect(
          tester.widget<Text>(find.text('Show More')).style!.color,
          semantic.toggleHover,
        );
        await mouse.removePointer();
        await tester.pump();
        expect(
          tester.widget<Text>(find.text('Show More')).style!.color,
          semantic.toggle,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(presses, 1);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'prose inherits strong role and heading margin does not double adjacent gap ${dark ? 'dark' : 'light'}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: const Scaffold(
              body: RaftMessageBody(
                content: '# Heading\n\nParagraph\n\n## Subheading\n\nMore',
              ),
            ),
          ),
        );
        final context = tester.element(find.byType(RaftMessageBody));
        final recipe = MessageContentRecipe(RaftTokens.of(context));
        expect(recipe.body.color, RaftTokens.of(context).strong);
        expect(recipe.heading(1).color, RaftTokens.of(context).strong);
        final heading = tester.getRect(
          find.text('Heading', findRichText: true),
        );
        final paragraph = tester.getRect(
          find.text('Paragraph', findRichText: true),
        );
        final subheading = tester.getRect(
          find.text('Subheading', findRichText: true),
        );
        expect(heading.top, closeTo(12, .1));
        expect(paragraph.top - heading.bottom, closeTo(4, .1));
        expect(subheading.top - paragraph.bottom, closeTo(8, .1));
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final (width, density, expectedHeight) in [
    (320.0, RaftDensity.desktop, 18.0),
    // Original ui/ShowMoreToggle has no touch min-height/padding.
    (1200.0, RaftDensity.touch, 18.0),
  ]) {
    testWidgets(
      'toggle density follows input contract at width $width/$density',
      (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(
              body: SizedBox(
                width: width,
                child: RaftDensityScope(
                  density: density,
                  child: RaftShowMoreToggle(
                    label: 'Show More',
                    onPressed: () => pressed = true,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(RaftShowMoreToggle)).height,
          expectedHeight,
        );
        await tester.tap(find.text('Show More'));
        expect(pressed, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'generic touch target keeps 48px and receives a real touch outside its 16px visual content',
    (tester) async {
      var presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RaftDensityScope(
                density: RaftDensity.touch,
                child: RaftControl(
                  visualHeight: 16,
                  onPressed: () => presses++,
                  child: const Text(
                    'Touch target',
                    style: TextStyle(fontSize: 11, height: 16 / 11),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final bounds = tester.getRect(find.byType(RaftControl));
      final text = tester.getRect(find.text('Touch target'));
      expect(bounds.height, 48);
      final point = Offset(bounds.center.dx, bounds.bottom - 2);
      expect(text.contains(point), isFalse);
      final touch = await tester.startGesture(
        point,
        kind: PointerDeviceKind.touch,
      );
      await touch.up();
      await tester.pump();
      expect(presses, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
