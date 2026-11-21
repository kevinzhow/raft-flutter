import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/human_login.dart';
import 'package:raft_flutter/features/human_login_sheet.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/human_login_fake.dart';

void main() {
  for (final consentOn in [true, false]) {
    testWidgets('reviews installation with prompt consent $consentOn', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = FakeHumanLoginApi(
        client: {
          ...FakeHumanLoginApi.app(installRequired: true, canInstall: true),
          'allowedScopes': ['openid', 'profile', 'agent:read'],
          'appNotificationGroups': ['computer'],
          'promptTextRevisionId': 'reviewed-text',
          'whenToUse': 'Summarize releases from attached artifacts.',
          'bot': {'handle': 'artifact-share-bot'},
        },
      )..promptTextConsentOn = consentOn;

      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: TargetPlatform.android),
          home: Builder(
            builder: (context) => RaftButton(
              label: 'Start',
              onPressed: () => showHumanLoginSheet(
                context,
                api: api,
                request: const HumanLoginRequest(
                  clientId: 'artifact-share',
                  returnUrl: 'https://artifacts.example.com/auth/callback',
                  state: '',
                  scopes: ['openid', 'profile'],
                  serverHint: '',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(find.text('Installing approves for this Server:'), findsOneWidget);
      expect(find.text('Login scopes'), findsOneWidget);
      expect(find.text('agent:read'), findsWidgets);
      expect(find.text('Data access'), findsOneWidget);
      expect(find.text('Computer · read'), findsOneWidget);
      expect(
        find.text('Text added to agent prompts'),
        consentOn ? findsOneWidget : findsNothing,
      );
      expect(
        find.textContaining(
          'Use it when: Summarize releases from attached artifacts.',
        ),
        consentOn ? findsOneWidget : findsNothing,
      );
      expect(api.installs, isEmpty);

      final bot = find.byKey(
        const ValueKey('connected-app-bot-install-checkbox'),
      );
      await tester.ensureVisible(bot);
      await tester.pumpAndSettle();
      await tester.tap(bot);
      await tester.pumpAndSettle();
      final install = find.byKey(const ValueKey('human-login-continue'));
      await tester.ensureVisible(install);
      await tester.tap(install);
      await tester.pumpAndSettle();

      expect(api.installs.single.body, {
        'expected_scopes': ['openid', 'profile', 'agent:read'],
        'expected_groups': ['computer'],
        if (consentOn) 'expected_text_revision_id': 'reviewed-text',
        'bot': false,
      });
      expect(api.authorizations.single['serverId'], 'srv-1');
      expect(install, findsNothing);
    });
  }
}
