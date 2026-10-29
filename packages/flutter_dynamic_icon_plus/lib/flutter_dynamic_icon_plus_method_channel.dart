import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dynamic_icon_plus/src/consts/arguments.dart';
import 'package:flutter_dynamic_icon_plus/src/consts/method_names.dart';

import 'flutter_dynamic_icon_plus_platform_interface.dart';

/// An implementation of [FlutterDynamicIconPlusPlatform] that uses method channels.
class MethodChannelFlutterDynamicIconPlus
    extends FlutterDynamicIconPlusPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_dynamic_icon_plus');

  @override
  Future<bool> get supportsAlternateIcons async {
    final bool supportsAltIcons =
        await methodChannel.invokeMethod(MethodNames.supportsAlternateIcons);
    return supportsAltIcons;
  }

  @override
  Future<String?> get alternateIconName async {
    final String? altIconName =
        await methodChannel.invokeMethod(MethodNames.getAlternateIconName);
    return altIconName;
  }

  @override
  Future<void> setAlternateIconName({
    String? iconName,
    List<String> blacklistBrands = const [],
    List<String> blacklistManufactures = const [],
    List<String> blacklistModels = const [],
    bool isSilent = false,
  }) async {
    final brands = blacklistBrands.join(',');
    final manufactures = blacklistManufactures.join(',');
    final models = blacklistModels.join(',');

    await methodChannel.invokeMethod(
      MethodNames.setAlternateIconName,
      {
        Arguments.iconName: iconName,
        Arguments.brands: brands,
        Arguments.manufactures: manufactures,
        Arguments.models: models,
        Arguments.isSilent: isSilent,
      },
    );
  }

  @override
  Future<int> get applicationIconBadgeNumber async {
    final int batchIconNumber = await methodChannel
        .invokeMethod(MethodNames.getApplicationIconBadgeNumber);
    return batchIconNumber;
  }

  @override
  Future<void> setApplicationIconBadgeNumber(int batchIconNumber) async {
    await methodChannel.invokeMethod(MethodNames.setApplicationIconBadgeNumber,
        <String, Object>{Arguments.batchIconNumber: batchIconNumber});
  }
}
