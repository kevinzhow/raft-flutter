import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_dynamic_icon_plus_method_channel.dart';

abstract class FlutterDynamicIconPlusPlatform extends PlatformInterface {
  /// Constructs a FlutterDynamicIconPlusPlatform.
  FlutterDynamicIconPlusPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterDynamicIconPlusPlatform _instance =
      MethodChannelFlutterDynamicIconPlus();

  /// The default instance of [FlutterDynamicIconPlusPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterDynamicIconPlus].
  static FlutterDynamicIconPlusPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterDynamicIconPlusPlatform] when
  /// they register themselves.
  static set instance(FlutterDynamicIconPlusPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<bool> get supportsAlternateIcons => throw UnimplementedError(
      'supportsAlternateIcons has not been implemented.');

  Future<String?> get alternateIconName =>
      throw UnimplementedError('alternateIconName has not been implemented.');

  Future<void> setAlternateIconName({
    String? iconName,
    List<String> blacklistBrands = const [],
    List<String> blacklistManufactures = const [],
    List<String> blacklistModels = const [],
    bool isSilent = false,
  }) =>
      throw UnimplementedError(
          'setAlternateIconName(String? iconName) has not been implemented.');

  Future<int> get applicationIconBadgeNumber => throw UnimplementedError(
      'applicationIconBadgeNumber has not been implemented.');

  Future<void> setApplicationIconBadgeNumber(int batchIconNumber) =>
      throw UnimplementedError(
          'setApplicationIconBadgeNumber(int batchIconNumber) has not been implemented.');
}
