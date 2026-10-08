import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget host(
  Widget child, {
  RaftFamily family = RaftFamily.elegant,
  bool dark = false,
  Duration delay = const Duration(milliseconds: 600),
}) => MaterialApp(
  theme: raftTheme(family, dark: dark),
  home: Scaffold(
    body: RaftTooltipProvider(
      delay: delay,
      child: Center(child: child),
    ),
  ),
);

void main() {
  final themes = [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ];
  for (final (family, dark) in themes) {
    testWidgets('Product hover waits600ms with unchanged flow $family/$dark', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          RaftTooltip(
            message: 'Delayed help',
            child: SizedBox(
              width: 80,
              height: 32,
              child: TextButton(onPressed: () {}, child: const Text('A')),
            ),
          ),
          family: family,
          dark: dark,
        ),
      );
      final before = tester.getRect(find.text('A'));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(before.center);
      await tester.pump(const Duration(milliseconds: 599));
      expect(find.text('Delayed help'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Delayed help'), findsOneWidget);
      expect(tester.getRect(find.text('A')), before);
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.binding.transientCallbackCount, 0);
      final tokens = RaftTokens.of(tester.element(find.text('A')));
      final recipe = RaftTooltipRecipe(tokens);
      expect(recipe.sideOffset, family == RaftFamily.brutal ? 6 : 8);
      expect(recipe.text.fontSize, 13);
      expect(recipe.text.height, 18 / 13);
      expect(
        recipe.text.fontWeight,
        family == RaftFamily.brutal ? FontWeight.w700 : FontWeight.w500,
      );
      final box = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('raft-tooltip-surface')),
      );
      expect((box.decoration as BoxDecoration).color, recipe.background);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('Member strip override250 and hover exit cancels pending', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const RaftTooltip(
          message: 'Member',
          delay: Duration(milliseconds: 250),
          child: SizedBox(width: 80, height: 32, child: Text('B')),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('B')));
    await tester.pump(const Duration(milliseconds: 249));
    expect(find.text('Member'), findsNothing);
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Member'), findsNothing);
    await mouse.moveTo(tester.getCenter(find.text('B')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Member'), findsOneWidget);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'Moving hover rest timer restarts rather than opens during motion',
    (tester) async {
      await tester.pumpWidget(
        host(
          const RaftTooltip(
            message: 'Rest',
            child: SizedBox(width: 120, height: 32, child: Text('C')),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      final center = tester.getCenter(find.text('C'));
      await mouse.moveTo(center);
      await tester.pump(const Duration(milliseconds: 500));
      await mouse.moveTo(center + const Offset(3, 0));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Rest'), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Rest'), findsOneWidget);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('Adjacent provider trigger instant then expires after400', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RaftTooltip(
              message: 'First',
              child: SizedBox(width: 80, height: 32, child: Text('D')),
            ),
            RaftTooltip(
              message: 'Second',
              child: SizedBox(width: 80, height: 32, child: Text('E')),
            ),
          ],
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('D')));
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.text('First'), findsOneWidget);
    await mouse.moveTo(tester.getCenter(find.text('E')));
    await tester.pump();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 401));
    await mouse.moveTo(tester.getCenter(find.text('D')));
    await tester.pump(const Duration(milliseconds: 599));
    expect(find.text('First'), findsNothing);
    await tester.pump(const Duration(milliseconds: 151));
    expect(find.text('First'), findsOneWidget);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'Controlled genuine keyboard focus immediate, Escape finite, no focus creation',
    (tester) async {
      final focus = FocusNode();
      final projected = ValueNotifier(false);
      await tester.pumpWidget(
        host(
          ValueListenableBuilder<bool>(
            valueListenable: projected,
            builder: (context, keyboardFocused, child) => RaftTooltip(
              message: 'Keyboard help',
              keyboardFocused: keyboardFocused,
              child: TextButton(
                focusNode: focus,
                onPressed: () {},
                child: const Text('F'),
              ),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      final before = FocusManager.instance.primaryFocus;
      // Projection seam. Pages must also exercise actual RaftControl adapter.
      projected.value = focus.hasFocus;
      await tester.pump();
      await tester.pump();
      expect(find.text('Keyboard help'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, same(before));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.text('Keyboard help'), findsNothing);
      expect(FocusManager.instance.primaryFocus, same(before));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Keyboard help'), findsNothing);
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      projected.dispose();
      focus.dispose();
    },
  );

  testWidgets('Disabled and disposed triggers cannot reopen delayed hover', (
    tester,
  ) async {
    final enabled = ValueNotifier(true);
    await tester.pumpWidget(
      host(
        ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (context, value, _) => RaftTooltip(
            message: 'Canceled',
            enabled: value,
            child: const SizedBox(width: 80, height: 32, child: Text('G')),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('G')));
    await tester.pump(const Duration(milliseconds: 500));
    enabled.value = false;
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Canceled'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
    enabled.dispose();
  });

  testWidgets('Touch activates child once without hover tooltip', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        RaftTooltip(
          message: 'Mouse only',
          child: TextButton(onPressed: () => calls++, child: const Text('H')),
        ),
      ),
    );
    await tester.tap(find.text('H'));
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 1);
    expect(find.text('Mouse only'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'Continuous genuine wheel changes offset only by user delta and cancels retired hover',
    (tester) async {
      final scroll = ScrollController(initialScrollOffset: 240);
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 300,
            height: 200,
            child: ListView.builder(
              controller: scroll,
              itemExtent: 80,
              itemCount: 30,
              itemBuilder: (context, index) => RaftTooltip(
                key: ValueKey('tip-$index'),
                message: 'Help $index',
                child: SizedBox(height: 80, child: Text('Row $index')),
              ),
            ),
          ),
        ),
      );
      final viewport = tester.getRect(find.byType(ListView));
      final primary = FocusManager.instance.primaryFocus;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(viewport.center);
      for (var i = 0; i < 20; i++) {
        final before = scroll.offset;
        tester.binding.handlePointerEvent(
          PointerScrollEvent(
            position: viewport.center,
            kind: PointerDeviceKind.mouse,
            scrollDelta: const Offset(0, 10),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        expect(scroll.offset, closeTo(before + 10, .01));
        expect(FocusManager.instance.primaryFocus, same(primary));
        expect(tester.getRect(find.byType(ListView)), viewport);
      }
      final end = scroll.offset;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(scroll.offset, end);
      // The newly hovered row may legitimately open once motion stops. The
      // retired original row must not resurrect, move focus or reveal itself.
      expect(find.text('Help 4'), findsNothing);
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.binding.transientCallbackCount, 0);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      scroll.dispose();
    },
  );
}
