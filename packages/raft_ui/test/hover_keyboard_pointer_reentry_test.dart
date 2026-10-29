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
  testWidgets(
    'fresh pointer movement reopens a navigation-retired keyboard tooltip',
    (t) async {
      final host = _NavigationHost();
      final focus = FocusNode();
      addTearDown(host.location.dispose);
      addTearDown(focus.dispose);
      TestGesture? mouse;
      try {
        await t.pumpWidget(
          host.build(
            RaftControl(
              focusNode: focus,
              tooltip: 'Profile popup',
              onPressed: () {},
              child: const Text('Profile trigger'),
            ),
          ),
        );
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await rest(t);
        expect(focus.hasFocus, isTrue);
        expect(find.text('Profile popup'), findsOneWidget);
        mouse = await mouseAt(t);
        await rest(t);
        host.location.value = '/channel/a?profile=agent-1';
        await t.pump();
        host.location.value = '/channel/a';
        await rest(t);
        await t.pump(const Duration(seconds: 1));
        expect(focus.hasFocus, isTrue);
        expect(find.text('Profile popup'), findsNothing);
        await mouse.moveBy(const Offset(1, 0));
        // RaftControl uses the unmodified 600ms tooltip hover delay.
        await t.pump(const Duration(milliseconds: 590));
        expect(find.text('Profile popup'), findsNothing);
        await t.pump(const Duration(milliseconds: 20));
        await t.pump(const Duration(milliseconds: 200));
        expect(focus.hasFocus, isTrue);
        expect(find.text('Profile popup'), findsOneWidget);
      } finally {
        await mouse?.removePointer();
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      }
    },
  );
  testWidgets(
    'retained keyboard focus still requires pointer rest and respects Escape',
    (t) async {
      final host = _NavigationHost();
      final focus = FocusNode();
      addTearDown(host.location.dispose);
      addTearDown(focus.dispose);
      TestGesture? mouse;
      try {
        await t.pumpWidget(
          host.build(
            RaftControl(
              focusNode: focus,
              tooltip: 'Profile popup',
              onPressed: () {},
              child: const Text('Profile trigger'),
            ),
          ),
        );
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await rest(t);
        expect(find.text('Profile popup'), findsOneWidget);
        mouse = await mouseAt(t);
        await rest(t);
        host.location.value = '/agents';
        await t.pump();
        host.location.value = '/channel/a';
        await t.pump(const Duration(seconds: 1));
        expect(focus.hasFocus, isTrue);
        expect(find.text('Profile popup'), findsNothing);
        // Every physical move restarts the existing 600ms rest requirement.
        for (var step = 0; step < 7; step++) {
          await mouse.moveBy(const Offset(1, 0));
          await t.pump(const Duration(milliseconds: 100));
          expect(find.text('Profile popup'), findsNothing);
        }
        await t.pump(const Duration(milliseconds: 490));
        expect(find.text('Profile popup'), findsNothing);
        await t.pump(const Duration(milliseconds: 20));
        await t.pump(const Duration(milliseconds: 200));
        expect(focus.hasFocus, isTrue);
        expect(find.text('Profile popup'), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        expect(find.text('Profile popup'), findsNothing);
        await mouse.moveBy(const Offset(1, 0));
        await t.pump(const Duration(seconds: 1));
        expect(find.text('Profile popup'), findsNothing);
        await mouse.moveTo(const Offset(1, 1));
        await t.pump();
        await mouse.moveTo(t.getCenter(find.text('Profile trigger')));
        await t.pump(const Duration(milliseconds: 610));
        await t.pump(const Duration(milliseconds: 200));
        expect(focus.hasFocus, isTrue);
        expect(find.text('Profile popup'), findsOneWidget);
      } finally {
        await mouse?.removePointer();
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      }
    },
  );
}
