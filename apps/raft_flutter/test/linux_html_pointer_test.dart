import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Exercise the maintained plugin's actual texture widget and channel ordering.
// ignore: implementation_imports
import 'package:flutter_inappwebview_linux/src/in_app_webview/custom_platform_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const manager = MethodChannel(
    'com.pichillilorenzo/flutter_inappwebview_manager',
  );
  const native = MethodChannel('com.pichillilorenzo/custom_platform_view_1');
  const events = MethodChannel(
    'com.pichillilorenzo/custom_platform_view_1_events',
  );
  final calls = <MethodCall>[];
  Completer<void>? pendingFocus;
  late FocusNode outside;

  setUp(() {
    calls.clear();
    pendingFocus = null;
    outside = FocusNode();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(manager, (call) async {
      return call.method == 'createInAppWebView' ? 1 : null;
    });
    messenger.setMockMethodCallHandler(events, (_) async => null);
    messenger.setMockMethodCallHandler(native, (call) async {
      calls.add(call);
      if (call.method == 'setFocused' && call.arguments == true) {
        await pendingFocus?.future;
      }
      return null;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [manager, native, events]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  Future<void> show(WidgetTester tester, {bool focused = false}) async {
    addTearDown(() async {
      if (pendingFocus != null && !pendingFocus!.isCompleted) {
        pendingFocus!.complete();
        await tester.pump();
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      outside.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Focus(focusNode: outside, child: const SizedBox(height: 10)),
            const Expanded(child: CustomPlatformView()),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final focus = tester
        .widgetList<Focus>(find.byType(Focus))
        .singleWhere(
          (widget) =>
              widget.debugLabel ==
              'flutter_inappwebview_linux_custom_platform_view',
        );
    if (focused) {
      focus.focusNode!.requestFocus();
    } else {
      outside.requestFocus();
    }
    await tester.pump();
    expect(focus.focusNode!.hasFocus, focused);
    calls.clear();
    if (!focused) pendingFocus = Completer<void>();
  }

  List<MethodCall> inputCalls() => calls
      .where(
        (call) =>
            call.method == 'setCursorPos' ||
            call.method == 'sendTouchEvent' ||
            (call.method == 'setPointerButton' &&
                [1, 4, 6].contains((call.arguments as Map)['kind'])),
      )
      .toList();

  List<int> kinds(String method, String field) => calls
      .where((call) => call.method == method)
      .map((call) => (call.arguments as Map)[field] as int)
      .where((kind) => method != 'setPointerButton' || ![2, 3].contains(kind))
      .toList();

  testWidgets('mouse Up and Move wait for the first native focus', (
    tester,
  ) async {
    await show(tester);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(tester.getCenter(find.byType(CustomPlatformView)));
    await gesture.moveBy(const Offset(2, 0));
    await gesture.up();
    await tester.pump();
    expect(inputCalls(), isEmpty);
    pendingFocus!.complete();
    await tester.pump();
    expect(kinds('setPointerButton', 'kind'), [1, 4]);
    expect(calls.where((call) => call.method == 'setCursorPos').length, 2);
  });

  testWidgets('touch Down Move Up retain order across delayed focus', (
    tester,
  ) async {
    await show(tester);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
    await gesture.down(tester.getCenter(find.byType(CustomPlatformView)));
    await gesture.moveBy(const Offset(2, 0));
    await gesture.up();
    await tester.pump();
    expect(inputCalls(), isEmpty);
    pendingFocus!.complete();
    await tester.pump();
    expect(kinds('sendTouchEvent', 'type'), [0, 2, 1]);
  });

  testWidgets('Cancel cannot overtake a pending mouse Down', (tester) async {
    await show(tester);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(tester.getCenter(find.byType(CustomPlatformView)));
    await gesture.cancel();
    await tester.pump();
    expect(inputCalls(), isEmpty);
    pendingFocus!.complete();
    await tester.pump();
    expect(kinds('setPointerButton', 'kind'), [1, 6]);
  });

  testWidgets('already-focused fast first click remains a single click', (
    tester,
  ) async {
    await show(tester, focused: true);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(tester.getCenter(find.byType(CustomPlatformView)));
    await gesture.up();
    await tester.pump();
    expect(kinds('setPointerButton', 'kind'), [1, 4]);
    expect(calls.where((call) => call.method == 'setFocused'), isEmpty);
    expect(
      (calls.firstWhere((call) => call.method == 'setPointerButton').arguments
          as Map)['clickCount'],
      1,
    );
  });

  testWidgets('failed focus drops that gesture and permits the next one', (
    tester,
  ) async {
    await show(tester);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(tester.getCenter(find.byType(CustomPlatformView)));
    await gesture.moveBy(const Offset(2, 0));
    await gesture.up();
    pendingFocus!.completeError(PlatformException(code: 'focus-denied'));
    await tester.pump();
    expect(tester.takeException(), isA<PlatformException>());
    expect(inputCalls(), isEmpty);
    pendingFocus = Completer<void>()..complete();
    final retry = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await retry.down(tester.getCenter(find.byType(CustomPlatformView)));
    await retry.up();
    await tester.pump();
    expect(kinds('setPointerButton', 'kind'), [1, 4]);
  });

  testWidgets('dispose releases the queue without native focus completing', (
    tester,
  ) async {
    await show(tester);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(tester.getCenter(find.byType(CustomPlatformView)));
    await gesture.moveBy(const Offset(2, 0));
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(inputCalls(), isEmpty);
    pendingFocus!.complete();
    await tester.pump();
    expect(inputCalls(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late focus failure after dispose cannot send input or escape', (
    tester,
  ) async {
    await show(tester);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
    await gesture.down(tester.getCenter(find.byType(CustomPlatformView)));
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    pendingFocus!.completeError(PlatformException(code: 'late-focus-denied'));
    await tester.pump();
    expect(inputCalls(), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
