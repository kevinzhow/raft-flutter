import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
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
  testWidgets(
    'approving records the displayed scope, group and text revision',
    (tester) async {
      var approved = false;
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
      await tester.tap(find.text('Garden'));
      await tester.pumpAndSettle();

      expect(find.text('Login scopes'), findsOneWidget);
      expect(find.text('New in this update'), findsNWidgets(2));
      expect(
        find.textContaining('Answer questions about the greenhouse.'),
        findsOneWidget,
      );
      final approve = find.text('Approve update');
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
      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Garden'));
      await tester.pumpAndSettle();
      expect(approve, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
