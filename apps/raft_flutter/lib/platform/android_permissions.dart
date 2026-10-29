import 'package:flutter/services.dart';

/// What Android says about one runtime permission (`app.raft/permissions`).
class AndroidPermissionStatus {
  const AndroidPermissionStatus({
    required this.sdk,
    required this.granted,
    required this.rationale,
  });

  final int sdk;
  final bool granted;

  /// `shouldShowRequestPermissionRationale`: true after a first refusal, false
  /// before the first request and after "don't ask again".
  final bool rationale;

  /// Whether a request can still put a system dialog on screen. [asked] is the
  /// app's own record that it requested the permission before: without it the
  /// platform cannot tell "never asked" from "don't ask again".
  bool canPrompt({required bool asked}) => granted || !asked || rationale;
}

/// Runtime-permission facts and the app's settings page. Off Android, or when
/// the native bridge is missing (tests), every answer is "unknown" (null).
class AndroidPermissions {
  const AndroidPermissions({MethodChannel? channel})
    : _channel = channel ?? _default;
  static const _default = MethodChannel('app.raft/permissions');
  final MethodChannel _channel;

  static const postNotifications = 'android.permission.POST_NOTIFICATIONS';
  static const accessLocalNetwork = 'android.permission.ACCESS_LOCAL_NETWORK';

  Future<AndroidPermissionStatus?> status(String permission) async {
    try {
      final map = await _channel.invokeMapMethod<String, Object?>('status', {
        'permission': permission,
      });
      if (map == null) return null;
      return AndroidPermissionStatus(
        sdk: map['sdk'] as int,
        granted: map['granted'] == true,
        rationale: map['rationale'] == true,
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Opens this app's system settings page. False when no screen opened.
  Future<bool> openAppSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
