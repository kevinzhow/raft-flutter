import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('non-swiping host leaves Android edge controls tappable', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 600);
    t.view.devicePixelRatio = 1;
    t.view.systemGestureInsets = const FakeViewPadding(left: 40, right: 40);
    addTearDown(t.view.reset);
    var taps = 0;
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: RaftSectionPager<String>(
            sections: const ['page'],
            value: 'page',
            swipeEnabled: false,
            onChanged: null,
            builder: (_, _) => Row(
              children: [
                for (final label in ['left', 'right'])
                  Expanded(
                    child: Align(
                      alignment: label == 'left'
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: SizedBox(
                        width: 32,
                        height: 48,
                        child: TextButton(
                          onPressed: () => taps++,
                          child: Text(label),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('left'));
    await t.tap(find.text('right'));
    await t.pump();
    expect(taps, 2);
    expect(t.takeException(), isNull);
  });

  testWidgets('a swiping pager still passes taps on Android edge controls', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 600);
    t.view.devicePixelRatio = 1;
    t.view.systemGestureInsets = const FakeViewPadding(left: 40, right: 40);
    addTearDown(t.view.reset);
    var taps = 0;
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: RaftSectionPager<String>(
            sections: const ['a', 'b'],
            value: 'a',
            onChanged: (_) {},
            builder: (_, _) => Stack(
              children: [
                for (final left in [0.0, 358.0])
                  Positioned(
                    left: left,
                    top: 100,
                    width: 32,
                    height: 48,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => taps++,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tapAt(const Offset(10, 120));
    await t.tapAt(const Offset(380, 120));
    expect(taps, 2);
    // A swipe starting on the same edge control still belongs to system Back.
    final position = t.state<ScrollableState>(find.byType(Scrollable)).position;
    final gesture = await t.startGesture(const Offset(10, 120));
    await gesture.moveBy(const Offset(270, 0));
    await gesture.up();
    await t.pumpAndSettle();
    expect(position.pixels, 0);
    expect(taps, 2);
  });

  for (final direction in TextDirection.values) {
    for (final right in [false, true]) {
      testWidgets(
        'Android $direction ${right ? 'right' : 'left'} back edge never starts section input',
        (t) async {
          final fixture = _Fixture();
          await fixture.mount(t, direction: direction);
          final gesture = await t.startGesture(Offset(right ? 389 : 1, 300));
          // Content still sees the pointer (a tap on an edge control works);
          // only the pager's own drag ignores it.
          final position = t
              .state<ScrollableState>(find.byType(Scrollable))
              .position;
          final initialPixels = position.pixels;
          await gesture.moveBy(Offset(right ? -270 : 270, 0));
          for (var i = 0; i < 12; i++) {
            await t.pump(const Duration(milliseconds: 16));
            expect(position.pixels, initialPixels);
            expect(fixture.changes, isEmpty);
            expect(fixture.mounted, {'b'});
          }
          await gesture.up();
          await t.pumpAndSettle();
          expect(position.pixels, initialPixels);
          expect(fixture.changes, isEmpty);
          expect(fixture.taps, 0);

          // A canceled system gesture does not leave an app drag behind.
          final canceled = await t.startGesture(Offset(right ? 389 : 1, 300));
          await canceled.moveBy(Offset(right ? -270 : 270, 0));
          await canceled.cancel();
          await t.pumpAndSettle();
          expect(position.pixels, initialPixels);
          expect(fixture.changes, isEmpty);

          // Only a fresh gesture starting in content may page.
          await t.dragFrom(const Offset(300, 300), const Offset(-250, 0));
          await t.pumpAndSettle();
          expect(fixture.changes, [direction == TextDirection.ltr ? 'c' : 'a']);
          expect(t.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'system route back after an edge drag does not also select a section',
    (t) async {
      final fixture = _Fixture();
      final navigator = GlobalKey<NavigatorState>();
      fixture.setView(t);
      await t.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: ThemeData(platform: TargetPlatform.android),
          home: const Scaffold(body: Text('previous page')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(body: fixture.pager()),
        ),
      );
      await t.pumpAndSettle();
      final back = await t.startGesture(const Offset(389, 300));
      await back.moveBy(const Offset(-270, 0));
      await t.pump(const Duration(milliseconds: 100));
      await back.up();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('previous page'), findsOneWidget);
      expect(fixture.changes, isEmpty);
      expect(fixture.mounted, {'b'});
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('edge ownership follows changed physical insets at DPR 2', (
    t,
  ) async {
    final fixture = _Fixture();
    await fixture.mount(t);
    t.view.systemGestureInsets = const FakeViewPadding(left: 80, right: 80);
    await t.pumpAndSettle();
    await t.dragFrom(const Offset(365, 300), const Offset(-250, 0));
    await t.pumpAndSettle();
    expect(fixture.changes, isEmpty);
    t.view.systemGestureInsets = const FakeViewPadding();
    await t.pumpAndSettle();
    await t.dragFrom(const Offset(365, 300), const Offset(-250, 0));
    await t.pumpAndSettle();
    expect(fixture.changes, ['c']);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'an inset pager uses screen edges rather than its own local edges',
    (t) async {
      final fixture = _Fixture();
      await fixture.mount(t, inset: true);
      // Local x=1 is global x=61, outside the OS-owned display edge.
      await t.dragFrom(const Offset(61, 300), const Offset(240, 0));
      await t.pumpAndSettle();
      expect(fixture.changes, ['a']);
      expect(t.takeException(), isNull);
    },
  );

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    testWidgets(
      '$platform does not invent a system edge when none is reserved',
      (t) async {
        final fixture = _Fixture();
        await fixture.mount(
          t,
          platform: platform,
          reserveEdges: platform != TargetPlatform.android,
        );
        await t.dragFrom(const Offset(389, 300), const Offset(-270, 0));
        await t.pumpAndSettle();
        expect(fixture.changes, ['c']);
        expect(fixture.pointerDowns, 1);
        expect(t.takeException(), isNull);
      },
    );
  }
}

class _Fixture {
  String value = 'b';
  int pointerDowns = 0, taps = 0;
  final changes = <String>[];
  final mounted = <String>{};

  void setView(WidgetTester t, {bool reserveEdges = true}) {
    t.view.physicalSize = const Size(780, 1200);
    t.view.devicePixelRatio = 2;
    t.view.systemGestureInsets = reserveEdges
        ? const FakeViewPadding(left: 36, right: 36)
        : const FakeViewPadding();
    addTearDown(t.view.reset);
  }

  Widget pager() => StatefulBuilder(
    builder: (_, update) => RaftSectionPager<String>(
      sections: const ['a', 'b', 'c'],
      value: value,
      onChanged: (next) {
        changes.add(next);
        update(() => value = next);
      },
      builder: (_, id) {
        mounted.add(id);
        return Listener(
          onPointerDown: (_) => pointerDowns++,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: Center(child: Text(id)),
          ),
        );
      },
    ),
  );

  Future<void> mount(
    WidgetTester t, {
    TextDirection direction = TextDirection.ltr,
    TargetPlatform platform = TargetPlatform.android,
    bool reserveEdges = true,
    bool inset = false,
  }) async {
    setView(t, reserveEdges: reserveEdges);
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: Directionality(
            textDirection: direction,
            child: Padding(
              padding: inset
                  ? const EdgeInsets.symmetric(horizontal: 60)
                  : EdgeInsets.zero,
              child: pager(),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }
}
