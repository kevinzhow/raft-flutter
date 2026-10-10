import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/timeline_composition.dart';

double top(WidgetTester tester, String key) =>
    tester.getTopLeft(find.byKey(ValueKey(key))).dy;

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
