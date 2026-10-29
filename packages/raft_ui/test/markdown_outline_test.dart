// Web MarkdownPreviewPane: an "Outline" of the h1-h3 headings beside the
// document from `xl` (1280) up; an item scrolls the document to its heading.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/lazy_markdown_document.dart';

String _section(int n, {String? title}) =>
    '## ${title ?? 'Section $n'}\n\n${List.filled(6, 'Paragraph text of section $n goes here and goes on a little.').join('\n\n')}\n';

String _document(int sections, {Map<int, String> titles = const {}}) =>
    '# Guide\n\n${[for (var i = 1; i <= sections; i++) _section(i, title: titles[i])].join('\n')}';

Future<ScrollController> _pump(
  WidgetTester tester,
  String markdown, {
  double width = 1400,
  int lazyChars = 4096,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: RaftDocumentPreview(
          data: {'kind': 'markdown', 'markdown': markdown},
          lazyMarkdownChars: lazyChars,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return PrimaryScrollController.of(tester.element(find.byType(Scaffold)));
}

double _offset(WidgetTester tester) => tester
    .widgetList<Scrollable>(find.byType(Scrollable))
    .map((s) => s.controller?.hasClients == true ? s.controller!.offset : 0.0)
    .fold(0.0, (a, b) => a > b ? a : b);

void main() {
  // The off-thread parse of a long document runs in place under test.
  final parser = raftMarkdownDocumentParser;
  setUpAll(
    () =>
        raftMarkdownDocumentParser = (s) async => raftParseMarkdownDocument(s),
  );
  tearDownAll(() => raftMarkdownDocumentParser = parser);
  group('raftExtractMarkdownOutline (Web markdownPreviewOutline.test)', () {
    test(
      'h1-h3 with stable duplicate ids, fences and deeper levels skipped',
      () {
        final outline = raftExtractMarkdownOutline(
          [
            '# Title',
            '',
            '```',
            '# ignored code heading',
            '```',
            '## Usage `API`',
            '### [Usage API](https://example.com)',
            '#### Too deep',
            '## Usage API',
          ].join('\n'),
        );
        expect(outline, const [
          RaftMarkdownOutlineItem(
            id: 'title',
            level: 1,
            sourceLine: 1,
            title: 'Title',
          ),
          RaftMarkdownOutlineItem(
            id: 'usage-api',
            level: 2,
            sourceLine: 6,
            title: 'Usage API',
          ),
          RaftMarkdownOutlineItem(
            id: 'usage-api-2',
            level: 3,
            sourceLine: 7,
            title: 'Usage API',
          ),
          RaftMarkdownOutlineItem(
            id: 'usage-api-3',
            level: 2,
            sourceLine: 9,
            title: 'Usage API',
          ),
        ]);
      },
    );

    test('indented code, tilde fences and empty titles are not headings', () {
      final outline = raftExtractMarkdownOutline(
        '    # indented\n~~~\n# in tilde fence\n~~~\n## \n##   \n## Real ##\n',
      );
      expect([for (final i in outline) i.title], ['Real']);
    });

    test('slugs keep letters and numbers of any script and fold accents', () {
      final ids = [
        for (final i in raftExtractMarkdownOutline(
          '# Café déjà vu\n# 中文 标题\n# !!!\n# ---\n',
        ))
          i.id,
      ];
      expect(ids, ['cafe-deja-vu', '中文-标题', 'section', 'section-2']);
    });
  });

  group('the preview', () {
    testWidgets('shows the Outline from 1280 wide and not below', (
      tester,
    ) async {
      await _pump(tester, _document(6), width: 1400);
      expect(find.byKey(const ValueKey('markdown-outline')), findsOneWidget);
      expect(find.text('Outline'), findsOneWidget);
      expect(find.byKey(const ValueKey('outline-section-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('outline-guide')), findsOneWidget);
      await _pump(tester, _document(6), width: 1000);
      expect(find.byKey(const ValueKey('markdown-outline')), findsNothing);
    });

    testWidgets('a document without headings has no Outline', (tester) async {
      await _pump(tester, 'Just a paragraph.\n\nAnother one.', width: 1400);
      expect(find.byKey(const ValueKey('markdown-outline')), findsNothing);
    });

    testWidgets('heading levels indent their items', (tester) async {
      await _pump(tester, '# One\n\n## Two\n\n### Three\n\ntext', width: 1400);
      double left(String id) => tester
          .getTopLeft(
            find.descendant(
              of: find.byKey(ValueKey('outline-$id')),
              matching: find.byType(Text),
            ),
          )
          .dx;
      expect(left('two') - left('one'), 12);
      expect(left('three') - left('one'), 24);
    });

    testWidgets('an item scrolls the document to its heading', (tester) async {
      await _pump(tester, _document(30), width: 1400);
      expect(_offset(tester), 0);
      await tester.tap(find.byKey(const ValueKey('outline-section-20')));
      await tester.pumpAndSettle();
      expect(_offset(tester), greaterThan(0));
      // The heading is now in view, near the top.
      final heading = find.text('Section 20');
      expect(heading, findsWidgets);
      final y = tester
          .getTopLeft(
            find
                .descendant(of: find.byType(RaftMessageBody), matching: heading)
                .first,
          )
          .dy;
      expect(y, inInclusiveRange(0, 200));
    });

    testWidgets('a repeated title takes its own heading', (tester) async {
      await _pump(
        tester,
        _document(30, titles: {5: 'Notes', 25: 'Notes'}),
        width: 1400,
      );
      await tester.tap(find.byKey(const ValueKey('outline-notes-2')));
      await tester.pumpAndSettle();
      final scrolledToSecond = _offset(tester);
      await tester.tap(find.byKey(const ValueKey('outline-notes')));
      await tester.pumpAndSettle();
      expect(_offset(tester), lessThan(scrolledToSecond));
    });

    testWidgets(
      'a long document builds the blocks it needs to reach a heading',
      (tester) async {
        final markdown = _document(120);
        expect(markdown.length, greaterThan(raftLazyMarkdownChars));
        await _pump(tester, markdown, width: 1400);
        expect(find.byType(RaftLazyMarkdownDocument), findsOneWidget);
        // The 120 items overflow the column: it scrolls on its own.
        await tester.ensureVisible(
          find.byKey(const ValueKey('outline-section-100')),
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('outline-section-100')));
        await tester.pumpAndSettle();
        expect(_offset(tester), greaterThan(1000));
        expect(
          find.descendant(
            of: find.byType(RaftMessageBody),
            matching: find.text('Section 100'),
          ),
          findsWidgets,
        );
      },
    );
  });
}
