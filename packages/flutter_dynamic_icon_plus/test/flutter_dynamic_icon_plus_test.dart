import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus_platform_interface.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus_method_channel.dart';

void main() {
  final FlutterDynamicIconPlusPlatform initialPlatform =
      FlutterDynamicIconPlusPlatform.instance;

  test('$MethodChannelFlutterDynamicIconPlus is the default instance', () {
    expect(
        initialPlatform, isInstanceOf<MethodChannelFlutterDynamicIconPlus>());
  });
}
