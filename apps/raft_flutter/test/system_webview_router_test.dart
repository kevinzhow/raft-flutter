import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/app_root_router.dart';
import 'package:raft_flutter/platform/attachment_html_linux.dart';
import 'package:raft_flutter/platform/attachment_html_webview_events.dart';
import 'package:raft_system_webview/raft_system_webview.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('the app router publishes the browser and HTML preview bounds', (
    tester,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    final layouts = <int, Map>{};
    var nextId = 0;
    messenger.setMockMethodCallHandler(
      SystemWebViewController.rootChannel,
      (call) async => {
        'id': ++nextId,
        'protocol': 1,
        'browser': call.method == 'createBrowser',
        'ephemeral': true,
        'sandboxed': true,
      },
    );
    for (final id in [1, 2]) {
      messenger.setMockMethodCallHandler(
        MethodChannel('app.raft/system_webview/$id'),
        (call) async {
          if (call.method == 'layout') layouts[id] = call.arguments as Map;
          return null;
        },
      );
    }
    final browser = await SystemWebViewController.createBrowser({});
    final router = RaftAppRouter(
      onLocation: (_) async {},
      onRootBack: () async => false,
      observers: [],
      home: (_) => Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 440,
          height: 160,
          child: Row(
            children: [
              Expanded(
                child: SystemWebView(controller: browser, visible: true),
              ),
              Expanded(
                child: LinuxAttachmentHtmlWebView(
                  uri: Uri.parse('https://preview.test/document'),
                  events: AttachmentHtmlWebViewEvents(
                    onNavigation: (_) => false,
                    onLoaded: () {},
                    onFailed: (error) => fail(error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: raftTheme(), routerDelegate: router),
    );
    await tester.pumpAndSettle();
    await messenger.handlePlatformMessage(
      'app.raft/system_webview/2',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('event', {'type': 'loaded'}),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
    final visible = layouts.map(
      (id, layout) => MapEntry(id, layout['visible']),
    );
    await tester.pumpWidget(const SizedBox());
    await browser.dispose();
    router.dispose();
    expect(visible, {1: true, 2: true});
  });
}
