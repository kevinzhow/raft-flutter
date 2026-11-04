import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

/// A preview owns its desktop browser environment. It never uses a login
/// viewer's profile or the default WebView2 directory beside the executable.
class DesktopHtmlEnvironment {
  DesktopHtmlEnvironment({this.platform, this.directory});

  final PlatformWebViewEnvironment? platform;
  final Directory? directory;

  static Future<DesktopHtmlEnvironment> create(TargetPlatform target) async {
    // WPE creates a fresh ephemeral network session for each incognito view.
    if (target != TargetPlatform.windows) return DesktopHtmlEnvironment();
    final directory = await Directory.systemTemp.createTemp('raft-html-');
    PlatformWebViewEnvironment? environment;
    try {
      environment = await PlatformWebViewEnvironment.static().create(
        settings: WebViewEnvironmentSettings(
          userDataFolder: directory.path,
          allowSingleSignOnUsingOSPrimaryAccount: false,
          areBrowserExtensionsEnabled: false,
          isCustomCrashReportingEnabled: false,
        ),
      );
      // The plugin's older-runtime fallback does not create an InPrivate
      // controller. Do not silently take that fallback for untrusted HTML.
      if (!await environment.isInterfaceSupported(
        WebViewInterface.ICoreWebView2Environment10,
      )) {
        throw StateError('The renderer cannot isolate this preview.');
      }
      return DesktopHtmlEnvironment(
        platform: environment,
        directory: directory,
      );
    } catch (_) {
      await environment?.dispose();
      if (await directory.exists()) await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> dispose() async {
    await platform?.dispose();
    final folder = directory;
    if (folder == null) return;
    // WebView2 releases its process handles after controller disposal.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        if (await folder.exists()) await folder.delete(recursive: true);
        return;
      } on FileSystemException {
        if (attempt == 2) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  }
}
