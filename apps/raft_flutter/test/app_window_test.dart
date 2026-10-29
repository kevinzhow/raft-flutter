import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/app_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<String>> run(TargetPlatform platform, String channelName) async {
    final calls = <String>[];
    final channel = MethodChannel(channelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await presentAppWindow(platform: platform, channel: channel);
    return calls;
  }

  test('desktop shells are asked to raise the window', () async {
    expect(await run(TargetPlatform.linux, 'app.raft/window'), ['present']);
    expect(await run(TargetPlatform.macOS, 'app.raft/window'), ['present']);
    expect(
      await run(TargetPlatform.windows, 'app.raft/windows-notifications'),
      ['present'],
    );
  });

  test('mobile has no window to raise (the deep link already does)', () async {
    expect(await run(TargetPlatform.android, 'app.raft/window'), isEmpty);
    expect(await run(TargetPlatform.iOS, 'app.raft/window'), isEmpty);
  });

  test('default channels are the ones the native runners register', () async {
    final seen = <String>[];
    for (final (platform, name) in const [
      (TargetPlatform.linux, 'app.raft/window'),
      (TargetPlatform.macOS, 'app.raft/window'),
      (TargetPlatform.windows, 'app.raft/windows-notifications'),
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async {
            seen.add('$name:${call.method}');
            return null;
          });
      await presentAppWindow(platform: platform);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
    expect(seen, [
      'app.raft/window:present',
      'app.raft/window:present',
      'app.raft/windows-notifications:present',
    ]);
  });
  for (final (platform, name) in const [
    (TargetPlatform.macOS, 'app.raft/window'),
    (TargetPlatform.linux, 'app.raft/window'),
    (TargetPlatform.windows, 'app.raft/windows-notifications'),
  ]) {
    test(
      '$platform activation read uses its runner without presenting',
      () async {
        final calls = <String>[];
        final channel = MethodChannel(name);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call.method);
              return true;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        expect(await isAppWindowActive(platform: platform), isTrue);
        expect(calls, ['isActive']);
      },
    );
  }

  for (final reply in [false, null, 'true']) {
    test('activation reply $reply defaults to background', () async {
      const channel = MethodChannel('activation-test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => reply);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      expect(
        await isAppWindowActive(
          platform: TargetPlatform.macOS,
          channel: channel,
        ),
        isFalse,
      );
    });
  }

  for (final error in [
    MissingPluginException(),
    PlatformException(code: 'unavailable'),
  ]) {
    test('activation read failure $error defaults to background', () async {
      const channel = MethodChannel('activation-test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => throw error);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      expect(
        await isAppWindowActive(
          platform: TargetPlatform.macOS,
          channel: channel,
        ),
        isFalse,
      );
    });
  }

  testWidgets('an unresponsive runner cannot hold startup indefinitely', (
    t,
  ) async {
    const channel = MethodChannel('activation-test');
    final reply = Completer<Object?>();
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) => reply.future,
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final active = isAppWindowActive(
      platform: TargetPlatform.macOS,
      channel: channel,
    );
    await t.pump(const Duration(seconds: 1));
    expect(await active, isFalse);
    reply.complete(true);
    await t.pump();
  });

  test('mobile activation does not call a desktop runner', () async {
    expect(await isAppWindowActive(platform: TargetPlatform.iOS), isFalse);
    expect(await isAppWindowActive(platform: TargetPlatform.android), isFalse);
  });
}
