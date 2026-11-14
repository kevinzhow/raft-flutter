// Web v1.24.0 SecondFactorSignInStep + SecondFactorRecoveryScreens: a person
// who can't answer the second step asks for the emailed reset ("Can't use
// any of these?"), backup codes first; once the reset is past its wait the
// challenge lists `recovery` and Finish reset answers `{recovery: true}`.
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
}) => {
  'secondFactorRequired': true,
  'challenge': _token,
  'expiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 5))
      .toIso8601String(),
  'methods': methods,
  'maskedEmail': 'p***@example.invalid',
};

const _signedIn = {
  'accessToken': 'access',
  'refreshToken': 'refresh',
  'user': {'id': 'user-1', 'name': 'person', 'email': 'p@example.invalid'},
};

class _Page {
  _Page(this.t);
  final WidgetTester t;
  final server = ScriptedServer();
  final signedIn = <RaftClient>[];

  RaftClient client(String origin) => RaftClient(
    origin: origin,
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = server,
  );

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
        supportedLocales: const [Locale('en', 'US')],
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

  Future<void> tap(Key key) async {
    await t.ensureVisible(find.byKey(key));
    await t.tap(find.byKey(key));
    await settle();
  }
}

void main() {
  testWidgets(
    "Can't use any of these? offers a backup code first, then the email",
    (t) async {
      final page = _Page(t);
      page.server.answers['/auth/login'] = [(200, _challenge())];
      await page.mount();
      await page.signIn();

      await page.tap(const Key('second-factor-cant-verify'));
      expect(find.byKey(const Key('second-factor-recovery-request')), findsOne);
      expect(find.text("Can't verify?"), findsOneWidget);
      expect(find.text('No backup codes?'), findsOneWidget);

      // Use a backup code: back on the step, answering with a backup code.
      await page.tap(const Key('second-factor-recovery-use-backup-code'));
      expect(find.byKey(const Key('second-factor-sign-in')), findsOneWidget);
      expect(find.text('Backup code'), findsOneWidget);

      // The email the password sign-in typed is already in the field.
      await page.tap(const Key('second-factor-cant-verify'));
      final field = find.byKey(const ValueKey('second-factor-recovery-email'));
      expect(
        t
            .widget<EditableText>(
              find.descendant(of: field, matching: find.byType(EditableText)),
            )
            .controller
            .text,
        'p@example.invalid',
      );
      await page.tap(const Key('second-factor-recovery-reset'));
      final sent = page.server.to('/auth/second-factor/recovery');
      expect(sent.single.data, {'email': 'p@example.invalid'});
      expect(sent.single.headers['Authorization'], isNull);
      expect(find.byKey(const Key('second-factor-recovery-sent')), findsOne);
      expect(find.text('Check your email'), findsOneWidget);
      expect(page.signedIn, isEmpty);

      // Back to sign in drops this sign-in.
      await page.tap(const Key('second-factor-recovery-back-to-sign-in'));
      expect(find.byKey(const Key('second-factor-sign-in')), findsNothing);
      expect(find.byKey(const Key('login-submit')), findsOneWidget);
    },
  );

  testWidgets('a refused email request says so; 429 says too many', (t) async {
    final page = _Page(t);
    page.server.answers['/auth/login'] = [(200, _challenge())];
    page.server.answers['/auth/second-factor/recovery'] = [
      (429, {'error': 'Too many'}),
    ];
    await page.mount();
    await page.signIn();
    await page.tap(const Key('second-factor-cant-verify'));
    await page.tap(const Key('second-factor-recovery-reset'));
    expect(find.text('Too many requests. Try again later.'), findsOneWidget);
    expect(find.byKey(const Key('second-factor-recovery-sent')), findsNothing);
  });

  testWidgets('a ready reset finishes with recovery: true and signs in', (
    t,
  ) async {
    final page = _Page(t);
    page.server.answers['/auth/login'] = [
      (200, _challenge(methods: ['totp', 'recovery'])),
    ];
    page.server.answers['/auth/second-factor/verify'] = [
      (409, {'error': 'Not ready', 'code': 'recovery_not_ready'}),
      (200, _signedIn),
    ];
    await page.mount();
    await page.signIn();

    expect(find.byKey(const Key('second-factor-recovery-ready')), findsOne);
    expect(find.text('Your reset is ready'), findsOneWidget);
    // A ready reset replaces "Can't use any of these?".
    expect(find.byKey(const Key('second-factor-cant-verify')), findsNothing);

    await page.tap(const Key('second-factor-recovery-ready-finish'));
    expect(find.byKey(const Key('second-factor-recovery-finish')), findsOne);
    expect(find.text('Finish the reset'), findsOneWidget);
    expect(page.server.to('/auth/second-factor/verify'), isEmpty);

    await page.tap(const Key('second-factor-recovery-finish-button'));
    expect(
      find.text(
        "This reset can't be finished now: it was cancelled, has lapsed, or isn't ready yet. Use your second step, or start a new reset.",
      ),
      findsOneWidget,
    );
    expect(page.signedIn, isEmpty);

    await page.tap(const Key('second-factor-recovery-finish-button'));
    final verify = page.server.to('/auth/second-factor/verify');
    expect(verify.last.data, {'challenge': _token, 'recovery': true});
    expect(page.signedIn, hasLength(1));
    expect(
      find.byKey(const Key('second-factor-recovery-finish')),
      findsNothing,
    );
  });
}
