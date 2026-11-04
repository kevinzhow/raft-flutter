import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart' show RaftApiException;
import 'package:raft_ui/raft_ui.dart' show RaftUserError;
import 'package:raft_flutter/data/user_error.dart' show userErrorText;
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
    const host = MethodChannel('app.raft/desktop-window');
    var protectedDisplay = false;
    Map<dynamic, dynamic>? created, registration;
    final creating = Completer<void>();
    messenger.setMockMethodCallHandler(windows, (call) async {
      switch (call.method) {
        case 'getWindowDefinition':
          return {'windowId': 'main', 'windowArgument': ''};
        case 'createWindow':
          expect(protectedDisplay, isTrue);
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
    messenger.setMockMethodCallHandler(host, (call) async {
      if (call.method == 'prepareOpen') protectedDisplay = true;
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
    messenger.setMockMethodCallHandler(host, null);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final revoked in [false, true]) {
    test(
      revoked
          ? 'Linux refuses a stale engine open after held display preparation'
          : 'Linux refuses engine creation when shared display protection is unavailable',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const windows = MethodChannel('mixin.one/desktop_multi_window');
        const channels = MethodChannel(
          'mixin.one/desktop_multi_window/channels',
        );
        const host = MethodChannel('app.raft/desktop-window');
        final checked = Completer<void>();
        final protection = Completer<void>();
        final creationAttempt = Completer<void>();
        var created = 0;
        messenger.setMockMethodCallHandler(windows, (call) async {
          if (call.method == 'getWindowDefinition') {
            return {'windowId': 'main', 'windowArgument': ''};
          }
          if (call.method == 'createWindow') {
            created++;
            creationAttempt.complete();
            throw PlatformException(code: 'unexpected_engine_creation');
          }
          return null;
        });
        messenger.setMockMethodCallHandler(channels, (_) async => null);
        messenger.setMockMethodCallHandler(host, (call) async {
          if (call.method == 'prepareOpen') {
            checked.complete();
            await protection.future;
          }
          return null;
        });
        final (client, _) = await owner();
        final runtime = (await initializeDesktopWindows(const []))!;
        addTearDown(() async {
          await runtime.dispose();
          await client.dispose();
          for (final channel in [windows, channels, host]) {
            messenger.setMockMethodCallHandler(channel, null);
          }
          debugDefaultTargetPlatformOverride = null;
        });
        runtime.bind(client, null, cache: RootCache());
        final outcome = runtime
            .openServer(beta)
            .then<Object?>((_) => null, onError: (Object error) => error);
        await Future.any([checked.future, creationAttempt.future]);
        expect(created, 0);
        expect(checked.isCompleted, isTrue);
        if (revoked) {
          runtime.bind(null, null);
          protection.complete();
          expect(await outcome, isA<RaftApiException>());
        } else {
          protection.completeError(
            PlatformException(code: 'desktop_display_unavailable'),
          );
          final error = await outcome;
          expect(error, isA<RaftUserError>());
          expect(
            userErrorText(error),
            contains('Select the server in this window instead.'),
          );
        }
        expect(created, 0);
      },
    );
  }

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
