import 'app_badge_plus_platform_interface.dart';

class AppBadgePlus {
  static Future<void> updateBadge(int count) {
    return AppBadgePlusPlatform.instance.updateBadge(count);
  }

  static Future<bool> isSupported() {
    return AppBadgePlusPlatform.instance.isSupported();
  }
}
