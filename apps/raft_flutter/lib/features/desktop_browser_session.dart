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
  Future<DesktopHtmlEnvironment>? _environment;
  PlatformHeadlessInAppWebView? _keeper;
  bool _closed = false;

  Future<DesktopHtmlEnvironment> open() {
    if (_closed) throw StateError('The browser session is closed.');
    return _environment ??= _open();
  }

  Future<DesktopHtmlEnvironment> _open() async {
    final environment = await DesktopHtmlEnvironment.create(
      TargetPlatform.windows,
    );
    try {
      final keeper = _keeper = PlatformHeadlessInAppWebView(
        PlatformHeadlessInAppWebViewCreationParams(
          webViewEnvironment: environment.platform,
          initialSettings: InAppWebViewSettings(
            incognito: true,
            javaScriptEnabled: false,
            javaScriptBridgeEnabled: false,
          ),
        ),
      );
      await keeper.run();
      return environment;
    } catch (_) {
      await _keeper?.dispose();
      await environment.dispose();
      rethrow;
    }
  }

  void dispose() {
    _closed = true;
    final environment = _environment;
    if (environment != null) {
      unawaited(
        environment
            .then((created) async {
              try {
                await _keeper?.dispose();
              } finally {
                await created.dispose();
              }
            })
            .catchError((Object _) {}),
      );
    }
  }
}
