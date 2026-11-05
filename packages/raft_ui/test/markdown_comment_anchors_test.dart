import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/lazy_markdown_document.dart';
import 'package:raft_ui/src/markdown_comment_anchors.dart';

const document =
    '# Guide\n\nBefore usage.\n\n## **Usage** `API`\n\nSelect this paragraph.\n\n## Usage API\n\nSecond usage paragraph.';

const fencedDocument = '''
# Anchor Roundtrip QA

A synthetic attachment, containing no account data.

## Shared Section

First occurrence: alpha target. The second section must not jump here.

```text
## This is a code example, not a real heading
```

## Shared Section

Second occurrence: beta target. Web and Flutter must preserve this exact section.

### 中文标题 Café

Unicode target: 你好，世界。The stored heading must match the original Web outline.
''';

Future<RaftAttachmentCommentState> open(
  WidgetTester t,
  String source, {
  TargetPlatform platform = TargetPlatform.android,
  Size size = const Size(856, 944),
  bool enabled = true,
  int lazyChars = 4096,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final session = RaftAttachmentCommentState()..commentMode = enabled;
  addTearDown(session.dispose);
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform),
      home: Scaffold(
        body: RaftAttachmentCommentScope(
          state: session,
          child: RaftDocumentPreview(
            data: {'kind': 'markdown', 'markdown': source},
            lazyMarkdownChars: lazyChars,
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return session;
}

List<RenderParagraph> paragraphs(WidgetTester t) {
  final list = <RenderParagraph>[];
  void visit(RenderObject object) {
    if (object is RenderParagraph) list.add(object);
    object.visitChildren(visit);
  }

  visit(t.renderObject(find.byType(RaftDocumentPreview)));
  return list;
}

Rect textRect(WidgetTester t, String text) {
  final p = paragraphs(t)
      .firstWhere((p) => p.text.toPlainText().contains(text));
  final start = p.text.toPlainText().indexOf(text);
  return p
      .getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + text.length),
      )
      .map((box) => box.toRect().shift(p.localToGlobal(Offset.zero)))
      .reduce((a, b) => a.expandToInclude(b));
}

Future<void> select(WidgetTester t, String text, {bool reverse = false}) async {
  final rect = textRect(t, text);
  final start = Offset(rect.left + 1, rect.center.dy);
  final end = Offset(rect.right - 1, rect.center.dy);
  final gesture = await t.startGesture(
    reverse ? end : start,
    kind: PointerDeviceKind.mouse,
  );
  await t.pump();
  await gesture.moveTo(reverse ? start : end);
  await t.pump();
  await gesture.up();
  await t.pump();
  await t.pump();
}

Map<String, dynamic> anchor(String id, {String title = 'Usage API'}) => {
  'type': 'md-section',
  'data': {
    'headingId': id,
    'headingTitle': title,
    'quote': 'Web-created context',
  },
};

void main() {
  final parser = raftMarkdownDocumentParser;
  setUpAll(
    () =>
        raftMarkdownDocumentParser = (s) async => raftParseMarkdownDocument(s),
  );
  tearDownAll(() => raftMarkdownDocumentParser = parser);

  for (final selection in [
    ('Second occurrence:', 'shared-section-2'),
    ('Unicode target:', '中文标题-cafe'),
  ]) {
    for (final reverse in [false, true]) {
      testWidgets(
        'desktop selection after a fence belongs to ${selection.$2}, reverse=$reverse',
        (t) async {
          final session = await open(
            t,
            fencedDocument,
            platform: TargetPlatform.linux,
            size: const Size(856, 944),
          );
          await select(t, selection.$1, reverse: reverse);
          expect(session.pendingAnchor?['data']['headingId'], selection.$2);
          expect(session.pendingAnchor?['data']['quote'], selection.$1);
        },
      );
    }
  }

  testWidgets('reverse selection across a fence keeps the intervening code', (
    t,
  ) async {
    final session = await open(
      t,
      fencedDocument,
      platform: TargetPlatform.linux,
    );
    final first = textRect(t, 'First occurrence:');
    final last = textRect(t, 'Unicode target:');
    final gesture = await t.startGesture(
      Offset(last.right - 1, last.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await t.pump();
    await gesture.moveTo(Offset(first.left + 1, first.center.dy));
    await t.pump();
    await gesture.up();
    await t.pump();
    await t.pump();
    expect(session.pendingAnchor?['data']['headingId'], 'shared-section');
    final quote = session.pendingAnchor?['data']['quote'] as String;
    expect(quote, startsWith('First occurrence:'));
    expect(quote, contains('## This is a code example, not a real heading'));
    expect(quote, contains('Second occurrence: beta target.'));
    expect(quote, endsWith('Unicode target:'));
  });
  testWidgets('a horizontal code selection still scrolls at its right edge', (
    t,
  ) async {
    final code = List.filled(12, '0123456789_abcdefghij_').join();
    final session = await open(
      t,
      '# Code\n\n```text\n$code\n```\n\nAfter paragraph.',
      platform: TargetPlatform.linux,
      size: const Size(390, 844),
    );
    final viewport = find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
    );
    expect(viewport, findsOneWidget);
    final rect = t.getRect(viewport);
    final scroll = t.state<ScrollableState>(
      find.descendant(of: viewport, matching: find.byType(Scrollable)),
    );
    final before = scroll.position.pixels;
    final gesture = await t.startGesture(
      Offset(rect.left + 20, rect.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await t.pump();
    await gesture.moveTo(Offset(rect.right + 24, rect.center.dy));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(scroll.position.pixels, greaterThan(before));
    await gesture.up();
    await t.pump();
    expect(session.pendingAnchor?['data']['headingId'], 'code');
  });

  for (final size in [const Size(856, 944), const Size(944, 856)]) {
    testWidgets(
      'coarse section tap captures at $size independently of desktop width',
      (t) async {
        final session = await open(t, document, size: size);
        await t.tap(find.text('Select this paragraph.', findRichText: true));
        await t.pump();
        expect(session.pendingAnchor, {
          'type': 'md-section',
          'data': {
            'headingId': 'usage-api',
            'headingTitle': 'Usage API',
            'quote': 'Select this paragraph.',
          },
        });
        session.clearAnchor();
        expect(session.pendingAnchor, isNull);
        await t.drag(find.byType(RaftDocumentPreview), const Offset(0, -150));
        await t.pumpAndSettle();
        expect(
          session.pendingAnchor,
          isNull,
          reason: 'Scrolling is not a section tap.',
        );
      },
    );
  }
  for (final reverse in [false, true]) {
    testWidgets('narrow desktop uses actual text selection, reverse=$reverse', (
      t,
    ) async {
      final session = await open(
        t,
        document,
        platform: TargetPlatform.linux,
        size: const Size(390, 844),
      );
      await t.tap(
        find.text('Select this paragraph.', findRichText: true),
        kind: PointerDeviceKind.mouse,
      );
      await t.pump();
      expect(
        session.pendingAnchor,
        isNull,
        reason: 'A desktop click only starts a selection.',
      );
      await select(t, 'Select this', reverse: reverse);
      expect(session.pendingAnchor?['type'], 'md-section');
      expect(session.pendingAnchor?['data']['headingId'], 'usage-api');
      expect(session.pendingAnchor?['data']['quote'], 'Select this');
      session.clearAnchor();
      await t.pump();
      expect(session.pendingAnchor, isNull);
    });
  }
  testWidgets(
    'duplicate formatted headings use stable distinct IDs and live document order',
    (t) async {
      final session = await open(t, document);
      await t.tap(find.text('Second usage paragraph.', findRichText: true));
      await t.pump();
      expect(session.pendingAnchor?['data']['headingId'], 'usage-api-2');
      expect(
        session.order(anchor('usage-api')),
        lessThan(session.order(anchor('usage-api-2'))!),
      );
      expect(session.order(anchor('missing')), isNull);
      expect(session.jump(anchor('missing')), isFalse);
      expect(
        session.jump({
          'type': 'md-section',
          'data': {'headingId': 1},
        }),
        isFalse,
      );
      session.clearAnchor();
      expect(session.jump(anchor('usage-api-2')), isTrue);
      var peak = 0;
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 100));
        final colors = t
            .widgetList<ColoredBox>(
              find.descendant(
                of: find.byType(RaftMarkdownAnchorBlock),
                matching: find.byType(ColoredBox),
              ),
            )
            .where((box) => box.color.a > 0)
            .length;
        if (colors > peak) peak = colors;
      }
      expect(peak, greaterThan(0));
      await t.pump(const Duration(seconds: 2));
      expect(
        t
            .widgetList<ColoredBox>(
              find.descendant(
                of: find.byType(RaftMarkdownAnchorBlock),
                matching: find.byType(ColoredBox),
              ),
            )
            .where((box) => box.color.a > 0),
        isEmpty,
      );
    },
  );
  testWidgets(
    'text before the first heading and comment mode off capture nothing',
    (t) async {
      final session = await open(
        t,
        'Unsectioned preface.\n\n# Heading\n\nBody.',
      );
      await t.tap(find.text('Unsectioned preface.', findRichText: true));
      await t.pump();
      expect(session.pendingAnchor, isNull);
      session.commentMode = false;
      await t.tap(find.text('Body.', findRichText: true));
      await t.pump();
      expect(session.pendingAnchor, isNull);
    },
  );
  testWidgets(
    'a Web anchor reveals the proper late duplicate in a lazy document',
    (t) async {
      final source = [
        for (var i = 1; i <= 55; i++)
          '## Same\n\nSection $i content. ${'More words. ' * 40}\n',
      ].join('\n');
      final session = await open(t, source);
      expect(
        find.textContaining('Section 50 content.', findRichText: true),
        findsNothing,
      );
      expect(session.jump(anchor('same-50', title: 'Same')), isTrue);
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      final entry = find.byWidgetPredicate(
        (w) =>
            w is RaftMarkdownAnchorBlock && w.heading && w.item.id == 'same-50',
      );
      expect(entry, findsOneWidget);
      expect(t.getCenter(entry).dy, inInclusiveRange(0, 944));
      expect(
        session.order(anchor('same-50')),
        greaterThan(session.order(anchor('same-2'))!),
      );
      await t.pump(const Duration(seconds: 3));
    },
  );
  testWidgets(
    'closing a document cancels pending lazy jumps and detaches its authority',
    (t) async {
      final parse = Completer<RaftParsedMarkdown>();
      raftMarkdownDocumentParser = (_) => parse.future;
      addTearDown(
        () =>
            raftMarkdownDocumentParser = (s) async =>
                raftParseMarkdownDocument(s),
      );
      final source = document + '\n\n' + 'paragraph\n\n' * 1000;
      final session = await open(t, source);
      expect(session.jump(anchor('usage-api-2')), isTrue);
      await t.pumpWidget(const SizedBox());
      await t.pump();
      expect(session.jump(anchor('usage-api-2')), isFalse);
      expect(session.order(anchor('usage-api')), isNull);
      parse.complete(raftParseMarkdownDocument(source));
      await t.pump(const Duration(seconds: 3));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Setext and same-named body text cannot steal an ATX section ID',
    (t) async {
      final session = await open(
        t,
        '# Start\n\nUsage API\n\n## **Usage** `API`\n\nActual first section.\n\nSetext\n------\n\nStill the first ATX section.\n\n## Usage API\n\nActual second section.',
      );
      await t.tap(
        find.text('Still the first ATX section.', findRichText: true),
      );
      await t.pump();
      expect(session.pendingAnchor?['data']['headingId'], 'usage-api');
      await t.tap(find.text('Actual second section.', findRichText: true));
      await t.pump();
      expect(session.pendingAnchor?['data']['headingId'], 'usage-api-2');
    },
  );
  testWidgets(
    'code selection inherits the preceding section and preserves copied text',
    (t) async {
      final session = await open(
        t,
        '# Code\n\n```dart\nfinal value = 42;\n```',
        platform: TargetPlatform.linux,
        size: const Size(390, 844),
      );
      await select(t, 'value = 42');
      expect(session.pendingAnchor?['data']['headingId'], 'code');
      expect(session.pendingAnchor?['data']['quote'], 'value = 42');
    },
  );
  testWidgets(
    'a replaced document retires stale pending locations and live order',
    (t) async {
      final session = await open(t, document);
      await t.tap(find.text('Second usage paragraph.', findRichText: true));
      await t.pump();
      expect(session.pendingAnchor?['data']['headingId'], 'usage-api-2');
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: RaftAttachmentCommentScope(
              state: session,
              child: const RaftDocumentPreview(
                data: {
                  'kind': 'markdown',
                  'markdown': '# Replacement\n\nOther content.',
                },
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(session.pendingAnchor, isNull);
      expect(session.jump(anchor('usage-api-2')), isFalse);
      expect(session.order(anchor('usage-api-2')), isNull);
    },
  );
  testWidgets(
    'Japanese formatted duplicate headings capture and accept the Web NFKD ID',
    (t) async {
      final session = await open(
        t,
        '# **ガイド**\n\nFirst guide.\n\n## ガイド\n\nSecond guide.',
      );
      await t.tap(find.text('Second guide.', findRichText: true));
      await t.pump();
      expect(session.pendingAnchor?['data'], {
        'headingId': 'カ-イト-2',
        'headingTitle': 'ガイド',
        'quote': 'Second guide.',
      });
      expect(session.jump(anchor('カ-イト', title: 'ガイド')), isTrue);
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await t.pump(const Duration(seconds: 3));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'selection starting before the first heading does not retarget to a later section',
    (t) async {
      final session = await open(
        t,
        'Unsectioned preface.\n\n# Heading\n\nBody.',
        platform: TargetPlatform.linux,
        size: const Size(390, 844),
      );
      final first = textRect(t, 'Unsectioned preface.');
      final last = textRect(t, 'Body.');
      final gesture = await t.startGesture(
        Offset(first.left + 1, first.center.dy),
        kind: PointerDeviceKind.mouse,
      );
      await t.pump();
      await gesture.moveTo(Offset(last.right - 1, last.center.dy));
      await t.pump();
      await gesture.up();
      await t.pump();
      await t.pump();
      expect(
        paragraphs(t)
            .firstWhere(
              (p) => p.text.toPlainText().contains('Unsectioned preface.'),
            )
            .selections
            .any((s) => !s.isCollapsed),
        isTrue,
      );
      expect(session.pendingAnchor, isNull);
    },
  );
}
