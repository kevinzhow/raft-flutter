import 'dart:async';

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
  Completer<bool>? confirmation;
  var nativeFocused = true;
  setUp(() {
    confirmation = null;
    nativeFocused = true;
    messenger.setMockMethodCallHandler(
      SystemWebViewController.rootChannel,
      (_) async => {
        'id': 17,
        'protocol': 1,
        'ephemeral': true,
        'sandboxed': true,
      },
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'hasFocus') {
        return confirmation?.future ?? nativeFocused;
      }
      return null;
    });
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
    FocusNode editor,
    FocusNode other,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(focusNode: editor),
              TextField(focusNode: other),
              Expanded(
                child: SystemWebView(controller: controller, visible: true),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(editor.hasFocus, true);
  }

  testWidgets('a native click releases the previous Flutter editor focus', (
    tester,
  ) async {
    final controller = await SystemWebViewController.create();
    final editor = FocusNode(), other = FocusNode();
    await mount(tester, controller, editor, other);
    await event(false);
    await tester.pump();
    expect(editor.hasFocus, true);
    await event(true);
    await tester.pump();
    expect(editor.hasFocus, false);
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
    editor.dispose();
    other.dispose();
  });

  testWidgets('a delayed native confirmation preserves a newer editor', (
    tester,
  ) async {
    final controller = await SystemWebViewController.create();
    final editor = FocusNode(), other = FocusNode();
    await mount(tester, controller, editor, other);
    confirmation = Completer<bool>();
    await event(true);
    await tester.pump();
    await tester.tap(find.byType(TextField).last);
    await tester.pump();
    expect(other.hasFocus, true);
    confirmation!.complete(true);
    await tester.pump();
    expect(other.hasFocus, true);
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
    editor.dispose();
    other.dispose();
  });

  testWidgets('a stale native focus event cannot clear the current editor', (
    tester,
  ) async {
    final controller = await SystemWebViewController.create();
    final editor = FocusNode(), other = FocusNode();
    await mount(tester, controller, editor, other);
    nativeFocused = false;
    await event(true);
    await tester.pump();
    expect(editor.hasFocus, true);
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
    editor.dispose();
    other.dispose();
  });

  testWidgets('retiring a native pane cancels its pending focus confirmation', (
    tester,
  ) async {
    final controller = await SystemWebViewController.create();
    final editor = FocusNode(), other = FocusNode();
    await mount(tester, controller, editor, other);
    confirmation = Completer<bool>();
    await event(true);
    await tester.pump();
    await controller.dispose();
    confirmation!.complete(true);
    await tester.pump();
    expect(editor.hasFocus, true);
    await tester.pumpWidget(const SizedBox());
    editor.dispose();
    other.dispose();
  });
}
