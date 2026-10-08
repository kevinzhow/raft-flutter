import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/account_onboarding.dart';

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
      await tester.enterText(
        find.byKey(const Key('login-origin')),
        'https://user:secret@example.invalid',
      );
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();
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
    await tester.tap(find.text('Create account'));
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
    expect(registered, 0);
    expect(
      find.text('Accept the terms and privacy policy to create an account.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const Key('register-legal')));
    await tester.tap(find.byKey(const Key('register-legal')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(registered, 1);
  });
}
