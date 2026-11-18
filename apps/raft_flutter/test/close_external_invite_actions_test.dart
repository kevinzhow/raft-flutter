import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/external_invite_api.dart';
import 'package:raft_flutter/features/channel_joint_section_actions.dart';
import 'package:raft_flutter/features/external_invite_channel_members.dart';
import 'package:raft_flutter/features/external_invite_page.dart';

import 'close_dialogs_test.dart'
    show anyX, openFromButton, registerNoScrimTests;
import 'support/close_registry_external_invites.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';
import 'support/joint_channel_fixture.dart' show fixture, host;

final _channel = RaftChannel({
  'id': 'project',
  'name': 'project',
  'type': 'private',
  'joined': true,
  'hasExternalRelation': true,
});

SurfaceProbe _dialog(String id) => SurfaceProbe(
  isOpen: () => find.byKey(ValueKey(id)).evaluate().isNotEmpty,
  x: anyX,
  scrim: const Offset(6, 6),
);

void main() {
  final harness = <String, OpenSurface>{
    'external-invite-cancel-dialog': (tester, size) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(
          ExternalInvitePage(
            api: ExternalInviteApi(
              (_, _, {data}) async => {
                'status': 'awaiting_approval',
                'channelName': 'project',
                'pendingRequest': {
                  'serverName': 'Other',
                  'approverName': 'Owner',
                },
              },
            ),
            token: 'fake-invite',
            account: 'fixture@example.invalid',
            onSignOut: () {},
            onClose: () {},
            onOpen: (_, _) async => true,
            onUpgrade: (_) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel request'));
      await tester.pumpAndSettle();
      return _dialog('external-invite-cancel-dialog');
    },
    'external-invite-withdraw-dialog': (tester, size) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final (workspace, api) = (await tester.runAsync(fixture))!;
      addTearDown(workspace.dispose);
      api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
      api.routes['GET /channels/project/external-invites'] = (_) => {
        'invites': [
          {'id': 'a', 'email': 'fixture@example.invalid'},
        ],
      };
      await tester.pumpWidget(
        host(ChannelExternalInvites(workspace: workspace, channel: _channel)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Withdraw invite'));
      await tester.pumpAndSettle();
      return _dialog('external-invite-withdraw-dialog');
    },
    'joint-connect-menu': (tester, size) async {
      final (workspace, _) = (await tester.runAsync(fixture))!;
      addTearDown(workspace.dispose);
      await openFromButton(tester, size, (_) {});
      await tester.pumpWidget(
        host(
          Center(
            child: JointConnectMenu(
              workspace: workspace,
              channel: _channel,
              rows: [],
            ),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('channel-settings-joint-servers-menu')),
      );
      await tester.pumpAndSettle();
      return SurfaceProbe(
        isOpen: () => find.text('Connect your servers').evaluate().isNotEmpty,
        scrim: const Offset(6, 6),
      );
    },
  };
  final surfaces = externalInviteCloseSurfaces
      .where((surface) => harness.containsKey(surface.id))
      .toList();
  registerCloseTests(surfaces, harness);
  registerNoScrimTests(surfaces, harness);
}
