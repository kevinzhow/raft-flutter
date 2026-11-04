import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/desktop_window_runtime.dart';

import 'app_global_server_selector_test.dart' show RootCache;
import 'desktop_window_broker_test.dart' show owner, beta;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native facade sends only a route in arguments and credentials only on its paired broker channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const windows = MethodChannel('mixin.one/desktop_multi_window');
    const channels = MethodChannel('mixin.one/desktop_multi_window/channels');
    Map<dynamic, dynamic>? created, registration;
    final creating = Completer<void>();
    messenger.setMockMethodCallHandler(windows, (call) async {
      switch (call.method) {
        case 'getWindowDefinition':
          return {'windowId': 'main', 'windowArgument': ''};
        case 'createWindow':
          created = call.arguments;
          creating.complete();
          return 'child-1';
        case 'window_show':
          return null;
        default:
          throw MissingPluginException();
      }
    });
    messenger.setMockMethodCallHandler(channels, (call) async {
      if (call.method == 'registerMethodHandler') registration = call.arguments;
      return null;
    });
    final (client, _) = await owner();
    final runtime = (await initializeDesktopWindows(const []))!;
    runtime.bind(client, null, cache: RootCache());
    final opening = runtime.openServer(beta);
    await creating.future;
    Future<dynamic> invoke(String name, [String method = 'read']) async {
      final result = Completer<ByteData?>();
      await messenger.handlePlatformMessage(
        channels.name,
        channels.codec.encodeMethodCall(
          MethodCall('methodCall', {
            'channel': name,
            'method': method,
            'arguments': null,
          }),
        ),
        result.complete,
      );
      return channels.codec.decodeEnvelope((await result.future)!);
    }

    final accepted = await invoke(registration!['channel']);
    await invoke(registration!['channel'], 'ready');
    await opening;
    final route = jsonDecode(created!['arguments']);
    expect(route.keys.toSet(), {'v', 'binding', 'server', 'slug'});
    expect(route['server'], 'b');
    expect(jsonEncode(created), isNot(contains('accessToken')));
    expect(jsonEncode(created), isNot(contains('refresh-first')));
    expect(registration!['mode'], 'bidirectional');

    expect(accepted['session']['accessToken'], 'first');
    expect(accepted['epoch'], isA<String>());
    runtime.bind(null, null);
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      invoke(registration!['channel']),
      throwsA(isA<PlatformException>()),
    );
    await runtime.dispose();
    await client.dispose();
    messenger.setMockMethodCallHandler(windows, null);
    messenger.setMockMethodCallHandler(channels, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('malformed native routes close their own window without exposing input or reading a session', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const windows = MethodChannel('mixin.one/desktop_multi_window');
    const host = MethodChannel('app.raft/desktop-window');
    var closed = 0;
    String arguments = 'bad fixture-credential';
    messenger.setMockMethodCallHandler(
      windows,
      (_) async => {'windowId': 'child', 'windowArgument': arguments},
    );
    messenger.setMockMethodCallHandler(host, (call) async {
      if (call.method == 'forceClose') closed++;
      return null;
    });
    for (final route in [
      'bad fixture-credential',
      jsonEncode({'v': 1, 'token': 'fixture-credential'}),
    ]) {
      arguments = route;
      await expectLater(
        initializeDesktopWindows(const []),
        throwsA(
          predicate(
            (e) =>
                e is FormatException &&
                !e.toString().contains('fixture-credential'),
          ),
        ),
      );
    }
    expect(closed, 2);
    messenger.setMockMethodCallHandler(windows, null);
    messenger.setMockMethodCallHandler(host, null);
    debugDefaultTargetPlatformOverride = null;
  });
}
