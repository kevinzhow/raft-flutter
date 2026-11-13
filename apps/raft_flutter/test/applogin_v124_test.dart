// Web v1.24.0 sign-in pages (WP-APPLOGIN): the browser leg's reasons, the
// Settings "Connect" refusals, the reserved provider space, the reset notice,
// the email verification page, the legal links and the form rhythm.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/account_onboarding.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'parity/cases/screens/screen_fixture.dart';
import 'support/auth_harness.dart';

Widget _app(Widget home, {bool zh = false, TargetPlatform? platform}) =>
    MaterialApp(
      locale: zh ? const Locale('zh') : null,
      supportedLocales: zh ? const [Locale('zh')] : const [Locale('en', 'US')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: raftTheme().copyWith(platform: platform),
      home: home,
    );

Widget _auth({String mode = 'login', String? resetToken}) => AuthView(
  origin: 'https://example.invalid',
  initialMode: mode,
  resetToken: resetToken,
  onLogin: (b, e, p) async {},
  onRegister: (b, e, p, a) async {},
);

void main() {
  // NativeOAuthBroker.helpUrl, as in social_legal_acceptance_test.dart.
  leakDebt(const ['ValueNotifier<Uri?>']);

  group('the browser comes back with the server reason', () {
    for (final (code, en, zh) in [
      (
        'access_denied',
        'GitHub sign-in was denied at the provider. Try again if that was unintended.',
        'GitHub 拒绝了这次登录。如果是误操作，请重试。',
      ),
      (
        'provider_cancelled',
        'GitHub sign-in was cancelled before Raft was authorized.',
        '在授权 Raft 之前，GitHub 登录已被取消。',
      ),
      (
        'weird_reason',
        "Couldn't complete GitHub sign-in — please try again, or sign in with email and password. (reason: weird_reason)",
        '没能完成 GitHub 登录，请重试，或用邮箱和密码登录。（原因：weird_reason）',
      ),
    ]) {
      for (final inZh in [false, true]) {
        testWidgets('$code (zh: $inZh)', (t) async {
          final h = AuthHarness(t, zh: inZh);
          await h.mount();
          await t.tap(find.byKey(const ValueKey('auth-social-github')));
          await h.settle();
          h.callbacks.add(
            Uri.parse(
              'raft://oauth/callback?provider=github&mode=login&error=$code',
            ),
          );
          await h.settle();
          expect(find.text(inZh ? zh : en), findsOneWidget);
          expect(h.server.to('/auth/mobile/oauth/complete'), isEmpty);
          expect(h.signedIn, isEmpty);
        });
      }
    }
  });

  testWidgets('the provider buttons keep their space while they load', (
    t,
  ) async {
    t.view
      ..physicalSize = const Size(800, 1800)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final providers = Completer<void>();
    final server = _GatedServer(providers.future);
    server.answers['/auth/providers'] = [
      (
        200,
        {
          'providers': [
            for (final id in ['google', 'github', 'apple'])
              {'id': id, 'label': id, 'enabled': true},
          ],
        },
      ),
    ];
    await t.pumpWidget(
      _app(
        AuthView(
          origin: 'https://first-seen.invalid',
          onLogin: (b, e, p) async {},
          onRegister: (b, e, p, a) async {},
          onOAuth: (o, c, v, a) async {},
          anonymousClientFactory: (origin) => RaftClient(
            origin: origin,
            sessionStore: MemorySessionStore(),
            transport: Dio()..httpClientAdapter = server,
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.byKey(const ValueKey('auth-social-reserved')), findsOneWidget);
    final legal = t.getTopLeft(find.byType(RaftAuthLegalNotice));
    providers.complete();
    for (var i = 0; i < 6; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await t.pump(const Duration(milliseconds: 10));
    }
    expect(find.byKey(const ValueKey('auth-social-reserved')), findsNothing);
    expect(find.byKey(const ValueKey('auth-social-apple')), findsOneWidget);
    // The first frame is the settled one: nothing below the buttons moved.
    expect(t.getTopLeft(find.byType(RaftAuthLegalNotice)), legal);
  });

  for (final zh in [false, true]) {
    testWidgets('reset says it signs out everywhere (zh: $zh)', (t) async {
      await t.pumpWidget(
        _app(
          _auth(mode: 'reset', resetToken: 't'),
          zh: zh,
        ),
      );
      expect(
        find.text(
          zh
              ? '设置新密码会让你在所有设备上退出登录。通过设备登录（Raft Computer、raft CLI）设置的电脑连接和 Agent 凭证也会失效，需要在这些地方重新登录。'
              : "Setting a new password signs you out everywhere. Computers and agent credentials set up through a device login (Raft Computer, the raft CLI) stop working too, so you'll need to log in on them again.",
        ),
        findsOneWidget,
      );
      expect(
        t.getTopLeft(find.byKey(const Key('reset-device-login-notice'))).dy,
        lessThan(t.getTopLeft(find.byKey(const Key('reset-password'))).dy),
      );
      // Back to sign in is the default (muted) link now, not the primary one.
      expect(
        t
            .widget<RaftAuthTextLink>(
              find.byKey(const Key('auth-back-to-sign-in')),
            )
            .primary,
        isFalse,
      );
    });
  }

  testWidgets('email verification: spam hint, Paste link and Cancel', (
    t,
  ) async {
    final client = ScreenFixtureClient(
      (method, path, query) => <String, dynamic>{},
      user: {
        'id': 'u',
        'email': 'person@example.invalid',
        'emailVerified': false,
      },
    );
    addTearDown(client.dispose);
    await t.pumpWidget(
      _app(
        AccountOnboardingView(
          client: client,
          onComplete: () async {},
          onSignOut: () async {},
        ),
      ),
    );
    expect(find.text("Can't find it? Check your spam folder."), findsOneWidget);
    final toggle = find.byKey(const Key('verify-manual-toggle'));
    expect(
      find.descendant(of: toggle, matching: find.text('Paste link')),
      findsOneWidget,
    );
    await t.tap(toggle);
    await t.pump();
    expect(find.text('Paste the verification link'), findsOneWidget);
    await t.enterText(
      find.byKey(const Key('verification-token')),
      'half-typed',
    );
    await t.tap(toggle);
    await t.pump();
    await t.tap(toggle);
    await t.pump();
    // Cancel dropped what was typed.
    expect(find.text('half-typed'), findsNothing);
    expect(
      t.widget<RaftButton>(find.byKey(const Key('verify-logout'))).variant,
      RaftControlVariant.surface,
    );
  });

  testWidgets('the legal links say they leave Raft', (t) async {
    t.view
      ..physicalSize = const Size(800, 1800)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final semantics = t.ensureSemantics();
    await t.pumpWidget(_app(_auth()));
    expect(find.byKey(const Key('auth-legal-external')), findsNWidgets(2));
    expect(
      find.semantics.byLabel(
        RegExp(r'^Terms of Service \(opens in a new tab\)$'),
      ),
      findsOne,
    );
    semantics.dispose();
  });

  testWidgets('the sign-up agreement: links leave Raft, the label toggles', (
    t,
  ) async {
    t.view
      ..physicalSize = const Size(800, 1800)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(_auth(mode: 'register')));
    expect(find.byKey(const Key('auth-legal-external')), findsNWidgets(2));
    final agreement = find.textContaining('I agree to the', findRichText: true);
    expect(agreement, findsOneWidget);
    await t.tapAt(t.getTopLeft(agreement) + const Offset(4, 6));
    await t.pump();
    expect(
      t.widget<RaftCheckbox>(find.byKey(const Key('register-legal'))).value,
      isTrue,
    );
  });

  testWidgets('"Forgot password?" sits at the end of the label row', (t) async {
    await t.pumpWidget(_app(_auth()));
    expect(
      t.getTopRight(find.byKey(const Key('login-forgot-password'))).dx,
      moreOrLessEquals(
        t.getTopRight(find.byKey(const Key('login-password'))).dx,
        epsilon: 1,
      ),
    );
  });

  testWidgets('a wide window with a mouse spaces the form 12, touch 16', (
    t,
  ) async {
    t.view
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Future<double> gap(TargetPlatform platform) async {
      await t.pumpWidget(_app(_auth(), platform: platform));
      // MaterialApp animates a theme change (the platform flips mid-way).
      await t.pumpAndSettle();
      return t.getTopLeft(find.byKey(const Key('login-submit'))).dy -
          t.getBottomLeft(find.byKey(const Key('login-password'))).dy;
    }

    final pointer = await gap(TargetPlatform.linux);
    final touch = await gap(TargetPlatform.android);
    expect(touch - pointer, moreOrLessEquals(4, epsilon: .5));
  });

  testWidgets('server selector Cancel is the default button', (t) async {
    await t.pumpWidget(
      _app(
        Scaffold(
          body: GlobalServerSelector(
            servers: [
              RaftRecord({'id': 's', 'name': 'Dev', 'slug': 'dev'}),
            ],
            user: RaftRecord({'id': 'u', 'email': 'person@example.invalid'}),
            loading: false,
            onSelect: (_) async {},
            onCreate: (_, _) async {},
            onLogout: () async {},
            onRetry: () async {},
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('global-server-create-new')));
    await t.pump();
    expect(
      t
          .widget<RaftAuthWideButton>(
            find.byKey(const ValueKey('global-server-create-cancel')),
          )
          .variant,
      RaftControlVariant.surface,
    );
  });
}

/// Holds `/auth/providers` until [gate] completes.
class _GatedServer extends ScriptedServer {
  _GatedServer(this.gate);
  final Future<void> gate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    if (options.path == '/auth/providers') await gate;
    return super.fetch(options, stream, cancel);
  }
}
