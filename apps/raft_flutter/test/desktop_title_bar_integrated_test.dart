import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/desktop_title_bar.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;

class _Runner {
  _Runner(this.tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'setIntegrated') {
        integrated = (call.arguments as Map)['enabled'] == true;
      }
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
  bool integrated = false;
  Map<String, Object> get state => {
    'height': integrated ? 40.0 : 28.0,
    'fullscreen': false,
    'integrated': integrated,
    'leadingInset': integrated ? 88.0 : 0.0,
  };

  Future<void> fullscreen(bool value) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        MethodCall('state', {...state, 'fullscreen': value}),
      ),
      (_) {},
    );
    await tester.pump();
  }
}

Widget _app(
  DesktopTitleBarController controller, {
  bool integrated = true,
  double height = 48,
  VoidCallback? onPressed,
}) => MaterialApp(
  theme: raftTheme(),
  home: DesktopTitleBar(
    controller: controller,
    integrated: integrated,
    integratedHeight: height,
    child: Builder(
      builder: (context) {
        final scope = DesktopTitleBarScope.maybeOf(context);
        return Column(
          key: const Key('content'),
          children: [
            SizedBox(
              height: height,
              child: Row(
                children: [
                  SizedBox(
                    key: const Key('native-controls'),
                    width: scope?.leadingInset ?? 0,
                  ),
                  Expanded(
                    child: GestureDetector(
                      key: const Key('blank'),
                      behavior: HitTestBehavior.opaque,
                      onPanStart: scope?.onDragStart == null
                          ? null
                          : (_) => scope!.onDragStart!(),
                      onDoubleTap: scope?.onDoubleTap,
                    ),
                  ),
                  TextButton(onPressed: onPressed, child: const Text('Search')),
                ],
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        );
      },
    ),
  ),
);

void main() {
  // Same process-wide notifier ownership as DesktopTitleBarController.platform.
  leakDebt(const ['ValueNotifier<DesktopTitleBarState>']);

  testWidgets('Mac global row replaces the empty strip and reserves controls', (
    tester,
  ) async {
    final runner = _Runner(tester);
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.macOS,
      web: false,
    );
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    expect(runner.integrated, isTrue);
    expect(find.byType(RaftDesktopTitleStrip), findsNothing);
    expect(tester.getTopLeft(find.byKey(const Key('content'))).dy, 0);
    expect(tester.getSize(find.byKey(const Key('native-controls'))).width, 88);
    final call = runner.calls.singleWhere((c) => c.method == 'setIntegrated');
    expect(call.arguments, {'enabled': true, 'height': 48.0});
  });

  testWidgets(
    'Mac keeps its measured control gutter during a transient native layout',
    (tester) async {
      final runner = _Runner(tester);
      final controller = DesktopTitleBarController(
        platform: TargetPlatform.macOS,
        web: false,
      );
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        runner.channel.name,
        runner.channel.codec.encodeMethodCall(
          const MethodCall('state', {
            'height': 0.0,
            'leadingInset': 0.0,
            'integrated': true,
            'fullscreen': false,
          }),
        ),
        (_) {},
      );
      await tester.pump();
      expect(
        tester.getSize(find.byKey(const Key('native-controls'))).width,
        88,
      );
      expect(find.byType(RaftDesktopTitleStrip), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fullscreen releases native inset while keeping global actions', (
    tester,
  ) async {
    final runner = _Runner(tester);
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.macOS,
      web: false,
    );
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    await runner.fullscreen(true);
    expect(find.text('Search'), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('native-controls'))).width, 0);
    expect(find.byType(RaftDesktopTitleStrip), findsNothing);
    await runner.fullscreen(false);
    expect(tester.getSize(find.byKey(const Key('native-controls'))).width, 88);
  });

  testWidgets('blank regions move and zoom, controls keep their own clicks', (
    tester,
  ) async {
    final runner = _Runner(tester);
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.macOS,
      web: false,
    );
    var searches = 0;
    await tester.pumpWidget(_app(controller, onPressed: () => searches++));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search'));
    expect(searches, 1);
    expect(runner.calls.where((c) => c.method == 'startDragging'), isEmpty);
    await tester.drag(find.byKey(const Key('blank')), const Offset(50, 0));
    expect(
      runner.calls.where((c) => c.method == 'startDragging'),
      hasLength(1),
    );
    await tester.tap(find.byKey(const Key('blank')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('blank')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(runner.calls.where((c) => c.method == 'doubleClick'), hasLength(1));
  });

  testWidgets('leaving the workspace retains the 48px branded Mac frame', (
    tester,
  ) async {
    final runner = _Runner(tester);
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.macOS,
      web: false,
    );
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(controller, height: 60));
    await tester.pumpAndSettle();
    expect(
      runner.calls.where((c) => c.method == 'setIntegrated').last.arguments,
      {'enabled': true, 'height': 60.0},
    );
    final count = runner.calls.length;
    await tester.pumpWidget(_app(controller, height: 60));
    await tester.pumpAndSettle();
    expect(runner.calls.length, count);
    await tester.pumpWidget(_app(controller, integrated: false));
    await tester.pumpAndSettle();
    expect(runner.integrated, isTrue);
    expect(find.byType(RaftDesktopTitleStrip), findsOneWidget);
    expect(tester.getSize(find.byType(RaftDesktopTitleStrip)).height, 48);
    expect(find.byType(RaftBrandMark), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('content'))).dy, 48);
    expect(tester.getSize(find.byKey(const Key('native-controls'))).width, 0);
  });

  testWidgets(
    'Mac chooser and narrow frame preserve content through fullscreen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runner = _Runner(tester);
      final controller = DesktopTitleBarController(
        platform: TargetPlatform.macOS,
        web: false,
      );
      await tester.pumpWidget(_app(controller, integrated: false));
      await tester.pumpAndSettle();
      expect(runner.integrated, isTrue);
      expect(tester.getTopLeft(find.byType(RaftBrandMark)).dx, 82);
      expect(tester.getTopLeft(find.byKey(const Key('content'))).dy, 48);
      final content = tester.element(find.byKey(const Key('content')));
      await runner.fullscreen(true);
      expect(tester.element(find.byKey(const Key('content'))), same(content));
      expect(tester.getTopLeft(find.byKey(const Key('content'))).dy, 48);
      expect(find.byType(RaftBrandMark), findsOneWidget);
      await runner.fullscreen(false);
      expect(tester.element(find.byKey(const Key('content'))), same(content));
      expect(tester.takeException(), isNull);
    },
  );
  for (final page in [false, true]) {
    testWidgets(
      'Mac preview ${page ? 'page' : 'dialog'} clears native controls',
      (tester) async {
        final runner = _Runner(tester);
        final controller = DesktopTitleBarController(
          platform: TargetPlatform.macOS,
          web: false,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            builder: (context, child) => DesktopTitleBar(
              controller: controller,
              integrated: true,
              child: child!,
            ),
            home: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      page
                          ? RaftPreviewPageRoute<void>(
                              builder: (_) => const ColoredBox(
                                color: Colors.white,
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: Text('Preview title'),
                                ),
                              ),
                            )
                          : RaftFullBleedDialogRoute<void>(
                              context: context,
                              builder: (_) => const Align(
                                alignment: Alignment.topLeft,
                                child: Text('Preview title'),
                              ),
                            ),
                    ),
                    child: const Text('Open preview'),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open preview'));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text('Preview title')).dy,
          greaterThanOrEqualTo(48),
        );
        await runner.fullscreen(true);
        expect(tester.getTopLeft(find.text('Preview title')).dy, 0);
        await runner.fullscreen(false);
        expect(
          tester.getTopLeft(find.text('Preview title')).dy,
          greaterThanOrEqualTo(48),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
