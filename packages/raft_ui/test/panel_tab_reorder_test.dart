import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  Future<List<List<String>>> pump(
    WidgetTester tester, {
    bool reorderable = true,
    TargetPlatform platform = TargetPlatform.linux,
  }) async {
    final orders = <List<String>>[];
    tester.view.physicalSize = const Size(900, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: platform),
        home: Scaffold(
          body: RaftPanelTabBar<String>(
            value: 'a',
            onChanged: (_) {},
            onReorder: reorderable ? orders.add : null,
            tabs: const [
              RaftPanelTab('a', 'Alpha', RaftGlyph.bot),
              RaftPanelTab('b', 'Beta', RaftGlyph.bot),
              RaftPanelTab('c', 'Gamma', RaftGlyph.bot),
            ],
          ),
        ),
      ),
    );
    return orders;
  }

  testWidgets('a tab dragged onto another takes its place', (tester) async {
    final orders = await pump(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('panel-tab-c'))),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('panel-tab-a'))),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(orders, [
      ['c', 'a', 'b'],
    ]);
  });

  testWidgets('a tap still selects and a drop on itself changes nothing', (
    tester,
  ) async {
    final orders = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('panel-tab-b')));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('panel-tab-b'))),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.moveBy(const Offset(4, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(orders, isEmpty);
  });

  testWidgets('a finger drags after a long press, so the strip still scrolls', (
    tester,
  ) async {
    final orders = await pump(tester, platform: TargetPlatform.android);
    // A quick swipe does not lift a tab.
    await tester.drag(
      find.byKey(const ValueKey('panel-tab-c')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(orders, isEmpty);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('panel-tab-b'))),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('panel-tab-a'))),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(orders, [
      ['b', 'a', 'c'],
    ]);
  });

  testWidgets('without onReorder the tabs are not draggable', (tester) async {
    final orders = await pump(tester, reorderable: false);
    expect(find.byType(Draggable<Object>), findsNothing);
    expect(find.byType(DragTarget<Object>), findsNothing);
    expect(orders, isEmpty);
  });
}
