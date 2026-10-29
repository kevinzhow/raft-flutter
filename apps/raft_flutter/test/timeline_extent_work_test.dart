import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/message_timeline.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets(
    'idle preparation is bounded, pauses for input, and preserves the anchor',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 600);
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      final controller = RaftTimelineScrollController(bottomAnchored: true);
      addTearDown(controller.dispose);
      var messages = [
        for (var i = 0; i < 1000; i++)
          chat.Message.text(id: '$i', authorId: 'fixture', text: '$i'),
      ];
      var idle = false;
      var estimates = 0;
      Widget view(bool active, {bool revised = false}) => MaterialApp(
        home: TickerMode(
          enabled: active,
          child: Column(
            children: [
              Expanded(
                child: RaftMessageTimeline(
                  controller: controller,
                  messages: messages,
                  centerIndex: 999,
                  epoch: 0,
                  indexOfId: int.tryParse,
                  canPrepareNearbyRows: () => idle,
                  estimateRow: (_) {
                    estimates++;
                    return 100;
                  },
                  rowBuilder: (_, index) => SizedBox(
                    height: 100,
                    child: Text('row-$index${revised ? '-updated' : ''}'),
                  ),
                  slivers: (history, forward) => [history, forward],
                ),
              ),
              const Material(
                child: TextField(
                  key: Key('composer'),
                  decoration: InputDecoration(labelText: 'Message composer'),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(view(true));
      final initial = find
          .textContaining('row-', skipOffstage: false)
          .evaluate()
          .length;
      final anchor = tester.getRect(find.text('row-999'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.textContaining('row-', skipOffstage: false).evaluate().length,
        initial,
      );
      idle = true;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 32));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
      final prepared = find
          .textContaining('row-', skipOffstage: false)
          .evaluate()
          .length;
      expect(prepared, greaterThan(initial));
      expect(prepared, lessThanOrEqualTo(32));
      expect(tester.getRect(find.text('row-999')), anchor);
      expect(estimates, 1000);
      idle = false;
      controller.jumpTo(controller.position.pixels - 100);
      await tester.pump();
      final afterInput = find
          .textContaining('row-', skipOffstage: false)
          .evaluate()
          .length;
      expect(afterInput, lessThan(prepared));
      expect(estimates, 1000);
      final existingBuilds = RaftMessageTimeline.debugRowBuilds;
      for (var i = 0; i < 10; i++) {
        controller.jumpTo(controller.position.pixels - 100);
        await tester.pump();
      }
      expect(
        RaftMessageTimeline.debugRowBuilds - existingBuilds,
        lessThanOrEqualTo(20),
      );
      expect(
        tester
            .getSemantics(find.text('row-985'))
            .getSemanticsData()
            .flagsCollection
            .isHidden,
        isFalse,
      );
      expect(
        tester
            .getSemantics(find.byKey(const Key('composer')))
            .getSemanticsData()
            .flagsCollection
            .isHidden,
        isFalse,
      );
      for (var i = 0; i < 100; i++) {
        controller.jumpTo(controller.position.pixels - 600);
        await tester.pump();
      }
      await tester.pump();
      expect(
        find.textContaining('row-', skipOffstage: false).evaluate().length,
        lessThanOrEqualTo(20),
      );
      expect(find.text('row-997', skipOffstage: false), findsNothing);
      idle = true;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 32));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
      expect(
        find.textContaining('row-', skipOffstage: false).evaluate().length,
        greaterThan(12),
      );
      idle = false;
      final beforeUpdate = RaftMessageTimeline.debugRowBuilds;
      final warmBeforeUpdate = find
          .textContaining('row-', skipOffstage: false)
          .evaluate()
          .length;
      await tester.pumpWidget(view(true));
      expect(
        find.textContaining('row-', skipOffstage: false).evaluate().length,
        warmBeforeUpdate,
      );
      expect(
        RaftMessageTimeline.debugRowBuilds - beforeUpdate,
        lessThanOrEqualTo(24),
        reason: 'Foreground updates keep the already bounded warm window.',
      );
      final beforeHide = RaftMessageTimeline.debugRowBuilds;
      await tester.pumpWidget(view(false));
      expect(RaftMessageTimeline.debugRowBuilds, beforeHide);
      final hidden = RaftMessageTimeline.debugRowBuilds;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(RaftMessageTimeline.debugRowBuilds, hidden);
      messages = [
        ...messages,
        chat.Message.text(id: '1000', authorId: 'fixture', text: 'arrival'),
      ];
      await tester.pumpWidget(view(false, revised: true));
      expect(RaftMessageTimeline.debugRowBuilds, hidden);
      expect(
        find.textContaining('-updated', skipOffstage: false),
        findsNothing,
      );
      await tester.pumpWidget(view(true, revised: true));
      expect(find.textContaining('-updated'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
  testWidgets(
    'scrolling estimates once per presentation and keeps measured heights on both sides',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 600);
      addTearDown(tester.view.reset);
      final controller = RaftTimelineScrollController(
        bottomAnchored: false,
        initial: RaftTimelineAlignment.start,
      );
      addTearDown(controller.dispose);
      final messages = [
        for (var i = 0; i < 1000; i++)
          chat.Message.text(id: '$i', authorId: 'fixture', text: '$i'),
      ];
      var estimates = 0;
      final heights = <int, double>{};
      final updates = <int, StateSetter>{};
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: RaftMessageTimeline(
              controller: controller,
              messages: messages,
              centerIndex: 500,
              epoch: 0,
              indexOfId: int.tryParse,
              rowBuilder: (context, index) => StatefulBuilder(
                builder: (context, update) {
                  updates[index] = update;
                  return SizedBox(
                    height: heights[index] ?? 20,
                    child: Text('row-$index'),
                  );
                },
              ),
              estimateRow: (index) {
                estimates++;
                return 20;
              },
              slivers: (history, forward) => [history, forward],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(estimates, 1000);
      double range() =>
          controller.position.maxScrollExtent -
          controller.position.minScrollExtent;
      expect(range(), closeTo(19400, .01));
      expect(find.text('row-0'), findsOneWidget);
      updates[0]!(() => heights[0] = 80);
      await tester.pumpAndSettle();
      expect(range(), closeTo(19460, .01));
      final seeded = estimates;
      for (var i = 1; i <= 8; i++) {
        controller.jumpTo(controller.position.minScrollExtent + i * 1200);
        await tester.pump();
      }
      expect(estimates, seeded);
      expect(range(), closeTo(19460, .01));
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('row-999'), findsOneWidget);
      updates[999]!(() => heights[999] = 100);
      await tester.pumpAndSettle();
      expect(range(), closeTo(19540, .01));
      controller.jumpTo(controller.position.minScrollExtent);
      await tester.pumpAndSettle();
      expect(range(), closeTo(19540, .01));
      expect(estimates, seeded);
      expect(tester.takeException(), isNull);
    },
  );
}
