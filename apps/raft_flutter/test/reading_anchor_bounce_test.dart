import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/reading_anchor.dart';

void main() {
  for (final trailing in [false, true]) {
    for (final contentChanges in [false, true]) {
      testWidgets(
        'a pending reading anchor preserves a held ${trailing ? 'bottom' : 'top'} bounce${contentChanges ? ' while content grows' : ''}',
        (tester) async {
          final anchor = RaftReadingAnchorController();
          final scroll = RaftAnchoredScrollController(anchor);
          addTearDown(scroll.dispose);
          var growth = 0.0;
          late StateSetter rebuild;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: TargetPlatform.macOS),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    rebuild = setState;
                    return RaftReadingAnchor(
                      controller: anchor,
                      child: ListView.builder(
                        controller: scroll,
                        physics: const BouncingScrollPhysics(),
                        itemCount: 40,
                        itemBuilder: (_, i) => SizedBox(
                          key: ValueKey(i),
                          height: 50 + (i == (trailing ? 37 : 0) ? growth : 0),
                          child: Text('row $i'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
          scroll.jumpTo(trailing ? scroll.position.maxScrollExtent - 20 : 20);
          await tester.pumpAndSettle();
          final row = find.text(trailing ? 'row 38' : 'row 1');
          RenderObject child = tester.renderObject(row);
          while (child.parent is! RenderSliverMultiBoxAdaptor) {
            child = child.parent!;
          }
          // Live Activity updates hold a visible row through the next layouts.
          anchor.capture(child as RenderBox, scroll.position);
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(ListView)),
          );
          try {
            await gesture.moveBy(Offset(0, trailing ? -100 : 100));
            await gesture.moveBy(Offset(0, trailing ? -40 : 40));
            final before = scroll.offset;
            expect(scroll.position.outOfRange, isTrue);
            if (contentChanges) rebuild(() => growth = 24);
            await tester.pump();
            expect(
              scroll.offset,
              closeTo(before + growth, .01),
              reason:
                  'correct content shifts without clamping the user\'s bounce',
            );
          } finally {
            await gesture.up();
            await tester.pumpAndSettle();
          }
          expect(scroll.position.outOfRange, isFalse);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
