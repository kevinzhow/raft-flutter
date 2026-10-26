import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/desktop_title_bar.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;

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

Widget _app(DesktopTitleBarController controller, {bool integrated = true}) =>
    MaterialApp(
      theme: raftTheme(),
      home: DesktopTitleBar(
        controller: controller,
        integrated: integrated,
        child: const SizedBox.expand(key: Key('body')),
      ),
    );

void main() {
  leakDebt(const ['ValueNotifier<DesktopTitleBarState>']);
  testWidgets('Linux captions occupy one row and call runner commands', (
    tester,
  ) async {
    final runner = _Runner(tester);
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.linux,
      web: false,
    );
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
  });
  testWidgets(
    'configured left captions keep positions and maximize state updates',
    (tester) async {
      final runner = _Runner(tester, layout: 'close,minimize:maximize');
      final controller = DesktopTitleBarController(
        platform: TargetPlatform.linux,
        web: false,
      );
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
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.linux,
      web: false,
    );
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
      final controller = DesktopTitleBarController(
        platform: TargetPlatform.windows,
        web: false,
      );
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
}
