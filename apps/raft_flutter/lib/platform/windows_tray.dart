import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:raft_updater/raft_updater.dart';

import 'cache_exit.dart';

/// The runner owns the icon and persisted window preference. Dart only supplies
/// labels/unread and routes window commands; message authority stays shared.
class WindowsTray {
  WindowsTray({
    TargetPlatform? platform,
    MethodChannel? channel,
    bool? lab,
    this._updater,
  }) : supported =
           !kIsWeb &&
           (platform ?? defaultTargetPlatform) == TargetPlatform.windows,
       _channel = channel ?? nativeChannel,
       lab = lab ?? const bool.fromEnvironment('RAFT_WINDOWS_NOTIFICATION_LAB');

  static const nativeChannel = MethodChannel('app.raft/windows-tray');

  /// One future per request id. A repeat, including one that arrives after the
  /// reply, joins that close and does not start another.
  static final _prepareExits = <int, Future<String>>{};

  @visibleForTesting
  static void debugResetPrepareExit() => _prepareExits.clear();

  /// Reply for native `prepareExit`: `{requestId, outcome}`.
  static Future<Map<String, Object?>> answerPrepareExit(
    Object? arguments,
  ) async {
    final args = arguments is Map ? arguments : const <Object?, Object?>{};
    final requestId = args['requestId'];
    final id = requestId is int ? requestId : null;
    final outcome =
        (id == null ? null : _prepareExits[id]) ??
        _startPrepareExit(id, args['reason']);
    return {'requestId': requestId, 'outcome': await outcome};
  }

  static Future<String> _startPrepareExit(int? id, Object? reason) {
    final future = _runPrepareExit(reason);
    if (id != null) _prepareExits[id] = future;
    return future;
  }

  static Future<String> _runPrepareExit(Object? reason) async {
    final hook = cachePrepareExit;
    if (hook == null || (reason != 'explicitQuit' && reason != 'sessionEnd')) {
      return CacheExitOutcome.absent.name;
    }
    try {
      return (await hook()).name;
    } catch (_) {
      return CacheExitOutcome.failed.name;
    }
  }

  final bool supported, lab;
  final MethodChannel _channel;
  final AppUpdater? _updater;
  Future<String>? _updateCheck;
  void Function()? onHidden;
  bool _closed = false;
  String? _labels;

  Future<void> initialize(String Function(String) localize) async {
    if (!supported || _closed) return;
    _channel.setMethodCallHandler(_onCall);
    await configure(localize);
  }

  Future<void> configure(String Function(String) localize) async {
    if (!supported || _closed) return;
    final labels = {
      'lab': lab,
      'open': localize('Open Raft'),
      'hide': localize('Hide Window'),
      'quit': localize('Quit Raft'),
      'unread': localize('unread'),
      'checkUpdates': '${localize('Check for updates')}…',
      'updateFailed': localize(
        "Can't check for a new version right now. Try again later.",
      ),
    };
    final key = labels.toString();
    if (_labels == key) return;
    // Remember the attempted copy before awaiting the optional shell service.
    // Workspace changes must not retry failures or overlap pending calls; the
    // runner independently restores the icon after TaskbarCreated.
    _labels = key;
    try {
      await _channel
          .invokeMapMethod<String, dynamic>('configure', labels)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Optional shell service: without a registered icon, Close still exits.
    }
  }

  Future<WindowsTrayState> readState() async =>
      WindowsTrayState.from(await _invoke('state'));

  Future<WindowsTrayState> setCloseToTray(bool enabled) async =>
      WindowsTrayState.from(
        await _invoke('setCloseToTray', {'enabled': enabled}),
      );

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method == 'prepareExit') {
      return answerPrepareExit(call.arguments);
    }
    if (call.method == 'checkForUpdates') {
      if (_closed || !supported) return AppUpdateOutcome.failed.name;
      final pending = _updateCheck;
      if (pending != null) return pending;
      final request = _runUpdateCheck();
      _updateCheck = request;
      try {
        return await request;
      } finally {
        if (identical(_updateCheck, request)) _updateCheck = null;
      }
    }
    if (!_closed && call.method == 'hidden') onHidden?.call();
    return null;
  }

  Future<String> _runUpdateCheck() async {
    try {
      return (await (_updater ?? AppUpdater.instance).checkAndInstall()).name;
    } catch (_) {
      return AppUpdateOutcome.failed.name;
    }
  }

  Future<Map<String, dynamic>?> _invoke(String method, [Object? args]) async {
    if (!supported || _closed) return null;
    return _channel
        .invokeMapMethod<String, dynamic>(method, args)
        .timeout(const Duration(seconds: 2));
  }

  static Future<void> writeUnread(int count) => nativeChannel
      .invokeMethod<void>('setUnread', {'count': count})
      .timeout(const Duration(seconds: 2));

  /// Explicit exit uses the same native request as the tray menu and updater.
  Future<void> quit() async {
    if (!supported || _closed) return;
    await _channel
        .invokeMethod<void>('quit')
        .timeout(const Duration(seconds: 2));
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    onHidden = null;
    if (!supported) return;
    _channel.setMethodCallHandler(null);
    try {
      await _channel
          .invokeMethod<void>('dispose')
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
  }
}

class WindowsTrayState {
  const WindowsTrayState({this.available = false, this.closeToTray = true});
  factory WindowsTrayState.from(Map<String, dynamic>? value) =>
      WindowsTrayState(
        available: value?['available'] == true,
        closeToTray: value?['closeToTray'] != false,
      );
  final bool available, closeToTray;
}
