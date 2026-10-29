import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

Widget host(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 200,
        height: 100,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  ),
);

Color? fillOf(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(RaftSeparator),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).color;
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'Raft look: hairline 1px, ignores a caller colour (dark=$dark)',
      (tester) async {
        final theme = raftTheme(dark: dark);
        await tester.pumpWidget(
          host(theme, const RaftSeparator(color: Color(0xFFFF0000))),
        );
        final hairline = theme.extension<RaftTokens>()!.ui.lineHairline;
        expect(tester.getSize(find.byType(RaftSeparator)), const Size(200, 1));
        expect(fillOf(tester), hairline);
      },
    );

    testWidgets('vertical takes the row height and 1px width (dark=$dark)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          raftTheme(dark: dark),
          const Row(
            children: [
              SizedBox(height: 40, child: RaftSeparator(axis: Axis.vertical)),
            ],
          ),
        ),
      );
      expect(tester.getSize(find.byType(RaftSeparator)), const Size(1, 40));
    });

    testWidgets('a label sits between two lines (dark=$dark)', (tester) async {
      await tester.pumpWidget(
        host(raftTheme(dark: dark), const RaftSeparator(label: 'Actions')),
      );
      expect(find.text('Actions'), findsOneWidget);
      expect(find.byType(DecoratedBox), findsWidgets);
    });
  }

  testWidgets('Elegant paints exactly what Divider painted', (tester) async {
    Future<List<int>> render(Widget line, double width, double height) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(elegantThemePackId)),
          home: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: const Color(0xFFFFFFFF),
              child: SizedBox(width: width, height: height, child: line),
            ),
          ),
        ),
      );
      late List<int> bytes;
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3);
        bytes = (await image.toByteData())!.buffer.asUint8List();
        image.dispose();
      });
      return bytes;
    }

    for (final (thickness, color) in [
      (null, null),
      (1.0, const Color(0xFF123456)),
      (2.0, null),
    ]) {
      final before = await render(
        Divider(height: 1, thickness: thickness, color: color),
        100,
        20,
      );
      final after = await render(
        RaftSeparator(thickness: thickness, color: color),
        100,
        20,
      );
      expect(after, before, reason: 'horizontal $thickness $color');
      final beforeV = await render(
        VerticalDivider(width: 1, thickness: thickness, color: color),
        20,
        100,
      );
      final afterV = await render(
        RaftSeparator(axis: Axis.vertical, thickness: thickness, color: color),
        20,
        100,
      );
      expect(afterV, beforeV, reason: 'vertical $thickness $color');
    }
  }, skip: raftLookSkip(raftLookElegant));
}
