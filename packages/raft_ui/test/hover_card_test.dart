import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget hoverHost(Widget child, {RaftFamily family = RaftFamily.elegant}) =>
    MaterialApp(
      theme: raftTheme(family),
      home: Scaffold(body: Center(child: child)),
    );

Widget card(String label, {RaftHoverCardController? controller}) =>
    RaftHoverCard(
      controller: controller,
      card: (_) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Card $label'),
      ),
      child: SizedBox(width: 80, height: 30, child: Text('Trigger $label')),
    );

Future<TestGesture> mouseAt(WidgetTester tester, Offset at) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(at);
  return mouse;
}

Future<void> settle(WidgetTester tester, TestGesture mouse) async {
  await mouse.removePointer();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('opens after the Web 200ms delay below the trigger', (
    tester,
  ) async {
    await tester.pumpWidget(hoverHost(card('A')));
    final mouse = await mouseAt(
      tester,
      tester.getCenter(find.text('Trigger A')),
    );
    await tester.pump(const Duration(milliseconds: 190));
    expect(find.text('Card A'), findsNothing);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Card A'), findsOneWidget);
    final trigger = tester.getRect(find.text('Trigger A'));
    final surface = tester.getRect(
      find.byKey(const ValueKey('raft-hover-card-surface')),
    );
    // side bottom, align start, sideOffset 6, w-[280px].
    expect(surface.top, moreOrLessEquals(trigger.bottom + 6));
    expect(surface.left, moreOrLessEquals(trigger.left));
    expect(surface.width, 280);
    await settle(tester, mouse);
  });

  testWidgets('the pointer can travel into the card; leaving both closes', (
    tester,
  ) async {
    await tester.pumpWidget(hoverHost(card('B')));
    final mouse = await mouseAt(
      tester,
      tester.getCenter(find.text('Trigger B')),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Card B'), findsOneWidget);
    // Into the card within the 120ms grace.
    await mouse.moveTo(tester.getCenter(find.text('Card B')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Card B'), findsOneWidget);
    await mouse.moveTo(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 119));
    expect(find.text('Card B'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Card B'), findsNothing);
    await settle(tester, mouse);
  });

  testWidgets('Escape and a trigger press dismiss it', (tester) async {
    await tester.pumpWidget(hoverHost(card('C')));
    final at = tester.getCenter(find.text('Trigger C'));
    final mouse = await mouseAt(tester, at);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Card C'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Card C'), findsNothing);
    // Staying on the trigger does not reopen it.
    await mouse.moveBy(const Offset(2, 0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Card C'), findsNothing);
    // Re-entering does; a press closes it again.
    await mouse.moveTo(const Offset(5, 5));
    await tester.pump();
    await mouse.moveTo(at);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Card C'), findsOneWidget);
    await mouse.down(at);
    await tester.pump();
    await mouse.up();
    await tester.pump();
    expect(find.text('Card C'), findsNothing);
    await settle(tester, mouse);
  });

  testWidgets('a touch never opens it', (tester) async {
    await tester.pumpWidget(hoverHost(card('D')));
    await tester.tap(find.text('Trigger D'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Card D'), findsNothing);
  });

  testWidgets('rows scrolled under a resting pointer open no card', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      hoverHost(
        SizedBox(
          width: 200,
          height: 300,
          child: ListView(
            controller: scroll,
            children: [
              for (var i = 0; i < 40; i++)
                RaftHoverCard(
                  card: (_) => Text('Card $i'),
                  child: SizedBox(height: 30, child: Text('Row $i')),
                ),
            ],
          ),
        ),
      ),
    );
    final mouse = await mouseAt(tester, tester.getCenter(find.text('Row 2')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Card 2'), findsOneWidget);
    // Scrolling closes it; rows passing under the pointer stay quiet.
    for (var step = 1; step <= 6; step++) {
      scroll.jumpTo(step * 45.0);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Card '), findsNothing);
    }
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Card '), findsNothing);
    // A real pointer move is hover intent again.
    await mouse.moveBy(const Offset(3, 0));
    await tester.pump(const Duration(milliseconds: 199));
    expect(find.textContaining('Card '), findsNothing);
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Card '), findsOneWidget);
    await settle(tester, mouse);
  });

  testWidgets('keyboard focus opens it; a pinned card ignores pointer exit', (
    tester,
  ) async {
    final controller = RaftHoverCardController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      hoverHost(
        RaftHoverCard(
          controller: controller,
          card: (_) => const Text('Card E'),
          child: TextButton(onPressed: () {}, child: const Text('Trigger E')),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Card E'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Card E'), findsNothing);

    controller.open(pinned: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.pinned, isTrue);
    final mouse = await mouseAt(
      tester,
      tester.getCenter(find.text('Trigger E')),
    );
    await mouse.moveTo(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Card E'), findsOneWidget);
    // An outside press closes a pinned card.
    await mouse.down(const Offset(5, 5));
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Card E'), findsNothing);
    await settle(tester, mouse);
  });

  testWidgets('flips above when there is no room below', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomLeft,
            child: RaftHoverCard(
              card: (_) => const SizedBox(height: 120, child: Text('Card F')),
              child: const SizedBox(width: 60, height: 30, child: Text('F')),
            ),
          ),
        ),
      ),
    );
    final mouse = await mouseAt(tester, tester.getCenter(find.text('F')));
    await tester.pump(const Duration(milliseconds: 210));
    await tester.pump(const Duration(milliseconds: 300));
    final trigger = tester.getRect(find.text('F'));
    final surface = tester.getRect(
      find.byKey(const ValueKey('raft-hover-card-surface')),
    );
    expect(surface.bottom, moreOrLessEquals(trigger.top - 6));
    await settle(tester, mouse);
  });
}
