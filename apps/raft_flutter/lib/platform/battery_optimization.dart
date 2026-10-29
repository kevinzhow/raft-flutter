import 'dart:io';

import 'package:flutter/services.dart';

/// Android battery optimisation of this app (`app.raft/battery-optimization`).
///
/// Raft has no push service: a notification that arrives while the app is in
/// the background comes over the live socket, which Android may stop for an
/// optimised app. The settings page uses this to say so.
class BatteryOptimization {
  BatteryOptimization({MethodChannel? channel, bool? supported})
    : _channel =
          channel ?? const MethodChannel('app.raft/battery-optimization'),
      supported = supported ?? Platform.isAndroid;
  final MethodChannel _channel;
  final bool supported;

  /// True when the app is exempt, false when it is optimised, null when the
  /// platform cannot say (not Android, or no native bridge).
  Future<bool?> exempt() async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<bool>('exempt');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Opens the system battery optimisation list. False when no screen opened.
  Future<bool> openSettings() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('openSettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
