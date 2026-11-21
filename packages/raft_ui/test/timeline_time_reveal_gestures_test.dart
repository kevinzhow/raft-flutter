import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// The touch time reveal (Web v1.24 useTimelineTimeReveal) leaves a drag to
/// whatever it starts on that takes sideways drags: a wide table, a code
/// block, display math, a slider. Only a drag that starts on content with
/// nothing of its own to drag sideways slides the rows.
void main() {
  final wideTable = [
    '| ${List.generate(12, (i) => 'Column $i').join(' | ')} |',
    '| ${List.filled(12, '---').join(' | ')} |',
    '| ${List.generate(12, (i) => 'value $i').join(' | ')} |',
  ].join('\n');
  const narrowTable = '| A | B |\n| --- | --- |\n| 1 | 2 |';
  final wideMath = '\$\$\n${List.filled(40, r'x^2 +').join()} 1\n\$\$';

  Future<void> pump(WidgetTester t, String content) => t.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(400, 800)),
      child: MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftTimelineTimeReveal(
            child: ListView(
              children: [
                RaftMessageRow(
                  key: const ValueKey('row-0'),
                  author: 'Alice',
                  timestamp: '9:00 AM',
                  continuationTimestamp: '9:00',
                  content: RaftMessageBody(
                    content: content,
                    messagePipeline: true,
                  ),
                ),
                const RaftMessageRow(
                  key: ValueKey('row-1'),
                  author: 'Alice',
                  timestamp: '9:01 AM',
                  continuationTimestamp: '9:01',
                  continuation: true,
                  content: Text('plain reply'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  double rowShift(WidgetTester t, String key) => t
      .widget<Transform>(
        find
            .descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform
      .getTranslation()
      .x;

  /// The first sideways scroll position under the first row, if any.
  ScrollPosition? sidewaysScroll(WidgetTester t) {
    for (final state in t.stateList<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('row-0')),
        matching: find.byType(Scrollable),
      ),
    )) {
      if (state.position.axis == Axis.horizontal) return state.position;
    }
    return null;
  }

  /// The middle of the first sideways scroller under the first row.
  Offset scrollerCenter(WidgetTester t) {
    final box = t.renderObject<RenderBox>(
      find
          .descendant(
            of: find.byKey(const ValueKey('row-0')),
            matching: find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
            ),
          )
          .first,
    );
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  Future<void> dragLeft(WidgetTester t, Offset start, {bool hold = false}) async {
    final gesture = await t.startGesture(start, kind: PointerDeviceKind.touch);
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(-15, 0));
      await t.pump();
    }
    if (hold) return;
    await gesture.up();
    await t.pumpAndSettle();
  }

  Future<void> expectRevealFrom(WidgetTester t, Offset start) async {
    final gesture = await t.startGesture(start, kind: PointerDeviceKind.touch);
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(-15, 0));
      await t.pump();
    }
    expect(rowShift(t, 'row-0'), lessThan(-40));
    expect(rowShift(t, 'row-1'), rowShift(t, 'row-0'));
    await gesture.up();
    await t.pumpAndSettle();
    expect(rowShift(t, 'row-0'), 0);
  }

  testWidgets('a drag on plain text reveals the times', (t) async {
    await pump(t, 'Plain text that fits the row.');
    await expectRevealFrom(t, t.getCenter(find.text('plain reply')));
    await expectRevealFrom(
      t,
      t.getTopLeft(find.byKey(const ValueKey('row-0'))) + const Offset(80, 30),
    );
  });

  testWidgets('a wide table scrolls; the rows stay', (t) async {
    await pump(t, 'Before\n\n$wideTable\n\nAfter');
    final start = t.getCenter(find.text('value 1'));
    final position = sidewaysScroll(t)!;
    expect(position.maxScrollExtent, greaterThan(0));
    await dragLeft(t, start, hold: true);
    expect(rowShift(t, 'row-0'), 0);
    expect(find.byKey(const ValueKey('timeline-reveal-time')), findsNothing);
    expect(position.pixels, greaterThan(40));
    await t.pumpAndSettle();
  }, variant: TargetPlatformVariant.mobile());

  testWidgets('a wide table at its end never hands the drag over', (t) async {
    await pump(t, '$wideTable\n\nAfter');
    final position = sidewaysScroll(t)!;
    position.jumpTo(position.maxScrollExtent);
    await t.pump();
    await dragLeft(t, scrollerCenter(t), hold: true);
    expect(rowShift(t, 'row-0'), 0);
    expect(find.byKey(const ValueKey('timeline-reveal-time')), findsNothing);
  }, variant: TargetPlatformVariant.mobile());

  testWidgets('a table that fits reveals the times', (t) async {
    await pump(t, narrowTable);
    await expectRevealFrom(t, t.getCenter(find.text('1')));
  }, variant: TargetPlatformVariant.mobile());

  testWidgets('a wide code block keeps its drag', (t) async {
    await pump(t, '```\n${List.filled(30, 'longIdentifier').join('_')}\n```');
    await dragLeft(
      t,
      t.getCenter(find.byKey(const ValueKey('code-container'))),
      hold: true,
    );
    expect(rowShift(t, 'row-0'), 0);
  });

  testWidgets('wide display math keeps its drag', (t) async {
    await pump(t, wideMath);
    final position = sidewaysScroll(t);
    expect(position, isNotNull);
    expect(position!.maxScrollExtent, greaterThan(0));
    await dragLeft(t, scrollerCenter(t), hold: true);
    expect(rowShift(t, 'row-0'), 0);
  });

  testWidgets('a sideways control in a message keeps its drag', (t) async {
    var dragged = 0.0;
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: RaftTimelineTimeReveal(
              child: ListView(
                children: [
                  RaftMessageRow(
                    key: const ValueKey('row-0'),
                    author: 'Alice',
                    timestamp: '9:00 AM',
                    content: GestureDetector(
                      key: const ValueKey('seek'),
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (d) => dragged += d.delta.dx,
                      child: const SizedBox(width: 240, height: 32),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await dragLeft(
      t,
      t.getCenter(find.byKey(const ValueKey('seek'))),
      hold: true,
    );
    expect(rowShift(t, 'row-0'), 0);
    expect(dragged, lessThan(-40));
  });

}
