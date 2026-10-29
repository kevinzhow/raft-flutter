import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

/// Tells Android which theme the next cold start should show before any Dart
/// code runs: the system splash is drawn from a theme persisted natively
/// (Android 13+, `LaunchTheme.kt`), so it must be updated whenever the stored
/// appearance or the app icon changes. iOS reads the same preference keys
/// natively (`SceneDelegate.swift`) and needs no channel. Failures are ignored:
/// the launch screen is cosmetic.
class NativeLaunchTheme {
  NativeLaunchTheme({MethodChannel? channel, this.platformOverride})
    : _channel = channel ?? const MethodChannel('app.raft/launch-theme');

  static final instance = NativeLaunchTheme();
  final MethodChannel _channel;
  final TargetPlatform? platformOverride;
  bool get _android =>
      !kIsWeb &&
      (platformOverride ?? defaultTargetPlatform) == TargetPlatform.android;

  /// Reports the stored appearance (`raft.mode`). The native side still takes a
  /// theme family; it is always null now, which selects its default (white) light
  /// splash.
  Future<void> set(RaftAppearance appearance) =>
      _call('set', {'mode': appearance.mode.name, 'light': null});

  /// Re-applies the native splash theme, e.g. after the launcher icon changed.
  Future<void> refresh() => _call('refresh');

  Future<void> _call(String method, [Object? arguments]) async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (_) {}
  }
}
