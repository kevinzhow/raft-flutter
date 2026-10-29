import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/device_memory.dart';
import 'package:raft_flutter/platform/memory_budgets.dart';

const _gib = 1024 * 1024 * 1024;
const _mib = 1024 * 1024;
const _channel = MethodChannel('app.raft/device-memory');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    RaftMemoryBudgets.resetDetection();
  });

  test('Linux capacity is MemTotal, not fluctuating MemAvailable', () async {
    final info = await readDeviceMemory(
      platform: TargetPlatform.linux,
      readMeminfo: () async =>
          'MemTotal:       16777216 kB\nMemAvailable:      1024 kB\n',
    );
    expect(info!.totalBytes, 16 * _gib);
  });

  test('missing, malformed, or unreadable capacity selects the conservative fallback', () async {
    for (final text in [
      '',
      'MemTotal: -1 kB\n',
      'MemTotal: 0 kB\n',
      'MemTotal: word kB\n',
    ]) {
      expect(
        await readDeviceMemory(
          platform: TargetPlatform.linux,
          readMeminfo: () async => text,
        ),
        isNull,
      );
    }
    expect(
      await readDeviceMemory(
        platform: TargetPlatform.linux,
        readMeminfo: () async => throw StateError('unavailable'),
      ),
      isNull,
    );
    expect(await readDeviceMemory(platform: TargetPlatform.android), isNull);
  });

  test(
    'native capacity and Android low-RAM classification are consumed',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            expect(call.method, 'snapshot');
            return {'totalBytes': 8 * _gib, 'lowRam': true};
          });
      final info = await readDeviceMemory(platform: TargetPlatform.android);
      expect(info!.totalBytes, 8 * _gib);
      expect(info.lowRam, isTrue);
      expect(
        RaftMemoryBudgets.forPlatform(TargetPlatform.android, memory: info),
        same(RaftMemoryBudgets.phone),
      );
    },
  );

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.linux,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    test('${platform.name}: exact tier boundaries and temporary capacity', () {
      final phone =
          platform == TargetPlatform.android || platform == TargetPlatform.iOS;
      final low = phone ? 3 : 8;
      final medium = phone ? 6 : 16;
      for (final (bytes, cache, active, tier) in [
        (0, phone ? 64 : 96, phone ? 192 : 384, RaftMemoryTier.low),
        (low * _gib, phone ? 64 : 96, phone ? 192 : 384, RaftMemoryTier.low),
        (
          low * _gib + 1,
          phone ? 128 : 192,
          phone ? 384 : 768,
          RaftMemoryTier.medium,
        ),
        (
          medium * _gib,
          phone ? 128 : 192,
          phone ? 384 : 768,
          RaftMemoryTier.medium,
        ),
        (medium * _gib + 1, 256, phone ? 768 : 1024, RaftMemoryTier.high),
      ]) {
        final result = RaftMemoryBudgets.forPlatform(
          platform,
          memory: DeviceMemoryInfo(bytes),
        );
        expect(result.memoryTier, tier);
        expect(result.attachmentImageDecodedBytes, cache * _mib);
        expect(result.attachmentImageActiveDecodedBytes, active * _mib);
      }
    });
  }

  test(
    'startup reads capacity once and falls back if the probe fails',
    () async {
      await RaftMemoryBudgets.initialize(
        probe: () async => const DeviceMemoryInfo(32 * _gib),
      );
      expect(RaftMemoryBudgets.current.memoryTier, RaftMemoryTier.high);
      await RaftMemoryBudgets.initialize(
        probe: () async => throw StateError('probe failed'),
      );
      expect(RaftMemoryBudgets.current.memoryTier, RaftMemoryTier.low);
    },
  );
}
