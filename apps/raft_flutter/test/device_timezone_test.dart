import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/device_timezone.dart';

void main() {
  const channel = MethodChannel('flutter_timezone');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('completed native results cancel the timeout immediately', () {
    for (final fails in [false, true]) {
      messenger.setMockMethodCallHandler(channel, (_) async {
        if (fails) throw PlatformException(code: 'unavailable');
        return 'Europe/Paris';
      });
      fakeAsync((clock) {
        var completed = false;
        String? timezone;
        readDeviceTimezone().then((value) {
          timezone = value;
          completed = true;
        });
        clock.flushMicrotasks();
        expect(completed, isTrue);
        expect(timezone, fails ? null : 'Europe/Paris');
        expect(clock.nonPeriodicTimerCount, 0);
        expect(clock.periodicTimerCount, 0);
      });
    }
  });
  test('OS names are read afresh; unavailable, malformed and empty values are omitted', () async {
    for (final value in [
      'Europe/Paris',
      'UTC',
      '',
      'Etc/Unknown',
      {'identifier': 'Asia/Shanghai'},
      {'identifier': 5},
    ]) {
      messenger.setMockMethodCallHandler(channel, (_) async => value);
      expect(await readDeviceTimezone(), switch (value) {
        'Europe/Paris' => 'Europe/Paris',
        'UTC' => 'UTC',
        {'identifier': 'Asia/Shanghai'} => 'Asia/Shanghai',
        _ => null,
      });
    }
    messenger.setMockMethodCallHandler(channel, null);
    expect(await readDeviceTimezone(), isNull);
  });
  testWidgets(
    'a stalled native service is bounded without blocking sending forever',
    (t) async {
      final response = Completer<Object?>();
      messenger.setMockMethodCallHandler(channel, (_) => response.future);
      final pending = readDeviceTimezone();
      await t.pump(const Duration(milliseconds: 501));
      expect(await pending, isNull);
      response.complete('Europe/Paris');
      await t.pump();
    },
  );
}
