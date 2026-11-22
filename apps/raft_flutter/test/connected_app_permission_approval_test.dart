import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/app_install_expectation.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/connected_app_consent.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/screens/screen_fixture.dart';

const _permissions =
    '/integrations/marketplace/app-1/install/app-notifications';

class _PermissionClient extends ScreenFixtureClient {
  _PermissionClient(super.route)
    : super(user: const {'id': 'owner'}, server: 'server');

  final approvals = <Object?>[];

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
  }) {
    if (method == 'PUT' && path == '$_permissions/grant') approvals.add(data);
    return super.request(method, path, data: data, query: query);
  }
}

void main() {
  testWidgets('permission names use the full row on a narrow review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 306,
              child: ConnectedAppPermissionSet(
                permissions: AppInstallExpectation(
                  scopes: ['openid', 'profile', 'agent:read'],
                  groups: ['server'],
                ),
                newScopes: ['agent:read'],
                newGroups: ['server'],
              ),
            ),
          ),
        ),
      ),
    );
    final label = tester.getTopLeft(find.text('Login scopes'));
    final scopeName = find.text('openid', findRichText: true);
    final scope = tester.getTopLeft(scopeName);
    expect(scope.dx, label.dx + RaftSpace.x1);
    expect(scope.dy, greaterThan(label.dy));
    expect(tester.widget<RichText>(scopeName).text.style?.fontSize, 12.25);
  });

  testWidgets('permission code keeps the desktop callout line box', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: const Scaffold(
          body: ConnectedAppPermissionSet(
            permissions: AppInstallExpectation(scopes: ['openid'], groups: []),
          ),
        ),
      ),
    );
    final scope = find.text('openid', findRichText: true);
    final paintedLabel = find.ancestor(
      of: scope,
      matching: find.byType(RaftRecipeBox),
    );
    final height = tester.getSize(paintedLabel).height;
    await tester.pumpWidget(const SizedBox.shrink());
    expect(height, 24);
  });

  testWidgets(
    'approving records the displayed scope, group and text revision',
    (tester) async {
      var approved = false;
      var listingReads = 0;
      final client = _PermissionClient((method, path, _) {
        if (path == '/feature-flags/evaluate') {
          return {
            'evaluations': [
              {'key': 'app_prompt_text_consent', 'enabled': true},
            ],
          };
        }
        if (path == '/integrations/marketplace') {
          return [
            {
              'id': 'app-1',
              'clientId': 'garden',
              'name': 'Garden',
              'installedAt': '2026-11-01T00:00:00Z',
              'permissionApprovalRequired': !approved,
            },
          ];
        }
        if (path == '/integrations/marketplace/listings') {
          listingReads++;
          return {'items': [], 'total': 0};
        }
        if (path == '$_permissions/grant') {
          approved = true;
          return {
            'approved_groups': ['server', 'computer'],
          };
        }
        if (path == _permissions) {
          return {
            'approval_required': !approved,
            'requested_scopes': ['openid', 'agent:read'],
            'new_scopes': approved ? [] : ['agent:read'],
            'requested_groups': ['server', 'computer'],
            'approved_groups': ['server', if (approved) 'computer'],
            'prompt_text': {
              'confirmation_required': !approved,
              'current': {
                'id': 'garden-revision',
                'name': 'Garden',
                'when_to_use': 'Answer questions about the greenhouse.',
              },
            },
          };
        }
        return const <Object>[];
      });
      final workspace = WorkspaceController(client)
        ..server = RaftRecord({'id': 'server', 'role': 'owner'});
      addTearDown(workspace.dispose);
      addTearDown(client.dispose);
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: TargetPlatform.linux),
          home: Scaffold(body: IntegrationsView(controller: workspace)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('connected-apps-tab-marketplace')),
      );
      await tester.pumpAndSettle();
      expect(listingReads, 1);
      await tester.tap(find.text('View updates'));
      await tester.pumpAndSettle();

      expect(listingReads, 1);
      expect(
        find.text('Approving the update approves all of this:'),
        findsOneWidget,
      );
      expect(
        find.text('Approve Update also confirms this text.'),
        findsOneWidget,
      );
      expect(find.text('Login scopes'), findsOneWidget);
      expect(find.text('New in this update'), findsNWidgets(2));
      final newBadges = tester.widgetList<RaftBadge>(
        find.ancestor(
          of: find.text('New in this update'),
          matching: find.byType(RaftBadge),
        ),
      );
      expect(newBadges.map((badge) => badge.appearance), [
        RaftBadgeRecipeAppearance.outline,
        RaftBadgeRecipeAppearance.outline,
      ]);
      expect(
        tester.getTopLeft(find.text('App permissions')).dy,
        lessThan(tester.getTopLeft(find.text('Login with Raft access')).dy),
      );
      expect(
        find.textContaining('Answer questions about the greenhouse.'),
        findsOneWidget,
      );
      final approve = find.text('Approve update');
      final banner = tester.widget<RaftBanner>(
        find.ancestor(of: approve, matching: find.byType(RaftBanner)).first,
      );
      expect(banner.action, isA<RaftButton>());
      await tester.ensureVisible(approve);
      await tester.pumpAndSettle();
      await tester.tap(approve);
      await tester.pumpAndSettle();
      expect(client.approvals, [
        {
          'expected_scopes': ['openid', 'agent:read'],
          'expected_groups': ['server', 'computer'],
          'expected_text_revision_id': 'garden-revision',
        },
      ]);
      expect(approve, findsNothing);
      expect(
        find.text('Approve Update also confirms this text.'),
        findsNothing,
      );
      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Garden'));
      await tester.pumpAndSettle();
      expect(approve, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
