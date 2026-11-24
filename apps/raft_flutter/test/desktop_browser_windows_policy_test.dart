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

  group('Windows download handoff', () {
    const hosts = {'raft.test'};
    const start = 'https://public.test/export';
    const intermediate = 'https://cdn.test/redirect';
    const finish = 'https://cdn.test/report.csv';
    late Duration elapsed;
    late WindowsBrowserDownloads downloads;

    setUp(() {
      elapsed = Duration.zero;
      downloads = WindowsBrowserDownloads(elapsed: () => elapsed);
    });

    void request(
      String id,
      String address, {
      bool userInitiated = false,
      String? redirectedFrom,
      bool clickListenerAvailable = true,
    }) => downloads.requestStarted(
      id,
      address,
      hosts,
      userInitiated: userInitiated,
      redirectedFrom: redirectedFrom,
      clickListenerAvailable: clickListenerAvailable,
    );

    Uri? download(String address) => downloads.consume(
      DownloadStartRequest(url: WebUri(address), contentLength: 0),
      hosts,
    );

    test('a user-initiated navigation follows its delayed redirects once', () {
      downloads.clicked('', hosts);
      request('first', start, userInitiated: true);
      elapsed = const Duration(seconds: 2);
      request('second', intermediate, redirectedFrom: 'first');
      request('third', finish, redirectedFrom: 'second');
      expect(download(start), isNull);
      expect(download(finish), Uri.parse(finish));
      expect(download(finish), isNull);
    });

    test('an untrusted navigation and an unrelated redirect cannot open', () {
      request('untrusted', start, userInitiated: true);
      request('redirect', finish, redirectedFrom: 'untrusted');
      expect(download(finish), isNull);

      downloads.clicked('', hosts);
      request('trusted', start, userInitiated: true);
      request('other', finish, redirectedFrom: 'unrelated');
      expect(download(finish), isNull);
    });

    test('a direct download can respond slowly without a navigation', () {
      downloads.clicked('$start#details', hosts);
      expect(download(start), isNull);
      request('direct', start);
      elapsed = const Duration(seconds: 2);
      expect(download(finish), isNull);
      expect(download(start), Uri.parse(start));
      expect(download(start), isNull);
    });

    test('a direct download follows its request through a slow redirect', () {
      downloads.clicked(start, hosts);
      request('direct', start);
      elapsed = const Duration(seconds: 2);
      request('redirect', finish, redirectedFrom: 'direct');
      expect(download(finish), Uri.parse(finish));
      expect(download(finish), isNull);
    });

    test('a click elsewhere leaves an authorized request in flight', () {
      downloads.clicked('', hosts);
      request('navigation', start, userInitiated: true);
      elapsed = const Duration(milliseconds: 200);
      downloads.clicked('', hosts);
      elapsed = const Duration(seconds: 2);
      expect(download(start), Uri.parse(start));
    });

    test('the click expires before a late request of either kind starts', () {
      downloads.clicked(start, hosts);
      elapsed = const Duration(milliseconds: 1001);
      request('late-direct', start);
      expect(download(start), isNull);

      downloads.clicked('', hosts);
      elapsed += const Duration(milliseconds: 1001);
      request('late-navigation', start, userInitiated: true);
      expect(download(start), isNull);
    });

    test('failed listener setup falls back to user-initiated navigation', () {
      downloads.clicked(start, hosts);
      request('script', start, clickListenerAvailable: false);
      expect(download(start), isNull);
      request(
        'navigation',
        start,
        userInitiated: true,
        clickListenerAvailable: false,
      );
      elapsed = const Duration(seconds: 2);
      request('redirect', finish, redirectedFrom: 'navigation');
      expect(download(finish), Uri.parse(finish));
      expect(download(finish), isNull);
    });
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
