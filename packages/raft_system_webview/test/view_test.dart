import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_system_webview/raft_system_webview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const view = MethodChannel('app.raft/system_webview/7');
  final layouts = <Map>[];
  setUp(() {
    layouts.clear();
    messenger.setMockMethodCallHandler(
      SystemWebViewController.rootChannel,
      (_) async => {
        'id': 7,
        'protocol': 1,
        'ephemeral': true,
        'sandboxed': true,
      },
    );
    messenger.setMockMethodCallHandler(view, (call) async {
      if (call.method == 'layout') layouts.add(call.arguments as Map);
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(
      SystemWebViewController.rootChannel,
      null,
    );
    messenger.setMockMethodCallHandler(view, null);
  });

  Widget host(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 300, height: 200, child: child),
    ),
  );
  testWidgets(
    'an offstage retained pane immediately retires native pixels and input',
    (tester) async {
      final controller = await SystemWebViewController.create();
      var offstage = false;
      late StateSetter change;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, set) {
              change = set;
              return Offstage(
                offstage: offstage,
                child: SystemWebView(controller: controller, visible: true),
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(layouts.last['visible'], true);
      change(() => offstage = true);
      await tester.pump();
      expect(layouts.last['visible'], false);
      change(() => offstage = false);
      await tester.pump();
      expect(layouts.last['visible'], true);
      await tester.pumpWidget(const SizedBox());
      await controller.dispose();
    },
  );
  testWidgets('caller occlusion hides and restores only the current viewport', (
    tester,
  ) async {
    final controller = await SystemWebViewController.create();
    var visible = true;
    late StateSetter change;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, set) {
            change = set;
            return SystemWebView(controller: controller, visible: visible);
          },
        ),
      ),
    );
    await tester.pump();
    expect(layouts.last['visible'], true);
    change(() => visible = false);
    await tester.pump();
    expect(layouts.last['visible'], false);
    change(() => visible = true);
    await tester.pump();
    expect(layouts.last['visible'], true);
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
  });
  testWidgets(
    'removing the Flutter pane hides its native view without extra frames',
    (tester) async {
      final controller = await SystemWebViewController.create();
      await tester.pumpWidget(
        host(SystemWebView(controller: controller, visible: true)),
      );
      await tester.pump();
      expect(layouts.last['visible'], true);
      await tester.pumpWidget(const SizedBox());
      expect(layouts.last['visible'], false);
      await controller.dispose();
    },
  );
}
