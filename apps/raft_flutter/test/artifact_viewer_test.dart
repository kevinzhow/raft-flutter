import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/artifact_link.dart';
import 'package:raft_flutter/features/custom_protocol_link.dart';
import 'package:raft_flutter/features/human_login.dart';
import 'package:raft_flutter/features/human_login_scope.dart';
import 'package:raft_flutter/features/human_login_sheet.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/close_support.dart' show frames;
import 'support/fake_webview.dart';
import 'support/human_login_fake.dart';

/// Artifact links open in the app, and "Login with Raft" on a private artifact
/// is answered natively with the app's session. The WebView and the HTTP layer
/// are fakes; the navigation delegate and the app's own code are real.
void main() {
  const artifact = 'https://raft-artifacts.com/p/acme/report';
  const callback = 'https://raft-artifacts.com/auth/human/callback';
  const phone = Size(390, 844);
  const desktop = Size(1280, 800);

  String setupUrl({
    String path = '/login-with-raft/setup',
    String server = 'srv-1',
    String scope = 'openid+profile+identity',
    String origin = 'https://app.example.com',
  }) =>
      '$origin$path?client_id=artifact-share'
      '&return_to=${Uri.encodeComponent(callback)}&state=st-1'
      '&scope=$scope${server.isEmpty ? '' : '&server=$server'}';

  late List<String> launched;
  late List<String> cookieCalls;
  late List<String> logs;

  setUpAll(() => WebViewPlatform.instance = FakeWebView());
  setUp(() {
    FakeWebView.reset();
    launched = [];
    cookieCalls = [];
    logs = [];
  });

  /// Runs [body] with `debugPrint` captured (and restored before the test
  /// ends: the framework checks it).
  Future<void> withLogs(Future<void> Function() body) async {
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    try {
      await body();
    } finally {
      debugPrint = previous;
    }
  }

  Future<void> mount(
    WidgetTester t, {
    HumanLoginApi? api,
    Size size = phone,
    String link = artifact,
    Locale locale = const Locale('en'),
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final messenger = t.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        if (call.method == 'launch') {
          launched.add((call.arguments as Map)['url'] as String);
        }
        return true;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('app.raft/html-preview-privacy'),
      (call) async {
        cookieCalls.add(call.method);
        return null;
      },
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('app.raft/html-preview-privacy'),
        null,
      );
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: HumanLoginScope(
          api: api,
          child: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  key: const Key('open-link'),
                  onPressed: () => unawaited(openMessageLink(context, link)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const Key('open-link')));
    await frames(t, 25);
  }

  final viewer = find.byKey(const ValueKey('artifact-viewer'));
  final sheet = find.byKey(const ValueKey('human-login-sheet'));
  final loginButton = find.byKey(const ValueKey('human-login-continue'));
  final cancelButton = find.byKey(const ValueKey('human-login-cancel'));

  /// The artifact answered "Sign in required"; the person pressed its "Login
  /// with Raft" link and the server redirected to the Web setup page.
  Future<bool> openSetup(WidgetTester t, String url) async {
    FakeWebView.finish(artifact);
    final allowed = await FakeWebView.navigate(url);
    await frames(t, 25);
    return allowed;
  }

  group('link routing', () {
    test('only raft-artifacts.com is an artifact link', () {
      for (final url in [
        'https://raft-artifacts.com',
        'https://raft-artifacts.com/p/acme/report',
        'https://RAFT-ARTIFACTS.com/auth/human/start?redirect=%2Fp%2Fx#h',
        'https://raft-artifacts.com:443/x',
      ]) {
        expect(ArtifactLinks.matches(Uri.parse(url)), isTrue, reason: url);
      }
      for (final url in [
        'https://raft-artifacts.com.evil.example/p/a/b',
        'https://evil.example/raft-artifacts.com',
        'https://www.raft-artifacts.com/p/a/b',
        'http://raft-artifacts.com/p/a/b',
        'https://user@raft-artifacts.com/p/a/b',
        'https://raft-artifacts.com:8443/p/a/b',
        'mailto:a@raft-artifacts.com',
        'javascript:alert(1)',
        'obsidian://open?vault=a',
      ]) {
        expect(ArtifactLinks.matches(Uri.parse(url)), isFalse, reason: url);
      }
    });

    test('a test stack can add its own artifact origin', () {
      final origins = ArtifactLinks.origins('http://localhost:18080, bad, ');
      expect(
        ArtifactLinks.matches(
          Uri.parse('http://localhost:18080/p/a/b'),
          origins: origins,
        ),
        isTrue,
      );
      expect(
        ArtifactLinks.matches(
          Uri.parse('http://localhost:18081/p/a/b'),
          origins: origins,
        ),
        isFalse,
      );
    });

    testWidgets('an artifact link opens in the app, not the browser', (
      t,
    ) async {
      await mount(t, api: FakeHumanLoginApi());
      expect(viewer, findsOneWidget);
      expect(find.byKey(const ValueKey('fake-webview')), findsOneWidget);
      expect(FakeWebView.loads, [artifact]);
      expect(launched, isEmpty);
      expect(FakeWebView.javaScriptMode, JavaScriptMode.unrestricted);
      // The HTML preview switches the cookie jar off; the artifact needs it.
      expect(cookieCalls, ['enableCookies']);
      expect(find.text('raft-artifacts.com'), findsOneWidget);
    });

    testWidgets(
      'without a platform WebView (Linux, Windows) the browser opens it',
      (t) async {
        debugArtifactViewerSupported = false;
        addTearDown(() => debugArtifactViewerSupported = null);
        await mount(t, api: FakeHumanLoginApi());
        expect(viewer, findsNothing);
        expect(launched, [artifact]);
      },
    );

    testWidgets('any path of the host opens in the app', (t) async {
      await mount(
        t,
        link: 'https://raft-artifacts.com/auth/human/start?redirect=%2Fp%2Fa',
      );
      expect(viewer, findsOneWidget);
      expect(launched, isEmpty);
    });

    for (final link in [
      'https://example.com/page',
      'http://example.com/page',
      'mailto:person@example.com',
      'https://raft-artifacts.com.evil.example/p/a/b',
    ]) {
      testWidgets('$link keeps its behaviour: the system opens it', (t) async {
        await mount(t, link: link);
        expect(viewer, findsNothing);
        expect(launched, [link]);
        expect(FakeWebView.loads, isEmpty);
      });
    }

    testWidgets(
      'a custom protocol still asks first; other schemes are not links',
      (t) async {
        await mount(t, link: 'obsidian://open?vault=a');
        expect(viewer, findsNothing);
        expect(
          find.byKey(const ValueKey('custom-protocol-link-confirm')),
          findsOneWidget,
        );
        expect(launched, isEmpty);
        await t.tap(find.text('Cancel'));
        await frames(t);
        await t.tap(find.byKey(const Key('open-link')));
        await mount(t, link: 'javascript:alert(1)');
        expect(viewer, findsNothing);
        expect(launched, isEmpty);
      },
    );

    testWidgets('a phone gets a full page, a wide window a full-bleed dialog', (
      t,
    ) async {
      await mount(t, api: FakeHumanLoginApi());
      expect(find.byType(RaftPanelHeaderBar), findsOneWidget);
      expect(find.byType(RaftLightboxHeader), findsNothing);
      expect(
        find.byKey(const ValueKey('artifact-viewer-close')),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('artifact-viewer-close')));
      await frames(t, 25);
      expect(viewer, findsNothing);

      await mount(t, api: FakeHumanLoginApi(), size: desktop);
      expect(find.byType(RaftLightboxHeader), findsOneWidget);
      expect(find.byType(RaftPanelHeaderBar), findsNothing);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(t, 25);
      expect(viewer, findsNothing);
    });

    testWidgets('Open in browser sends the page being shown to the system', (
      t,
    ) async {
      await mount(t, api: FakeHumanLoginApi());
      await t.tap(find.byKey(const ValueKey('artifact-viewer-open-browser')));
      await frames(t);
      expect(launched, [artifact]);
      FakeWebView.finish('https://raft-artifacts.com/p/acme/other');
      await frames(t);
      await t.tap(find.byKey(const ValueKey('artifact-viewer-open-browser')));
      await frames(t);
      expect(launched.last, 'https://raft-artifacts.com/p/acme/other');
    });

    testWidgets('a page that cannot load offers Retry and the browser', (
      t,
    ) async {
      await mount(t, api: FakeHumanLoginApi());
      FakeWebView.failMainFrame('net::ERR_INTERNET_DISCONNECTED');
      await frames(t);
      expect(
        find.byKey(const ValueKey('artifact-viewer-error')),
        findsOneWidget,
      );
      expect(find.text('This page could not be loaded.'), findsOneWidget);
      await t.tap(find.text('Retry'));
      await frames(t);
      expect(FakeWebView.loads, [artifact, artifact]);
      expect(find.byKey(const ValueKey('artifact-viewer-error')), findsNothing);
    });
  });

  group('what stays in the WebView', () {
    testWidgets('phone Back returns from a nested page before closing', (
      t,
    ) async {
      await mount(t, api: FakeHumanLoginApi());
      FakeWebView.finish(artifact);
      const nested = 'https://raft-artifacts.com/p/acme/report/details.html';
      expect(await FakeWebView.navigate(nested), isTrue);
      FakeWebView.finish(nested);
      await frames(t);
      await t.tap(find.byKey(const ValueKey('artifact-viewer-close')));
      await frames(t, 25);
      expect(viewer, findsOneWidget);
      expect(FakeWebView.shown, artifact);
      expect(FakeWebView.backCalls, 1);
      expect(launched, isEmpty);
      await t.tap(find.byKey(const ValueKey('artifact-viewer-close')));
      await frames(t, 25);
      expect(viewer, findsNothing);
    });

    testWidgets('phone system Back returns to the report before leaving', (
      t,
    ) async {
      await mount(t, api: FakeHumanLoginApi());
      FakeWebView.finish(artifact);
      const nested = 'https://raft-artifacts.com/p/acme/report/details.html';
      expect(await FakeWebView.navigate(nested), isTrue);
      FakeWebView.finish(nested);
      await frames(t);
      await t.binding.handlePopRoute();
      await frames(t, 25);
      expect(viewer, findsOneWidget);
      expect(FakeWebView.shown, artifact);
      expect(FakeWebView.backCalls, 1);
    });

    testWidgets('desktop offers report history without replacing Close', (
      t,
    ) async {
      await mount(t, api: FakeHumanLoginApi(), size: desktop);
      FakeWebView.finish(artifact);
      const nested = 'https://raft-artifacts.com/p/acme/report/details.html';
      expect(await FakeWebView.navigate(nested), isTrue);
      FakeWebView.finish(nested);
      await frames(t);
      await t.tap(find.byKey(const ValueKey('artifact-viewer-back')));
      await frames(t);
      expect(viewer, findsOneWidget);
      expect(FakeWebView.shown, artifact);
      expect(find.byKey(const ValueKey('artifact-viewer-back')), findsNothing);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(t, 25);
      expect(viewer, findsNothing);
    });

    testWidgets('system Back also returns while a child page is loading', (
      t,
    ) async {
      await mount(t, api: FakeHumanLoginApi());
      FakeWebView.finish(artifact);
      expect(
        await FakeWebView.navigate(
          'https://raft-artifacts.com/p/acme/report/slow.html',
        ),
        isTrue,
      );
      // No onPageFinished: the report's child page is still in flight.
      await t.binding.handlePopRoute();
      await frames(t, 25);
      expect(viewer, findsOneWidget);
      expect(FakeWebView.shown, artifact);
      expect(FakeWebView.backCalls, 1);
      await t.binding.handlePopRoute();
      await frames(t, 25);
      expect(viewer, findsNothing);
    });

    testWidgets('Back at the entry never revisits a sign-in callback', (
      t,
    ) async {
      await mount(t, api: FakeHumanLoginApi());
      FakeWebView.finish(artifact);
      expect(await FakeWebView.navigate(callback), isTrue);
      FakeWebView.finish(callback);
      expect(await FakeWebView.navigate(artifact), isTrue);
      FakeWebView.finish(artifact);
      await frames(t);
      await t.tap(find.byKey(const ValueKey('artifact-viewer-close')));
      await frames(t, 25);
      expect(viewer, findsNothing);
      expect(FakeWebView.backCalls, 0);
    });

    testWidgets('artifact pages stay; other sites open in the browser', (
      t,
    ) async {
      await mount(t, api: FakeHumanLoginApi());
      expect(await FakeWebView.navigate(artifact), isTrue);
      expect(
        await FakeWebView.navigate('https://raft-artifacts.com/p/acme/b'),
        isTrue,
      );
      // An embedded frame is the page's own business.
      expect(
        await FakeWebView.navigate(
          'https://cdn.example.net/x',
          mainFrame: false,
        ),
        isTrue,
      );
      expect(launched, isEmpty);

      expect(await FakeWebView.navigate('https://example.com/out'), isFalse);
      expect(launched, ['https://example.com/out']);
      expect(await FakeWebView.navigate('intent://x#Intent;end'), isFalse);
      expect(await FakeWebView.navigate('javascript:alert(1)'), isFalse);
      expect(launched, ['https://example.com/out']);
    });

    testWidgets('closing unloads the page and ignores what it still does', (
      t,
    ) async {
      await mount(t, api: FakeHumanLoginApi());
      await t.tap(find.byKey(const ValueKey('artifact-viewer-close')));
      await frames(t, 25);
      expect(FakeWebView.loads.last, 'about:blank');
      expect(await FakeWebView.navigate('about:blank'), isTrue);
      expect(
        await FakeWebView.navigate('https://raft-artifacts.com/x'),
        isFalse,
      );
    });
  });

  group('Login with Raft takeover', () {
    testWidgets(
      'the setup page is cancelled and answered by the confirmation',
      (t) async {
        final api = FakeHumanLoginApi();
        await mount(t, api: api);
        expect(await openSetup(t, setupUrl()), isFalse);

        // Nothing was loaded for it; the sign-in page is still the page.
        expect(FakeWebView.loads, [artifact]);
        expect(sheet, findsOneWidget);
        expect(find.text('Login with Raft'), findsWidgets);
        expect(
          find.text('Artifact Share wants to connect to Acme'),
          findsOneWidget,
        );
        expect(find.text('Acme (acme)'), findsOneWidget);
        expect(find.text('Shares private artifacts'), findsOneWidget);
        expect(find.text('Signed in as person@example.com'), findsOneWidget);
        // Web `GET /oauth/clients/lookup` parameters.
        expect(api.lookups.single.serverId, 'srv-1');
        expect(api.lookups.single.query, {
          'client_id': 'artifact-share',
          'server_id': 'srv-1',
          'scope': 'openid profile identity',
        });
        // Never authorized silently.
        expect(api.authorizations, isEmpty);
      },
    );

    testWidgets('the consent lists the scopes in Web\'s words', (t) async {
      await mount(t, api: FakeHumanLoginApi());
      await openSetup(t, setupUrl());
      final scopes = find.byKey(const ValueKey('human-login-scopes'));
      expect(scopes, findsOneWidget);
      expect(
        find.descendant(of: scopes, matching: find.text('Requested access')),
        findsOneWidget,
      );
      expect(
        find.text(
          'These scopes are the exact capabilities this Login with Raft request will grant.',
        ),
        findsOneWidget,
      );
      for (final scope in ['openid', 'profile', 'identity']) {
        expect(
          find.byKey(ValueKey('human-login-scope-$scope')),
          findsOneWidget,
          reason: scope,
        );
      }
      expect(
        find.text(
          'Signs you in with Raft and issues a stable identity token. Authentication only.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Reads your basic profile fields (display name and similar). No access to messages, files, or agents.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Who you are and your basic profile'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Login with Raft authorizes with the app\'s session and loads the callback',
      (t) => withLogs(() async {
        final api = FakeHumanLoginApi();
        await mount(t, api: api);
        await openSetup(t, setupUrl());
        await t.tap(loginButton);
        await frames(t, 25);

        expect(api.authorizations, [
          {
            'clientId': 'artifact-share',
            'serverId': 'srv-1',
            'returnUrl': callback,
            'scopes': ['openid', 'profile', 'identity'],
          },
        ]);
        expect(sheet, findsNothing);
        expect(FakeWebView.loads, [
          artifact,
          '$callback?code=issued-code-1&state=st-1',
        ]);
        expect(viewer, findsOneWidget);
        // The callback was approved: its own redirects stay in the WebView.
        expect(
          await FakeWebView.navigate('$callback?code=issued-code-1&state=st-1'),
          isTrue,
        );
        // The code never reaches a log.
        expect(logs.join('\n'), isNot(contains('issued-code-1')));
      }),
    );

    for (final path in [
      '/login-with-slock/setup',
      '/login-with-slock-human/setup',
    ]) {
      testWidgets('the legacy $path is taken over too', (t) async {
        final api = FakeHumanLoginApi();
        await mount(t, api: api);
        expect(await openSetup(t, setupUrl(path: path)), isFalse);
        expect(sheet, findsOneWidget);
        expect(api.lookups, hasLength(1));
      });
    }

    testWidgets('only the app\'s own Raft Web origin is taken over', (t) async {
      final api = FakeHumanLoginApi();
      await mount(t, api: api);
      FakeWebView.finish(artifact);
      // Another host serving the same path is just another site.
      expect(
        await FakeWebView.navigate(
          setupUrl(origin: 'https://evil.example.com'),
        ),
        isFalse,
      );
      await frames(t);
      expect(sheet, findsNothing);
      expect(launched, [setupUrl(origin: 'https://evil.example.com')]);
      expect(api.lookups, isEmpty);
    });

    testWidgets('a platform that reports the redirect late is handled too', (
      t,
    ) async {
      final api = FakeHumanLoginApi();
      await mount(t, api: api);
      FakeWebView.finish(artifact);
      FakeWebView.urlChanged(setupUrl());
      await frames(t, 25);
      expect(sheet, findsOneWidget);
      await t.tap(cancelButton);
      await frames(t, 25);
      // The WebView had already moved on: it goes back to the sign-in page.
      expect(FakeWebView.loads, [artifact, artifact]);
      expect(FakeWebView.shown, artifact);
    });

    testWidgets('Cancel authorizes nothing and leaves the sign-in page', (
      t,
    ) async {
      final api = FakeHumanLoginApi();
      await mount(t, api: api);
      await openSetup(t, setupUrl());
      await t.tap(cancelButton);
      await frames(t, 25);
      expect(sheet, findsNothing);
      expect(api.authorizations, isEmpty);
      expect(FakeWebView.loads, [artifact]);
      expect(FakeWebView.shown, artifact);
      expect(viewer, findsOneWidget);
    });

    testWidgets('closing the sheet with Back or Escape is Cancel', (t) async {
      final api = FakeHumanLoginApi();
      await mount(t, api: api, size: desktop);
      await openSetup(t, setupUrl());
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(t, 25);
      expect(sheet, findsNothing);
      expect(api.authorizations, isEmpty);
      expect(viewer, findsOneWidget);
    });

    testWidgets('a refusal shows the server\'s reason and can be left', (
      t,
    ) async {
      final api = FakeHumanLoginApi(
        authorizeError: RaftApiException.response(
          'invalid_scope',
          status: 400,
          body: {
            'error': 'invalid_scope',
            'error_description':
                'This OAuth client is not allowed to request: identity.',
          },
        ),
      );
      await mount(t, api: api);
      await openSetup(t, setupUrl());
      await t.tap(loginButton);
      await frames(t, 25);
      expect(sheet, findsOneWidget);
      expect(
        find.text('This OAuth client is not allowed to request: identity.'),
        findsOneWidget,
      );
      expect(FakeWebView.loads, [artifact], reason: 'nothing was loaded');
      await t.tap(cancelButton);
      await frames(t, 25);
      expect(sheet, findsNothing);
      expect(FakeWebView.shown, artifact);
    });

    testWidgets('a failure with no reason shows Web\'s generic text', (
      t,
    ) async {
      final api = FakeHumanLoginApi(
        authorizeError: StateError('code=secret-9'),
      );
      await mount(t, api: api);
      await openSetup(t, setupUrl());
      await t.tap(loginButton);
      await frames(t, 25);
      expect(find.text('Failed to continue with Raft.'), findsOneWidget);
      expect(find.textContaining('secret-9'), findsNothing);
      // The person may try again.
      api.authorizeError = null;
      await t.tap(loginButton);
      await frames(t, 25);
      expect(sheet, findsNothing);
      expect(FakeWebView.loads.last, startsWith('$callback?code='));
    });

    testWidgets('a server the account is not in: Web\'s message, then back', (
      t,
    ) async {
      final api = FakeHumanLoginApi();
      await mount(t, api: api);
      await openSetup(t, setupUrl(server: 'srv-other'));
      expect(
        find.text('You do not have access to any Raft Servers.'),
        findsOneWidget,
      );
      expect(loginButton, findsNothing);
      expect(api.lookups, isEmpty);
      await t.tap(cancelButton);
      await frames(t, 25);
      expect(sheet, findsNothing);
      expect(api.authorizations, isEmpty);
      expect(FakeWebView.shown, artifact);
    });

    testWidgets('an app not registered on the server: Web\'s explanation', (
      t,
    ) async {
      final api = FakeHumanLoginApi(clients: {});
      await mount(t, api: api);
      await openSetup(t, setupUrl());
      // Web shows its "not accessible" page, not the form.
      expect(find.text('This App is not accessible yet'), findsOneWidget);
      expect(
        find.text(
          'This private third-party App is not available on any Raft Server you can access.',
        ),
        findsOneWidget,
      );
      expect(loginButton, findsNothing);
    });

    testWidgets('the server the link names is used, not the current one', (
      t,
    ) async {
      final api = FakeHumanLoginApi(
        servers: const [
          HumanLoginServer(id: 'srv-1', slug: 'acme', name: 'Acme'),
          HumanLoginServer(id: 'srv-2', slug: 'beta', name: 'Beta'),
        ],
      );
      await mount(t, api: api);
      // By id, and (next test) by slug.
      await openSetup(t, setupUrl(server: 'srv-2'));
      expect(api.lookups.map((l) => l.serverId), ['srv-2']);
      expect(
        find.text('Artifact Share wants to connect to Beta'),
        findsOneWidget,
      );
      expect(find.text('Beta (beta)'), findsOneWidget);
      await t.tap(loginButton);
      await frames(t, 25);
      expect(api.authorizations.single['serverId'], 'srv-2');
    });

    testWidgets('a slug names the server too', (t) async {
      final api = FakeHumanLoginApi(
        servers: const [
          HumanLoginServer(id: 'srv-1', slug: 'acme', name: 'Acme'),
          HumanLoginServer(id: 'srv-2', slug: 'beta', name: 'Beta'),
        ],
      );
      await mount(t, api: api);
      await openSetup(t, setupUrl(server: 'beta'));
      expect(api.lookups.map((l) => l.serverId), ['srv-2']);
    });

    testWidgets('with no server named, the person picks among the available', (
      t,
    ) async {
      final api = FakeHumanLoginApi(
        servers: const [
          HumanLoginServer(id: 'srv-1', slug: 'acme', name: 'Acme'),
          HumanLoginServer(id: 'srv-2', slug: 'beta', name: 'Beta'),
        ],
      );
      await mount(t, api: api);
      await openSetup(t, setupUrl(server: ''));
      expect(api.lookups, hasLength(2));
      await t.tap(find.byKey(const ValueKey('human-login-server-srv-2')));
      await frames(t);
      await t.tap(loginButton);
      await frames(t, 25);
      expect(api.authorizations.single['serverId'], 'srv-2');
    });

    for (final canInstall in [true, false]) {
      testWidgets(
        'install_required (canInstall: $canInstall) asks before installing',
        (t) async {
          final api = FakeHumanLoginApi(
            client: FakeHumanLoginApi.app(
              installRequired: true,
              canInstall: canInstall,
            ),
          );
          await mount(t, api: api);
          await openSetup(t, setupUrl());
          final zone = find.byKey(const ValueKey('human-login-commit-zone'));
          expect(zone, findsOneWidget);
          expect(
            find.descendant(
              of: zone,
              matching: find.textContaining(
                canInstall
                    ? 'Continuing will install the App as you.'
                    : 'Only an owner or admin of this Server can install it.',
              ),
            ),
            findsOneWidget,
          );
          // Only a person who may install is offered it; looking at the
          // sheet installs and authorizes nothing.
          expect(loginButton.evaluate().isNotEmpty, canInstall);
          if (canInstall) {
            expect(find.text('Install and continue'), findsOneWidget);
          }
          expect(api.installs, isEmpty);
          expect(api.authorizations, isEmpty);
        },
      );
    }

    testWidgets(
      'scopes the client may not request, or a person cannot grant, block it',
      (t) async {
        var api = FakeHumanLoginApi(
          client: FakeHumanLoginApi.app(
            disallowed: ['identity'],
            reason: 'not_allowed',
          ),
        );
        await mount(t, api: api);
        await openSetup(t, setupUrl());
        expect(
          find.byKey(const ValueKey('human-login-scope-error')),
          findsOneWidget,
        );
        expect(
          find.textContaining('OAuth client permissions need attention'),
          findsOneWidget,
        );
        expect(t.widget<RaftButton>(loginButton).onPressed, isNull);
        await t.tap(cancelButton);
        await frames(t, 25);
        await t.tap(find.byKey(const ValueKey('artifact-viewer-close')));
        await frames(t, 25);

        api = FakeHumanLoginApi();
        await mount(t, api: api);
        await openSetup(t, setupUrl(scope: 'openid+agent:event:write'));
        expect(
          find.text(
            'Agent messaging requires Raft Agent Login. Cannot send chat as you, speak as the agent, read messages, or take actions.',
          ),
          findsOneWidget,
        );
        expect(t.widget<RaftButton>(loginButton).onPressed, isNull);
        expect(api.authorizations, isEmpty);
      },
    );

    testWidgets('scopes Raft does not know are listed as unrecognized', (
      t,
    ) async {
      await mount(t, api: FakeHumanLoginApi());
      await openSetup(t, setupUrl(scope: 'openid+files:all'));
      expect(find.text('Unrecognized scopes:'), findsOneWidget);
      expect(find.text('files:all'), findsOneWidget);
      expect(
        find.text(
          'Recognized capabilities are shown below. Review unrecognized requested scopes before continuing.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('signed out: the setup page goes to the browser, no sheet', (
      t,
    ) async {
      await mount(t);
      FakeWebView.finish(artifact);
      // Without a session there is no origin to compare with: the setup page
      // is like any other site.
      expect(await FakeWebView.navigate(setupUrl()), isFalse);
      await frames(t);
      expect(sheet, findsNothing);
      expect(launched, [setupUrl()]);
    });

    testWidgets('the sheet is a dialog on a wide window', (t) async {
      final api = FakeHumanLoginApi();
      await mount(t, api: api, size: desktop);
      await openSetup(t, setupUrl());
      expect(sheet, findsOneWidget);
      expect(t.getSize(sheet).width, lessThan(desktop.width));
      await t.tap(loginButton);
      await frames(t, 25);
      expect(FakeWebView.loads.last, startsWith('$callback?code='));
    });

    testWidgets('the confirmation reads in Chinese', (t) async {
      await mount(
        t,
        api: FakeHumanLoginApi(),
        locale: const Locale('zh', 'CN'),
      );
      await openSetup(t, setupUrl());
      expect(find.text('使用 Raft 登录'), findsWidgets);
      expect(find.text('Artifact Share 想要连接到 Acme'), findsOneWidget);
      expect(find.text('请求的权限'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(
        find.textContaining('使用 Raft 登录并签发稳定的身份令牌').evaluate(),
        isEmpty,
        reason: 'the scope text is "使用 Raft 为你登录，并签发稳定的身份令牌"',
      );
      expect(find.textContaining('签发稳定的身份令牌'), findsOneWidget);
    });
  });

  testWidgets('showHumanLoginSheet resolves to the callback only on confirm', (
    t,
  ) async {
    final api = FakeHumanLoginApi();
    t.view.physicalSize = phone;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Uri? result;
    var done = false;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Builder(
          builder: (context) => TextButton(
            key: const Key('go'),
            onPressed: () async {
              result = await showHumanLoginSheet(
                context,
                api: api,
                request: HumanLoginRequest.fromSetupUri(Uri.parse(setupUrl())),
              );
              done = true;
            },
            child: const Text('go'),
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const Key('go')));
    await frames(t, 25);
    expect(done, isFalse, reason: 'waiting for the person');
    await t.tap(loginButton);
    await frames(t, 25);
    expect(done, isTrue);
    expect(result.toString(), '$callback?code=issued-code-1&state=st-1');
  });
}
