import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/account_onboarding.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/screens/screen_fixture.dart';

/// Account setup (Web AccountIdentitySetupPage, v1.24): the avatar is the way
/// to change it (pencil veil, Upload a photo; no Build an avatar yet, because
/// there is no current server) and a new account's built avatar is drawn.
void main() {
  Future<ScreenFixtureClient> open(WidgetTester t, {String? avatar}) async {
    final client = ScreenFixtureClient(
      (method, path, query) => <String, dynamic>{},
      user: {
        'id': 'u',
        'email': 'ada@example.invalid',
        'emailVerified': true,
        'avatarUrl': ?avatar,
      },
    );
    addTearDown(client.dispose);
    t.view
      ..physicalSize = const Size(900, 1400)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: AccountOnboardingView(
          client: client,
          onComplete: () async {},
          onSignOut: () async {},
        ),
      ),
    );
    await t.pumpAndSettle();
    return client;
  }

  testWidgets(
    'the avatar is the Upload a photo menu; the Upload button is gone',
    (t) async {
      await open(t, avatar: 'pixel-human:v1:sky.3.curly.brown.grin.cap.none');
      expect(find.byKey(const Key('identity-avatar-edit')), findsOneWidget);
      expect(find.text('Upload'), findsNothing);
      expect(find.byType(RaftHumanPixelAvatar), findsWidgets);
      await t.tap(find.byKey(const Key('identity-avatar-edit')));
      await t.pumpAndSettle();
      expect(find.text('Upload a photo'), findsOneWidget);
      expect(find.text('Build an avatar'), findsNothing);
    },
  );
}
