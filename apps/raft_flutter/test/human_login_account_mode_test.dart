import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/human_login.dart';
import 'package:raft_flutter/features/human_login_sheet.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/parity_harness.dart' show loadParityFonts;
import 'support/human_login_fake.dart';

void main() {
  setUpAll(loadParityFonts);

  final primary = find.byKey(const ValueKey('human-login-continue'));
  final serverPicker = find.byKey(const ValueKey('human-login-servers'));

  Future<void> open(
    WidgetTester tester,
    FakeHumanLoginApi api,
    ValueChanged<Uri?> onResult, {
    String serverHint = '',
    Size size = const Size(390, 844),
    TargetPlatform platform = TargetPlatform.linux,
    Future<bool> Function(Uri)? openExternal,
    bool settle = true,
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
                openExternal: openExternal,
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
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('slow lookup shows loading after one second', (tester) async {
    final pending = Completer<void>();
    final api = FakeHumanLoginApi(lookupGate: pending);
    await open(tester, api, (_) {}, settle: false);

    final skeleton = find.byKey(const ValueKey('human-login-lookup-skeleton'));
    await tester.pump(const Duration(milliseconds: 999));
    expect(tester.widget<Opacity>(skeleton).opacity, 0);
    expect(primary, findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(tester.widget<Opacity>(skeleton).opacity, 1);
    expect(find.text('Loading…'), findsOneWidget);
    expect(primary, findsNothing);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Loading…'), findsNothing);
    expect(primary, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('human-login-cancel')));
    await tester.pumpAndSettle();
  });

  testWidgets('opening the app homepage keeps the consent open', (
    tester,
  ) async {
    final api = FakeHumanLoginApi(
      client: {...FakeHumanLoginApi.app(), 'loginMode': 'account'},
    );
    final opened = <Uri>[];
    await open(
      tester,
      api,
      (_) => fail('Opening the homepage must not close consent'),
      openExternal: (location) async {
        opened.add(location);
        return true;
      },
    );
    final homepage = find.byKey(const ValueKey('human-login-app-homepage'));
    await tester.ensureVisible(homepage);
    await tester.tap(homepage);
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse('https://example.com')]);
    expect(primary, findsOneWidget);
    expect(api.installs, isEmpty);
    expect(api.authorizations, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('desktop account consent uses the Web card content width', (
    tester,
  ) async {
    final api = FakeHumanLoginApi(
      client: {...FakeHumanLoginApi.app(), 'loginMode': 'account'},
    );
    await open(tester, api, (_) {}, size: const Size(1280, 900));

    final consent = find.byKey(const ValueKey('human-login-content'));
    expect(tester.getSize(consent).width, 550);
    expect(
      find.ancestor(of: consent, matching: find.byType(RaftDialog)),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('human-login-cancel')));
    await tester.pumpAndSettle();
  });

  testWidgets('phone account consent uses the inset Web card body in a sheet', (
    tester,
  ) async {
    final api = FakeHumanLoginApi(
      client: {...FakeHumanLoginApi.app(), 'loginMode': 'account'},
    );
    await open(tester, api, (_) {}, platform: TargetPlatform.android);

    final consent = find.byKey(const ValueKey('human-login-content'));
    expect(tester.getSize(consent).width, 324);
    expect(
      find.ancestor(of: consent, matching: find.byType(RaftFormSheet)),
      findsOneWidget,
    );
    expect(primary.hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('human-login-cancel')));
    await tester.pumpAndSettle();
  });

  testWidgets('account consent spaces the scopes below the app details', (
    tester,
  ) async {
    final api = FakeHumanLoginApi(
      client: {...FakeHumanLoginApi.app(), 'loginMode': 'account'},
    );
    await open(tester, api, (_) {}, size: const Size(1280, 900));

    final explanation = find.text(
      'The app you are continuing to with Login with Raft.',
    );
    final description = find.text(
      "Sign in to Artifact Share with your Raft account. The app learns who you are. What it can see on each Server is decided by that Server's owners and admins.",
    );
    final signedInAs = find.text('Signed in as person@example.com');
    final scopes = find.byKey(const ValueKey('human-login-scopes'));
    final descriptionStyle = tester.widget<Text>(description).style!;
    expect(descriptionStyle.height! * descriptionStyle.fontSize!, 22);
    Rect lineBox(Finder text) => tester.getRect(
      find.ancestor(of: text, matching: find.byType(RaftCssText)).first,
    );
    expect(lineBox(signedInAs).top - lineBox(description).bottom, 8);
    final gap = tester.getTopLeft(scopes).dy - lineBox(explanation).bottom;
    expect(gap, 20);

    await tester.tap(find.byKey(const ValueKey('human-login-cancel')));
    await tester.pumpAndSettle();
  });

  for (final (size, platform) in [
    (const Size(390, 844), TargetPlatform.linux),
    (const Size(390, 844), TargetPlatform.android),
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
  ]) {
    testWidgets(
      'authorizes account mode without a server at $size on $platform',
      (tester) async {
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
        expect(find.text('Artifact Share'), findsNWidgets(2));
        expect(
          find.text('The app you are continuing to with Login with Raft.'),
          findsOneWidget,
        );
        final identityScope = find.descendant(
          of: find.byKey(const ValueKey('human-login-scopes')),
          matching: find.text('openid'),
        );
        expect(identityScope, findsNothing);
        final identityDisclosure = find.byKey(
          const ValueKey('human-login-identity-disclosure'),
        );
        if (size.width == 390) {
          final disclosure = find.ancestor(
            of: identityDisclosure,
            matching: find.byType(RaftDisclosureCard),
          );
          expect(tester.getSize(disclosure).height, 58);
        }
        if (identityDisclosure.hitTestable().evaluate().isEmpty) {
          final scroller = find
              .ancestor(
                of: identityDisclosure,
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.drag(scroller, const Offset(0, -280));
          await tester.pumpAndSettle();
        }
        expect(identityDisclosure.hitTestable(), findsOneWidget);
        await tester.tap(identityDisclosure);
        await tester.pumpAndSettle();
        expect(identityScope, findsOneWidget);
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
      },
    );
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
