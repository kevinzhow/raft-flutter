// raft-ui `TextLinkExternalIcon`: a link that leaves Raft ends in the lucide
// ArrowUpRight, never the box-with-arrow glyph.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _app(Widget link) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: link),
  ),
);

void main() {
  testWidgets('external ends in a 0.857em ArrowUpRight, stroke 2, gap 2', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        RaftTextLink(
          label: 'Read the guide',
          variant: RaftTextLinkVariant.strong,
          external: true,
          externalLabel: '(opens in a new tab)',
          onPressed: () {},
        ),
      ),
    );
    final icons = tester.widgetList<RaftIcon>(find.byType(RaftIcon)).toList();
    expect(icons.map((i) => i.glyph), [RaftGlyph.arrowUpRight]);
    // 0.857em of the label's own size.
    final label = tester.widget<Text>(find.text('Read the guide'));
    expect(icons.single.size, closeTo(label.style!.fontSize! * 0.857, .01));
    expect(icons.single.strokeWidth, 2);
    final text = tester.getRect(find.text('Read the guide'));
    final icon = tester.getRect(find.byType(RaftIcon));
    expect(icon.left - text.right, closeTo(2, .01));
    // Centred on the cap height: inside the line, above its midline by at most
    // a few pixels, never hanging below the text box.
    expect(icon.center.dy, greaterThan(text.top));
    expect(icon.center.dy, lessThan(text.bottom));
    expect(find.bySemanticsLabel(RegExp('opens in a new tab')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the hover underline stops at the text, before the arrow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        RaftTextLink(
          label: 'Read the guide',
          variant: RaftTextLinkVariant.strong,
          external: true,
          onPressed: () {},
        ),
      ),
    );
    final underlined = tester.getRect(
      find.descendant(
        of: find.byType(RaftTextLink),
        matching: find.byType(RaftUnderlinedText),
      ),
    );
    final icon = tester.getRect(find.byType(RaftIcon));
    expect(underlined.right, lessThanOrEqualTo(icon.left));
  });

  testWidgets('download uses the download glyph the same way', (tester) async {
    await tester.pumpWidget(
      _app(
        RaftTextLink(
          label: 'Get the app',
          variant: RaftTextLinkVariant.muted,
          download: true,
          onPressed: () {},
        ),
      ),
    );
    expect(
      tester.widget<RaftIcon>(find.byType(RaftIcon)).glyph,
      RaftGlyph.download,
    );
  });

  testWidgets('without the flag nothing is added', (tester) async {
    await tester.pumpWidget(
      _app(RaftTextLink(label: 'Plain', onPressed: () {})),
    );
    expect(find.byType(RaftIcon), findsNothing);
  });

  testWidgets('the connected-app URL link ends in the arrow, not the box', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const RaftConnectedAppUrlLink(url: 'https://example.com/app')),
    );
    final glyphs = tester
        .widgetList<RaftIcon>(find.byType(RaftIcon))
        .map((i) => i.glyph);
    expect(glyphs, [RaftGlyph.arrowUpRight]);
  });
}
