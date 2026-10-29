@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/lazy_markdown_document.dart';

Future<void> pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(900, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('a long text builds only the lines near the viewport', (
    tester,
  ) async {
    final text = List.generate(50000, (i) => 'line number $i').join('\n');
    await pump(
      tester,
      RaftDocumentPreview(data: {'kind': 'text', 'text': text}),
    );
    expect(find.text('line number 0'), findsOneWidget);
    expect(find.text('line number 40000'), findsNothing);
    final built = find.byType(Text).evaluate().length;
    expect(built, lessThan(120), reason: 'a screenful, not 50 000 lines');
    await tester.drag(
      find.byKey(const ValueKey('lazy-text-lines')),
      const Offset(0, -200000),
    );
    await tester.pump();
    expect(find.text('line number 0'), findsNothing);
  });

  testWidgets('a short text keeps the single selectable box', (tester) async {
    await pump(
      tester,
      const RaftDocumentPreview(data: {'kind': 'text', 'text': 'a\nb\nc'}),
    );
    expect(find.byKey(const ValueKey('lazy-text-lines')), findsNothing);
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('a long Markdown is blocks on one sheet, built on demand', (
    tester,
  ) async {
    final md = [
      for (var i = 0; i < 2000; i++)
        '## Section $i\n\nParagraph $i with **bold** text and a [link](https://example.invalid).\n',
    ].join('\n');
    expect(md.length, greaterThan(raftLazyMarkdownChars));
    final defaultParser = raftMarkdownDocumentParser;
    raftMarkdownDocumentParser = (source) async =>
        raftParseMarkdownDocument(source);
    addTearDown(() => raftMarkdownDocumentParser = defaultParser);
    await pump(
      tester,
      RaftDocumentPreview(data: {'kind': 'markdown', 'markdown': md}),
    );
    await tester.pump(Duration.zero);
    await tester.pump();
    expect(find.text('Section 0'), findsOneWidget);
    expect(find.text('Section 1900'), findsNothing);
    expect(find.byType(RaftMessageBody).evaluate().length, lessThan(20));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300000));
    await tester.pump();
    expect(find.text('Section 0'), findsNothing);
  });

  testWidgets('a long CSV is fixed-height rows under a header', (tester) async {
    final rows = [
      for (var i = 0; i < 5000; i++) ['$i', 'Name $i', '${i * 2}'],
    ];
    await pump(
      tester,
      RaftDocumentPreview(
        data: {
          'kind': 'csv',
          'headers': ['id', 'name', 'amount'],
          'rows': rows,
          'rowCount': rows.length,
          'columnCount': 3,
        },
      ),
    );
    expect(find.byKey(const ValueKey('lazy-csv-rows')), findsOneWidget);
    expect(find.text('amount'), findsOneWidget);
    expect(find.text('Name 0'), findsOneWidget);
    expect(find.text('Name 4000'), findsNothing);
    expect(find.text('Showing 5000 of 5000 rows'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('lazy-csv-rows')),
      const Offset(0, -100000),
    );
    await tester.pump();
    expect(find.text('Name 0'), findsNothing);
    expect(find.text('amount'), findsOneWidget, reason: 'the header stays');
  });

  testWidgets('the unavailable panel gives the reason and the actions', (
    tester,
  ) async {
    var opened = 0, downloaded = 0, retried = 0;
    await pump(
      tester,
      RaftPreviewUnavailable(
        filename: 'budget.xlsx',
        meta: 'XLSX · 12 MB',
        reason: 'This file is too large to open here. Download it instead.',
        onOpen: () => opened++,
        onDownload: () => downloaded++,
        onRetry: () => retried++,
      ),
    );
    expect(
      find.text('This file is too large to open here. Download it instead.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('preview-open-system')));
    await tester.tap(find.byKey(const ValueKey('preview-download')));
    await tester.tap(find.byKey(const ValueKey('preview-retry')));
    expect((opened, downloaded, retried), (1, 1, 1));
  });

  testWidgets('the notice names the shown part and the way to the rest', (
    tester,
  ) async {
    var opened = 0;
    await pump(
      tester,
      RaftPreviewNotice(
        message: 'Large file: showing the first 26214 lines.',
        onOpen: () => opened++,
        onDownload: () {},
      ),
    );
    expect(
      find.text('Large file: showing the first 26214 lines.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('preview-open-system')));
    expect(opened, 1);
  });

  test('the Chinese notice is Kevin\'s wording', () {
    expect(
      raftChinese['Large file: showing the first {count} lines.'],
      '文件较大，已显示前 {count} 行',
    );
  });
}
