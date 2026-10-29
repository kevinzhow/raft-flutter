import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/desktop_title_bar.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;

/// A runner stand-in on `app.raft/titlebar`: records what the app sends and
/// can push `state` the way the macOS runner does on resize / fullscreen.
class _Runner {
  _Runner(this.tester, {this.height = 28}) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'status') {
        return {'height': height, 'fullscreen': fullscreen};
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
  }

  final WidgetTester tester;
  final channel = const MethodChannel(DesktopTitleBarController.channelName);
  final calls = <MethodCall>[];
  double height;
  bool fullscreen = false;

  List<MethodCall> named(String method) => [
    for (final call in calls)
      if (call.method == method) call,
  ];

  Future<Object?> cancelPointer(int stamp, {VoidCallback? onReply}) async {
    Object? reply;
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        MethodCall('cancelHeaderPointer', {'downTimestampMicros': stamp}),
      ),
      (message) {
        reply = channel.codec.decodeEnvelope(message!);
        onReply?.call();
      },
    );
    return reply;
  }

  Future<void> push({double? height, bool? fullscreen}) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        MethodCall('state', {
          'height': height ?? this.height,
          'fullscreen': fullscreen ?? this.fullscreen,
        }),
      ),
      (_) {},
    );
    await tester.pump();
  }
}

Widget _app(
  DesktopTitleBarController controller, {
  bool dark = false,
  Widget child = const SizedBox.expand(key: Key('content')),
}) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: RepaintBoundary(
    key: const Key('titlebar-surface'),
    child: DesktopTitleBar(controller: controller, child: child),
  ),
);

void main() {
  // Leak debt (other): see docs/development.md, Leak tracking.
  leakDebt(const ['ValueNotifier<DesktopTitleBarState>']);
  testWidgets('header cancellation: waits for its not-yet-delivered down', (
    tester,
  ) async {
    final runner = _Runner(tester);
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.macOS,
      web: false,
    );
    final events = <String>[];
    var taps = 0;
    await tester.pumpWidget(
      _app(
        controller,
        child: Listener(
          onPointerCancel: (_) => events.add('cancel'),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final pending = runner.cancelPointer(
      700707,
      onReply: () => events.add('ack'),
    );
    final repeated = runner.cancelPointer(
      700707,
      onReply: () => events.add('repeated ack'),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    var pressed = false;
    try {
      await tester.idle();
      expect(events, isEmpty);
      await mouse.down(
        const Offset(400, 100),
        timeStamp: const Duration(microseconds: 700707),
      );
      pressed = true;
      expect(await Future.wait([pending, repeated]), [true, true]);
      expect(events.first, 'cancel');
      expect(events.where((event) => event == 'cancel'), hasLength(1));
      expect(events, hasLength(3));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await Future.wait([pending, repeated]);
      if (pressed) await mouse.up();
      await mouse.removePointer();
    }
    expect(taps, 0);
  });

  testWidgets('header cancellation: ack waits for unlocked pointer dispatch', (
    tester,
  ) async {
    final runner = _Runner(tester);
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.macOS,
      web: false,
    );
    final events = <String>[];
    await tester.pumpWidget(
      _app(
        controller,
        child: Listener(
          onPointerCancel: (_) => events.add('cancel'),
          child: const ColoredBox(color: Colors.white),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.down(
      const Offset(400, 100),
      timeStamp: const Duration(microseconds: 800808),
    );
    final routes = GestureBinding.instance.pointerRouter.debugGlobalRouteCount;
    final unlock = Completer<void>();
    // ignore: invalid_use_of_protected_member -- Exercise the binding's real input lock.
    final held = tester.binding.lockEvents(() => unlock.future);
    final pending = runner.cancelPointer(
      800808,
      onReply: () => events.add('ack'),
    );
    try {
      try {
        await tester.idle();
        expect(events, isEmpty);
        expect(
          GestureBinding.instance.pointerRouter.debugGlobalRouteCount,
          routes + 1,
        );
      } finally {
        unlock.complete();
        await held;
      }
      expect(await pending, isTrue);
      expect(events, ['cancel', 'ack']);
      expect(
        GestureBinding.instance.pointerRouter.debugGlobalRouteCount,
        routes,
      );
    } finally {
      await mouse.up();
      await mouse.removePointer();
    }
  });

  testWidgets(
    'header cancellation: unmount rejects pending ack and removes route',
    (tester) async {
      final runner = _Runner(tester);
      final controller = DesktopTitleBarController(
        platform: TargetPlatform.macOS,
        web: false,
      );
      await tester.pumpWidget(
        _app(controller, child: const ColoredBox(color: Colors.white)),
      );
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.down(
        const Offset(400, 100),
        timeStamp: const Duration(microseconds: 900909),
      );
      final routes =
          GestureBinding.instance.pointerRouter.debugGlobalRouteCount;
      final unlock = Completer<void>();
      // ignore: invalid_use_of_protected_member -- Keep cancellation pending through unmount.
      final held = tester.binding.lockEvents(() => unlock.future);
      final pending = runner.cancelPointer(900909);
      try {
        await tester.idle();
        expect(
          GestureBinding.instance.pointerRouter.debugGlobalRouteCount,
          routes + 1,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        expect(await pending, isFalse);
        expect(
          GestureBinding.instance.pointerRouter.debugGlobalRouteCount,
          routes,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        unlock.complete();
        await held;
        await pending;
        await mouse.up();
        await mouse.removePointer();
      }
    },
  );

  testWidgets('header pointer: standalone drag snapshots the mouse down', (
    tester,
  ) async {
    final runner = _Runner(tester);
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.macOS,
      web: false,
    );
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.down(
      const Offset(400, 10),
      timeStamp: const Duration(microseconds: 100101),
    );
    var pressed = true;
    try {
      await mouse.moveBy(
        const Offset(60, 0),
        timeStamp: const Duration(microseconds: 150101),
      );
      expect(runner.named('startDragging').single.arguments, {
        'downTimestampMicros': 100101,
      });
      final pending = controller.startDragging();
      await mouse.up();
      pressed = false;
      await pending;
      expect(runner.named('startDragging').last.arguments, {
        'downTimestampMicros': 100101,
      });
      await controller.startDragging();
      expect(runner.named('startDragging').last.arguments, isNull);
    } finally {
      // A failed expectation may leave the gesture pressed.
      if (pressed) await mouse.cancel();
      await mouse.removePointer();
      await tester.pump(const Duration(milliseconds: 400));
    }
  });

  testWidgets('header pointer: native cancel precedes its ack and blocks tap', (
    tester,
  ) async {
    final runner = _Runner(tester);
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.macOS,
      web: false,
    );
    final events = <String>[];
    var taps = 0;
    await tester.pumpWidget(
      _app(
        controller,
        child: Listener(
          onPointerCancel: (_) => events.add('cancel'),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.down(
      const Offset(400, 100),
      timeStamp: const Duration(microseconds: 200202),
    );
    try {
      final ack = await runner.cancelPointer(
        200202,
        onReply: () => events.add('ack'),
      );
      expect(events, ['cancel', 'ack']);
      expect(ack, isTrue);
      await controller.startDragging();
      expect(runner.named('startDragging').last.arguments, isNull);
    } finally {
      await mouse.up();
      await mouse.removePointer();
    }
    expect(taps, 0);
  });

  testWidgets('header pointer: stale cancel preserves the next real tap', (
    tester,
  ) async {
    final runner = _Runner(tester);
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.macOS,
      web: false,
    );
    var taps = 0;
    var cancels = 0;
    await tester.pumpWidget(
      _app(
        controller,
        child: Listener(
          onPointerCancel: (_) => cancels++,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final old = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await old.down(
      const Offset(400, 100),
      timeStamp: const Duration(microseconds: 300303),
    );
    await old.up();
    await old.removePointer();
    expect(taps, 1);
    final current = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await current.down(
      const Offset(400, 100),
      timeStamp: const Duration(microseconds: 400404),
    );
    try {
      expect(await runner.cancelPointer(300303), isTrue);
      expect(cancels, 0);
      await controller.startDragging();
      expect(runner.named('startDragging').last.arguments, {
        'downTimestampMicros': 400404,
      });
    } finally {
      await current.up();
      await current.removePointer();
    }
    expect(taps, 2);
  });

  testWidgets('header pointer: unrelated release keeps the mouse record', (
    tester,
  ) async {
    final runner = _Runner(tester);
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.macOS,
      web: false,
    );
    await tester.pumpWidget(
      _app(controller, child: const ColoredBox(color: Colors.white)),
    );
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final touch = await tester.createGesture(kind: PointerDeviceKind.touch);
    await mouse.down(
      const Offset(400, 100),
      timeStamp: const Duration(microseconds: 500505),
    );
    var pressed = true;
    try {
      await touch.down(const Offset(450, 100));
      await touch.up();
      await controller.startDragging();
      expect(runner.named('startDragging').last.arguments, {
        'downTimestampMicros': 500505,
      });
      await mouse.cancel();
      pressed = false;
      await controller.startDragging();
      expect(runner.named('startDragging').last.arguments, isNull);
    } finally {
      if (pressed) await mouse.up();
      await mouse.removePointer();
    }
  });

  testWidgets('header pointer: touch and secondary mouse retain legacy args', (
    tester,
  ) async {
    final runner = _Runner(tester);
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.macOS,
      web: false,
    );
    await tester.pumpWidget(
      _app(controller, child: const ColoredBox(color: Colors.white)),
    );
    await tester.pumpAndSettle();
    for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
      final gesture = await tester.createGesture(
        kind: kind,
        buttons: kind == PointerDeviceKind.mouse
            ? kSecondaryMouseButton
            : kPrimaryButton,
      );
      await gesture.down(const Offset(400, 100));
      try {
        await controller.startDragging();
        expect(runner.named('startDragging').last.arguments, isNull);
      } finally {
        await gesture.up();
        if (kind == PointerDeviceKind.mouse) await gesture.removePointer();
      }
    }
  });

  testWidgets('macOS: the standalone brand row stays 48px', (tester) async {
    final runner = _Runner(tester, height: 32);
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.macOS,
      web: false,
    );
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    expect(find.byType(RaftDesktopTitleStrip), findsOneWidget);
    expect(tester.getSize(find.byType(RaftDesktopTitleStrip)).height, 48);
    expect(tester.getRect(find.byKey(const Key('content'))).top, 48);
    expect(runner.named('status'), hasLength(1));
  });

  testWidgets('macOS: fullscreen retains the standalone brand row', (
    tester,
  ) async {
    final runner = _Runner(tester);
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.macOS,
      web: false,
    );
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    expect(find.byType(RaftDesktopTitleStrip), findsOneWidget);
    // Native controls hide, while the Flutter brand row remains.
    await runner.push(height: 0, fullscreen: true);
    expect(find.byType(RaftDesktopTitleStrip), findsOneWidget);
    expect(tester.getRect(find.byKey(const Key('content'))).top, 48);
    // Native measurements do not change the reference frame height.
    await runner.push(height: 28, fullscreen: true);
    expect(find.byType(RaftDesktopTitleStrip), findsOneWidget);
    await runner.push(height: 28, fullscreen: false);
    expect(find.byType(RaftDesktopTitleStrip), findsOneWidget);
  });

  testWidgets('macOS: drag and double tap reach the runner', (tester) async {
    final runner = _Runner(tester);
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.macOS,
      web: false,
    );
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    await tester.dragFrom(const Offset(400, 10), const Offset(50, 0));
    expect(runner.named('startDragging'), hasLength(1));
    await tester.tapAt(const Offset(400, 10));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(400, 10));
    await tester.pump(const Duration(milliseconds: 400));
    expect(runner.named('doubleClick'), hasLength(1));
  });

  testWidgets('every theme sends the rail colours, once per change', (
    tester,
  ) async {
    final runner = _Runner(tester);
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.macOS,
      web: false,
    );
    for (final (dark) in [(false), (true)]) {
      await tester.pumpWidget(_app(controller, dark: dark));
      await tester.pumpAndSettle();
      final tokens = raftTheme(dark: dark).extension<RaftTokens>()!;
      final rail = RaftRailRecipe(tokens, viewportHeight: 800);
      final sent = runner.named('setStyle').last.arguments as Map;
      expect(sent['background'], rail.background.toARGB32());
      expect(
        sent['rule'],
        Color.alphaBlend(rail.border.color, rail.background).toARGB32(),
      );
      expect(sent['ruleWidth'], 1.0);
      expect(sent['dark'], dark);
    }
    final before = runner.named('setStyle').length;
    await tester.pump();
    await tester.pumpWidget(_app(controller, dark: true));
    await tester.pumpAndSettle();
    expect(runner.named('setStyle'), hasLength(before));
  });

  testWidgets('Linux: GTK draws the bar and rule, the app sends colours', (
    tester,
  ) async {
    final runner = _Runner(tester, height: 0);
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.linux,
      web: false,
    );
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    expect(find.byType(RaftDesktopTitleStrip), findsNothing);
    expect(tester.getRect(find.byKey(const Key('content'))).top, 0);
    expect(runner.named('setStyle'), hasLength(1));
    // Even a runner that wrongly reported a height cannot make the app
    // draw a second strip over the system's bar.
    await runner.push(height: 28);
    expect(find.byType(RaftDesktopTitleStrip), findsNothing);
  });

  testWidgets('Windows: only the rule is painted across every theme', (
    tester,
  ) async {
    final runner = _Runner(tester);
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.windows,
      web: false,
    );
    for (final (dark) in [(false), (true)]) {
      final tokens = raftTheme(dark: dark).extension<RaftTokens>()!;
      final rail = RaftRailRecipe(tokens, viewportHeight: 600);
      final width = 1.0;
      double? viewportHeight;
      await tester.pumpWidget(
        _app(
          controller,
          dark: dark,
          child: Builder(
            builder: (context) {
              viewportHeight = MediaQuery.sizeOf(context).height;
              return ColoredBox(
                color: tokens.canvas,
                child: const SizedBox.expand(key: Key('content')),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(RaftDesktopTitleStrip)),
        Rect.fromLTWH(0, 0, 800, width),
      );
      expect(tester.getRect(find.byKey(const Key('content'))).top, width);
      expect(viewportHeight, 600 - width);
      // Inspect the painted pixels, including both ends of the full-width
      // rule and the first content row, rather than only its decoration.
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('titlebar-surface')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          Color pixel(int x, int y) {
            final index = (y * image.width + x) * 4;
            return Color.fromARGB(
              bytes.getUint8(index + 3),
              bytes.getUint8(index),
              bytes.getUint8(index + 1),
              bytes.getUint8(index + 2),
            );
          }

          final rule = Color.alphaBlend(rail.border.color, rail.background);
          for (final x in [0, 400, 799]) {
            for (var y = 0; y < width; y++) {
              expect(pixel(x, y).toARGB32(), rule.toARGB32());
            }
            expect(
              pixel(x, width.toInt()).toARGB32(),
              tokens.canvas.toARGB32(),
            );
          }
        } finally {
          image.dispose();
        }
      });
    }
    await tester.dragFrom(const Offset(400, .5), const Offset(60, 0));
    await tester.tapAt(const Offset(400, .5));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(400, .5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(runner.named('startDragging'), isEmpty);
    expect(runner.named('doubleClick'), isEmpty);
    // Native caption measurements do not add a second title bar.
    await runner.push(height: 28);
    expect(tester.getSize(find.byType(RaftDesktopTitleStrip)).height, 1);
    await runner.push(fullscreen: true);
    expect(find.byType(RaftDesktopTitleStrip), findsNothing);
    expect(tester.getRect(find.byKey(const Key('content'))).top, 0);
    await runner.push(fullscreen: false);
    expect(tester.getSize(find.byType(RaftDesktopTitleStrip)).height, 1);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform: nothing is drawn or sent', (tester) async {
      final runner = _Runner(tester);
      final controller = DesktopTitleBarController(
        platform: platform,
        web: false,
      );
      await tester.pumpWidget(_app(controller));
      await tester.pump();
      expect(find.byType(RaftDesktopTitleStrip), findsNothing);
      expect(runner.calls, isEmpty);
    });
  }

  testWidgets('macOS bundle without the channel: no strip', (tester) async {
    // An older runner answers nothing: the engine replies "not implemented".
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(DesktopTitleBarController.channelName),
      (call) async => throw MissingPluginException(),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel(DesktopTitleBarController.channelName),
        null,
      ),
    );
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.macOS,
      web: false,
    );
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    await tester.pump();
    expect(find.byType(RaftDesktopTitleStrip), findsNothing);
    expect(controller.state.value.height, 0);
  });
}
