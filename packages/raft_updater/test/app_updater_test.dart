import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_updater/raft_updater.dart';

const _channel = MethodChannel('app.raft/updater');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  final opened = <Uri>[];
  Object? Function(MethodCall call) native = (_) => null;

  setUp(() {
    calls.clear();
    opened.clear();
    AppUpdater.requiredExitHook = null;
    native = (call) => switch (call.method) {
      'configure' => <String, Object?>{'available': true},
      'checkForUpdates' => true,
      _ => null,
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          return native(call);
        });
  });

  tearDown(() {
    AppUpdater.requiredExitHook = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  AppUpdater updater(
    TargetPlatform platform, {
    AppUpdaterConfig config = const AppUpdaterConfig(
      enabled: true,
      publicKey: 'KEY',
      buildNumber: '47',
      version: '0.1.1',
    ),
    bool installed = true,
    bool opens = true,
  }) => AppUpdater(
    channel: _channel,
    config: config,
    platform: platform,
    isInstalledBuild: () => installed,
    openUrl: (url) async {
      opened.add(url);
      return opens;
    },
  );

  test('macOS and installed Windows builds with a key are available', () {
    expect(updater(TargetPlatform.macOS).available, isTrue);
    expect(updater(TargetPlatform.windows).available, isTrue);
  });

  test('other platforms, keyless builds and portable Windows are not', () {
    for (final platform in [
      TargetPlatform.linux,
      TargetPlatform.android,
      TargetPlatform.iOS,
    ]) {
      final unsupported = updater(platform);
      expect(unsupported.available, isFalse, reason: '$platform');
      expect(unsupported.unavailableReason, isNotNull);
    }
    expect(
      updater(
        TargetPlatform.macOS,
        config: const AppUpdaterConfig(),
      ).available,
      isFalse,
    );
    expect(updater(TargetPlatform.windows, installed: false).available, isFalse);
    expect(
      updater(
        TargetPlatform.windows,
        config: const AppUpdaterConfig(enabled: true, buildNumber: '47'),
      ).available,
      isFalse,
    );
  });

  test('feed URL follows the platform unless overridden', () {
    expect(
      updater(TargetPlatform.macOS).feedUrl,
      'https://github.com/kevinzhow/raft-flutter/releases/latest/download/appcast-macos.xml',
    );
    expect(
      updater(TargetPlatform.windows).feedUrl,
      endsWith('/appcast-windows.xml'),
    );
    expect(
      updater(
        TargetPlatform.macOS,
        config: const AppUpdaterConfig(enabled: true, feedUrl: 'https://x/y.xml'),
      ).feedUrl,
      'https://x/y.xml',
    );
  });

  test('checkAndInstall configures once then hands over to the native UI', () async {
    final subject = updater(TargetPlatform.windows);
    expect(await subject.checkAndInstall(), AppUpdateOutcome.started);
    expect(await subject.checkAndInstall(), AppUpdateOutcome.started);
    expect(calls.map((c) => c.method), [
      'configure',
      'checkForUpdates',
      'checkForUpdates',
    ]);
    final configure = calls.first.arguments as Map<Object?, Object?>;
    expect(configure['publicKey'], 'KEY');
    expect(configure['buildNumber'], '47');
    expect(opened, isEmpty);
  });

  test('unsupported platforms open the release page without native calls', () async {
    final subject = updater(TargetPlatform.android);
    expect(await subject.checkAndInstall(), AppUpdateOutcome.openedReleasePage);
    expect(opened, [AppUpdater.releasePage]);
    expect(calls, isEmpty);
  });

  test('native reports unavailable (missing Info.plist key): fall back and stop trying', () async {
    native = (call) => call.method == 'configure'
        ? <String, Object?>{'available': false, 'reason': 'No SUPublicEDKey'}
        : true;
    final subject = updater(TargetPlatform.macOS);
    final changes = <bool>[];
    subject.availability.addListener(() => changes.add(subject.available));
    expect(await subject.checkAndInstall(), AppUpdateOutcome.openedReleasePage);
    expect(subject.available, isFalse);
    expect(subject.unavailableReason, 'No SUPublicEDKey');
    expect(changes, [false]);
    expect(await subject.checkAndInstall(), AppUpdateOutcome.openedReleasePage);
    expect(calls.map((c) => c.method), ['configure']);
  });

  test('missing plugin or native error falls back to the release page', () async {
    native = (call) => throw MissingPluginException();
    var subject = updater(TargetPlatform.macOS);
    expect(await subject.checkAndInstall(), AppUpdateOutcome.openedReleasePage);
    expect(subject.available, isFalse);

    native = (call) => call.method == 'configure'
        ? <String, Object?>{'available': true}
        : throw PlatformException(code: 'boom');
    subject = updater(TargetPlatform.macOS);
    expect(await subject.checkAndInstall(), AppUpdateOutcome.openedReleasePage);
  });

  test('reports failure only when the browser fallback also fails', () async {
    final subject = updater(TargetPlatform.linux, opens: false);
    expect(await subject.checkAndInstall(), AppUpdateOutcome.failed);
  });

  void recordRequiredExit(AppUpdater subject, List<String> order) {
    subject.performRequiredExit = () async {
      order.add('exit');
    };
  }

  test('beforeQuit finishes before the required exit', () async {
    final subject = updater(TargetPlatform.linux);
    final order = <String>[];
    subject.beforeQuit = () async {
      order.add('close');
    };
    recordRequiredExit(subject, order);
    await subject.quitAfterHook();
    expect(order, ['close', 'exit']);
  });

  test('a missing beforeQuit still requests the required exit', () async {
    final subject = updater(TargetPlatform.linux);
    final order = <String>[];
    expect(subject.beforeQuit, isNull);
    recordRequiredExit(subject, order);
    await subject.quitAfterHook();
    expect(order, ['exit']);
  });

  test('a throwing beforeQuit still requests the required exit', () async {
    final subject = updater(TargetPlatform.linux);
    final order = <String>[];
    subject.beforeQuit = () async => throw StateError('close failed');
    recordRequiredExit(subject, order);
    await subject.quitAfterHook();
    expect(order, ['exit']);
  });

  test('requiredExitHook runs when beforeQuit is unset', () async {
    final subject = updater(TargetPlatform.linux);
    final order = <String>[];
    AppUpdater.requiredExitHook = () async {
      order.add('close');
    };
    recordRequiredExit(subject, order);
    await subject.quitAfterHook();
    expect(subject.beforeQuit, isNull);
    expect(order, ['close', 'exit']);
  });
}
