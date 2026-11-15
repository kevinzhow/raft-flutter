// Web v1.24.0 components/auth/secondFactorSignIn.ts `initialMethod` /
// `rememberSecondFactorMethod` (key `raft.second-factor.last-method`): the
// sign-in second step (SecondFactorSignInStep.tsx:108) and "Verify it's you"
// (VerifyItsYouDialog.tsx:41,63) start on the method this device answered
// with last. Settings' Turn off and Regenerate do not
// (TwoStepVerificationSection.tsx:558 `methods[0]`).
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/second_factor_last_method.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/account_security_passkeys.dart';
import 'package:raft_flutter/features/account_security_two_step.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/second_factor_step_up.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/auth_harness.dart';
import 'support/second_factor_server.dart';

const _both = [SecondFactorMethod.totp, SecondFactorMethod.backupCode];

/// The device as the last release left it, plus [stored].
Future<void> _device([Map<String, Object> stored = const {}]) async {
  SharedPreferences.setMockInitialValues(stored);
  DevicePreferences.reset();
  await DevicePreferences.load();
  addTearDown(() {
    DevicePreferences.reset();
  });
}

String? _stored() =>
    DevicePreferences.current!.getString(secondFactorLastMethodKey);

void main() {
  group("Verify it's you", () {
    late SecondFactorServerClient client;
    setUp(() => client = SecondFactorServerClient());
    tearDown(() => client.dispose());

    Future<void> open(
      WidgetTester t, {
      List<SecondFactorMethod> methods = _both,
      Future<void> Function(StepUpAnswer)? server,
    }) async {
      t.view
        ..physicalSize = const Size(1280, 900)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showVerifyItsYou(
                    context,
                    client,
                    methods: methods,
                    description: StepUpReason.other.description,
                    onAnswer: server ?? (_) async {},
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    Future<void> answer(WidgetTester t, String code) async {
      await t.enterText(
        find.descendant(
          of: find.byType(RaftFormDialog),
          matching: find.byType(EditableText),
        ),
        code,
      );
      await t.pump();
      await t.tap(find.text('Verify'));
      await t.pumpAndSettle();
    }

    testWidgets('a device without a remembered method starts on the first '
        'listed one and stores nothing until an answer passes', (t) async {
      await _device();
      await open(t);
      expect(find.text('Authenticator code'), findsOneWidget);
      expect(_stored(), isNull);
    });

    testWidgets('a backup code that passed is where the next one starts', (
      t,
    ) async {
      await _device();
      await open(t);
      await t.tap(find.byKey(const ValueKey('step-up-use-backup_code')));
      await t.pumpAndSettle();
      await answer(t, SecondFactorServerClient.goodBackup);
      expect(find.text("Verify it's you"), findsNothing);
      expect(_stored(), 'backup_code');

      await open(t);
      expect(find.text('Backup code'), findsOneWidget);
      expect(find.text('Use authenticator code'), findsOneWidget);
    });

    testWidgets('a refused answer is not remembered', (t) async {
      await _device({secondFactorLastMethodKey: 'totp'});
      await open(
        t,
        server: (_) async =>
            throw secondFactorRefusal(400, 'second_factor_code_invalid'),
      );
      await t.tap(find.byKey(const ValueKey('step-up-use-backup_code')));
      await t.pumpAndSettle();
      await answer(t, 'wrong-code');
      expect(_stored(), 'totp');
    });

    testWidgets('a remembered method the server does not list falls back to '
        'the first listed', (t) async {
      await _device({secondFactorLastMethodKey: 'backup_code'});
      await open(t, methods: const [SecondFactorMethod.totp]);
      expect(find.text('Authenticator code'), findsOneWidget);
      // An unknown stored value (a newer client's method) is ignored too.
      await _device({secondFactorLastMethodKey: 'something-new'});
      await t.pumpWidget(const SizedBox.shrink());
      await open(t);
      expect(find.text('Authenticator code'), findsOneWidget);
    });
  });

  group('sign-in second step', () {
    const token = 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789_-abcde';
    Map<String, dynamic> challenge() => {
      'secondFactorRequired': true,
      'challenge': token,
      'expiresAt': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .toIso8601String(),
      'methods': ['totp', 'backup_code'],
      'maskedEmail': 'p***@example.invalid',
    };
    const signedIn = {
      'accessToken': 'access',
      'refreshToken': 'refresh',
      'user': {'id': 'user-1', 'name': 'person', 'email': 'p@example.invalid'},
    };

    Future<ScriptedServer> signIn(WidgetTester t, {int verify = 200}) async {
      final server = ScriptedServer()
        ..answers['/auth/login'] = [(200, challenge())]
        ..answers['/auth/second-factor/verify'] = [
          verify == 200
              ? (200, signedIn)
              : (400, {'error': 'x', 'code': 'second_factor_code_invalid'}),
        ];
      RaftClient client(String origin) => RaftClient(
        origin: origin,
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = server,
      );
      final made = <RaftClient>[];
      addTearDown(() async {
        for (final c in made) {
          await c.dispose();
        }
      });
      Future<void> authenticate(
        String origin,
        Future<void> Function(RaftClient) action,
      ) async {
        final c = client(origin);
        made.add(c);
        await action(c);
      }

      t.view
        ..physicalSize = const Size(800, 1800)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
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
      await settle(t);
      await t.enterText(
        find.byKey(const Key('login-email')),
        'p@example.invalid',
      );
      await t.enterText(find.byKey(const Key('login-password')), 'password-1');
      await t.tap(find.byKey(const Key('login-submit')));
      await settle(t);
      expect(find.byKey(const Key('second-factor-sign-in')), findsOneWidget);
      return server;
    }

    Finder label(String text) => find.descendant(
      of: find.byKey(const Key('second-factor-sign-in')),
      matching: find.text(text),
    );

    testWidgets('starts on the first method on a device that never answered', (
      t,
    ) async {
      await _device();
      await signIn(t);
      expect(label('Authenticator code'), findsOneWidget);
    });

    testWidgets('starts on the backup code this device used last', (t) async {
      await _device({secondFactorLastMethodKey: 'backup_code'});
      await signIn(t);
      expect(label('Backup code'), findsOneWidget);
      expect(find.text('Use authenticator code'), findsOneWidget);
    });

    testWidgets('a backup code that signs in is remembered', (t) async {
      await _device();
      final server = await signIn(t);
      await t.tap(find.text('Use a backup code'));
      await t.pump();
      await t.enterText(
        find.descendant(
          of: find.byKey(const Key('second-factor-sign-in')),
          matching: find.byType(EditableText),
        ),
        'abcde-12345',
      );
      await t.pump();
      await t.tap(find.byKey(const Key('second-factor-verify')));
      await settle(t);
      expect(server.to('/auth/second-factor/verify'), hasLength(1));
      expect(_stored(), 'backup_code');
    });

    testWidgets('a refused code is not remembered', (t) async {
      await _device();
      await signIn(t, verify: 400);
      await t.tap(find.text('Use a backup code'));
      await t.pump();
      await t.enterText(
        find.descendant(
          of: find.byKey(const Key('second-factor-sign-in')),
          matching: find.byType(EditableText),
        ),
        'wrong-code',
      );
      await t.pump();
      await t.tap(find.byKey(const Key('second-factor-verify')));
      await settle(t);
      expect(_stored(), isNull);
    });
  });

  testWidgets('Turn off keeps Web order: the authenticator code first even '
      'after a backup code', (t) async {
    await _device({secondFactorLastMethodKey: 'backup_code'});
    final client = SecondFactorServerClient()
      ..enabled = true
      ..totp = true
      ..codesRemaining = 10;
    final w = WorkspaceController(client);
    addTearDown(() async {
      w.dispose();
      await client.dispose();
    });
    t.view
      ..physicalSize = const Size(900, 1600)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AccountSecuritySections(
              controller: w,
              passkeys: (s) => PasskeysSection(controller: w, settings: s),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('two-step-turn-off')));
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('second-factor-answer-totp')),
      findsOneWidget,
    );
  });
}

Future<void> settle(WidgetTester t, [int rounds = 6]) async {
  for (var i = 0; i < rounds; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pump(const Duration(milliseconds: 10));
  }
}
