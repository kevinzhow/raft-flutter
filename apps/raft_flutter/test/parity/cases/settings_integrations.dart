// Official case owned by this file (v1.21.12 sharedCases.json, baseline
// pending):
//   components.settings.integrations.permission-review
//
// Settings > Applications on the 390x844 phone viewport: the Slack Bridge
// listing carries a pending outbound-permission revision, so its app detail
// shows the "Permission update pending review" badge, the requested data
// groups / events and the reviewer-only "Approve update" action. Data mirrors
// react-provider.spec.ts (marketplace: Slack Bridge + installed GitHub
// Issues; clients: server-local Slack Bridge; overview empty).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/features/workspace_settings.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parity_harness.dart';
import 'members_settings/fixture_client.dart';

final Map<String, ParityCase> settingsIntegrationsCases = {
  'components.settings.integrations.permission-review': ParityCase(
    widgets: [
      'raft_flutter:WorkspaceSettings',
      'raft_flutter:IntegrationsView',
      'raft_ui:RaftConnectedAppDetailCard',
      'raft_ui:RaftAppPermissionsSummary',
      'raft_ui:RaftAppPermissionsApproval',
    ],
    notes:
        'Marketplace app detail of Slack Bridge opened by tapping its card, '
        'with appNotificationReviewPending and the pending groups/events the '
        'React spec serves; the fixture owner is a marketplace reviewer '
        '(canReviewAppNotifications).',
    settle: const Duration(milliseconds: 600),
    build: (ctx) {
      SharedPreferences.setMockInitialValues({});
      final fixture = MsFixture(ctx);
      final created = fixture.times['entityCreatedAtIso'];
      Map<String, dynamic> listing(
        String id,
        String clientId,
        String name,
        String description,
        String category, {
        String? installedAt,
        Map<String, dynamic> extra = const {},
      }) => {
        'id': id,
        'serverId': fixture.server['id'],
        'clientId': clientId,
        'appType': 'third_party_global',
        'publishStatus': 'published',
        'category': category,
        'name': name,
        'description': description,
        'homepageUrl':
            'https://example.com/${name.split(' ').first.toLowerCase()}',
        'returnUrl': null,
        'agentManifestUrl': null,
        'allowedScopes': <String>[],
        'logoUrl': null,
        'humanMarketplaceVisible': true,
        'createdByUserId': fixture.owner['id'],
        'createdAt': created,
        'updatedAt': created,
        'installedAt': installedAt,
        'publisherName': 'Raft Labs',
        'privateShared': false,
        ...extra,
      };
      final (w, _) = fixture.workspace({
        'GET /integrations/marketplace': (_) => [
          listing(
            'market_slack',
            'client_slack_bridge',
            'Slack Bridge',
            'Mirror Slock activity into Slack channels.',
            'Productivity & Collaboration',
            extra: {
              'dataAccessSummary': 'Messages and channel metadata',
              'appNotificationGroups': ['server'],
              'appNotificationEvents': ['server.plan_changed'],
              'appNotificationReviewPending': true,
              'appNotificationPendingRevisionId':
                  '00000000-0000-4000-8000-000000000001',
              'appNotificationPendingGroups': ['server', 'agent'],
              'appNotificationPendingEvents': ['server.plan_changed'],
              'canReviewAppNotifications': true,
            },
          ),
          listing(
            'market_github',
            'client_github_issues',
            'GitHub Issues',
            'Create issues from tasks and feedback.',
            'Development',
            installedAt: created as String?,
          ),
        ],
        'GET /integrations/clients': (_) => [
          {
            ...listing(
              'client_1',
              'client_slack_bridge',
              'Slack Bridge',
              'Server-local OAuth client.',
              'Productivity & Collaboration',
            ),
            'appType': 'server_local',
            'publishStatus': 'private',
            'returnUrl': 'https://example.com/oauth/callback',
          },
        ],
        'GET /integrations/overview': (_) => <dynamic>[],
      });
      return Scaffold(
        body: WorkspaceSettings(
          controller: w,
          appearance: const RaftAppearance(mode: ThemeMode.light),
          onAppearance: (_) {},
          presentation: PersonalPresentationStore(),
          notifications: NativeNotificationService(
            platform: TargetPlatform.android,
          ),
          onLogout: () async {},
          initialTab: 'integrations',
          mobileRoot: false,
        ),
      );
    },
    interact: (t, ctx) async {
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byKey(const ValueKey('connected-app-market_slack')));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('PERMISSION UPDATE PENDING REVIEW'), findsOneWidget);
      expect(find.text('Approve update'), findsOneWidget);
    },
  ),
};

final Map<String, ParityUncovered> settingsIntegrationsUncovered = {};
