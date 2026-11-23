import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
import 'package:raft_system_webview/raft_system_webview.dart';

import '../platform/attachment_html_desktop_environment.dart';

class DesktopBrowserSession {
  static int _sequence = 0;
  static const _mac = MethodChannel('app.raft/desktop_browser');

  final int _id = ++_sequence;
  final windows = DesktopBrowserWindowsProfile();
  bool _usesLinux = false, _usesMac = false;
  bool _closed = false;

  Future<SystemWebViewController> openLinux(Set<String> hosts) {
    if (_closed) throw StateError('The browser session is closed.');
    _usesLinux = true;
    return SystemWebViewController.createBrowser(hosts, session: _id);
  }

  Map<String, Object> macArguments(Set<String> hosts) {
    _usesMac = true;
    return {'session': _id, 'blockedHosts': hosts.toList()};
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    if (_usesLinux) {
      unawaited(
        SystemWebViewController.retireBrowserSession(_id)
            .catchError((Object _) {}),
      );
    }
    if (_usesMac) {
      unawaited(
        _mac
            .invokeMethod<void>('retireBrowserSession', _id)
            .catchError((Object _) {}),
      );
    }
    windows.dispose();
  }
}

class DesktopBrowserWindowsProfile {
  DesktopBrowserWindowsProfile({
    Future<DesktopHtmlEnvironment> Function()? createEnvironment,
  }) : _createEnvironment =
           createEnvironment ??
           (() => DesktopHtmlEnvironment.create(TargetPlatform.windows));

  final Future<DesktopHtmlEnvironment> Function() _createEnvironment;
  Future<_WindowsProfile>? _opening;
  _WindowsProfile? _current;
  bool _closed = false;

  Future<DesktopHtmlEnvironment> open() async {
    if (_closed) throw StateError('The browser session is closed.');
    if (_current case final current?) return current.environment;
    return (await (_opening ??= _open())).environment;
  }

  Future<_WindowsProfile> _open() async {
    try {
      final environment = await Future.sync(_createEnvironment);
      final profile = _WindowsProfile(
        environment,
        environment.platform == null
            ? null
            : PlatformHeadlessInAppWebView(
                PlatformHeadlessInAppWebViewCreationParams(
                  webViewEnvironment: environment.platform,
                  initialSettings: InAppWebViewSettings(
                    incognito: true,
                    javaScriptEnabled: false,
                    javaScriptBridgeEnabled: false,
                  ),
                ),
              ),
      );
      var exited = false;
      final browser = environment.platform;
      if (browser != null) {
        final previous = browser.onBrowserProcessExited;
        browser.onBrowserProcessExited = (detail) {
          exited = true;
          previous?.call(detail);
          invalidate(environment);
        };
      }
      try {
        await profile.keeper?.run();
        if (_closed || exited) {
          throw StateError('The browser environment closed during startup.');
        }
      } catch (_) {
        _retire(profile);
        rethrow;
      }
      return _current = profile;
    } finally {
      _opening = null;
    }
  }

  void invalidate(DesktopHtmlEnvironment environment) {
    final current = _current;
    if (current == null || !identical(current.environment, environment)) {
      return;
    }
    _current = null;
    _retire(current);
  }

  void _retire(_WindowsProfile profile) {
    unawaited(profile.dispose().catchError((Object _) {}));
  }

  void dispose() {
    _closed = true;
    if (_current case final profile?) invalidate(profile.environment);
  }
}

class _WindowsProfile {
  const _WindowsProfile(this.environment, this.keeper);

  final DesktopHtmlEnvironment environment;
  final PlatformHeadlessInAppWebView? keeper;

  Future<void> dispose() async {
    try {
      await keeper?.dispose();
    } finally {
      await environment.dispose();
    }
  }
}
