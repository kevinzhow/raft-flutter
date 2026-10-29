import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/lazy_markdown_document.dart';

/// About 40 KB: 60 sections of prose, a list, a code block and a link.
String fixture({int sections = 60}) => [
  for (var i = 0; i < sections; i++) ...[
    '## Section $i\n',
    'Paragraph $i with **bold** text, `inline code` and a '
            '[link $i](https://example.invalid/$i). ' *
        6,
    '',
    '- item one $i\n- item two $i\n- item three $i\n',
    '```dart\nvoid main$i() {\n  print("hello $i");\n}\n```\n',
    '> quote $i\n',
  ],
].join('\n');

Future<void> pumpDocument(
  WidgetTester tester,
  String markdown, {
  bool truncated = false,
  int? lazyChars,
  double height = 700,
}) async {
  tester.view.physicalSize = Size(900, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: RaftDocumentPreview(
          truncated: truncated,
          lazyMarkdownChars: lazyChars ?? raftLazyMarkdownChars,
          data: {'kind': 'markdown', 'markdown': markdown},
        ),
      ),
    ),
  );
}

/// Lets the parser's future complete, then builds the frame it asked for.
Future<void> settle(WidgetTester tester) async {
  await tester.pump(Duration.zero);
  await tester.pump();
}

void main() {
  late List<String> parsed;
  var released = false;
  Completer<void>? pending;

  // Lets the parser answer: waiting ones now, later ones at once.
  void release() {
    released = true;
    pending?.complete();
  }

  final defaultParser = raftMarkdownDocumentParser;

  setUp(() {
    parsed = [];
    released = false;
    pending = null;
    clearParsedMarkdownDocuments();
    raftMarkdownAstCache.clear();
    // The real parser hands the work to another isolate; here the hand-off
    // is observed and released by the test.
    raftMarkdownDocumentParser = (source) async {
      parsed.add(source);
      if (!released) await (pending = Completer<void>()).future;
      return raftParseMarkdownDocument(source);
    };
  });
  tearDown(() => raftMarkdownDocumentParser = defaultParser);

  test('the fixture is a 40 KB document', () {
    expect(fixture().length, inInclusiveRange(38 * 1024, 48 * 1024));
  });

  testWidgets('the document is parsed off the UI isolate, then built', (
    tester,
  ) async {
    final md = fixture();
    await pumpDocument(tester, md);
    // Handed to the parser; this frame parsed only the first block itself.
    expect(parsed, [md]);
    expect(find.byType(RaftMessageBody), findsOneWidget);
    expect(raftMarkdownAstCache.length, lessThan(6));
    release();
    await settle(tester);
    expect(find.text('Section 0'), findsOneWidget);
    expect(parsed, hasLength(1));
  });

  testWidgets('the first frame shows the document, never an empty sheet', (
    tester,
  ) async {
    await pumpDocument(tester, fixture());
    // The parser has not answered: the beginning is already on screen.
    expect(find.text('Section 0'), findsOneWidget);
    expect(find.text('item one 0'), findsOneWidget);
    expect(find.text('Section 59'), findsNothing);
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(300);
    await tester.pump();
    final heading = tester.getTopLeft(find.text('Section 0'));
    release();
    await settle(tester);
    // The parsed blocks take over without a jump or a scroll reset.
    expect(position.pixels, 300);
    expect(tester.getTopLeft(find.text('Section 0')), heading);
    for (var i = 0; i < 12; i++) {
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
    }
    expect(find.textContaining('quote 59', findRichText: true), findsOneWidget);
  });

  test('the first block is the first block of the full split', () {
    final md = fixture();
    expect(firstMarkdownBlock(md), raftParseMarkdownDocument(md).blocks.first);
    expect(firstMarkdownBlock('# only\n\nshort'), '# only\n\nshort');
  });

  testWidgets('the first frame builds only the blocks near the viewport', (
    tester,
  ) async {
    release();
    await pumpDocument(tester, fixture());
    await settle(tester);
    final first = find.byType(RaftMessageBody).evaluate().length;
    expect(first, inInclusiveRange(1, 4), reason: 'a screenful of 20 blocks');
    expect(find.text('Section 0'), findsOneWidget);
    expect(find.text('Section 59'), findsNothing);
    expect(raftParseMarkdownDocument(fixture()).blocks.length, greaterThan(10));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -9000));
    await tester.pump();
    expect(find.text('Section 0'), findsNothing);
    expect(find.byType(RaftMessageBody).evaluate().length, lessThan(8));
    // The list's end is estimated until its last blocks are built.
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    for (var i = 0; i < 12; i++) {
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
    }
    expect(find.textContaining('quote 59', findRichText: true), findsOneWidget);
    expect(find.text('Section 0'), findsNothing);
  });

  testWidgets('building a block parses nothing: the isolate delivered it', (
    tester,
  ) async {
    release();
    await pumpDocument(tester, fixture());
    await settle(tester);
    final misses = raftMarkdownAstCache.misses;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pump();
    expect(find.byType(RaftMessageBody), findsWidgets);
    expect(
      raftMarkdownAstCache.misses,
      misses,
      reason: 'every prose chunk came from the isolate',
    );
  });

  testWidgets('reopening the same document needs no second parse', (
    tester,
  ) async {
    release();
    final md = fixture();
    await pumpDocument(tester, md);
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    raftMarkdownAstCache.clear();
    await pumpDocument(tester, md);
    // Content on the very first frame, from the cache.
    expect(find.text('Section 0'), findsOneWidget);
    expect(parsed, hasLength(1));
  });

  testWidgets('the real parser runs in a worker and matches the sync one', (
    tester,
  ) async {
    final md = fixture();
    final sync = raftParseMarkdownDocument(md);
    final worker = (await tester.runAsync(
      () => defaultParser(md).timeout(const Duration(seconds: 30)),
    ))!;
    expect(worker.blocks, sync.blocks);
    expect(worker.bodies, hasLength(sync.bodies.length));
    expect(worker.blocks.join('\n').length, greaterThan(md.length * 0.9));
  });

  testWidgets('a source that changes is parsed again', (tester) async {
    release();
    await pumpDocument(tester, fixture());
    await settle(tester);
    await pumpDocument(tester, fixture(sections: 70));
    await settle(tester);
    expect(parsed, hasLength(2));
    expect(find.text('Section 0'), findsOneWidget);
  });

  testWidgets('a parser that fails falls back to parsing in place', (
    tester,
  ) async {
    raftMarkdownDocumentParser = (_) async => throw StateError('no worker');
    await pumpDocument(tester, fixture());
    await settle(tester);
    expect(find.text('Section 0'), findsOneWidget);
  });

  testWidgets('a small document stays one column, parsed in place', (
    tester,
  ) async {
    await pumpDocument(tester, fixture(sections: 3));
    expect(find.byType(RaftLazyMarkdownDocument), findsNothing);
    expect(parsed, isEmpty);
    expect(find.text('Section 2'), findsOneWidget);
  });

  testWidgets('links, headings, lists and code blocks render in a block', (
    tester,
  ) async {
    release();
    await pumpDocument(tester, fixture());
    await settle(tester);
    expect(find.text('Section 0'), findsOneWidget);
    expect(find.text('item one 0'), findsOneWidget);
    expect(find.byKey(const ValueKey('code-container')), findsWidgets);
    final links = <String>[];
    void visit(InlineSpan span) {
      if (span is TextSpan) {
        if (span.recognizer is TapGestureRecognizer) {
          links.add(span.toPlainText());
        }
        span.children?.forEach(visit);
      }
    }

    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      visit(rich.text);
    }
    expect(links, contains('link 0'));
  });

  testWidgets('a truncated preview keeps its notice above the first block', (
    tester,
  ) async {
    release();
    await pumpDocument(tester, fixture(), truncated: true);
    await settle(tester);
    expect(find.text('Preview truncated. Download the full file.'), findsOne);
    expect(find.text('Section 0'), findsOneWidget);
  });

  group('selection and copy', () {
    Future<String?> copyDrag(
      WidgetTester tester, {
      required int lazyChars,
      bool all = false,
    }) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      release();
      await pumpDocument(tester, fixture(), lazyChars: lazyChars, height: 6000);
      await settle(tester);
      if (all) {
        final area = tester.state<SelectableRegionState>(
          find.byType(SelectableRegion).first,
        );
        area.selectAll(SelectionChangedCause.toolbar);
        // The sheet builds every block, then selects them.
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        // ignore: deprecated_member_use -- the key shortcut needs a desktop platform
        area.copySelection(SelectionChangedCause.toolbar);
        await tester.pump();
        return copied;
      }
      final from =
          tester.getTopLeft(find.text('Section 0')) + const Offset(1, 5);
      final to =
          tester.getBottomRight(
            find.textContaining('quote 14', findRichText: true).first,
          ) -
          const Offset(1, 5);
      final gesture = await tester.startGesture(
        from,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveTo(to);
      await tester.pump();
      await gesture.up();
      await tester.pump();
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion).first,
      );
      // ignore: deprecated_member_use -- the key shortcut needs a desktop platform
      region.copySelection(SelectionChangedCause.toolbar);
      await tester.pump();
      return copied;
    }

    testWidgets('a drag across blocks copies what the single column copies', (
      tester,
    ) async {
      final single = await copyDrag(tester, lazyChars: 1 << 30);
      expect(find.byType(RaftLazyMarkdownDocument), findsNothing);
      expect(single, contains('quote 14'));
      await tester.pumpWidget(const SizedBox());
      clearParsedMarkdownDocuments();
      final lazy = await copyDrag(tester, lazyChars: 100);
      expect(find.byType(RaftLazyMarkdownDocument), findsOneWidget);
      expect(lazy, single);
    });

    testWidgets('Select All then Copy takes the whole document, built or not', (
      tester,
    ) async {
      final single = await copyDrag(tester, lazyChars: 1 << 30, all: true);
      expect(single, contains('quote 59'));
      await tester.pumpWidget(const SizedBox());
      clearParsedMarkdownDocuments();
      final lazy = await copyDrag(tester, lazyChars: 100, all: true);
      expect(find.byType(RaftLazyMarkdownDocument), findsOneWidget);
      expect(lazy, single);
    });

    testWidgets('after a Select All the sheet is lazy again once cleared', (
      tester,
    ) async {
      release();
      await pumpDocument(tester, fixture(), height: 6000);
      await settle(tester);
      final built = find
          .byType(RaftMessageBody, skipOffstage: false)
          .evaluate()
          .length;
      final area = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion).first,
      );
      area.selectAll(SelectionChangedCause.toolbar);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        find.byType(RaftMessageBody, skipOffstage: false).evaluate().length,
        greaterThan(10),
      );
      area.clearSelection();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        find.byType(RaftMessageBody, skipOffstage: false).evaluate().length,
        built,
      );
    });
  });
}
