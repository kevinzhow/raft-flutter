import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/cache_exit.dart';
import 'package:raft_flutter/platform/windows_tray.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/prepare-exit');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late WindowsTray tray;
  final originalLog = cacheExitLog;

  setUp(() async {
    tray = WindowsTray(platform: TargetPlatform.windows, channel: channel);
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    await tray.initialize((source) => source);
  });

  tearDown(() async {
    cacheExitLog = originalLog;
    bindCacheExit(null);
    resetCacheExitForTest();
    WindowsTray.debugResetPrepareExit();
    await tray.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<Map<Object?, Object?>> ask(int requestId, String reason) async {
    final done = Completer<ByteData?>();
    messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('prepareExit', {'requestId': requestId, 'reason': reason}),
      ),
      done.complete,
    );
    final decoded = const StandardMethodCodec().decodeEnvelope(
      (await done.future)!,
    );
    return Map<Object?, Object?>.from(decoded as Map);
  }

  test('explicitQuit and sessionEnd reply with the hook outcome', () async {
    cachePrepareExit = () async => CacheExitOutcome.completed;
    expect(await ask(1, 'explicitQuit'), {
      'requestId': 1,
      'outcome': 'completed',
    });
    WindowsTray.debugResetPrepareExit();
    cachePrepareExit = () async => CacheExitOutcome.timedOut;
    expect(await ask(2, 'sessionEnd'), {'requestId': 2, 'outcome': 'timedOut'});
  });

  test('one request id shares one close, including a late repeat', () async {
    final gate = Completer<CacheExitOutcome>();
    var calls = 0;
    cachePrepareExit = () {
      calls++;
      return gate.future;
    };
    final first = ask(7, 'explicitQuit');
    final duplicate = ask(7, 'explicitQuit');
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    gate.complete(CacheExitOutcome.completed);
    expect(await first, {'requestId': 7, 'outcome': 'completed'});
    expect(await duplicate, {'requestId': 7, 'outcome': 'completed'});
    expect(await ask(7, 'explicitQuit'), {
      'requestId': 7,
      'outcome': 'completed',
    });
    expect(calls, 1);
  });

  test(
    'a missing hook, an unknown reason, or a thrown hook stay outcomes',
    () async {
      expect((await ask(3, 'explicitQuit'))['outcome'], 'absent');
      cachePrepareExit = () async => CacheExitOutcome.completed;
      expect((await ask(4, 'query'))['outcome'], 'absent');
      WindowsTray.debugResetPrepareExit();
      cachePrepareExit = () async => throw StateError('close');
      expect((await ask(5, 'sessionEnd'))['outcome'], 'failed');
    },
  );

  test('prepareExit uses closeCacheForExit once per request id', () async {
    final lines = <String>[];
    cacheExitLog = lines.add;
    var calls = 0;
    bindCacheExit(
      () => closeCacheForExit(() async {
        calls++;
      }),
    );
    expect(await ask(9, 'explicitQuit'), {
      'requestId': 9,
      'outcome': 'completed',
    });
    expect(await ask(9, 'sessionEnd'), {
      'requestId': 9,
      'outcome': 'completed',
    });
    expect(calls, 1);
    expect(lines, ['raft.cache_exit completed']);
  });

  test('a settings instance leaves hidden and prepareExit on the initialized receiver', () async {
    var hidden = 0;
    tray.onHidden = () => hidden++;
    final settings = WindowsTray(
      platform: TargetPlatform.windows,
      channel: channel,
    );
    addTearDown(settings.dispose);
    cachePrepareExit = () async => CacheExitOutcome.completed;
    expect(await ask(11, 'explicitQuit'), {
      'requestId': 11,
      'outcome': 'completed',
    });
    final done = Completer<ByteData?>();
    messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('hidden', true),
      ),
      done.complete,
    );
    await done.future;
    expect(hidden, 1);
  });
}
