// Raft v1.24.0 privacy version 2026-10-14 (shared legalAcceptance.ts): an
// email sign-up names the current versions, and when the server refuses them
// with TERMS_CHANGED (a newer release than this build) the next explicit
// acceptance names the versions the refusal carries.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/auth_harness.dart';

void main() {
  testWidgets('sign-up names v1.24 legal versions and retries with the '
      'versions a TERMS_CHANGED names', (t) async {
    final server = ScriptedServer();
    server.answers['/auth/register'] = [
      (
        409,
        {
          'error': 'TERMS_CHANGED',
          'legal': {
            'termsVersion': '2027-02-01',
            'privacyVersion': '2027-02-01',
            'termsUrl': 'https://raft.build/terms',
            'privacyUrl': 'https://raft.build/privacy',
          },
        },
      ),
      (
        200,
        {
          'accessToken': 'access',
          'refreshToken': 'refresh',
          'user': {'id': 'new-user', 'emailVerified': false},
        },
      ),
    ];
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
          initialMode: 'register',
          onLogin: (b, e, p) async {},
          // The app root's own wiring (app_root.dart register()).
          onRegister: (b, e, p, a) =>
              authenticate(b, (c) => c.register(e, p, acceptTerms: a)),
          anonymousClientFactory: client,
          authenticate: authenticate,
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await t.pump(const Duration(milliseconds: 10));
      }
    }

    Future<void> agreeAndContinue() async {
      await t.ensureVisible(find.byKey(const Key('register-legal')));
      await t.tap(find.byKey(const Key('register-legal')));
      await t.pump();
      await t.tap(find.byKey(const Key('login-submit')));
      await settle();
    }

    await settle();
    await t.enterText(
      find.byKey(const Key('login-email')),
      'new@example.invalid',
    );
    await t.enterText(find.byKey(const Key('login-password')), 'password-1');
    await agreeAndContinue();
    final first = server.to('/auth/register');
    expect(first, hasLength(1));
    expect(first.single.data['termsVersion'], '2026-05-12');
    expect(first.single.data['privacyVersion'], '2026-10-14');
    expect(
      find.text(
        'The Terms of Service or Privacy Policy changed. Review and continue.',
      ),
      findsOneWidget,
    );
    expect(signedIn, isEmpty);

    // The agreement was reset: it has to be given again for the new terms.
    await t.tap(find.byKey(const Key('login-submit')), warnIfMissed: false);
    await settle();
    expect(server.to('/auth/register'), hasLength(1));

    await agreeAndContinue();
    final retry = server.to('/auth/register').last;
    expect(retry.data['termsVersion'], '2027-02-01');
    expect(retry.data['privacyVersion'], '2027-02-01');
    expect(retry.data['acceptTerms'], true);
    expect(signedIn, hasLength(1));
  });
}
