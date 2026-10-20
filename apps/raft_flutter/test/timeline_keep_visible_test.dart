import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/message_timeline.dart';

/// Web `keepTimelineMessageVisible`: collapsing a long message can leave the
/// row wholly outside the viewport (its top is fixed, its height shrinks under
/// the reader). The row is then revealed at its nearest edge; a row that is
/// still partly visible leaves the list alone.
void main() {
  testWidgets('a collapsed row that left the viewport is revealed', (
    tester,
  ) async {
    final controller = RaftTimelineScrollController(
      bottomAnchored: false,
      initial: null,
    );
    addTearDown(controller.dispose);
    final height = ValueNotifier<double>(3000);
    addTearDown(height.dispose);
    final rowKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 600,
          child: CustomScrollView(
            controller: controller,
            slivers: [
              SliverToBoxAdapter(
                child: ValueListenableBuilder(
                  valueListenable: height,
                  builder: (_, value, _) =>
                      SizedBox(key: rowKey, height: value),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 4000)),
            ],
          ),
        ),
      ),
    );
    // The reader is at the tail of the 3000px row.
    controller.jumpTo(2500);
    await tester.pump();
    height.value = 400; // collapse: the row now ends above the viewport
    await tester.pump();
    expect(controller.position.pixels, 2500);
    controller.keepVisible(rowKey.currentContext!);
    await tester.pump();
    expect(controller.position.pixels, 0, reason: 'the row top is revealed');
  });

  testWidgets('a row that is still partly visible is left alone', (
    tester,
  ) async {
    final controller = RaftTimelineScrollController(
      bottomAnchored: false,
      initial: null,
    );
    addTearDown(controller.dispose);
    final rowKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 600,
          child: CustomScrollView(
            controller: controller,
            slivers: [
              SliverToBoxAdapter(child: SizedBox(key: rowKey, height: 700)),
              const SliverToBoxAdapter(child: SizedBox(height: 4000)),
            ],
          ),
        ),
      ),
    );
    controller.jumpTo(300);
    await tester.pump();
    controller.keepVisible(rowKey.currentContext!);
    await tester.pump();
    expect(controller.position.pixels, 300);
  });
}
