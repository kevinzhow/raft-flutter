import 'dart:async';

import 'package:raft_flutter/features/computers_rack/rack_move_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'close_dialogs_test.dart' show inWorkspace, registerNoScrimTests;
import 'support/close_registry_dialogs.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';

/// The rack's Move to Another Computer dialog (Web RackMoveDialog ->
/// AgentMigrationDialog): Esc, the X, a press on the overlay and the system
/// back close it. It has its own file so the six `close_dialogs` parts keep
/// their deal.
void main() {
  final surfaces = [
    for (final surface in dialogSurfaces)
      if (surface.id == 'rack-move-dialog') surface,
  ];
  final harness = <String, OpenSurface>{
    'rack-move-dialog': (t, size) => inWorkspace(
      t,
      size,
      RaftFormDialog,
      (context, w) => unawaited(
        showRackMoveDialog(
          context,
          w,
          agent: const {'id': 'a1', 'name': 'cindy', 'machineId': 'm1'},
          targetId: 'm2',
        ),
      ),
    ),
  };
  registerCloseTests(surfaces, harness);
  registerNoScrimTests(surfaces, harness);
}
