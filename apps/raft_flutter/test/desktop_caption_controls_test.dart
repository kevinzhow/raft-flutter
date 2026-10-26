import 'dart:ui' show PointerDeviceKind;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/desktop_title_bar.dart';
import 'package:raft_ui/raft_ui.dart';

class _Runner {
  _Runner(this.tester, {this.layout = ':minimize,maximize,close'}) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return call.method == 'status' || call.method == 'setIntegrated'
          ? state
          : null;
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
  final String layout;
  Map<String, Object> get state => {
    'height': 48.0,
    'customControls': true,
    'fullscreen': false,
    'maximized': false,
    'active': true,
    'buttonLayout': layout,
  };
  Future<void> push(Map<String, Object> changes) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        MethodCall('state', {...state, ...changes}),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
  }
}

DesktopTitleBarController _controller(TargetPlatform platform) {
  final controller = DesktopTitleBarController(platform: platform, web: false);
  addTearDown(() => controller.state.dispose());
  return controller;
}

Widget _app(
  DesktopTitleBarController controller, {
  bool integrated = true,
  bool rtl = false,
}) => MaterialApp(
  theme: raftTheme(),
  builder: (context, child) => Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: child!,
  ),
  home: DesktopTitleBar(
    controller: controller,
    integrated: integrated,
    child: const SizedBox.expand(key: Key('body')),
  ),
);

void main() {
  for (final platform in [
    TargetPlatform.linux,
    TargetPlatform.windows,
    TargetPlatform.macOS,
  ]) {
    for (final page in ['dialog', 'page', 'media']) {
      testWidgets('$platform preview $page clears the caption region once', (
        tester,
      ) async {
        final runner = _Runner(tester);
        final controller = _controller(platform);
        Widget app(bool integrated) => MaterialApp(
          theme: raftTheme(),
          builder: (_, child) => DesktopTitleBar(
            controller: controller,
            integrated: integrated,
            child: child!,
          ),
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  page == 'media'
                      ? RaftMediaBrowserRoute<void>(
                          builder: (_) => const Align(
                            alignment: Alignment.topLeft,
                            child: Text('Preview heading'),
                          ),
                        )
                      : page == 'page'
                      ? RaftPreviewPageRoute<void>(
                          builder: (_) => const RaftWindowChromePadding(
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text('Preview heading'),
                            ),
                          ),
                        )
                      : RaftFullBleedDialogRoute<void>(
                          context: context,
                          builder: (_) => const RaftWindowChromePadding(
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text('Preview heading'),
                            ),
                          ),
                        ),
                ),
                child: const Text('Open preview'),
              ),
            ),
          ),
        );

        await tester.pumpWidget(app(true));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open preview'));
        await tester.pumpAndSettle();
        final heading = find.text('Preview heading');
        expect(tester.getTopLeft(heading).dy, 48);
        final routeContent = tester.element(heading);
        await runner.push({'fullscreen': true});
        expect(tester.getTopLeft(heading).dy, 0);
        expect(find.byKey(const Key('desktop-caption-close')), findsNothing);
        await runner.push({'fullscreen': false});
        expect(tester.getTopLeft(heading).dy, 48);
        await tester.pumpWidget(app(false));
        await tester.pumpAndSettle();
        expect(tester.element(heading), same(routeContent));
        expect(tester.getTopLeft(heading).dy, 48);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Linux caption paint matches the shipped Web frame and glyph', (
    tester,
  ) async {
    _Runner(tester);
    final controller = _controller(TargetPlatform.linux);
    const boundaryKey = Key('caption-reference-pixels');
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: _app(controller, integrated: false),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      Color pixel(int x, int y) {
        final offset = (y * image.width + x) * 4;
        return Color.fromARGB(
          bytes.getUint8(offset + 3),
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        );
      }

      // Desktop 1.21.33, active light frame at 1x: 24px circles, 37px
      // centre spacing, last centre 22px from the right. Its minimize line
      // occupies one physical row; it is not a faded two-row stroke.
      final centre = image.width - 22 - 2 * 37;
      try {
        expect(pixel(centre, 24), const Color(0xff141111));
        expect(pixel(centre, 23), const Color(0xffe8c13b));
        expect(pixel(centre, 16), const Color(0xffe8c13b));
      } finally {
        image.dispose();
      }
    });
  });

  testWidgets(
    'root caption tooltips have an overlay and leave body interactive',
    (tester) async {
      _Runner(tester);
      final controller = _controller(TargetPlatform.linux);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          builder: (context, child) => DesktopTitleBar(
            controller: controller,
            integrated: true,
            child: child!,
          ),
          home: GestureDetector(
            key: const Key('root-caption-body'),
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(
        tester.getCenter(find.byKey(const Key('desktop-caption-close'))),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Close window'), findsOneWidget);
      await mouse.moveTo(const Offset(20, 200));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 200));
      await tester.pump();
      expect(taps, 1);
      await mouse.removePointer();
    },
  );
  testWidgets('Linux captions occupy one row and call runner commands', (
    tester,
  ) async {
    final runner = _Runner(tester);
    final controller = _controller(TargetPlatform.linux);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    for (final action in ['minimize', 'maximize', 'close']) {
      final finder = find.byKey(Key('desktop-caption-$action'));
      expect(finder, findsOneWidget);
      expect(tester.getSize(finder), const Size(37, 48));
      await tester.tap(finder);
      await tester.pump();
    }
    expect(
      runner.calls.map((c) => c.method),
      containsAllInOrder(['minimize', 'toggleMaximize', 'close']),
    );
    expect(tester.getTopLeft(find.byKey(const Key('body'))).dy, 0);
    final focus = tester.widget<FocusableActionDetector>(
      find.descendant(
        of: find.byKey(const Key('desktop-caption-minimize')),
        matching: find.byType(FocusableActionDetector),
      ),
    );
    focus.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      runner.calls.where((call) => call.method == 'minimize'),
      hasLength(2),
    );
  });
  testWidgets(
    'configured left captions keep positions and maximize state updates',
    (tester) async {
      final runner = _Runner(tester, layout: 'close,minimize:maximize');
      final controller = _controller(TargetPlatform.linux);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();
      final close = find.byKey(const Key('desktop-caption-close'));
      final max = find.byKey(const Key('desktop-caption-maximize'));
      expect(close, findsOneWidget);
      expect(tester.getTopLeft(close).dx, 4);
      expect(tester.getTopLeft(max).dx, 800 - 41);
      await runner.push({'maximized': true});
      expect(find.bySemanticsLabel('Restore window'), findsOneWidget);
      await runner.push({'fullscreen': true});
      expect(close, findsNothing);
      final rectCalls = runner.calls.where(
        (c) => c.method == 'setCaptionButtonRects',
      );
      expect(rectCalls.last.arguments, isEmpty);
    },
  );
  testWidgets('standalone custom chrome reserves 48px including fullscreen', (
    tester,
  ) async {
    final runner = _Runner(tester);
    final controller = _controller(TargetPlatform.linux);
    await tester.pumpWidget(_app(controller, integrated: false));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const Key('body'))).dy, 48);
    await runner.push({'fullscreen': true});
    expect(tester.getTopLeft(find.byKey(const Key('body'))).dy, 48);
    expect(find.byKey(const Key('desktop-caption-close')), findsNothing);
  });
  testWidgets(
    'Windows capability uses rectangular targets and reports hit bounds',
    (tester) async {
      final runner = _Runner(tester);
      final controller = _controller(TargetPlatform.windows);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();
      final max = find.byKey(const Key('desktop-caption-maximize'));
      expect(max, findsOneWidget);
      expect(tester.getSize(max), const Size(46, 48));
      final calls = runner.calls.where(
        (c) => c.method == 'setCaptionButtonRects',
      );
      final rect = (calls.last.arguments as Map)['maximize'];
      expect(rect, {'x': 708.0, 'y': 0.0, 'width': 46.0, 'height': 48.0});
    },
  );
  testWidgets(
    'caption reservation keeps working agents and notifications usable at 768px',
    (tester) async {
      _Runner(tester);
      final controller = _controller(TargetPlatform.linux);
      tester.view.physicalSize = const Size(768, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var notifications = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: DesktopTitleBar(
            controller: controller,
            integrated: true,
            child: Builder(
              builder: (context) {
                final scope = DesktopTitleBarScope.maybeOf(context)!;
                return Align(
                  alignment: Alignment.topCenter,
                  child: RaftWorkspaceTopBar(
                    workspace: const Text('Workspace'),
                    onSearch: () {},
                    leadingInset: scope.leadingInset,
                    trailingInset: scope.trailingInset,
                    trailing: [
                      RaftWorkingSummary(
                        onFrame: true,
                        agents: [
                          for (var i = 0; i < 3; i++)
                            RaftWorkingAgent(
                              id: '$i',
                              name: 'Agent $i',
                              text: 'Working',
                              avatar: const SizedBox(),
                            ),
                        ],
                      ),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: GestureDetector(
                          key: const Key('bell'),
                          onTap: () => notifications++,
                          child: const Text('Bell'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byKey(const Key('bell'))).right,
        lessThan(
          tester
              .getRect(find.byKey(const Key('desktop-caption-minimize')))
              .left,
        ),
      );
      await tester.tap(find.byKey(const Key('bell')));
      expect(notifications, 1);
      final search = tester.getRect(find.byKey(const Key('topbar-search')));
      expect(search.center.dx, closeTo(384, .01));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('caption configuration keeps its physical order in an RTL host', (
    tester,
  ) async {
    _Runner(tester);
    final controller = _controller(TargetPlatform.linux);
    await tester.pumpWidget(_app(controller, rtl: true));
    await tester.pumpAndSettle();
    final min = tester.getRect(
      find.byKey(const Key('desktop-caption-minimize')),
    );
    final max = tester.getRect(
      find.byKey(const Key('desktop-caption-maximize')),
    );
    final close = tester.getRect(
      find.byKey(const Key('desktop-caption-close')),
    );
    expect(min.left, lessThan(max.left));
    expect(max.left, lessThan(close.left));
    expect(close.right, 796);
  });
}
