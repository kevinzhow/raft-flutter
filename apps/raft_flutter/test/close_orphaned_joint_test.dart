import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/orphaned_joint_channels_section.dart';
import 'package:raft_ui/raft_ui.dart';

import 'close_dialogs_test.dart'
    show anyX, ignoreOverflow, registerNoScrimTests;
import 'parity/cases/screens/screen_fixture.dart';
import 'support/close_registry_orphaned_joint.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';

/// The Disconnect confirmation of an orphaned joint channel: the X, Escape and
/// the Android back gesture close it, a press on the scrim does not.
void main() {
  final harness = <String, OpenSurface>{
    'orphaned-joint-disconnect-confirm': (t, size) async {
      ignoreOverflow();
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final client = ScreenFixtureClient(
        (method, path, query) {
          if (path == '/channels/joint-connections') {
            return {
              'connections': [
                {
                  'channelId': 'j1',
                  'name': 'partner',
                  'role': 'participant',
                  'memberCount': 0,
                  'isMember': false,
                  'archived': false,
                  'servers': <dynamic>[],
                },
              ],
            };
          }
          if (path == '/feature-flags/evaluate') {
            return {'evaluations': <dynamic>[]};
          }
          return <String, dynamic>{};
        },
        user: {'id': 'alice'},
        server: 's',
      );
      final w = WorkspaceController(client)
        ..server = RaftRecord({
          'id': 's',
          'name': 'Moon',
          'slug': 'moon',
          'role': 'owner',
        });
      w.servers = [w.server!];
      addTearDown(w.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: OrphanedJointChannelsSection(controller: w),
            ),
          ),
        ),
      );
      await frames(t, 5);
      await t.tap(
        find.byKey(const ValueKey('orphaned-joint-channel-disconnect-j1')),
      );
      await frames(t, 25);
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const Key('orphaned-joint-channel-confirm-button'))
            .evaluate()
            .isNotEmpty,
        x: find.descendant(of: find.byType(RaftConfirmDialog), matching: anyX),
        scrim: const Offset(6, 6),
      );
    },
  };
  registerCloseTests(orphanedJointSurfaces, harness);
  registerNoScrimTests(orphanedJointSurfaces, harness);
}
