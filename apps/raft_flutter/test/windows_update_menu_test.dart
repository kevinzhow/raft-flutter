import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/windows_tray.dart';
import 'package:raft_updater/raft_updater.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/windows-update-menu');
  const updateChannel = MethodChannel('test/windows-update-menu/updater');
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final updateCalls = <MethodCall>[];
  final opened = <Uri>[];
  late WindowsTray tray;
  var opens = true, throwsOpen = false, throwsNative = false, starts = true;
  Completer<bool>? pending;

  AppUpdater updater({bool installed = true, bool keyed = true}) => AppUpdater(
    channel: updateChannel,
    platform: TargetPlatform.windows,
    config: AppUpdaterConfig(
      enabled: true,
      publicKey: keyed ? 'KEY' : '',
      buildNumber: '47',
      version: '0.1.0',
    ),
    isInstalledBuild: () => installed,
    openUrl: (url) async {
      opened.add(url);
      if (throwsOpen) throw StateError('browser unavailable');
      return opens;
    },
  );

  WindowsTray bridge(AppUpdater subject) => WindowsTray(
    platform: TargetPlatform.windows,
    channel: channel,
    lab: true,
    updater: subject,
  );

  Future<Object?> nativeCheck() {
    final reply = Completer<Object?>();
    messenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(const MethodCall('checkForUpdates')),
      (data) =>
          reply.complete(data == null ? null : codec.decodeEnvelope(data)),
    );
    return reply.future;
  }

  setUp(() {
    calls.clear();
    updateCalls.clear();
    opened.clear();
    opens = true;
    starts = true;
    throwsOpen = false;
    throwsNative = false;
    pending = null;
    tray = bridge(updater());
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return {'available': true};
    });
    messenger.setMockMethodCallHandler(updateChannel, (call) async {
      updateCalls.add(call);
      if (call.method == 'configure') return {'available': true};
      if (throwsNative) throw PlatformException(code: 'check-unavailable');
      return pending?.future ?? starts;
    });
  });
  tearDown(() async {
    await tray.dispose();
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(updateChannel, null);
  });

  test(
    'logged-out desktop menus receive the localized update command',
    () async {
      await tray.initialize((text) => 'translated $text');
      final labels = calls.single.arguments as Map;
      expect(labels['checkUpdates'], 'translated Check for updates…');
      expect(
        labels['updateFailed'],
        "translated Can't check for a new version right now. Try again later.",
      );
    },
  );

  test('native update selection is answered without a workspace', () async {
    await tray.initialize((text) => text);
    expect(await nativeCheck(), 'started');
    expect(updateCalls.map((call) => call.method), [
      'configure',
      'checkForUpdates',
    ]);
    expect(opened, isEmpty);
  });

  for (final keyed in [false, true]) {
    test(
      'portable/keyless menu opens the release page (keyed=$keyed)',
      () async {
        await tray.dispose();
        tray = bridge(updater(installed: !keyed, keyed: keyed));
        await tray.initialize((text) => text);
        expect(await nativeCheck(), 'openedReleasePage');
        expect(opened, [AppUpdater.releasePage]);
        expect(updateCalls, isEmpty);
      },
    );
  }

  test('failed launch can be retried using the same menu bridge', () async {
    starts = false;
    opens = false;
    await tray.initialize((text) => text);
    expect(await nativeCheck(), 'failed');
    starts = true;
    expect(await nativeCheck(), 'started');
    expect(
      updateCalls.where((call) => call.method == 'checkForUpdates'),
      hasLength(2),
    );
  });

  test(
    'native failure opens download page and a browser error can recover',
    () async {
      throwsNative = true;
      throwsOpen = true;
      await tray.initialize((text) => text);
      expect(await nativeCheck(), 'failed');
      throwsOpen = false;
      expect(await nativeCheck(), 'openedReleasePage');
      expect(opened, [AppUpdater.releasePage, AppUpdater.releasePage]);
    },
  );

  test('simultaneous menu commands share one pending native check', () async {
    pending = Completer<bool>();
    await tray.initialize((text) => text);
    final first = nativeCheck();
    await Future<void>.delayed(Duration.zero);
    final second = nativeCheck();
    await Future<void>.delayed(Duration.zero);
    expect(
      updateCalls.where((call) => call.method == 'checkForUpdates'),
      hasLength(1),
    );
    pending!.complete(true);
    expect(await Future.wait([first, second]), ['started', 'started']);
  });

  test('retired bridge does not start another update', () async {
    await tray.initialize((text) => text);
    await tray.dispose();
    expect(await nativeCheck(), isNull);
    expect(updateCalls, isEmpty);
  });
}
