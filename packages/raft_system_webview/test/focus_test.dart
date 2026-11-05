import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_system_webview/raft_system_webview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('app.raft/system_webview/17');
  const codec = StandardMethodCodec();
  setUp(() {
    messenger.setMockMethodCallHandler(
      SystemWebViewController.rootChannel,
      (_) async => {
        'id': 17,
        'protocol': 1,
        'ephemeral': true,
        'sandboxed': true,
      },
    );
    messenger.setMockMethodCallHandler(channel, (_) async => null);
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(
      SystemWebViewController.rootChannel,
      null,
    );
    messenger.setMockMethodCallHandler(channel, null);
  });
  Future<void> event(bool focused) => messenger.handlePlatformMessage(
    channel.name,
    codec.encodeMethodCall(
      MethodCall('event', {'type': 'focus', 'focused': focused}),
    ),
    (_) {},
  );
  Future<void> mount(
    WidgetTester tester,
    SystemWebViewController controller,
    FocusNode editor, {
    bool visible = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(focusNode: editor),
              Expanded(
                child: SystemWebView(controller: controller, visible: visible),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(editor.hasFocus, true);
  }

  testWidgets('native and Flutter input hand off focus in event order', (
    tester,
  ) async {
    final controller = await SystemWebViewController.create();
    final editor = FocusNode();
    await mount(tester, controller, editor);
    await event(true);
    await tester.pump();
    expect(editor.hasFocus, false);
    await event(false);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(editor.hasFocus, true);
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
    editor.dispose();
  });

  testWidgets('a hidden native pane cannot take current editor focus', (
    tester,
  ) async {
    final controller = await SystemWebViewController.create();
    final editor = FocusNode();
    await mount(tester, controller, editor, visible: false);
    await event(true);
    await tester.pump();
    expect(editor.hasFocus, true);
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
    editor.dispose();
  });
}
