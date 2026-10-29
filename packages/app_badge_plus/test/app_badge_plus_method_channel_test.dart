import 'dart:async';

import 'package:app_badge_plus/app_badge_plus_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late MethodChannelAppBadgePlus platform;

  setUp(() {
    platform = MethodChannelAppBadgePlus();
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      platform.methodChannel,
      null,
    );
  });

  for (final count in [7, 0]) {
    test('updateBadge forwards $count and awaits the native reply', () async {
      final received = Completer<MethodCall>();
      final nativeReply = Completer<void>();
      addTearDown(() {
        if (!nativeReply.isCompleted) nativeReply.complete();
      });
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        platform.methodChannel,
        (call) async {
          received.complete(call);
          await nativeReply.future;
          return null;
        },
      );

      var completed = false;
      final update = platform.updateBadge(count).then((_) => completed = true);
      final call = await received.future;
      expect(call.method, 'updateBadge');
      expect(call.arguments, {'count': count});
      // Let queued Future callbacks settle while the native reply is held.
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      nativeReply.complete();
      await update;
      expect(completed, isTrue);
    });
  }

  test('updateBadge propagates the native PlatformException', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      platform.methodChannel,
      (_) async => throw PlatformException(
        code: 'badge_update_failed',
        message: 'Fixture badge failure',
        details: {'domain': 'FixtureBadge', 'code': 501},
      ),
    );

    await expectLater(
      platform.updateBadge(7),
      throwsA(
        isA<PlatformException>()
            .having((error) => error.code, 'code', 'badge_update_failed')
            .having(
              (error) => error.message,
              'message',
              'Fixture badge failure',
            )
            .having((error) => error.details, 'details', {
              'domain': 'FixtureBadge',
              'code': 501,
            }),
      ),
    );
  });

  for (final response in <bool?>[true, false, null]) {
    test('isSupported maps native $response to ${response ?? false}', () async {
      final calls = <MethodCall>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        platform.methodChannel,
        (call) async {
          calls.add(call);
          return response;
        },
      );

      expect(await platform.isSupported(), response ?? false);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'isSupported');
      expect(calls.single.arguments, isNull);
    });
  }

  test('isSupported propagates a native PlatformException', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      platform.methodChannel,
      (_) async => throw PlatformException(code: 'support_check_failed'),
    );

    await expectLater(
      platform.isSupported(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'support_check_failed',
        ),
      ),
    );
  });
}
