import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/timeline_composition.dart';

Widget harness({
  RaftTimelineSparseAnchor anchor = RaftTimelineSparseAnchor.bottom,
  double height = 400,
  double headerHeight = 40,
  List<double> heights = const [30, 50],
  double loadingFooterHeight = 0,
  ScrollController? controller,
  VoidCallback? onFirstTap,
  Widget? messagesSliver,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      key: const ValueKey('viewport'),
      width: 320,
      height: height,
      child: CustomScrollView(
        controller: controller,
        slivers: [
          RaftTimelineCompositionSliver(
            anchor: anchor,
            header: SizedBox(
              key: const ValueKey('header'),
              height: headerHeight,
            ),
            messagesSliver:
                messagesSliver ??
                SliverList.builder(
                  itemCount: heights.length,
                  itemBuilder: (context, index) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: index == 0 ? onFirstTap : null,
                    child: SizedBox(
                      key: ValueKey('row-$index'),
                      height: heights[index],
                    ),
                  ),
                ),
            footer: RaftTimelineFooter(
              key: const ValueKey('footer'),
              loadingNewer: loadingFooterHeight == 0
                  ? null
                  : SizedBox(height: loadingFooterHeight),
            ),
          ),
        ],
      ),
    ),
  ),
);

double top(WidgetTester tester, String key) =>
    tester.getTopLeft(find.byKey(ValueKey(key))).dy;

double leading(WidgetTester tester) => tester
    .renderObject<RenderRaftSparseTimelineSliver>(
      find.byType(RaftSparseTimelineSliver),
    )
    .leadingExtent;

void main() {
  test(
    'actual host controls anchor and dates without changing day grouping',
    () {
      const recipe = RaftTimelineCompositionRecipe();
      expect(
        recipe.anchorFor(RaftTimelineHost.chatPanel),
        RaftTimelineSparseAnchor.bottom,
      );
      expect(
        recipe.anchorFor(RaftTimelineHost.threadPanel),
        RaftTimelineSparseAnchor.top,
      );
      expect(recipe.emitsDayDivider(RaftTimelineHost.chatPanel), isTrue);
      expect(recipe.emitsDayDivider(RaftTimelineHost.threadPanel), isFalse);
    },
  );
  test(
    'source min-height slack is role-driven and clamps for long content',
    () {
      const recipe = RaftTimelineCompositionRecipe();
      expect(
        recipe.leadingSpace(
          anchor: RaftTimelineSparseAnchor.bottom,
          viewportExtent: 400,
          precedingExtent: 41,
          tailExtent: 105,
        ),
        254,
      );
      expect(
        recipe.leadingSpace(
          anchor: RaftTimelineSparseAnchor.top,
          viewportExtent: 400,
          precedingExtent: 41,
          tailExtent: 105,
        ),
        0,
      );
      expect(
        recipe.leadingSpace(
          anchor: RaftTimelineSparseAnchor.bottom,
          viewportExtent: 400,
          precedingExtent: 41,
          tailExtent: 500,
        ),
        0,
      );
    },
  );

  testWidgets('Main leaves header at top and pushes sparse tail to bottom', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(harness(controller: controller));
    expect(top(tester, 'header'), 0);
    expect(leading(tester), 254);
    expect(top(tester, 'row-0'), 295);
    expect(top(tester, 'row-1'), 325);
    expect(tester.getBottomRight(find.byKey(const ValueKey('footer'))).dy, 400);
    expect(controller.position.maxScrollExtent, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('Thread default keeps parent/history and sparse replies at top', (
    tester,
  ) async {
    await tester.pumpWidget(harness(anchor: RaftTimelineSparseAnchor.top));
    expect(top(tester, 'header'), 0);
    expect(leading(tester), 0);
    expect(top(tester, 'row-0'), 41);
    expect(tester.getBottomRight(find.byKey(const ValueKey('footer'))).dy, 146);
  });

  testWidgets('natural loading footer is measured rather than hardcoded away', (
    tester,
  ) async {
    await tester.pumpWidget(harness(loadingFooterHeight: 40));
    expect(leading(tester), 214);
    expect(top(tester, 'row-0'), 255);
    expect(tester.getSize(find.byKey(const ValueKey('footer'))).height, 64);
    expect(tester.getBottomRight(find.byKey(const ValueKey('footer'))).dy, 400);
  });

  testWidgets('first-frame geometry and hit positions use same layout', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(harness(onFirstTap: () => taps++));
    expect(top(tester, 'row-0'), 295);
    await tester.tapAt(const Offset(40, 100));
    expect(taps, 0, reason: 'spacer does not intercept as a hidden message');
    await tester.tapAt(const Offset(40, 310));
    expect(taps, 1);
  });

  testWidgets('resize recomputes source slack without post-frame feedback', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    expect(leading(tester), 254);
    await tester.pumpWidget(harness(height: 300));
    expect(leading(tester), 154);
    expect(top(tester, 'header'), 0);
    expect(top(tester, 'row-0'), 195);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(leading(tester), 154);
    }
  });

  testWidgets(
    'long mixed virtualized rows keep zero leading space when recycled',
    (tester) async {
      final controller = ScrollController();
      final heights = List.generate(48, (i) => i % 3 == 0 ? 320.0 : 24.0);
      await tester.pumpWidget(
        harness(heights: heights, controller: controller),
      );
      expect(leading(tester), 0);
      expect(controller.position.maxScrollExtent, greaterThan(400));
      for (final offset in [800.0, 1600.0, 400.0, 0.0]) {
        controller.jumpTo(offset);
        await tester.pump();
        expect(leading(tester), 0);
        expect(tester.takeException(), isNull);
      }
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.binding.hasScheduledFrame, isFalse);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'source anchor switch does not replace existing animated list state',
    (tester) async {
      final listKey = GlobalKey<SliverAnimatedListState>();
      Widget list() => SliverAnimatedList(
        key: listKey,
        initialItemCount: 2,
        itemBuilder: (context, index, animation) =>
            SizedBox(key: ValueKey('row-$index'), height: index == 0 ? 30 : 50),
      );
      await tester.pumpWidget(harness(messagesSliver: list()));
      final state = listKey.currentState;
      expect(top(tester, 'row-0'), 295);
      await tester.pumpWidget(
        harness(anchor: RaftTimelineSparseAnchor.top, messagesSliver: list()),
      );
      expect(identical(state, listKey.currentState), isTrue);
      expect(top(tester, 'row-0'), 41);
    },
  );

  testWidgets('centered composition: history grows above the center without '
      'moving the rows below it', (tester) async {
    Widget host(int history) {
      const forwardKey = ValueKey('forward');
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            height: 400,
            child: CustomScrollView(
              // At the latest end: forward rows, sentinel and footer.
              controller: ScrollController(initialScrollOffset: 85),
              center: forwardKey,
              anchor: 1,
              slivers: const RaftTimelineCompositionRecipe().centeredSlivers(
                header: [
                  const SliverToBoxAdapter(
                    child: SizedBox(key: ValueKey('header'), height: 40),
                  ),
                ],
                history: SliverList.builder(
                  itemCount: history,
                  itemBuilder: (context, index) =>
                      SizedBox(key: ValueKey('old-$index'), height: 50),
                ),
                forward: SliverList.builder(
                  key: forwardKey,
                  itemCount: 2,
                  itemBuilder: (context, index) =>
                      SizedBox(key: ValueKey('new-$index'), height: 30),
                ),
                footer: const RaftTimelineFooter(key: ValueKey('footer')),
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(host(3));
    expect(tester.getBottomLeft(find.byKey(const ValueKey('footer'))).dy, 400);
    final newest = top(tester, 'new-0');
    final nearest = top(tester, 'old-0');
    // Sentinels between header/history and forward/footer, as the sliver form.
    expect(top(tester, 'new-0') - top(tester, 'old-0'), 50);
    expect(top(tester, 'old-2') - top(tester, 'header'), 41);
    expect(top(tester, 'footer') - top(tester, 'new-1'), 31);
    await tester.pumpWidget(host(30));
    expect(top(tester, 'new-0'), newest);
    expect(top(tester, 'old-0'), nearest);
  });
}
