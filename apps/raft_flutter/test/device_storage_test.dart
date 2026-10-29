import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/device_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.raft/test-storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    test('storage volume uses the database directory: $platform', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'availableStorageBytes');
        expect(call.arguments, {'path': '/synthetic'});
        return 2 << 30;
      });
      expect(
        await availableDeviceStorage(
          '/synthetic/workspace.sqlite',
          platform: platform,
          channel: channel,
        ),
        2 << 30,
      );
    });
  }
  test(
    'unknown storage space is not converted to an allocation promise',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'unavailable'),
      );
      expect(
        await availableDeviceStorage(
          '/synthetic/workspace.sqlite',
          platform: TargetPlatform.android,
          channel: channel,
        ),
        isNull,
      );
      messenger.setMockMethodCallHandler(channel, (call) async => -1);
      expect(
        await availableDeviceStorage(
          '/synthetic/workspace.sqlite',
          platform: TargetPlatform.android,
          channel: channel,
        ),
        isNull,
      );
    },
  );
  test('Linux reads actual available volume bytes', () async {
    expect(
      await availableDeviceStorage(
        '${Directory.systemTemp.path}/workspace.sqlite',
        platform: TargetPlatform.linux,
      ),
      greaterThan(0),
    );
  }, skip: !Platform.isLinux);
}
