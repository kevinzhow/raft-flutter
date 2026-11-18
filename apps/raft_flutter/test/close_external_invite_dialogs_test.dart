import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_joint_section_actions.dart';
import 'package:raft_flutter/features/external_invite_channel_dialog.dart';

import 'close_dialogs_test.dart'
    show anyX, openFromButton, registerNoScrimTests;
import 'support/close_registry_external_invites.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';
import 'support/joint_channel_fixture.dart' show fixture;

final _channel = RaftChannel({
  'id': 'project',
  'type': 'private',
  'name': 'project',
  'joined': true,
});

const _dialogIds = {
  'add-external-member-dialog',
  'joint-disconnect-dialog',
  'member-connect-dialog',
};

void main() {
  final surfaces = externalInviteCloseSurfaces
      .where((surface) => _dialogIds.contains(surface.id))
      .toList();
  final harness = <String, OpenSurface>{
    for (final id in _dialogIds)
      id: (tester, size) async {
        final (workspace, api) = (await tester.runAsync(fixture))!;
        addTearDown(workspace.dispose);
        api.routes['GET /channels/external-connect-servers'] = (_) => {
          'servers': [],
        };
        api.routes['GET /channels/project/connect-my-servers'] = (_) => {
          'servers': [],
        };
        await openFromButton(tester, size, (context) {
          switch (id) {
            case 'joint-disconnect-dialog':
              unawaited(
                confirmJointServerDisconnect(
                  context,
                  workspace,
                  _channel,
                  'other',
                  'Other',
                ),
              );
            case 'member-connect-dialog':
              unawaited(
                showJointConnectDialog(context, workspace, _channel, []),
              );
            default:
              unawaited(showExternalInviteDialog(context, workspace, _channel));
          }
        });
        final dialog = find.byKey(ValueKey(id));
        return SurfaceProbe(
          isOpen: () => dialog.evaluate().isNotEmpty,
          x: anyX,
          scrim: const Offset(6, 6),
        );
      },
  };
  registerCloseTests(surfaces, harness);
  registerNoScrimTests(surfaces, harness);
}
