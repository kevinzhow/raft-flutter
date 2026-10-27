import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'app_badge_plus_method_channel.dart';

abstract class AppBadgePlusPlatform extends PlatformInterface {
  /// Constructs a AppBadgePlusPlatform.
  AppBadgePlusPlatform() : super(token: _token);

  static final Object _token = Object();

  static AppBadgePlusPlatform _instance = MethodChannelAppBadgePlus();

  /// The default instance of [AppBadgePlusPlatform] to use.
  ///
  /// Defaults to [MethodChannelAppBadgePlus].
  static AppBadgePlusPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AppBadgePlusPlatform] when
  /// they register themselves.
  static set instance(AppBadgePlusPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> updateBadge(int count) {
    throw UnimplementedError('updateBadge() has not been implemented.');
  }

  Future<bool> isSupported() {
    throw UnimplementedError('isSupported() has not been implemented.');
  }
}
