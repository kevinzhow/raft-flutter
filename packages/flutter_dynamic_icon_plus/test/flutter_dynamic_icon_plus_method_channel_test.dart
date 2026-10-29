import 'package:flutter/services.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_dynamic_icon_plus');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'public API carries an explicit icon and preserves the system alert',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'supportsAlternateIcons') return true;
        if (call.method == 'getAlternateIconName') return 'AppIconBlue';
        return null;
      });
      expect(await FlutterDynamicIconPlus.supportsAlternateIcons, isTrue);
      await FlutterDynamicIconPlus.setAlternateIconName(
        iconName: 'AppIconBlue',
      );
      expect(await FlutterDynamicIconPlus.alternateIconName, 'AppIconBlue');
      final args =
          calls
                  .singleWhere((call) => call.method == 'setAlternateIconName')
                  .arguments
              as Map;
      expect(args['iconName'], 'AppIconBlue');
      expect(args['isSilent'], isFalse);
    },
  );
  test('nil reset and native failures are forwarded to the caller', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect((call.arguments as Map)['iconName'], isNull);
      throw PlatformException(code: 'native_denied');
    });
    await expectLater(
      FlutterDynamicIconPlus.setAlternateIconName(),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'native_denied'),
      ),
    );
  });
}
