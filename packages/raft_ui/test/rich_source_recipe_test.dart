import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/message_content_tokens.dart';

void main() {
  test('original gallery mixed-wide and four-normal row contracts', () {
    expect(raftImageGalleryRows([(width: 100, height: 100), (width: 100, height: 100), (width: 100, height: 100), (width: 100, height: 100)]), [[0, 1], [2, 3]]);
    expect(raftImageGalleryRows([(width: 100, height: 100), (width: 300, height: 100), (width: 50, height: 200), (width: null, height: null)]), [[0], [1], [2, 3]]);
  });
  test('code tree retains function scope and enclosing string color', () {
    const source = r'function greet(name: string) { return `Hello ${name}`; }';
    final span = raftCodeSpan(source, 'typescript', const TextStyle(color: Colors.black), dark: false);
    expect(span.toPlainText(), source);
    final leaves = <(String, Color?)>[];
    void visit(InlineSpan node, TextStyle? inherited) {
      if (node is! TextSpan) return;
      final style = inherited?.merge(node.style) ?? node.style;
      if (node.text != null) leaves.add((node.text!, style?.color));
      for (final child in node.children ?? <InlineSpan>[]) { visit(child, style); }
    }
    visit(span, null);
    expect(leaves.where((v) => v.$1.contains('greet')).map((v) => v.$2), contains(const Color(0xff6f42c1)));
    expect(leaves.where((v) => v.$1.contains('Hello')).map((v) => v.$2), contains(const Color(0xff032f62)));
  });
  testWidgets('short forwarded snapshot displays every item without collapse footer', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: raftTheme(RaftFamily.elegant), home: Scaffold(body: RaftForwardedBundle(metadata: {
      'kind': 'forwarded-bundle', 'version': 1, 'forwardedItems': [
        for (var i = 0; i < 3; i++) {'contentSnapshot': 'Public message $i', 'provenanceState': 'available', 'attachmentPolicy': 'excluded'}
      ]
    }))));
    await tester.pumpAndSettle();
    expect(find.text('Public message 2', findRichText: true).hitTestable(), findsOneWidget);
    expect(find.textContaining('View all'), findsNothing);
    expect(find.text('Collapse'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final (family, dark) in [(RaftFamily.brutal, false), (RaftFamily.elegant, false), (RaftFamily.elegant, true)]) {
    testWidgets('intrinsic Markdown table, left headers and source link role $family/$dark', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: raftTheme(family, dark: dark), home: const Scaffold(body: SizedBox(width: 640, child: RaftMessageBody(content: '| Status | Count |\n|---|---|\n|Ready|3|\n\n[link](https://example.com)')))));
      final table = tester.widget<Table>(find.byType(Table));
      expect(table.defaultColumnWidth, isA<IntrinsicColumnWidth>());
      final body = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      double textWidth(String value) {
        final painter = TextPainter(text: TextSpan(text: value, style: body.styleSheet!.tableHead), textDirection: TextDirection.ltr)..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      }
      // Unit tests use Flutter's test font; validate natural content sizing,
      // while actual bundled-font pixel dimensions belong to paired captures.
      expect(tester.getSize(find.byType(Table)).width, closeTo(textWidth('Status') + textWidth('Count') + 32, 2));
      expect(body.styleSheet!.tableHeadAlign, TextAlign.left);
      expect(body.styleSheet!.a!.color, dark ? MessageContentPrimitive.linkDark : MessageContentPrimitive.linkLight);
      expect(tester.takeException(), isNull);
    });
    testWidgets('raw SVG remains file affordance; raster images keep preview $family/$dark', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: raftTheme(family, dark: dark), home: Scaffold(body: Column(children: [RaftAttachmentCard(filename: 'diagram.svg', mimeType: 'image/svg+xml', onOpen: () {}), RaftAttachmentCard(filename: 'diagram.png', mimeType: 'image/png', onOpen: () {})]))));
      expect(find.byTooltip('Preview diagram.svg'), findsNothing);
      expect(find.text('diagram.svg'), findsOneWidget);
      expect(find.byTooltip('Preview diagram.png'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('lightbox fills viewport, keeps safe chrome and closes from keyboard', (tester) async {
    var closed = 0;
    await tester.pumpWidget(MaterialApp(theme: raftTheme(RaftFamily.elegant), home: MediaQuery(data: const MediaQueryData(size: Size(800, 600), padding: EdgeInsets.only(top: 32, bottom: 24)), child: RaftAttachmentLightbox(title: 'public.png', onClose: () => closed++, child: const Center(child: Text('Public fixture'))))));
    await tester.pump();
    expect(tester.getTopLeft(find.byTooltip('Close preview')).dy, greaterThanOrEqualTo(32));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closed, 1);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(closed, 2);
    expect(tester.takeException(), isNull);
  });
}
