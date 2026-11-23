import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('an edit retains unchanged paragraphs and updates link taps', (
    tester,
  ) async {
    final links = <String>[];
    Widget view(String revision, String href) => MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: RaftMessageBody(
          content: 'First paragraph.\n\n$revision\n\n[Open details]($href)',
          onLink: links.add,
        ),
      ),
    );
    final first = find.text('First paragraph.', findRichText: true);
    final link = find.text('Open details', findRichText: true);
    try {
      await tester.pumpWidget(
        view('Before the edit.', 'https://example.com/a'),
      );
      final paragraph = tester.renderObject<RenderParagraph>(first);
      await tester.tap(link);
      await tester.pump();
      await tester.pumpWidget(view('After the edit.', 'https://example.com/b'));
      expect(tester.renderObject<RenderParagraph>(first), same(paragraph));
      await tester.tap(link);
      await tester.pump();
      expect(links, ['https://example.com/a', 'https://example.com/b']);
      expect(find.text('After the edit.', findRichText: true), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    }
  });
}
