import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets(
    'first layout resolves variable-height end and releases later scrolling',
    (tester) async {
      final controller = RaftInitialEndScrollController();
      addTearDown(controller.dispose);
      Widget host(int count) => MaterialApp(
        home: Center(
          child: SizedBox(
            width: 390,
            height: 360,
            child: ListView.builder(
              controller: controller,
              itemCount: count,
              itemBuilder: (_, index) => SizedBox(
                height: 20.0 * (index % 4 + 1),
                child: Text('Row $index'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(80));
      final tail = tester.getRect(find.text('Row 79'));
      expect(
        tail.bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(ListView)).bottom),
      );
      expect(controller.offset, controller.position.maxScrollExtent);
      for (var i = 0; i < 4; i++) {
        await tester.pump();
        expect(tester.getRect(find.text('Row 79')), tail);
      }
      await tester.drag(find.byType(ListView), const Offset(0, 180));
      await tester.pumpAndSettle();
      final readingOffset = controller.offset;
      expect(readingOffset, lessThan(controller.position.maxScrollExtent));
      await tester.pumpWidget(host(81));
      await tester.pump();
      expect(
        controller.offset,
        readingOffset,
        reason: 'A later append must not reclaim the viewport',
      );
      controller.jumpTo(0);
      await tester.pump();
      expect(controller.offset, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
