import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/message_timeline.dart';

void main() {
  testWidgets('a shrinking scroll range preserves a scroll into that range', (
    tester,
  ) async {
    final controller = RaftTimelineScrollController(
      bottomAnchored: false,
      initial: RaftTimelineAlignment.start,
    );
    final height = ValueNotifier(300.0);
    addTearDown(controller.dispose);
    addTearDown(height.dispose);
    final messages = [
      for (var index = 0; index < 30; index++)
        chat.Message.text(
          id: '$index',
          authorId: 'fixture',
          text: 'row-$index',
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: RaftMessageTimeline(
          controller: controller,
          messages: messages,
          centerIndex: messages.length,
          epoch: 0,
          indexOfId: int.tryParse,
          estimateRow: (index) => index == 0 ? height.value : 100,
          rowBuilder: (context, index) => index == 0
              ? ValueListenableBuilder(
                  valueListenable: height,
                  builder: (_, height, _) => SizedBox(height: height),
                )
              : const SizedBox(height: 100),
          slivers: (history, forward) => [history, forward],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final target = controller.offset + 650;
    final animation = controller.animateTo(
      target,
      duration: const Duration(milliseconds: 650),
      curve: Curves.linear,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    height.value = 40;
    for (var frame = 0; frame < 45; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await animation;
    final offset = controller.offset;
    await tester.pumpWidget(const SizedBox());
    expect(offset, closeTo(target, .5));
  });

  testWidgets('one live insert reuses the retained rows and their layout', (
    tester,
  ) async {
    final controller = RaftTimelineScrollController(
      bottomAnchored: false,
      initial: RaftTimelineAlignment.start,
    );
    addTearDown(controller.dispose);
    final messages = ValueNotifier([
      for (var index = 0; index < 80; index++)
        chat.Message.text(
          id: '$index',
          authorId: 'fixture',
          text: 'row-$index',
        ),
    ]);
    addTearDown(messages.dispose);
    final builds = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: messages,
          builder: (context, rows, _) => RaftMessageTimeline(
            controller: controller,
            messages: rows,
            centerIndex: 0,
            epoch: 0,
            cacheExtent: 0,
            extentRevision: 0,
            rowRevision: (_) => 0,
            retainRow: (_) => true,
            indexOfId: (id) {
              final index = rows.indexWhere((row) => row.id == id);
              return index < 0 ? null : index;
            },
            estimateRow: (_) => 40,
            rowBuilder: (context, index) {
              builds.add(rows[index].id);
              return SizedBox(
                height: 40,
                child: Text((rows[index] as chat.TextMessage).text),
              );
            },
            slivers: (history, forward) => [history, forward],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(builds.length, greaterThan(10));
    final anchor = tester.getRect(find.text('row-2'));
    builds.clear();
    final initialProfiling = debugProfileLayoutsEnabled;
    final initialCollection = FlutterTimeline.debugCollectionEnabled;
    debugProfileLayoutsEnabled = true;
    FlutterTimeline.debugCollectionEnabled = true;
    try {
      final rows = messages.value;
      messages.value = [
        ...rows.take(5),
        chat.Message.text(
          id: 'arrival',
          authorId: 'fixture',
          text: 'New arrival',
        ),
        ...rows.skip(5),
      ];
      await tester.pumpAndSettle();
      final rowLayouts = FlutterTimeline.debugCollect().timedBlocks.where(
        (block) => block.name == '_RenderLayoutBuilder',
      );
      expect(find.text('New arrival'), findsOneWidget);
      expect(tester.getRect(find.text('row-2')), anchor);
      expect(builds.toSet(), {'4', 'arrival', '5'});
      expect(rowLayouts.length, lessThanOrEqualTo(5));
    } finally {
      debugProfileLayoutsEnabled = initialProfiling;
      FlutterTimeline.debugCollectionEnabled = initialCollection;
      await tester.pumpWidget(const SizedBox());
    }
  });

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
      final unchangedWrappers = find
          .ancestor(
            of: find.text('row-0 / 0'),
            matching: find.byType(AutomaticKeepAlive),
          )
          .evaluate()
          .toSet();
      expect(unchangedWrappers, isNotEmpty);
      var wrapperBuilds = 0;
      final previousRebuild = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtFirstTime) {
        if (unchangedWrappers.contains(element)) wrapperBuilds++;
        previousRebuild?.call(element, builtFirstTime);
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previousRebuild);
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
      expect(
        wrapperBuilds,
        0,
        reason: 'The unchanged row keeps its sliver wrapper.',
      );
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
    'prepared rows survive parent updates and the start of scrolling',
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
      final prepared = find.text('prepared-988', skipOffstage: false);
      expect(prepared, findsOneWidget);
      final preparedElement = tester.element(prepared);
      final beforeScroll = RaftMessageTimeline.debugRowBuilds;
      controller.jumpTo(controller.position.pixels - 50);
      await tester.pump();
      expect(prepared, findsOneWidget);
      expect(tester.element(prepared), same(preparedElement));
      expect(RaftMessageTimeline.debugRowBuilds - beforeScroll, lessThan(2));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
