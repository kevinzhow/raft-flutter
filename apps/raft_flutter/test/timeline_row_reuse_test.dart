import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/message_timeline.dart';

void main() {
  testWidgets(
    'unchanged rows and extents survive updates; edits refresh their grouping neighbours',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 600);
      addTearDown(tester.view.reset);
      final controller = RaftTimelineScrollController(
        bottomAnchored: false,
        initial: RaftTimelineAlignment.start,
      );
      addTearDown(controller.dispose);
      var messages = [
        for (var i = 0; i < 40; i++)
          chat.Message.custom(
            id: '$i',
            authorId: 'fixture',
            metadata: {'label': 'row-$i'},
          ),
      ];
      var revision = 0, estimates = 0;
      final built = <String>[];
      Widget view() => MaterialApp(
        home: RaftMessageTimeline(
          controller: controller,
          messages: messages,
          centerIndex: 0,
          epoch: 0,
          cacheExtent: 0,
          extentRevision: revision,
          rowRevision: (_) => revision,
          indexOfId: (id) {
            final i = messages.indexWhere((m) => m.id == id);
            return i < 0 ? null : i;
          },
          estimateRow: (_) {
            estimates++;
            return 100;
          },
          rowBuilder: (_, i) {
            final m = messages[i];
            built.add(m.id);
            return SizedBox(
              height: 100,
              child: Text('${m.metadata!['label']} / $revision'),
            );
          },
          slivers: (history, forward) => [history, forward],
        ),
      );
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(estimates, 40);
      final anchor = tester.getRect(find.text('row-0 / 0'));
      built.clear();
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(built, isEmpty);
      expect(estimates, 40);
      messages = [
        ...messages,
        chat.Message.custom(
          id: '40',
          authorId: 'fixture',
          metadata: {'label': 'arrival'},
        ),
      ];
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(built, isEmpty);
      expect(estimates, 41);
      expect(tester.getRect(find.text('row-0 / 0')), anchor);
      messages = [
        for (final m in messages)
          if (m.id == '2')
            chat.Message.custom(
              id: '2',
              authorId: 'fixture',
              metadata: {'label': 'edited'},
            )
          else
            m,
      ];
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(built.toSet(), {'1', '2', '3'});
      expect(estimates, 42);
      expect(find.text('edited / 0'), findsOneWidget);
      built.clear();
      revision++;
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(built.length, greaterThan(3));
      expect(find.text('edited / 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'prepared rows survive parent updates; input restores the active margin',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 600);
      addTearDown(tester.view.reset);
      final controller = RaftTimelineScrollController(bottomAnchored: true);
      addTearDown(controller.dispose);
      final messages = [
        for (var i = 0; i < 1000; i++)
          chat.Message.text(id: '$i', authorId: 'fixture', text: '$i'),
      ];
      var idle = true;
      Widget view() => MaterialApp(
        home: RaftMessageTimeline(
          controller: controller,
          messages: messages,
          centerIndex: 999,
          epoch: 0,
          indexOfId: int.tryParse,
          canPrepareNearbyRows: () => idle,
          rowRevision: (_) => 0,
          extentRevision: 0,
          rowBuilder: (_, i) =>
              SizedBox(height: 100, child: Text('prepared-$i')),
          estimateRow: (_) => 100,
          slivers: (history, forward) => [history, forward],
        ),
      );
      int count() => find
          .textContaining('prepared-', skipOffstage: false)
          .evaluate()
          .length;
      await tester.pumpWidget(view());
      final cold = count();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 32));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
      final warm = count();
      expect(warm, greaterThan(cold));
      expect(warm, lessThanOrEqualTo(32));
      idle = false;
      await tester.pumpWidget(view());
      expect(count(), warm);
      controller.jumpTo(controller.position.pixels - 50);
      await tester.pump();
      expect(count(), lessThan(warm));
      expect(count(), lessThanOrEqualTo(cold + 1));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
