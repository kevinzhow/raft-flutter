import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// Web v1.24 `<InlineCode appearance="message">` paints `bg-fill-muted` with
// `rounded-sticker` (4) behind inline code. The vendored Markdown builder
// merged a paragraph's inline widgets by flattening every TextSpan with
// children, so the inline code's RaftBackgroundSpan lost its fill and the
// code rendered on the bare row.

List<dynamic> _backgrounds(WidgetTester tester) => [
  for (final e in find.byType(RaftUnderlines).evaluate())
    ...((e.renderObject as dynamic).debugBackgrounds as List),
];

Future<void> _pump(WidgetTester tester, String content, bool dark) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 340,
            child: RaftMessageBody(
              content: content,
              fontSize: 14,
              lineHeight: 22,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('inline code inside a paragraph keeps its fill $mode', (
      tester,
    ) async {
      await _pump(tester, 'run `make` then `push`', dark);
      final fills = _backgrounds(tester);
      // One fill per inline code run, both on the first line.
      expect(fills, hasLength(2));
      final t = RaftTokens.of(tester.element(find.byType(RaftMessageBody)));
      for (final fill in fills) {
        expect(fill.color, isNot(Colors.transparent));
        if (t.isRaftLook) expect(fill.radius, 4);
      }
    });

    testWidgets('inline code alone in a paragraph keeps its fill $mode', (
      tester,
    ) async {
      await _pump(tester, '`solo`', dark);
      expect(_backgrounds(tester), hasLength(1));
    });
  }
}
