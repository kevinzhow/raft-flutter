import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

class _Location extends ValueNotifier<String> {
  _Location() : super('/channel/a');
  void refresh() => notifyListeners();
}

class _NavigationHost {
  final dismiss = RaftHoverDismissController();
  final location = _Location();
  final navigator = GlobalKey<NavigatorState>();

  Widget build(Widget child) => MaterialApp(
    theme: raftTheme().copyWith(platform: TargetPlatform.macOS),
    navigatorKey: navigator,
    navigatorObservers: [dismiss],
    builder: (context, child) => RaftHoverDismissScope(
      controller: dismiss,
      navigation: location,
      location: () => location.value,
      child: child!,
    ),
    home: Scaffold(body: Center(child: child)),
  );

  void push() => navigator.currentState!.push<void>(
    MaterialPageRoute(
      builder: (_) => const Scaffold(body: Center(child: Text('Detail page'))),
    ),
  );
}

Widget trigger(bool tooltip, {FocusNode? focus}) {
  final child = focus == null
      ? const SizedBox(width: 80, height: 40, child: Text('Profile trigger'))
      : TextButton(
          focusNode: focus,
          onPressed: () {},
          child: const Text('Profile trigger'),
        );
  return tooltip
      ? RaftTooltip(
          message: 'Profile popup',
          delay: const Duration(milliseconds: 200),
          child: child,
        )
      : RaftHoverCard(card: (_) => const Text('Profile popup'), child: child);
}

Future<TestGesture> mouseAt(WidgetTester t) async {
  final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(t.getCenter(find.text('Profile trigger')));
  return mouse;
}

Future<void> rest(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 220));
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  for (final tooltip in [false, true]) {
    final family = tooltip ? 'tooltip' : 'hover card';
    testWidgets(
      '$family retires on logical navigation and requires new movement',
      (t) async {
        final host = _NavigationHost();
        addTearDown(host.location.dispose);
        TestGesture? mouse;
        try {
          await t.pumpWidget(host.build(trigger(tooltip)));
          mouse = await mouseAt(t);
          await rest(t);
          expect(find.text('Profile popup'), findsOneWidget);
          // A data refresh at the same location preserves the user's preview.
          host.location.refresh();
          await t.pump();
          expect(find.text('Profile popup'), findsOneWidget);
          host.location.value = '/channel/a?profile=agent-1';
          await t.pump();
          expect(find.text('Profile popup'), findsNothing);
          host.location.value = '/channel/a';
          await rest(t);
          expect(find.text('Profile popup'), findsNothing);
          await mouse.moveBy(const Offset(1, 0));
          await rest(t);
          expect(find.text('Profile popup'), findsOneWidget);
        } finally {
          await mouse?.removePointer();
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 1));
        }
      },
    );

    testWidgets('$family cancels a pending open on navigation and return', (
      t,
    ) async {
      final host = _NavigationHost();
      addTearDown(host.location.dispose);
      TestGesture? mouse;
      try {
        await t.pumpWidget(host.build(trigger(tooltip)));
        mouse = await mouseAt(t);
        await t.pump(const Duration(milliseconds: 100));
        host.location.value = '/agents';
        await t.pump();
        host.location.value = '/channel/a';
        await rest(t);
        expect(find.text('Profile popup'), findsNothing);
        await mouse.moveBy(const Offset(1, 0));
        await rest(t);
        expect(find.text('Profile popup'), findsOneWidget);
      } finally {
        await mouse?.removePointer();
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      }
    });

    testWidgets('$family closes for a pushed route and stays closed on pop', (
      t,
    ) async {
      final host = _NavigationHost();
      addTearDown(host.location.dispose);
      TestGesture? mouse;
      try {
        await t.pumpWidget(host.build(trigger(tooltip)));
        mouse = await mouseAt(t);
        await rest(t);
        expect(find.text('Profile popup'), findsOneWidget);
        host.push();
        await t.pumpAndSettle();
        expect(find.text('Detail page'), findsOneWidget);
        expect(find.text('Profile popup'), findsNothing);
        host.navigator.currentState!.pop();
        await t.pumpAndSettle();
        await rest(t);
        expect(find.text('Profile trigger'), findsOneWidget);
        expect(find.text('Profile popup'), findsNothing);
        await mouse.moveBy(const Offset(1, 0));
        await rest(t);
        expect(find.text('Profile popup'), findsOneWidget);
      } finally {
        await mouse?.removePointer();
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      }
    });
  }

  testWidgets(
    'a pending card cannot open behind a new route or on its return',
    (t) async {
      final host = _NavigationHost();
      addTearDown(host.location.dispose);
      TestGesture? mouse;
      try {
        await t.pumpWidget(host.build(trigger(false)));
        mouse = await mouseAt(t);
        await t.pump(const Duration(milliseconds: 100));
        host.push();
        await t.pumpAndSettle();
        expect(find.text('Profile popup'), findsNothing);
        host.navigator.currentState!.pop();
        await t.pumpAndSettle();
        await rest(t);
        expect(find.text('Profile popup'), findsNothing);
      } finally {
        await mouse?.removePointer();
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      }
    },
  );

  testWidgets('restored focus stays closed; fresh Tab focus opens a card', (
    t,
  ) async {
    final host = _NavigationHost();
    final focus = FocusNode();
    addTearDown(host.location.dispose);
    addTearDown(focus.dispose);
    try {
      await t.pumpWidget(
        host.build(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              trigger(false, focus: focus),
              TextButton(onPressed: () {}, child: const Text('Next')),
            ],
          ),
        ),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await rest(t);
      expect(focus.hasFocus, isTrue);
      expect(find.text('Profile popup'), findsOneWidget);
      host.push();
      await t.pumpAndSettle();
      host.navigator.currentState!.pop();
      await t.pumpAndSettle();
      await rest(t);
      expect(find.text('Profile popup'), findsNothing);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await rest(t);
      expect(focus.hasFocus, isTrue);
      expect(find.text('Profile popup'), findsOneWidget);
    } finally {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    }
  });

  testWidgets(
    'a pinned card keeps exit/scroll behavior but retires with its page',
    (t) async {
      final host = _NavigationHost();
      final card = RaftHoverCardController();
      addTearDown(host.location.dispose);
      addTearDown(card.dispose);
      TestGesture? mouse;
      try {
        await t.pumpWidget(
          host.build(
            RaftHoverCard(
              controller: card,
              closeOnTriggerPress: false,
              card: (_) => const Text('Profile popup'),
              child: const SizedBox(
                width: 80,
                height: 40,
                child: Text('Profile trigger'),
              ),
            ),
          ),
        );
        mouse = await mouseAt(t);
        card.open(pinned: true);
        await rest(t);
        await mouse.moveTo(const Offset(1, 1));
        await t.sendEventToBinding(
          const PointerScrollEvent(
            position: Offset(1, 1),
            scrollDelta: Offset(0, 20),
          ),
        );
        await rest(t);
        expect(card.pinned, isTrue);
        expect(find.text('Profile popup'), findsOneWidget);
        host.location.value = '/agents';
        await t.pump();
        expect(card.pinned, isFalse);
        expect(find.text('Profile popup'), findsNothing);
      } finally {
        await mouse?.removePointer();
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      }
    },
  );
  testWidgets(
    'restored keyboard tooltip stays closed until fresh focus entry',
    (t) async {
      final host = _NavigationHost();
      final focus = FocusNode();
      addTearDown(host.location.dispose);
      addTearDown(focus.dispose);
      try {
        await t.pumpWidget(
          host.build(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RaftControl(
                  focusNode: focus,
                  tooltip: 'Profile popup',
                  onPressed: () {},
                  child: const Text('Profile trigger'),
                ),
                TextButton(onPressed: () {}, child: const Text('Next')),
              ],
            ),
          ),
        );
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await rest(t);
        expect(focus.hasFocus, isTrue);
        expect(find.text('Profile popup'), findsOneWidget);
        host.push();
        await t.pumpAndSettle();
        host.navigator.currentState!.pop();
        await t.pumpAndSettle();
        await rest(t);
        expect(find.text('Profile popup'), findsNothing);
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
        expect(focus.hasFocus, isFalse);
        await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await rest(t);
        expect(focus.hasFocus, isTrue);
        expect(find.text('Profile popup'), findsOneWidget);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      }
    },
  );
}
