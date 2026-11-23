import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/desktop_browser_session.dart';
import 'package:raft_flutter/features/desktop_browser_windows_page.dart';
import 'package:raft_flutter/platform/attachment_html_desktop_environment.dart';

void main() {
  test('Windows frames can load local documents and allowed web addresses', () {
    const hosts = {'raft.test'};
    for (final address in [
      'https://public.test/',
      'http://public.test/',
      'about:blank',
      'about:srcdoc',
      'blob:https://public.test/id',
      'data:text/html,example',
    ]) {
      expect(
        allowsWindowsBrowserNavigation(address, hosts, mainFrame: false),
        isTrue,
        reason: address,
      );
    }
    for (final address in [
      'https://raft.test./',
      'https://user:pass@public.test/',
      'raft://channel/example',
      'file:///example.html',
      'about:config',
      'javascript:void(0)',
    ]) {
      expect(
        allowsWindowsBrowserNavigation(address, hosts, mainFrame: false),
        isFalse,
        reason: address,
      );
    }
    expect(
      allowsWindowsBrowserNavigation('about:blank', hosts, mainFrame: true),
      isFalse,
    );
  });

  test(
    'an exited Windows environment is replaced once per generation',
    () async {
      final environments = <DesktopHtmlEnvironment>[];
      final profile = DesktopBrowserWindowsProfile(
        createEnvironment: () async {
          final environment = DesktopHtmlEnvironment();
          environments.add(environment);
          return environment;
        },
      );
      final original = await profile.open();
      expect(await profile.open(), same(original));
      profile.invalidate(original);

      final [first, second] = await Future.wait([
        profile.open(),
        profile.open(),
      ]);
      expect(first, same(second));
      expect(first, isNot(same(original)));
      profile.invalidate(original);
      expect(await profile.open(), same(first));
      expect(environments, hasLength(2));

      profile.dispose();
      await expectLater(profile.open(), throwsStateError);
    },
  );
}
