import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/human_login.dart';
import 'package:raft_flutter/features/human_login_sheet.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/human_login_fake.dart';

void main() {
  final primary = find.byKey(const ValueKey('human-login-continue'));
  final serverPicker = find.byKey(const ValueKey('human-login-servers'));

  Future<void> open(
    WidgetTester tester,
    FakeHumanLoginApi api,
    ValueChanged<Uri?> onResult, {
    String serverHint = '',
    Size size = const Size(390, 844),
    TargetPlatform platform = TargetPlatform.linux,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: platform),
        home: Builder(
          builder: (context) => RaftButton(
            label: 'Open sign-in',
            onPressed: () async => onResult(
              await showHumanLoginSheet(
                context,
                api: api,
                request: HumanLoginRequest(
                  clientId: 'artifact-share',
                  returnUrl: 'https://artifacts.example.com/auth/callback',
                  scopes: const ['openid', 'profile'],
                  state: 'request-state',
                  serverHint: serverHint,
                  oidc: true,
                  nonce: 'request-nonce',
                  codeChallenge: 'request-challenge',
                  codeChallengeMethod: 'S256',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open sign-in'));
    await tester.pumpAndSettle();
  }

  for (final (size, platform) in [
    (const Size(390, 844), TargetPlatform.linux),
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
  ]) {
    testWidgets('authorizes account mode without a server at $size', (
      tester,
    ) async {
      final api = FakeHumanLoginApi(
        client: {...FakeHumanLoginApi.app(), 'loginMode': 'account'},
      );
      Uri? result;
      await open(
        tester,
        api,
        (location) => result = location,
        size: size,
        platform: platform,
      );

      expect(
        find.text('Artifact Share wants to use your Raft account'),
        findsOneWidget,
      );
      expect(serverPicker, findsNothing);
      expect(api.authorizations, isEmpty);

      await tester.ensureVisible(primary);
      await tester.tap(primary);
      await tester.pumpAndSettle();

      expect(api.authorizations, [
        {
          'clientId': 'artifact-share',
          'returnUrl': 'https://artifacts.example.com/auth/callback',
          'scopes': ['openid', 'profile'],
          'oidc': true,
          'nonce': 'request-nonce',
          'codeChallenge': 'request-challenge',
          'codeChallengeMethod': 'S256',
        },
      ]);
      expect(result?.queryParameters, {
        'code': 'issued-code-1',
        'state': 'request-state',
      });
      expect(primary, findsNothing);
    });
  }

  testWidgets(
    'refuses a server issuer for an account app before authorization',
    (tester) async {
      final api = FakeHumanLoginApi(
        client: {...FakeHumanLoginApi.app(), 'loginMode': 'account'},
      );
      await open(tester, api, (_) {}, serverHint: 'acme');

      expect(
        find.byKey(const ValueKey('human-login-account-refusal')),
        findsOneWidget,
      );
      expect(primary, findsNothing);
      expect(api.authorizations, isEmpty);
      await tester.tap(find.byKey(const ValueKey('human-login-cancel')));
      await tester.pumpAndSettle();
    },
  );
}
