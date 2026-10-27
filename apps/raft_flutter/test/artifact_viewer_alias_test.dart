import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/custom_protocol_link.dart';
import 'package:raft_flutter/features/human_login.dart';
import 'package:raft_flutter/features/human_login_scope.dart';
import 'package:raft_flutter/platform/content_links.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/close_support.dart' show frames;
import 'support/fake_webview.dart';
import 'support/human_login_fake.dart';

/// Replays the live Artifact -> legacy Web -> current Web boundary using the
/// real app session client and navigation delegate. HTTP and native WebView
/// are faked; this is not a native-device or real-account sign-in test.
class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  String? returnOverride;

  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    calls.add(request);
    final data = switch ('${request.method} ${request.path}') {
      'POST /auth/login' => {
        'accessToken': 'fixture-only',
        'refreshToken': 'fixture-only',
        'user': {'id': 'fixture-user', 'email': 'fixture@example.com'},
      },
      'GET /oauth/clients/lookup' => FakeHumanLoginApi.app(),
      'POST /oauth/authorize/human' => {
        'code': 'fixture-issued-code',
        'returnUrl': returnOverride ?? (request.data as Map)['returnUrl'],
      },
      _ => throw StateError('Unexpected fixture endpoint'),
    };
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const artifact = 'https://raft-artifacts.com/p/acme/report';
  const callback = 'https://raft-artifacts.com/auth/agent/callback';
  late _Adapter adapter;
  late List<Uri> launched;

  setUpAll(() => WebViewPlatform.instance = FakeWebView());
  setUp(() {
    FakeWebView.reset();
    adapter = _Adapter();
    launched = [];
  });

  String setup({
    String origin = 'https://app.slock.ai',
    String path = '/login-with-raft/setup',
    String returnTo = callback,
    Map<String, String> extra = const {},
  }) => Uri.parse('$origin$path')
      .replace(
        queryParameters: {
          'client_id': 'artifact-share',
          'return_to': returnTo,
          'state': 'fixture-state',
          'scope': 'openid profile identity',
          'server': 'acme',
          ...extra,
        },
      )
      .toString();

  Future<void> mount(
    WidgetTester tester, {
    String coordinator = 'https://api.raft.build',
    Uri? frontend,
    Size size = const Size(1280, 800),
    TargetPlatform platform = TargetPlatform.macOS,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        if (call.method == 'launch') {
          launched.add(Uri.parse((call.arguments as Map)['url'] as String));
        }
        return true;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('app.raft/html-preview-privacy'),
      (_) async => null,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        null,
      ),
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        const MethodChannel('app.raft/html-preview-privacy'),
        null,
      ),
    );
    final client = (await tester.runAsync(() async {
      final client = RaftClient(
        origin: coordinator,
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
      await client.login('fixture', 'fixture');
      return client;
    }))!;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester, 2);
      await tester.runAsync(client.dispose);
    });
    final api = ClientHumanLoginApi(
      client: client,
      webOrigin: frontend ?? ContentLinks.originFor(coordinator),
      directory: () => [
        RaftRecord({'id': 'srv-1', 'slug': 'acme', 'name': 'Acme'}),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: platform),
        home: HumanLoginScope(
          api: api,
          child: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  key: const Key('open-artifact'),
                  onPressed: () =>
                      unawaited(openMessageLink(context, artifact)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-artifact')));
    await frames(tester, 25);
    expect(find.byKey(const ValueKey('artifact-viewer')), findsOneWidget);
    expect(FakeWebView.loads, [artifact]);
    FakeWebView.finish(artifact);
  }

  testWidgets('legacy Artifact setup stays inside the official app session', (
    tester,
  ) async {
    await mount(tester);
    expect(await FakeWebView.navigate(setup()), isFalse);
    await frames(tester, 25);
    expect(find.byKey(const ValueKey('human-login-sheet')), findsOneWidget);
    expect(launched, isEmpty);
    expect(
      adapter.calls.where((c) => c.path == '/oauth/authorize/human'),
      isEmpty,
    );

    await tester.tap(find.byKey(const ValueKey('human-login-continue')));
    await frames(tester, 25);
    final authorization = adapter.calls.singleWhere(
      (c) => c.path == '/oauth/authorize/human',
    );
    expect(authorization.uri.origin, 'https://api.raft.build');
    expect(authorization.headers['Authorization'], isNotNull);
    expect(authorization.data, {
      'clientId': 'artifact-share',
      'serverId': 'srv-1',
      'returnUrl': callback,
      'scopes': ['openid', 'profile', 'identity'],
    });
    final loadedCallback = Uri.parse(FakeWebView.loads.last);
    expect(loadedCallback.origin, Uri.parse(callback).origin);
    expect(loadedCallback.path, Uri.parse(callback).path);
    expect(loadedCallback.queryParameters['code'], 'fixture-issued-code');
    expect(loadedCallback.queryParameters['state'], 'fixture-state');
    expect(FakeWebView.loadHeaders.every((headers) => headers.isEmpty), isTrue);
    FakeWebView.finish(loadedCallback.toString());
    expect(await FakeWebView.navigate(artifact), isTrue);
    FakeWebView.finish(artifact);
    await frames(tester, 2);
    expect(find.byKey(const ValueKey('human-login-sheet')), findsNothing);
    expect(find.byKey(const ValueKey('artifact-viewer-error')), findsNothing);
    expect(launched, isEmpty);
  });

  testWidgets('canonical setup and legacy coordinator keep their own session', (
    tester,
  ) async {
    await mount(tester, coordinator: 'https://api.slock.ai');
    await FakeWebView.navigate(setup(origin: 'https://app.raft.build'));
    await frames(tester, 25);
    expect(find.byKey(const ValueKey('human-login-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('human-login-continue')));
    await frames(tester, 25);
    final call = adapter.calls.singleWhere(
      (c) => c.path == '/oauth/authorize/human',
    );
    expect(call.uri.origin, 'https://api.slock.ai');
    expect(launched, isEmpty);
  });

  testWidgets('legacy setup preserves encoded state and OIDC parameters', (
    tester,
  ) async {
    await mount(tester);
    final returnTo = '$callback?next=fixture-report';
    const state = 'fixture +& state';
    await FakeWebView.navigate(
      setup(
        returnTo: returnTo,
        extra: {
          'state': state,
          'flow': 'oidc',
          'nonce': 'fixture-nonce',
          'code_challenge': 'fixture-challenge',
          'code_challenge_method': 'S256',
        },
      ),
    );
    await frames(tester, 25);
    await tester.tap(find.byKey(const ValueKey('human-login-continue')));
    await frames(tester, 25);
    final call = adapter.calls.singleWhere(
      (c) => c.path == '/oauth/authorize/human',
    );
    expect(call.data, {
      'clientId': 'artifact-share',
      'serverId': 'srv-1',
      'returnUrl': returnTo,
      'scopes': ['openid', 'profile', 'identity'],
      'oidc': true,
      'nonce': 'fixture-nonce',
      'codeChallenge': 'fixture-challenge',
      'codeChallengeMethod': 'S256',
      'server': 'acme',
    });
    final loaded = Uri.parse(FakeWebView.loads.last);
    expect(loaded.queryParameters['state'], state);
    expect(loaded.queryParameters['next'], 'fixture-report');
    expect(loaded.queryParameters['code'], 'fixture-issued-code');
    expect(FakeWebView.loadHeaders.every((headers) => headers.isEmpty), isTrue);
    expect(launched, isEmpty);
  });

  for (final entry in <String, String>{
    'evil subdomain': setup(origin: 'https://app.slock.ai.evil.example'),
    'userinfo': setup(origin: 'https://person@app.slock.ai'),
    'non-HTTPS alias': setup(origin: 'http://app.slock.ai'),
    'different port': setup(origin: 'https://app.slock.ai:9443'),
    'different path': setup(path: '/login-with-raft/setup/other'),
    'different callback origin': setup(returnTo: 'https://other.example/cb'),
    'callback userinfo': setup(
      returnTo: 'https://person@raft-artifacts.com/cb',
    ),
    'HTTP callback': setup(returnTo: 'http://raft-artifacts.com/cb'),
    'fragment callback': setup(returnTo: '$callback#fragment'),
  }.entries) {
    testWidgets('${entry.key} cannot use the native app session', (
      tester,
    ) async {
      await mount(tester);
      expect(await FakeWebView.navigate(entry.value), isFalse);
      await frames(tester, 25);
      expect(find.byKey(const ValueKey('human-login-sheet')), findsNothing);
      expect(adapter.calls.where((c) => c.path != '/auth/login'), isEmpty);
      expect(FakeWebView.loads, [artifact]);
    });
  }

  for (final pair in [
    ('self-hosted coordinator', 'https://api.example.com', null),
    (
      'custom frontend override',
      'https://api.raft.build',
      Uri.parse('https://custom.example.com'),
    ),
    (
      'self-hosted API with official frontend',
      'https://api.example.com',
      Uri.parse('https://app.raft.build'),
    ),
  ]) {
    testWidgets('${pair.$1} does not inherit official login aliases', (
      tester,
    ) async {
      await mount(tester, coordinator: pair.$2, frontend: pair.$3);
      expect(await FakeWebView.navigate(setup()), isFalse);
      await frames(tester, 25);
      expect(find.byKey(const ValueKey('human-login-sheet')), findsNothing);
      expect(adapter.calls.where((c) => c.path != '/auth/login'), isEmpty);
    });
  }

  testWidgets('an unexpected callback origin receives no authorization code', (
    tester,
  ) async {
    await mount(tester);
    adapter.returnOverride = 'https://other.example/callback';
    await FakeWebView.navigate(setup());
    await frames(tester, 25);
    await tester.tap(find.byKey(const ValueKey('human-login-continue')));
    await frames(tester, 25);
    expect(FakeWebView.loads, [artifact]);
    expect(launched, isEmpty);
    expect(find.byKey(const ValueKey('artifact-viewer-error')), findsOneWidget);
    await tester.tap(find.text('Retry'));
    FakeWebView.finish(artifact);
    await frames(tester, 5);
    expect(find.byKey(const ValueKey('artifact-viewer-error')), findsNothing);
    expect(FakeWebView.loads, [artifact, artifact]);
  });

  for (final surface in [
    ('phone', const Size(390, 844), TargetPlatform.android),
    ('fold portrait', const Size(856, 944), TargetPlatform.android),
    ('fold landscape', const Size(944, 856), TargetPlatform.android),
    ('narrow desktop', const Size(390, 844), TargetPlatform.linux),
  ]) {
    testWidgets('${surface.$1} cancels legacy setup without authorizing', (
      tester,
    ) async {
      await mount(tester, size: surface.$2, platform: surface.$3);
      await FakeWebView.navigate(setup());
      await frames(tester, 25);
      expect(find.byKey(const ValueKey('human-login-sheet')), findsOneWidget);
      expect(launched, isEmpty);
      await tester.tap(find.byKey(const ValueKey('human-login-cancel')));
      await frames(tester, 25);
      expect(find.byKey(const ValueKey('human-login-sheet')), findsNothing);
      expect(
        adapter.calls.where((c) => c.path == '/oauth/authorize/human'),
        isEmpty,
      );
      expect(FakeWebView.shown, artifact);
      expect(launched, isEmpty);
    });
  }
  for (final stage in ['navigation request', 'URL change', 'page finished']) {
    testWidgets('malformed UTF-8 in $stage does not use the native session', (
      tester,
    ) async {
      await mount(tester);
      // Uri parsing succeeds, but queryParametersAll rejects this UTF-8 byte.
      final malformed = '${setup()}&unexpected=%FF';
      switch (stage) {
        case 'navigation request':
          expect(await FakeWebView.navigate(malformed), isFalse);
        case 'URL change':
          expect(() => FakeWebView.urlChanged(malformed), returnsNormally);
        case 'page finished':
          expect(() => FakeWebView.finish(malformed), returnsNormally);
      }
      await frames(tester, 25);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('human-login-sheet')), findsNothing);
      expect(
        adapter.calls.where((call) => call.path != '/auth/login'),
        isEmpty,
      );
      expect(FakeWebView.loads, [artifact]);
      expect(
        FakeWebView.loadHeaders.every((headers) => headers.isEmpty),
        isTrue,
      );
      // Rejected main-frame links retain the existing external fallback.
      // URL-change/page-finished notifications do not themselves launch links.
      expect(
        launched,
        stage == 'navigation request' ? [Uri.parse(malformed)] : isEmpty,
      );
    });
  }
}
