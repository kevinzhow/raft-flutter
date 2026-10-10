import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/reading_anchor.dart';

/// RaftReadingAnchorController works in scroll space: rows inserted before the
/// anchor (scroll offset 0 side) push its layout offset by their extent and
/// the correction adds the same amount to the scroll position, whether offset
/// 0 is the top (Activity, newest first) or the bottom (reversed channel).
void main() {
  for (final reverse in [false, true]) {
    testWidgets(
      '${reverse ? 'reversed' : 'top-anchored'} list keeps the anchor row in place when rows are inserted at offset 0',
      (tester) async {
        final controller = RaftReadingAnchorController();
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        var ids = [for (var i = 0; i < 40; i++) i];
        late StateSetter rebuild;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return RaftReadingAnchor(
                  controller: controller,
                  child: ListView.builder(
                    controller: scroll,
                    reverse: reverse,
                    itemCount: ids.length,
                    findChildIndexCallback: (key) =>
                        ids.indexOf((key as ValueKey<int>).value),
                    itemBuilder: (context, index) => SizedBox(
                      key: ValueKey(ids[index]),
                      height: 40.0 + ids[index] % 3 * 10,
                      child: Text('row ${ids[index]}'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        scroll.jumpTo(600);
        await tester.pump();
        final row = find.text('row 20');
        final before = tester.getRect(row);
        final box = tester.renderObject<RenderBox>(
          find.ancestor(of: row, matching: find.byType(SizedBox)).first,
        );
        // The sliver's direct child (the repaint boundary around the row).
        RenderObject child = box;
        while (child.parent is! RenderSliverMultiBoxAdaptor) {
          child = child.parent!;
        }
        controller.capture(child as RenderBox, scroll.position);
        rebuild(() => ids = [-1, -2, ...ids]);
        await tester.pump();
        expect(tester.getRect(row), before);
        // Moved rows keep the lazy list's offsets of their new indices, so the
        // position moves by the anchor's new offset, away from offset 0.
        expect(scroll.offset, greaterThan(600));
        for (var frame = 0; frame < 4; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.getRect(row), before);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
