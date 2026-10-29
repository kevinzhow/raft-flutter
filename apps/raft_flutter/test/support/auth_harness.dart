// A scripted server and AuthView harness for the social sign-in tests.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/platform/oauth_broker.dart';
import 'package:raft_ui/raft_ui.dart';

const pendingLinkToken = 'pending-link-handle-0123456789';

Map<String, dynamic> conflictAnswer({
  bool password = true,
  List<String> providers = const ['google'],
}) => {
  'code': 'account_link_required',
  'error': 'An account with this email already exists.',
  'pendingLinkToken': pendingLinkToken,
  'provider': 'github',
  'email': 'person@example.invalid',
  'expiresAt': '2026-10-21T12:00:00.000Z',
  'signInMethods': {'password': password, 'providers': providers},
};

/// A scripted server: `answers[path]` is consumed one reply per request.
class ScriptedServer implements HttpClientAdapter {
  final answers = <String, List<(int, Map<String, dynamic>?)>>{};
  final calls = <RequestOptions>[];

  List<RequestOptions> to(String path) =>
      calls.where((c) => c.path == path).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add(options);
    final queue = answers[options.path];
    final (status, body) = queue != null && queue.isNotEmpty
        ? (queue.length > 1 ? queue.removeAt(0) : queue.first)
        : (200, const <String, dynamic>{});
    return ResponseBody.fromString(
      jsonEncode(body ?? const {}),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class AuthHarness {
  AuthHarness(this.t, {this.zh = false}) {
    server.answers['/auth/providers'] = [
      (
        200,
        {
          'providers': [
            {'id': 'github', 'label': 'GitHub', 'enabled': true},
            {'id': 'google', 'label': 'Google', 'enabled': true},
          ],
        },
      ),
    ];
    server.answers['/auth/mobile/oauth/start'] = [
      (200, {'authorizationUrl': 'https://provider.example.invalid/authorize'}),
    ];
  }
  final WidgetTester t;
  final bool zh;
  final server = ScriptedServer();
  final callbacks = StreamController<Uri>.broadcast();
  final signedIn = <RaftClient>[];
  final launched = <Uri>[];

  RaftClient client(String origin) => RaftClient(
    origin: origin,
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = server,
  );

  Future<void> mount() async {
    // Tall enough for the whole page: the buttons below the fold are tapped.
    t.view
      ..physicalSize = const Size(800, 1800)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        locale: zh ? const Locale('zh') : null,
        supportedLocales: zh
            ? const [Locale('zh')]
            : const [Locale('en', 'US')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: raftTheme(),
        home: AuthView(
          origin: 'https://example.invalid',
          onLogin: (b, e, p) async {},
          onRegister: (b, e, p, a) async {},
          anonymousClientFactory: client,
          authenticate: (origin, action) async {
            final c = client(origin);
            await action(c);
            signedIn.add(c);
          },
          oauthBrokerFactory: () => NativeOAuthBroker(
            android: true,
            links: callbacks.stream,
            launch: (url) async => launched.add(url),
          ),
        ),
      ),
    );
    await settle(10);
  }

  /// Real I/O time between pumps (the broker and Dio run on real timers).
  Future<void> settle([int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await t.pump(const Duration(milliseconds: 10));
    }
  }

  /// Taps a provider and lets the browser "return" with a handoff code.
  Future<void> socialSignIn(String id) async {
    await t.tap(find.byKey(ValueKey('auth-social-$id')));
    await settle();
    callbacks.add(
      Uri.parse('raft://oauth/callback?provider=$id&mode=login&code=handoff'),
    );
    await settle();
  }

  Future<void> enterPassword(String value) async {
    await t.enterText(find.byKey(const Key('login-password')), value);
    await t.pump();
  }

  Future<void> submit() async {
    await t.tap(find.byKey(const Key('login-submit')));
    await settle();
  }
}
