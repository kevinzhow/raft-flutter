// Server v1.24.0 two-step verification sign-in (Web SecondFactorSignInStep):
// the first step answers a challenge, the page asks for an authenticator or
// backup code, and the verify answer signs in like the first step would have.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/auth_harness.dart';

const _token = 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789_-abcde';

Map<String, dynamic> _challenge({
  List<String> methods = const ['totp', 'backup_code'],
  Duration validFor = const Duration(minutes: 5),
}) => {
  'secondFactorRequired': true,
  'challenge': _token,
  'expiresAt': DateTime.now().toUtc().add(validFor).toIso8601String(),
  'methods': methods,
  'maskedEmail': 'p***@example.invalid',
};

const _signedIn = {
  'accessToken': 'access',
  'refreshToken': 'refresh',
  'user': {'id': 'user-1', 'name': 'person', 'email': 'p@example.invalid'},
};

class _Page {
  _Page(this.t, {this.zh = false});
  final WidgetTester t;
  final bool zh;
  final server = ScriptedServer();
  final signedIn = <RaftClient>[];

  RaftClient client(String origin) => RaftClient(
    origin: origin,
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = server,
  );

  /// The app root's own wiring: every sign-in step runs on a fresh session
  /// client, which becomes the app's session only when the step succeeds.
  Future<void> authenticate(
    String origin,
    Future<void> Function(RaftClient) action,
  ) async {
    final c = client(origin);
    try {
      await action(c);
    } catch (_) {
      await c.dispose();
      rethrow;
    }
    signedIn.add(c);
  }

  Future<void> mount() async {
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
          onLogin: (b, e, p) => authenticate(b, (c) => c.login(e, p)),
          onRegister: (b, e, p, a) async {},
          anonymousClientFactory: client,
          authenticate: authenticate,
        ),
      ),
    );
    await settle();
  }

  Future<void> settle([int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await t.pump(const Duration(milliseconds: 10));
    }
  }

  Future<void> signIn() async {
    await t.enterText(
      find.byKey(const Key('login-email')),
      'p@example.invalid',
    );
    await t.enterText(find.byKey(const Key('login-password')), 'password-1');
    await t.tap(find.byKey(const Key('login-submit')));
    await settle();
  }

  Finder get codeField => find.descendant(
    of: find.byKey(const Key('second-factor-sign-in')),
    matching: find.byType(EditableText),
  );

  Future<void> answer(String code) async {
    await t.enterText(codeField, code);
    await t.pump();
    await t.tap(find.byKey(const Key('second-factor-verify')));
    await settle();
  }
}

void main() {
  testWidgets('a challenge opens the second step; a code signs in', (t) async {
    final page = _Page(t);
    page.server.answers['/auth/login'] = [(200, _challenge())];
    page.server.answers['/auth/second-factor/verify'] = [(200, _signedIn)];
    await page.mount();
    await page.signIn();

    expect(find.text('Two-step verification'), findsOneWidget);
    expect(find.textContaining('p***@example.invalid'), findsOneWidget);
    expect(find.text('Authenticator code'), findsOneWidget);
    expect(find.text('Use a backup code'), findsOneWidget);
    expect(find.text('Sign-in failed'), findsNothing);
    expect(find.text('Sign-in failed'), findsNothing);
    expect(page.signedIn, isEmpty);

    await page.answer('123 456');
    final verify = page.server.to('/auth/second-factor/verify');
    expect(verify, hasLength(1));
    expect(verify.single.data, {'challenge': _token, 'code': '123456'});
    expect(page.signedIn, hasLength(1));
    expect(page.signedIn.single.user?.id, 'user-1');
    expect(find.text('Two-step verification'), findsNothing);
  });

  testWidgets('a wrong code says so under the field; a backup code works', (
    t,
  ) async {
    final page = _Page(t);
    page.server.answers['/auth/login'] = [(200, _challenge())];
    page.server.answers['/auth/second-factor/verify'] = [
      (
        400,
        {
          'error': 'That code is not valid.',
          'code': 'second_factor_code_invalid',
        },
      ),
      (200, _signedIn),
    ];
    await page.mount();
    await page.signIn();
    await page.answer('000000');
    expect(
      find.text(
        "That code didn't work. Check your authenticator app and try again.",
      ),
      findsOneWidget,
    );
    expect(page.signedIn, isEmpty);

    await t.tap(find.byKey(const Key('second-factor-use-backupCode')));
    await t.pump();
    expect(find.text('Backup code'), findsOneWidget);
    expect(find.text('Use authenticator code'), findsOneWidget);
    await page.answer('abcde-12345');
    expect(page.server.to('/auth/second-factor/verify').last.data, {
      'challenge': _token,
      'backupCode': 'abcde-12345',
    });
    expect(page.signedIn, hasLength(1));
  });

  testWidgets('an expired challenge ends the step with Back to sign in', (
    t,
  ) async {
    final page = _Page(t);
    page.server.answers['/auth/login'] = [(200, _challenge())];
    page.server.answers['/auth/second-factor/verify'] = [
      (410, {'error': 'Expired', 'code': 'challenge_expired'}),
    ];
    await page.mount();
    await page.signIn();
    await page.answer('123456');
    expect(
      find.text('This sign-in has expired. Sign in again.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('second-factor-verify')), findsNothing);
    await t.tap(find.byKey(const Key('second-factor-back-button')));
    await page.settle();
    expect(find.text('Two-step verification'), findsNothing);
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    expect(page.signedIn, isEmpty);
  });

  testWidgets('passkey-only: the page says why and offers only Back', (
    t,
  ) async {
    final page = _Page(t);
    page.server.answers['/auth/login'] = [
      (200, _challenge(methods: const ['passkey'])),
    ];
    await page.mount();
    await page.signIn();
    expect(find.text('Two-step verification'), findsOneWidget);
    expect(
      find.text(
        "This browser can't use passkeys. Use another way, or open Raft in a browser that has your passkey.",
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('second-factor-verify')), findsNothing);
  });

  testWidgets('the step reads in zh like the Web catalog', (t) async {
    final page = _Page(t, zh: true);
    page.server.answers['/auth/login'] = [(200, _challenge())];
    await page.mount();
    await page.signIn();
    expect(find.text('两步验证'), findsOneWidget);
    expect(find.text('验证器验证码'), findsOneWidget);
    expect(find.text('使用备用码'), findsOneWidget);
  });
}
