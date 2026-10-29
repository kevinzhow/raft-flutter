import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

typedef _Stroke = ({Rect rect, double baseline, Color color, Offset origin});

/// Every stroke painted by any [RaftUnderlines] in the tree (global space).
List<_Stroke> _strokes(WidgetTester tester) => [
  for (final element in find.byType(RaftUnderlines).evaluate())
    ...(element.renderObject! as dynamic).debugUnderlines as List<_Stroke>,
];

Widget _host(bool dark, double scale, Widget child, {double width = 1400}) =>
    MaterialApp(
      theme: raftTheme(dark: dark),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('mention and hyperlink share one baseline gap '
          '${dark ? 'dark' : 'light'}/$scale', (tester) async {
        tester.view.physicalSize = const Size(3000, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _host(
            dark,
            scale,
            RaftMessageBody(
              content: '@Cindy https://pub.dev/a 看看这个',
              onLink: (_) {},
              references: const [
                RaftTextReference(
                  text: '@Cindy',
                  href: 'raft-ref://mention/user/cindy',
                ),
              ],
              referenceAppearance: (href) =>
                  const RaftReferenceAppearance(RaftReferenceKind.mention),
            ),
          ),
        );
        final strokes = _strokes(tester);
        expect(strokes, hasLength(2), reason: 'one mention + one link stroke');
        strokes.sort((a, b) => a.origin.dx.compareTo(b.origin.dx));
        final gaps = [for (final s in strokes) s.rect.top - s.baseline];
        final metrics = RaftTokens.of(
          tester.element(find.byType(RaftUnderlines).first),
        ).underline;
        // Equal gap and thickness for the mention and the link, taken from
        // the shared tokens (2px offset, 2px stroke, scaled with the text).
        expect(gaps[0], closeTo(gaps[1], .01));
        expect(strokes[0].rect.height, strokes[1].rect.height);
        expect(strokes[0].rect.height, metrics.thickness * scale);
        expect(gaps[0], closeTo(metrics.offset * scale, .5));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('standalone text, hover-only and wrapped underlines', (
    tester,
  ) async {
    var hovered = false;
    late StateSetter set;
    await tester.pumpWidget(
      _host(
        false,
        1,
        StatefulBuilder(
          builder: (context, setState) {
            set = setState;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RaftUnderlinedText(
                  'Standalone link',
                  style: TextStyle(fontSize: 14, color: Color(0xff112233)),
                ),
                RaftUnderlinedText(
                  'Hover only',
                  underline: hovered,
                  style: const TextStyle(fontSize: 14),
                ),
                const RaftCssText(
                  'Css text link',
                  underline: true,
                  style: TextStyle(fontSize: 14, height: 20 / 14),
                ),
                const SizedBox(
                  width: 70,
                  child: RaftUnderlinedText(
                    'wrapped underlined label here',
                    style: TextStyle(fontSize: 14, height: 20 / 14),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    var strokes = _strokes(tester);
    // standalone + css text + >= 3 wrapped lines; hover-only is at rest.
    expect(strokes.length, greaterThanOrEqualTo(5));
    for (final s in strokes) {
      expect(s.rect.top - s.baseline, closeTo(2, .5));
      expect(s.rect.height, 2);
    }
    expect(
      (strokes.toList()..sort(
            (a, b) =>
                (a.origin.dy + a.rect.top).compareTo(b.origin.dy + b.rect.top),
          ))
          .first
          .color
          .toARGB32(),
      0xff112233,
    );
    final wrapped = strokes
        .where((s) => s.origin.dy + s.rect.top > 60)
        .toList();
    expect(wrapped.length, greaterThanOrEqualTo(3));
    expect(
      wrapped.map((s) => s.origin.dy + s.rect.top).toSet(),
      hasLength(wrapped.length),
    );
    final restCount = strokes.length;
    set(() => hovered = true);
    await tester.pump();
    strokes = _strokes(tester);
    expect(strokes.length, restCount + 1);
    expect(tester.takeException(), isNull);
  });
}
