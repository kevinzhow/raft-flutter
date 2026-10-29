import 'package:app_badge_plus/app_badge_plus_method_channel.dart';
import 'package:app_badge_plus/app_badge_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAppBadgePlusPlatform
    with MockPlatformInterfaceMixin
    implements AppBadgePlusPlatform {
  @override
  Future<void> updateBadge(int count) {
    // TODO: implement updateBadge
    throw UnimplementedError();
  }

  @override
  Future<bool> isSupported() {
    // TODO: implement isSupported
    throw UnimplementedError();
  }
}

void main() {
  final AppBadgePlusPlatform initialPlatform = AppBadgePlusPlatform.instance;

  test('$MethodChannelAppBadgePlus is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAppBadgePlus>());
  });
}
