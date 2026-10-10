import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'tooltip_test.dart' show host;

/// Rows scrolled under a resting pointer are not hovered on purpose: no
/// tooltip opens until the pointer itself moves, and an open tooltip closes
/// on scroll without making the next rows open instantly.
void main() {
  Widget list(ScrollController scroll) => host(
    SizedBox(
      width: 200,
      height: 300,
      child: ListView(
        controller: scroll,
        children: [
          for (var i = 0; i < 40; i++)
            RaftTooltip(
              message: 'Tip $i',
              child: SizedBox(height: 30, child: Text('Row $i')),
            ),
        ],
      ),
    ),
  );

  testWidgets('scrolling under a resting pointer opens no tooltip', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(list(scroll));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Row 2')));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Tip 2'), findsOneWidget);

    // Scrolling closes it and rows passing under the pointer stay quiet,
    // also within the adjacent-instant window.
    for (var step = 1; step <= 6; step++) {
      scroll.jumpTo(step * 45.0);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Tip '), findsNothing);
    }
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('Tip '), findsNothing);

    // A real pointer move is hover intent again.
    await mouse.moveBy(const Offset(3, 0));
    await tester.pump(const Duration(milliseconds: 599));
    expect(find.textContaining('Tip '), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.textContaining('Tip '), findsOneWidget);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a tooltip repeating its text opens only when the text is cut', (
    tester,
  ) async {
    Widget line(String text) => RaftTooltip(
      message: text,
      onlyWhenTruncated: true,
      child: SizedBox(
        width: 160,
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
    await tester.pumpWidget(
      host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            line('Short'),
            const SizedBox(height: 40),
            line('A very long system line that cannot fit in this width'),
          ],
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Short')));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Short'), findsOneWidget);
    await mouse.moveTo(
      tester.getCenter(
        find.text('A very long system line that cannot fit in this width'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      find.text('A very long system line that cannot fit in this width'),
      findsNWidgets(2),
    );
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
