import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:raft_flutter/features/channel_side_web_preview_panel.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'message_presentation_test.dart' show host;
import 'support/fake_webview.dart';
import 'support/web_preview_fixture.dart';

/// Web v1.24 web preview (`features/webPreview`: webPreviewStore.ts,
/// WebPreviewPanel.tsx): what may open beside a conversation, the store, and
/// the panel's head, frame and insecure state.
void main() {
  setUpAll(() => WebViewPlatform.instance = FakeWebView());
  setUp(FakeWebView.reset);

  const raft = ['app.raft.build', 'example.invalid'];

  group('what may open beside the conversation', () {
    test('http and https only, not Raft\'s hosts, no credentials', () {
      expect(
        webPreviewTarget('https://docs.example.com/a?b=1#c', raft)?.toString(),
        'https://docs.example.com/a?b=1#c',
      );
      expect(webPreviewTarget('http://docs.example.com', raft), isNotNull);
      for (final bad in [
        null,
        '',
        'not a url',
        'javascript:alert(1)',
        'data:text/html,hi',
        'blob:https://example.com/x',
        'file:///etc/passwd',
        'mailto:a@example.com',
        'raft://invite/x',
        'https://user:pass@docs.example.com/',
        'https://user@docs.example.com/',
        'https://app.raft.build/s/x/channel/y',
        'https://example.invalid/anything',
      ]) {
        expect(webPreviewTarget(bad, raft), isNull, reason: '$bad');
      }
    });

    test('only https is shown; http says so', () {
      expect(canFrameWebPreview('https://docs.example.com'), isTrue);
      expect(canFrameWebPreview('http://docs.example.com'), isFalse);
      expect(canFrameWebPreview('javascript:alert(1)'), isFalse);
    });

    test('the head names the host and mutes the rest', () {
      expect(webPreviewAddressParts('https://docs.example.com/'), (
        host: 'docs.example.com',
        rest: '',
      ));
      expect(
        webPreviewAddressParts('https://docs.example.com:8443/a/b?q=1#h'),
        (host: 'docs.example.com:8443', rest: '/a/b?q=1#h'),
      );
    });

    test(
      'Raft\'s own hosts are the deployment\'s and the fixed defaults',
      () async {
        final (w, _) = await webPreviewFixture();
        addTearDown(w.dispose);
        expect(
          raftAppHostnames(w),
          containsAll(['example.invalid', 'app.raft.build', 'app.slock.ai']),
        );
      },
    );
  });

  group('the store', () {
    test('one page at a time: opening replaces, closing clears', () async {
      final (w, _) = await webPreviewFixture();
      addTearDown(w.dispose);
      final store = WebPreviewStore.of(w);
      var heard = 0;
      store.addListener(() => heard++);
      store.open(
        const WebPreviewPage(
          url: 'https://a.example.com/',
          conversationId: 'c1',
        ),
      );
      expect(store.page?.url, 'https://a.example.com/');
      expect(store.pageFor('c1'), isNotNull);
      expect(store.pageFor('c2'), isNull);
      expect(store.openedAt, greaterThan(0));
      store.reload();
      expect(store.reloads, 1);
      store.open(
        const WebPreviewPage(
          url: 'https://b.example.com/',
          conversationId: 'c2',
        ),
      );
      expect(store.page?.url, 'https://b.example.com/');
      expect(store.page?.conversationId, 'c2');
      expect(store.reloads, 0, reason: 'a new page starts unreloaded');
      store.setWidth(WebPreviewWidth.phone);
      expect(store.width, WebPreviewWidth.phone);
      store.close();
      expect(store.page, isNull);
      expect(heard, 5);
      store.close();
      expect(heard, 5, reason: 'closing nothing changes nothing');
    });

    test('an address that is not http(s) never opens', () async {
      final (w, _) = await webPreviewFixture();
      addTearDown(w.dispose);
      final store = WebPreviewStore.of(w)
        ..open(
          const WebPreviewPage(
            url: 'javascript:alert(1)',
            conversationId: 'c1',
          ),
        );
      expect(store.page, isNull);
    });
  });

  group('openWebPreviewBeside', () {
    test('an https page opens beside the channel on screen', () async {
      final (w, _) = await webPreviewFixture();
      addTearDown(w.dispose);
      expect(
        openWebPreviewBeside(
          w,
          'https://docs.example.com/x',
          conversationId: 'c1',
        ),
        isTrue,
      );
      expect(
        WebPreviewStore.of(w).page,
        const WebPreviewPage(
          url: 'https://docs.example.com/x',
          conversationId: 'c1',
        ),
      );
    });

    test('where it can\'t, it says false and opens nothing', () async {
      for (final (name, build, url, conversation)
          in <(String, Future<dynamic> Function(), String, String)>[
            (
              'plain http is never shown',
              () => webPreviewFixture(),
              'http://docs.example.com/',
              'c1',
            ),
            (
              'Raft\'s own page',
              () => webPreviewFixture(),
              'https://app.raft.build/s/x/channel/y',
              'c1',
            ),
            (
              'credentials in the address',
              () => webPreviewFixture(),
              'https://u:p@docs.example.com/',
              'c1',
            ),
            (
              'a conversation that is not on screen',
              () => webPreviewFixture(),
              'https://docs.example.com/',
              'c2',
            ),
            (
              'web preview off',
              () => webPreviewFixture(flag: false),
              'https://docs.example.com/',
              'c1',
            ),
            (
              'Linux has no WebView',
              () => webPreviewFixture(os: 'linux'),
              'https://docs.example.com/',
              'c1',
            ),
            (
              'Windows has no WebView',
              () => webPreviewFixture(os: 'windows'),
              'https://docs.example.com/',
              'c1',
            ),
            (
              'macOS with VoiceOver on',
              () async {
                final on = ValueNotifier(true);
                addTearDown(on.dispose);
                return webPreviewFixture(os: 'macos', voiceOver: on);
              },
              'https://docs.example.com/',
              'c1',
            ),
          ]) {
        final (w, _) = await build();
        addTearDown(w.dispose);
        expect(
          openWebPreviewBeside(w, url, conversationId: conversation),
          isFalse,
          reason: name,
        );
        expect(WebPreviewStore.of(w).page, isNull, reason: name);
      }
    });

    test('Android, iOS and macOS show pages in the app', () async {
      for (final os in ['android', 'ios', 'macos']) {
        final (w, _) = await webPreviewFixture(os: os);
        addTearDown(w.dispose);
        expect(
          openWebPreviewBeside(
            w,
            'https://docs.example.com/',
            conversationId: 'c1',
          ),
          isTrue,
          reason: os,
        );
      }
    });
  });

  group('the panel', () {
    const https = WebPreviewPage(
      url: 'https://docs.example.com/guide/start?x=1',
      conversationId: 'c1',
    );
    const http = WebPreviewPage(
      url: 'http://docs.example.com/guide',
      conversationId: 'c1',
    );

    Future<(WebPreviewStore, List<String>)> mount(
      WidgetTester t,
      WebPreviewPage page, {
      bool covering = false,
      String os = 'android',
      ValueNotifier<bool>? voiceOver,
    }) async {
      t.view.physicalSize = const Size(900, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final (w, _) = (await t.runAsync(
        () => webPreviewFixture(os: os, voiceOver: voiceOver),
      ))!;
      addTearDown(w.dispose);
      final store = WebPreviewStore.of(w)..open(page);
      final opened = <String>[];
      await t.pumpWidget(
        host(
          SizedBox(
            width: 600,
            height: 700,
            child: WebPreviewPanel(
              store: store,
              page: page,
              covering: covering,
              openExternal: opened.add,
            ),
          ),
        ),
      );
      await t.pump();
      await t.pump();
      return (store, opened);
    }

    testWidgets('an https page loads in a WebView with JavaScript on', (
      t,
    ) async {
      final semantics = t.ensureSemantics();
      await mount(t, https);
      expect(find.byKey(const ValueKey('fake-webview')), findsOneWidget);
      expect(FakeWebView.loads, [https.url]);
      expect(FakeWebView.javaScriptMode, JavaScriptMode.unrestricted);
      // The head: the host is the title, the rest of the address is muted.
      expect(find.text('docs.example.com'), findsOneWidget);
      expect(find.text('/guide/start?x=1'), findsOneWidget);
      expect(find.byKey(const ValueKey('web-preview-insecure')), findsNothing);
      expect(
        find.bySemanticsLabel('Web preview: docs.example.com'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('the page can\'t reach Raft: no JavaScript channel is added', (
      t,
    ) async {
      // The fake platform throws on addJavaScriptChannel; a panel that added
      // one would never finish loading.
      await mount(t, https);
      expect(t.takeException(), isNull);
      expect(FakeWebView.loads, isNotEmpty);
    });

    testWidgets(
      'an http page is never shown: the insecure state opens the browser',
      (t) async {
        final (_, opened) = await mount(t, http);
        expect(find.byKey(const ValueKey('fake-webview')), findsNothing);
        expect(FakeWebView.loads, isEmpty);
        expect(
          find.byKey(const ValueKey('web-preview-insecure')),
          findsOneWidget,
        );
        expect(find.text('This page can’t be shown here'), findsOneWidget);
        expect(
          find.text(
            'It uses http://, which isn’t secure, so it can’t be shown inside Raft.',
          ),
          findsOneWidget,
        );
        // Nothing to refresh or resize; Open in browser and Close stay.
        expect(find.byKey(const ValueKey('web-preview-refresh')), findsNothing);
        expect(find.byKey(const ValueKey('web-preview-width')), findsNothing);
        await t.tap(find.byKey(const ValueKey('web-preview-insecure-open')));
        expect(opened, [http.url]);
      },
    );

    testWidgets('Open in browser opens the address that was opened', (t) async {
      final (_, opened) = await mount(t, https);
      await t.tap(find.byKey(const ValueKey('web-preview-open-tab')));
      expect(opened, [https.url]);
    });

    testWidgets('a site that refuses to show keeps its way out on screen', (
      t,
    ) async {
      final (_, opened) = await mount(t, https);
      expect(find.textContaining('Page not showing?'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('web-preview-hint-open')));
      expect(opened, [https.url]);
    });

    testWidgets('Refresh mounts the page again', (t) async {
      final (store, _) = await mount(t, https);
      expect(FakeWebView.loads, hasLength(1));
      await t.tap(find.byKey(const ValueKey('web-preview-refresh')));
      await t.pump();
      await t.pump();
      expect(store.reloads, 1);
      expect(FakeWebView.loads, [https.url, https.url]);
    });

    testWidgets('one button for the two widths, named for the one it goes to', (
      t,
    ) async {
      final (store, _) = await mount(t, https);
      RaftPanelAction width() =>
          t.widget(find.byKey(const ValueKey('web-preview-width')));
      expect(width().tooltip, 'Phone width');
      expect(width().glyph, RaftGlyph.smartphone);
      expect(find.byKey(const ValueKey('web-preview-phone')), findsNothing);
      await t.tap(find.byKey(const ValueKey('web-preview-width')));
      await t.pump();
      expect(store.width, WebPreviewWidth.phone);
      expect(width().tooltip, 'Desktop width');
      expect(width().glyph, RaftGlyph.monitor);
      final phone = find.byKey(const ValueKey('web-preview-phone'));
      expect(phone, findsOneWidget);
      expect(
        t.getSize(find.byKey(const ValueKey('fake-webview'))).width,
        webPreviewPhoneWidth - 2,
        reason: 'the page is 390px wide inside its hairline border',
      );
      await t.tap(find.byKey(const ValueKey('web-preview-width')));
      await t.pump();
      expect(store.width, WebPreviewWidth.desktop);
      expect(find.byKey(const ValueKey('web-preview-phone')), findsNothing);
    });

    testWidgets('Close closes the page', (t) async {
      final (store, _) = await mount(t, https);
      await t.tap(find.byKey(const ValueKey('web-preview-close')));
      expect(store.page, isNull);
    });

    testWidgets('covering the chat on a phone: Back closes, no width, no X', (
      t,
    ) async {
      final (store, _) = await mount(t, https, covering: true);
      expect(find.byKey(const ValueKey('web-preview-close')), findsNothing);
      expect(find.byKey(const ValueKey('web-preview-width')), findsNothing);
      expect(find.byKey(const ValueKey('web-preview-refresh')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('web-preview-back')));
      expect(store.page, isNull);
    });

    testWidgets(
      'navigation: https stays, http goes to the browser, other schemes are refused',
      (t) async {
        final (_, opened) = await mount(t, https);
        expect(
          await FakeWebView.navigate('https://docs.example.com/other'),
          isTrue,
        );
        expect(
          await FakeWebView.navigate('https://elsewhere.example/'),
          isTrue,
        );
        expect(
          await FakeWebView.navigate('http://insecure.example/'),
          isFalse,
          reason: 'mixed content is blocked in Web; here it opens the browser',
        );
        expect(opened, ['http://insecure.example/']);
        for (final refused in [
          'intent://scan/#Intent;scheme=zxing;end',
          'mailto:a@example.com',
          'raft://invite/x',
          'file:///etc/passwd',
          'javascript:alert(1)',
        ]) {
          expect(await FakeWebView.navigate(refused), isFalse, reason: refused);
        }
        expect(opened, hasLength(1), reason: 'refused schemes open nothing');
        // A frame inside the page (an embed) loads as it asks to.
        expect(
          await FakeWebView.navigate(
            'https://player.example/embed',
            mainFrame: false,
          ),
          isTrue,
        );
      },
    );

    testWidgets('macOS with VoiceOver on shows no WebView, only the way out', (
      t,
    ) async {
      final voiceOver = ValueNotifier(false);
      addTearDown(voiceOver.dispose);
      final (_, opened) = await mount(
        t,
        https,
        os: 'macos',
        voiceOver: voiceOver,
      );
      expect(find.byKey(const ValueKey('fake-webview')), findsOneWidget);
      voiceOver.value = true;
      await t.pump();
      expect(find.byKey(const ValueKey('fake-webview')), findsNothing);
      await t.tap(find.byKey(const ValueKey('web-preview-browser-open')));
      expect(opened, [https.url]);
    });
  });

  test('the navigation rules by scheme', () {
    for (final (url, mainFrame, expected) in [
      ('https://a.example/', true, WebPreviewNavigation.stay),
      ('about:blank', true, WebPreviewNavigation.stay),
      ('http://a.example/', true, WebPreviewNavigation.browser),
      ('ftp://a.example/', true, WebPreviewNavigation.refuse),
      ('tel:123', true, WebPreviewNavigation.refuse),
      ('http://a.example/', false, WebPreviewNavigation.stay),
    ]) {
      expect(
        webPreviewNavigation(url, isMainFrame: mainFrame),
        expected,
        reason: '$url main=$mainFrame',
      );
    }
  });
}
