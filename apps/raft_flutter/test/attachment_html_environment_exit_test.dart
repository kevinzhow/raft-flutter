import 'dart:io';

import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/attachment_html_desktop_environment.dart';

class _BrowserEnvironment extends PlatformWebViewEnvironment {
  _BrowserEnvironment()
    : super.implementation(const PlatformWebViewEnvironmentCreationParams());

  bool disposed = false;
  @override
  Future<void> dispose() async => disposed = true;

  void exit() => onBrowserProcessExited?.call(
    BrowserProcessExitedDetail(kind: BrowserProcessExitKind.NORMAL),
  );
}

void main() {
  test(
    'close retains the profile until the native browser releases it',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'raft-html-exit-test-',
      );
      final browser = _BrowserEnvironment();
      final owner = DesktopHtmlEnvironment(
        platform: browser,
        directory: folder,
      );
      final closing = owner.dispose();
      try {
        await Future<void>.delayed(Duration.zero);
        expect(browser.disposed, isFalse);
        expect(await folder.exists(), isTrue);
        browser.exit();
        await closing;
        expect(browser.disposed, isTrue);
        expect(await folder.exists(), isFalse);
      } finally {
        browser.exit();
        await closing;
        if (await folder.exists()) await folder.delete(recursive: true);
      }
    },
  );

  test(
    'an early browser exit is remembered without replacing other observers',
    () async {
      var observed = 0;
      final browser = _BrowserEnvironment()
        ..onBrowserProcessExited = (_) => observed++;
      final owner = DesktopHtmlEnvironment(platform: browser);
      browser.exit();
      browser.exit();
      expect(observed, 2);
      await owner.dispose().timeout(const Duration(milliseconds: 200));
      expect(browser.disposed, isTrue);
    },
  );
}
