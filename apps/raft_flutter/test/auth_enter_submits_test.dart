// Web v1.24.0 LoginPage.tsx:187, RegisterPage.tsx:125,
// ForgotPasswordPage.tsx:90 and ResetPasswordPage.tsx:100 are `<form
// onSubmit>`: Enter in any field submits, unless the submit button is
// disabled (RegisterPage before the terms are accepted), and then nothing
// happens.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/platform/local_network_access.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/auth_harness.dart';

void main() {
  late ScriptedServer server;
  late List<String> logins, registers;
  setUp(() {
    server = ScriptedServer();
    logins = [];
    registers = [];
  });

  Future<void> mount(
    WidgetTester t, {
    String mode = 'login',
    String? resetToken,
  }) async {
    t.view
      ..physicalSize = const Size(800, 1800)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        // No DNS in a test: the fixture server is not on the local network.
        builder: (context, child) => AppServicesScope(
          services: AppServices.updatesDisabledForTestOrPreview(
            localNetwork: LocalNetworkAccess(lookup: (_) async => []),
          ),
          child: child!,
        ),
        home: AuthView(
          origin: 'https://example.invalid',
          initialMode: mode,
          resetToken: resetToken,
          onLogin: (b, e, p) async => logins.add('$e:$p'),
          onRegister: (b, e, p, a) async => registers.add('$e:$p:$a'),
          // AuthView disposes each anonymous client after its call.
          anonymousClientFactory: (origin) => RaftClient(
            origin: origin,
            sessionStore: MemorySessionStore(),
            transport: Dio()..httpClientAdapter = server,
          ),
        ),
      ),
    );
    await settle(t);
  }

  Future<void> enterIn(WidgetTester t, String key) async {
    await t.showKeyboard(find.byKey(Key(key)));
    await t.testTextInput.receiveAction(TextInputAction.done);
    await settle(t);
  }

  testWidgets('login: Enter in Email signs in', (t) async {
    await mount(t);
    await t.enterText(
      find.byKey(const Key('login-email')),
      'p@example.invalid',
    );
    await t.enterText(find.byKey(const Key('login-password')), 'password-1');
    await enterIn(t, 'login-email');
    expect(logins, ['p@example.invalid:password-1']);
  });

  testWidgets('login: Enter in an empty-password form shows the error, as '
      'the button does', (t) async {
    await mount(t);
    await t.enterText(
      find.byKey(const Key('login-email')),
      'p@example.invalid',
    );
    await enterIn(t, 'login-email');
    expect(logins, isEmpty);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('forgot password: Enter in Email sends the reset link', (
    t,
  ) async {
    await mount(t, mode: 'forgot');
    await t.enterText(
      find.byKey(const Key('login-email')),
      'p@example.invalid',
    );
    await enterIn(t, 'login-email');
    expect(server.to('/auth/forgot-password').single.data, {
      'email': 'p@example.invalid',
    });
  });

  testWidgets('reset: Enter in the code and in New password sets it', (
    t,
  ) async {
    await mount(t, mode: 'reset');
    await t.enterText(find.byKey(const Key('reset-token')), 'reset-code-1');
    await t.enterText(find.byKey(const Key('reset-password')), 'new-pass-12');
    await t.enterText(find.byKey(const Key('reset-confirm')), 'new-pass-12');
    await enterIn(t, 'reset-token');
    expect(server.to('/auth/reset-password'), hasLength(1));

    // A reset opened from the email link has no code field.
    await t.pumpWidget(const SizedBox.shrink());
    await mount(t, mode: 'reset', resetToken: 'link-token');
    await t.enterText(find.byKey(const Key('reset-password')), 'new-pass-12');
    await t.enterText(find.byKey(const Key('reset-confirm')), 'new-pass-12');
    await enterIn(t, 'reset-password');
    expect(server.to('/auth/reset-password'), hasLength(2));
    expect(server.to('/auth/reset-password').last.data, {
      'token': 'link-token',
      'password': 'new-pass-12',
    });
  });

  testWidgets('register: Enter does nothing until the terms are accepted', (
    t,
  ) async {
    await mount(t, mode: 'register');
    await t.enterText(
      find.byKey(const Key('login-email')),
      'p@example.invalid',
    );
    await t.enterText(find.byKey(const Key('login-password')), 'password-12');
    await enterIn(t, 'login-password');
    await enterIn(t, 'login-email');
    expect(registers, isEmpty);
    expect(
      find.textContaining('You must agree to the Terms of Service'),
      findsNothing,
    );
    await t.ensureVisible(find.byKey(const Key('register-legal')));
    await t.tap(find.byKey(const Key('register-legal')));
    await settle(t);
    await enterIn(t, 'login-email');
    expect(registers, ['p@example.invalid:password-12:true']);
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
