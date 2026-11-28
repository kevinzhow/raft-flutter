import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/account_onboarding.dart';
import 'package:raft_flutter/features/verification_location.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'support/auth_harness.dart';

void main() {
  test('a verification without a target clears its link parameters', () {
    final location = Uri.parse(
      '/?verify=fixture-code&returnTo=//example.invalid',
    );
    expect(verificationLocationAfter(location, null), Uri(path: '/'));
  });

  testWidgets('a pasted verification email submits its token and return path', (
    tester,
  ) async {
    final harness = AuthHarness(tester);
    const user = {
      'id': 'person',
      'name': 'person',
      'displayName': 'Person',
      'email': 'person@example.invalid',
      'emailVerified': false,
    };
    const target = '/artifacts/example?revision=1';
    harness.server.answers.addAll({
      '/auth/login': [
        (
          200,
          {'accessToken': 'fixture', 'refreshToken': 'fixture', 'user': user},
        ),
      ],
      '/auth/verify-email': [
        (200, {'ok': true, 'returnTo': target}),
      ],
      '/auth/resend-verification': [
        (200, {'ok': true}),
      ],
      '/auth/me': [
        (200, {...user, 'emailVerified': true}),
      ],
    });
    final client = (await tester.runAsync(() async {
      final client = harness.client('https://example.invalid');
      await client.login('person@example.invalid', 'fixture');
      return client;
    }))!;
    addTearDown(client.dispose);
    final landings = <Uri?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: AccountOnboardingView(
          client: client,
          location: Uri.parse(target),
          onVerified: landings.add,
          onComplete: () async {},
          onSignOut: () async {},
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('verify-resend')));
    await harness.settle();
    expect(
      harness.server.to('/auth/resend-verification').map((call) => call.data),
      [
        {'returnTo': target},
      ],
    );
    await tester.tap(find.byKey(const Key('verify-manual-toggle')));
    await tester.pump();
    final link = Uri.https('example.invalid', '/', {
      'verify': 'fixture-code',
      'returnTo': '/settings',
    });
    await tester.enterText(
      find.byKey(const Key('verification-token')),
      link.toString(),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('verify-submit')));
    await harness.settle();
    final submitted = harness.server
        .to('/auth/verify-email')
        .map((call) => call.data)
        .toList();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(submitted, [
      {'token': 'fixture-code', 'returnTo': target},
    ]);
    expect(landings, [Uri.parse(target)]);
  });

  testWidgets('an opened verification link returns to its workspace', (
    tester,
  ) async {
    final fixture = RootFixture();
    final target = Uri.parse('/s/alpha/channel/ca?source=email#message');
    var verified = false;
    fixture.overrides['GET /auth/me'] = (_) => {
      'id': 'alice',
      'name': 'alice',
      'email': 'alice@example.invalid',
      'emailVerified': verified,
    };
    fixture.overrides['POST /auth/verify-email'] = (request) {
      expect(request.data, {
        'token': 'fixture-code',
        'returnTo': target.toString(),
      });
      verified = true;
      return {'ok': true, 'returnTo': target.toString()};
    };
    try {
      await fixture.mount(
        tester,
        'light',
        1280,
        uri: Uri(
          path: '/',
          queryParameters: {
            'verify': 'fixture-code',
            'returnTo': target.toString(),
          },
        ),
      );
      await fixture.flush(tester);
      expect(find.byType(AccountOnboardingView), findsNothing);
      expect(fixture.router(tester).currentConfiguration, target);
      expect(find.text('Accepted a'), findsOneWidget);
      expect(
        fixture.adapter.calls.where(
          (request) => request.path == '/auth/verify-email',
        ),
        hasLength(1),
      );
    } finally {
      await fixture.close(tester);
    }
  });
}
