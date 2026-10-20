import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/account_onboarding.dart';

import 'parity/cases/screens/screen_fixture.dart';

void main() {
  test(
    'real legacy handle completes identity even if its timestamp is missing',
    () {
      expect(
        accountNeedsProfile(
          RaftRecord({
            'id': 'old',
            'name': 'developer',
            'profileSetupCompletedAt': null,
          }),
        ),
        false,
      );
      expect(
        accountNeedsProfile(
          RaftRecord({
            'id': 'new',
            'name': 'PENDING_fixtu',
            'profileSetupCompletedAt': '2026-07-01',
          }),
        ),
        true,
      );
      expect(
        accountNeedsOnboarding(
          RaftRecord({'name': 'developer', 'emailVerified': true}),
        ),
        false,
      );
    },
  );
  test('username validation follows Unicode first-letter contract', () {
    expect(accountUsernameError('123abc'), isNotNull);
    expect(accountUsernameError('日本語ユーザー'), isNull);
    expect(accountUsernameError('pending_fixture'), isNotNull);
  });
  testWidgets(
    'login preserves password spaces and validates origin before calling parent',
    (tester) async {
      final calls = <List<String>>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: AuthView(
            origin: 'https://example.invalid',
            onLogin: (b, e, p) async {
              calls.add([b, e, p]);
            },
            onRegister: (b, e, p, a) async {},
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'alice@example.invalid',
      );
      await tester.enterText(
        find.byKey(const Key('login-password')),
        '  password  ',
      );
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();
      expect(calls.single.last, '  password  ');
      // A native client's server origin is validated before the parent is
      // called (the origin is edited from the brand bar).
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: AuthView(
            key: const ValueKey('bad-origin'),
            origin: 'https://user:secret@example.invalid',
            onLogin: (b, e, p) async {
              calls.add([b, e, p]);
            },
            onRegister: (b, e, p, a) async {},
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'alice@example.invalid',
      );
      await tester.enterText(find.byKey(const Key('login-password')), 'pw');
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter the server origin, such as https://raft.example.com.'),
        findsOneWidget,
      );
      expect(calls, hasLength(1));
    },
  );
  testWidgets('registration requires a separate explicit legal agreement', (
    tester,
  ) async {
    var registered = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: AuthView(
          origin: 'https://example.invalid',
          onLogin: (b, e, p) async {},
          onRegister: (b, e, p, accepted) async {
            expect(accepted, true);
            registered++;
          },
        ),
      ),
    );
    await tester.tapOnText(find.textRange.ofSubstring('Create one'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'alice@example.invalid',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'valid-password',
    );
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    // RegisterPage.tsx: the submit button stays disabled until the legal
    // checkbox is ticked.
    expect(registered, 0);
    await tester.ensureVisible(find.byKey(const Key('register-legal')));
    await tester.tap(find.byKey(const Key('register-legal')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(registered, 1);
  });

  Widget authApp({
    String mode = 'login',
    Locale? locale,
    void Function(String)? onLogin,
  }) => MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('zh')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: raftTheme(RaftFamily.elegant),
    home: AuthView(
      origin: 'https://example.invalid',
      initialMode: mode,
      onLogin: (b, e, p) async => onLogin?.call(e),
      onRegister: (b, e, p, a) async {},
    ),
  );

  // Web v1.21.12 LoginPage: "Forgot password?" is the password FormField's
  // labelAction (far end of the label row); the no-account prompt comes before
  // the legal notice and nothing follows the legal notice.
  testWidgets('login: forgot-password sits in the password label row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(authApp());
    final label = tester.getRect(find.text('Password').first);
    final forgot = tester.getRect(
      find.byKey(const Key('login-forgot-password')),
    );
    final field = tester.getRect(find.byKey(const Key('login-password')));
    expect((forgot.center.dy - label.center.dy).abs(), lessThan(2));
    expect(forgot.left, greaterThan(label.right));
    expect(forgot.bottom, lessThan(field.top));
    // Right edge of the card column (max-w-md, 20dp page padding).
    expect(forgot.right, closeTo(field.right, 1));
    final prompt = tester.getRect(find.text('No account?\u00A0'));
    final legal = tester.getRect(
      find.textContaining('By continuing, you agree', findRichText: true),
    );
    expect(prompt.top, lessThan(legal.top));
    expect(
      find.text('Forgot password?'),
      findsOneWidget,
      reason: 'the old standalone link below the legal notice is gone',
    );
    // 24dp (mt-6) between the prompt line and the legal notice.
    expect(legal.top - prompt.bottom, closeTo(24, 2));
  });

  testWidgets('login: the forgot-password link opens the reset request', (
    tester,
  ) async {
    await tester.pumpWidget(authApp());
    await tester.ensureVisible(find.byKey(const Key('login-forgot-password')));
    await tester.tap(find.byKey(const Key('login-forgot-password')));
    await tester.pumpAndSettle();
    expect(find.text('Send Reset Link'), findsOneWidget);
  });

  // TextLink v1.21.12: no underline at rest, hover/focus shows it.
  testWidgets('text links are not underlined at rest, only on hover', (
    tester,
  ) async {
    await tester.pumpWidget(authApp());
    bool underlined(String label) => tester
        .widget<RaftUnderlinedText>(
          find.widgetWithText(RaftUnderlinedText, label),
        )
        .underline;
    expect(underlined('Forgot password?'), isFalse);
    expect(underlined('Create one'), isFalse);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('login-forgot-password'))),
    );
    await tester.pump();
    expect(underlined('Forgot password?'), isTrue);
    expect(underlined('Create one'), isFalse);
  });

  testWidgets('login prompt follows the zh Web wording without a gap', (
    tester,
  ) async {
    await tester.pumpWidget(authApp(locale: const Locale('zh')));
    expect(find.text('还没有账号？'), findsOneWidget);
    expect(find.text('创建一个'), findsOneWidget);
    expect(find.text('忘记密码？'), findsOneWidget);
  });

  // raft-ui field: elegant label is `font-medium text-foreground-strong
  // dark:text-foreground-hint` (muted in dark, not the strong ink).
  testWidgets('elegant-dark field labels are muted, light ones strong', (
    tester,
  ) async {
    Future<(Color?, FontWeight?, RaftTokens)> labelOf(bool dark) async {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(dark),
          theme: raftTheme(RaftFamily.elegant, dark: dark),
          home: AuthView(
            origin: 'https://example.invalid',
            onLogin: (b, e, p) async {},
            onRegister: (b, e, p, a) async {},
          ),
        ),
      );
      final style = tester.widget<Text>(find.text('Email').first).style;
      return (
        style?.color,
        style?.fontWeight,
        RaftTokens.of(tester.element(find.byType(AuthView))),
      );
    }

    final (darkColor, darkWeight, darkTokens) = await labelOf(true);
    expect(darkColor, darkTokens.semantic.foregroundHint);
    expect(darkWeight, FontWeight.w500);
    final (lightColor, lightWeight, lightTokens) = await labelOf(false);
    expect(lightColor, lightTokens.strong);
    expect(lightWeight, FontWeight.w500);
  });

  // RegisterPage (task #724): a disabled Continue says why.
  testWidgets('register: the disabled Continue states the legal reason', (
    tester,
  ) async {
    await tester.pumpWidget(authApp(mode: 'register'));
    const hint =
        'Agree to the Terms of Service and acknowledge the Privacy Policy to continue.';
    expect(find.text(hint), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('register-legal')));
    await tester.tap(find.byKey(const Key('register-legal')));
    await tester.pumpAndSettle();
    expect(find.text(hint), findsNothing);
    await tester.tap(find.byKey(const Key('register-legal')));
    await tester.pumpAndSettle();
    expect(find.text(hint), findsOneWidget);
  });

  testWidgets('register: the legal reason is localized to zh', (tester) async {
    await tester.pumpWidget(
      authApp(mode: 'register', locale: const Locale('zh')),
    );
    expect(find.text('请先同意服务条款并确认隐私政策，再继续。'), findsOneWidget);
    expect(find.text('已有账号？'), findsOneWidget);
  });

  testWidgets('login validation shows the Web messages under the field', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: AuthView(
          origin: 'https://example.invalid',
          onLogin: (b, e, p) async => calls.add(e),
          onRegister: (b, e, p, a) async {},
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('login-email')), 'nope');
    await tester.enterText(find.byKey(const Key('login-password')), 'secret');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Invalid email format'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('login-email')), 'a@b.co');
    await tester.enterText(find.byKey(const Key('login-password')), '');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Invalid email format'), findsNothing);
    expect(find.text('Password is required'), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('forgot password ends on the check-your-email page', (
    tester,
  ) async {
    final requests = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: AuthView(
          origin: 'http://localhost:13041',
          initialMode: 'forgot',
          onLogin: (b, e, p) async {},
          onRegister: (b, e, p, a) async {},
          anonymousClientFactory: (origin) => _AnonymousClient(requests),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'alice@example.invalid',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(requests, contains('POST /auth/forgot-password'));
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('alice@example.invalid'), findsOneWidget);
    await tester.tap(find.text('Back to Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsWidgets);
    expect(find.byKey(const Key('login-password')), findsOneWidget);
  });

  testWidgets('reset with a link token asks for the new password twice', (
    tester,
  ) async {
    final requests = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: AuthView(
          origin: 'http://localhost:13041',
          initialMode: 'reset',
          resetToken: 'abc',
          onLogin: (b, e, p) async {},
          onRegister: (b, e, p, a) async {},
          anonymousClientFactory: (origin) => _AnonymousClient(requests),
        ),
      ),
    );
    expect(find.byKey(const Key('reset-token')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('reset-password')),
      'longenough1',
    );
    await tester.enterText(
      find.byKey(const Key('reset-confirm')),
      'different11',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(requests, isEmpty);
    await tester.enterText(
      find.byKey(const Key('reset-confirm')),
      'longenough1',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(requests, ['POST /auth/reset-password']);
    expect(find.text('Password reset'), findsOneWidget);
  });
  testWidgets('unverified account gets the Web email verification page', (
    tester,
  ) async {
    final requests = <String>[];
    final client = ScreenFixtureClient((method, path, query) {
      requests.add('$method $path');
      return <String, dynamic>{};
    }, user: {'id': 'u', 'email': 'artin@raft.build', 'emailVerified': false});
    addTearDown(client.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: AccountOnboardingView(
          client: client,
          onComplete: () async {},
          onSignOut: () async {},
        ),
      ),
    );
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.text('artin@raft.build'), findsOneWidget);
    expect(find.byKey(const Key('verification-token')), findsNothing);
    await tester.tap(find.byKey(const Key('verify-manual-toggle')));
    await tester.pump();
    expect(find.byKey(const Key('verification-token')), findsOneWidget);
    expect(find.textContaining('Hide manual entry'), findsOneWidget);
    await tester.tap(find.byKey(const Key('verify-resend')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(requests, contains('POST /auth/resend-verification'));
    expect(
      find.text('Verification email resent! Check your inbox.'),
      findsOneWidget,
    );
  });
}

class _AnonymousClient extends RaftClient {
  _AnonymousClient(this.requests)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  final List<String> requests;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    requests.add('$method $path');
    return <String, dynamic>{};
  }
}
