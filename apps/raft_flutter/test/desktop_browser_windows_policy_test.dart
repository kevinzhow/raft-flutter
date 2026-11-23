import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
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

  test('Windows download adapter follows activated redirects once', () {
    final downloads = WindowsBrowserDownloads();
    const hosts = {'raft.test'};
    const start = 'https://public.test/export';
    const intermediate = 'https://cdn.test/redirect';
    const finish = 'https://cdn.test/report.csv';
    void navigate(
      String address, {
      bool redirect = false,
      bool trusted = true,
    }) {
      downloads.navigate(
        NavigationAction(
          request: URLRequest(url: WebUri(address)),
          isForMainFrame: true,
          isRedirect: redirect,
          navigationType: trusted
              ? NavigationType.LINK_ACTIVATED
              : NavigationType.OTHER,
        ),
        hosts,
      );
    }

    Uri? download(String address) => downloads.consume(
      DownloadStartRequest(url: WebUri(address), contentLength: 0),
      hosts,
    );

    downloads.clicked('', hosts);
    navigate(start);
    navigate(intermediate, redirect: true);
    navigate(finish, redirect: true);
    expect(download(start), isNull);
    expect(download(finish), Uri.parse(finish));
    expect(download(finish), isNull);

    navigate(start);
    navigate(finish, redirect: true);
    expect(download(finish), isNull);

    downloads.clicked('', hosts);
    navigate(start);
    navigate(finish, redirect: true, trusted: false);
    expect(download(finish), isNull);
  });

  test('Windows download attribute matches directly without navigation', () {
    final downloads = WindowsBrowserDownloads();
    const hosts = {'raft.test'};
    const address = 'https://public.test/report.csv';
    Uri? download(String target) => downloads.consume(
      DownloadStartRequest(url: WebUri(target), contentLength: 0),
      hosts,
    );

    expect(download(address), isNull);
    downloads.clicked('$address#details', hosts);
    expect(download('https://public.test/unrelated.csv'), isNull);
    expect(download(address), Uri.parse(address));
    expect(download(address), isNull);
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
