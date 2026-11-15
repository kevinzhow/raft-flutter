import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/create_external_agent_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'close_dialogs_test.dart'
    show anyX, openFromButton, registerNoScrimTests;
import 'support/close_registry_dialogs.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';
import 'support/external_agent_fixture.dart';

/// The create external agent dialog (Web `DialogCard`, no pointer dismissal):
/// the X, Escape and the Android back gesture close it, a press on the scrim
/// does not. Its own file so the close_dialogs parts keep their deal.
void main() {
  final surfaces = [
    for (final surface in dialogSurfaces)
      if (surface.id == 'create-external-agent' ||
          surface.id == 'external-credential-confirm')
        surface,
  ];
  final harness = <String, OpenSurface>{
    'external-credential-confirm': (t, size) async {
      await openFromButton(
        t,
        size,
        (context) => unawaited(
          RaftConfirmDialog.show(
            context,
            const RaftConfirmDialog(
              title: 'Revoke this credential?',
              message: "Whatever signed in as Nathan with it stops working right away. This can't be undone.",
              confirmLabel: 'Revoke',
              surfaceKey: ValueKey('external-agent-revoke'),
            ),
          ),
        ),
      );
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const ValueKey('external-agent-revoke'))
            .evaluate()
            .isNotEmpty,
        x: anyX,
        scrim: const Offset(6, 6),
      );
    },
    'create-external-agent': (t, size) async {
      final client = ExternalClient()..selectServer('s');
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
      addTearDown(() async {
        w.dispose();
        await client.stream.close();
      });
      await openFromButton(
        t,
        size,
        (context) => unawaited(showCreateExternalAgentDialog(context, w)),
      );
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const ValueKey('create-external-agent-dialog'))
            .evaluate()
            .isNotEmpty,
        x: anyX,
        scrim: const Offset(6, 6),
      );
    },
  };
  registerCloseTests(surfaces, harness);
  registerNoScrimTests(surfaces, harness);
}
