// Web v1.21.23 "sign in and connect": a social sign-in whose email already has
// an account becomes the "Connect to your existing account" page.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/platform/oauth_broker.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;

const _token = 'pending-link-handle-0123456789';

Map<String, dynamic> _conflict({
  bool password = true,
  List<String> providers = const ['google'],
}) => {
  'code': 'account_link_required',
  'error': 'An account with this email already exists.',
  'pendingLinkToken': _token,
  'provider': 'github',
  'email': 'person@example.invalid',
  'expiresAt': '2026-10-21T12:00:00.000Z',
  'signInMethods': {'password': password, 'providers': providers},
};

/// A scripted server: `answers[path]` is consumed one reply per request.
class _Server implements HttpClientAdapter {
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

class _Harness {
  _Harness(this.t, {this.zh = false}) {
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
  final server = _Server();
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
        theme: raftTheme(RaftFamily.elegant),
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

void main() {
  leakDebt(const ['ValueNotifier<Uri?>']);
  HttpOverrides.global = null;

  testWidgets('an email conflict opens the connect page for that account', (
    t,
  ) async {
    final h = _Harness(t);
    h.server.answers['/auth/mobile/oauth/complete'] = [(409, _conflict())];
    await h.mount();
    await h.socialSignIn('github');

    expect(
      h.server.to('/auth/mobile/oauth/start').single.data['linkOnConflict'],
      true,
      reason: 'the opt-in the server needs to answer account_link_required',
    );
    expect(find.text('Connect to your existing account'), findsOneWidget);
    expect(find.text('Sign In'), findsNothing);
    expect(
      find.textContaining('This email already has a Raft account'),
      findsOneWidget,
    );
    expect(find.text('Sign in and connect GitHub'), findsOneWidget);
    expect(find.text("Don't connect GitHub"), findsOneWidget);
    expect(find.textContaining('Create one'), findsNothing);
    expect(
      t.widget<EditableText>(find.byType(EditableText).first).controller.text,
      'person@example.invalid',
    );
    // Only the ways the existing account already signs in.
    expect(find.byKey(const ValueKey('auth-social-google')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-social-github')), findsNothing);
    expect(h.signedIn, isEmpty);
  });

  testWidgets('the password sign-in sends the handle and enters the app', (
    t,
  ) async {
    final h = _Harness(t);
    h.server.answers['/auth/mobile/oauth/complete'] = [(409, _conflict())];
    h.server.answers['/auth/login'] = [
      (
        200,
        {
          'accessToken': 'access',
          'refreshToken': 'refresh',
          'user': {'id': 'user-1', 'name': 'person'},
          'linkedProvider': 'github',
        },
      ),
    ];
    await h.mount();
    await h.socialSignIn('github');
    await h.enterPassword('secret');
    await h.submit();

    expect(h.server.to('/auth/login').single.data, {
      'email': 'person@example.invalid',
      'password': 'secret',
      'pendingLinkToken': _token,
    });
    expect(h.signedIn.single.signedIn, true);
  });

  testWidgets('a sign-in that did not connect the provider shows why', (
    t,
  ) async {
    final h = _Harness(t);
    h.server.answers['/auth/mobile/oauth/complete'] = [(409, _conflict())];
    h.server.answers['/auth/login'] = [
      (
        200,
        {
          'accessToken': 'access',
          'refreshToken': 'refresh',
          'user': {'id': 'user-1', 'name': 'person'},
        },
      ),
    ];
    await h.mount();
    await h.socialSignIn('github');
    await h.enterPassword('secret');
    await h.submit();

    expect(
      find.text(
        "We couldn't connect GitHub, so you haven't been signed in. Please try again.",
      ),
      findsOneWidget,
    );
    expect(find.text('Connect to your existing account'), findsOneWidget);
    expect(h.signedIn, isEmpty, reason: 'no session without the connection');
  });

  testWidgets('signing in to a different account is explained and retryable', (
    t,
  ) async {
    final h = _Harness(t);
    h.server.answers['/auth/mobile/oauth/complete'] = [(409, _conflict())];
    h.server.answers['/auth/login'] = [
      (
        403,
        {'code': 'pending_link_account_mismatch', 'error': 'Wrong account'},
      ),
    ];
    await h.mount();
    await h.socialSignIn('github');
    await h.enterPassword('secret');
    await h.submit();

    expect(
      find.text(
        "You signed in to a different account than person@example.invalid, so GitHub wasn't connected. Please sign in with person@example.invalid.",
      ),
      findsOneWidget,
    );
    expect(find.text('Sign in and connect GitHub'), findsOneWidget);
    expect(find.text('Wrong account'), findsNothing);
  });

  testWidgets('an expired link can only start the provider again', (t) async {
    final h = _Harness(t);
    h.server.answers['/auth/mobile/oauth/complete'] = [(409, _conflict())];
    h.server.answers['/auth/login'] = [
      (410, {'code': 'pending_link_expired', 'error': 'expired'}),
    ];
    await h.mount();
    await h.socialSignIn('github');
    await h.enterPassword('secret');
    await h.submit();

    expect(
      find.text(
        'This GitHub sign-in has expired. Please sign in with GitHub again.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('login-submit')), findsNothing);
    expect(find.byKey(const Key('login-password')), findsNothing);
    expect(find.text('Back to Sign In'), findsOneWidget);

    h.server.answers['/auth/mobile/oauth/complete'] = [
      (
        200,
        {
          'accessToken': 'access',
          'refreshToken': 'refresh',
          'user': {'id': 'user-1', 'name': 'person'},
        },
      ),
    ];
    await t.tap(find.byKey(const Key('account-link-restart')));
    await h.settle();
    expect(h.server.to('/auth/mobile/oauth/start'), hasLength(2));
    expect(h.launched, hasLength(2), reason: 'a new browser attempt');
    h.callbacks.add(
      Uri.parse('raft://oauth/callback?provider=github&mode=login&code=again'),
    );
    await h.settle();
    expect(
      h.server
          .to('/auth/mobile/oauth/complete')
          .last
          .data
          .containsKey('pendingLinkToken'),
      false,
      reason: 'the expired handle is not sent again',
    );
    expect(h.signedIn.single.signedIn, true);
  });

  testWidgets(
    '"Don\'t connect" drops the pending link and returns to sign in',
    (t) async {
      final h = _Harness(t);
      h.server.answers['/auth/mobile/oauth/complete'] = [(409, _conflict())];
      h.server.answers['/auth/pending-link/cancel'] = [(204, null)];
      await h.mount();
      await h.socialSignIn('github');
      await t.tap(find.byKey(const Key('account-link-cancel')));
      await h.settle();

      expect(h.server.to('/auth/pending-link/cancel').single.data, {
        'pendingLinkToken': _token,
      });
      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Connect to your existing account'), findsNothing);
      expect(find.byKey(const ValueKey('auth-social-github')), findsOneWidget);
    },
  );

  testWidgets('a failed cancel keeps the page and says so', (t) async {
    final h = _Harness(t);
    h.server.answers['/auth/mobile/oauth/complete'] = [(409, _conflict())];
    h.server.answers['/auth/pending-link/cancel'] = [
      (500, {'error': 'boom'}),
    ];
    await h.mount();
    await h.socialSignIn('github');
    await t.tap(find.byKey(const Key('account-link-cancel')));
    await h.settle();

    expect(find.text('Connect to your existing account'), findsOneWidget);
    expect(find.text('Login failed'), findsOneWidget);
  });

  testWidgets('an account with only social sign-in offers just those', (
    t,
  ) async {
    final h = _Harness(t);
    h.server.answers['/auth/mobile/oauth/complete'] = [
      (409, _conflict(password: false, providers: ['google'])),
    ];
    await h.mount();
    await h.socialSignIn('github');

    expect(find.text('Connect to your existing account'), findsOneWidget);
    expect(find.byKey(const Key('login-submit')), findsNothing);
    expect(find.byKey(const Key('login-password')), findsNothing);
    expect(find.byKey(const Key('login-forgot-password')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-social-google')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-social-github')), findsNothing);
  });

  testWidgets('the connect page reads in Chinese (Web zh-cn wording)', (
    t,
  ) async {
    final h = _Harness(t, zh: true);
    h.server.answers['/auth/mobile/oauth/complete'] = [(409, _conflict())];
    h.server.answers['/auth/login'] = [
      (403, {'code': 'pending_link_account_mismatch', 'error': 'Wrong'}),
    ];
    await h.mount();
    await h.socialSignIn('github');
    expect(find.text('连接到已有账户'), findsOneWidget);
    expect(
      find.text('这个邮箱已有 Raft 账户。请用原来的方式登录，登录后会自动连接 GitHub 并进入 Raft。'),
      findsOneWidget,
    );
    expect(find.text('登录并连接 GitHub'), findsOneWidget);
    expect(find.text('不连接 GitHub'), findsOneWidget);
    await h.enterPassword('secret');
    await h.submit();
    expect(
      find.text(
        '你登录的不是 person@example.invalid 的账户，没有连接 GitHub。请用 person@example.invalid 登录。',
      ),
      findsOneWidget,
    );
  });
}
