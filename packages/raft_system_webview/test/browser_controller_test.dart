import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_system_webview/raft_system_webview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const child = MethodChannel('app.raft/system_webview/42');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(SystemWebViewController.rootChannel, (
      call,
    ) async {
      calls.add(call);
      return {
        'id': 42,
        'protocol': 1,
        'browser': call.method == 'createBrowser',
        'snapshot': true,
        'ephemeral': true,
        'sandboxed': true,
      };
    });
    messenger.setMockMethodCallHandler(child, (call) async => calls.add(call));
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(
      SystemWebViewController.rootChannel,
      null,
    );
    messenger.setMockMethodCallHandler(child, null);
  });

  test('browser mode has a private host policy and history commands', () async {
    final browser = await SystemWebViewController.createBrowser({'raft.test'});
    final target = Uri.parse('http://localhost:8080/');
    await browser.load(target);
    await browser.goBack();
    await browser.goForward();
    await browser.reload();
    await browser.dispose();
    expect(calls.map((call) => call.method), [
      'createBrowser',
      'load',
      'back',
      'forward',
      'reload',
      'dispose',
    ]);
    expect(calls.first.arguments, {
      'blockedHosts': ['raft.test'],
    });
    expect(calls[1].arguments, {'url': target.toString()});
  });
}
