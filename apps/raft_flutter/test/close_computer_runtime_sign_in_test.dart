import 'dart:async';

import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/runtime_auth.dart';
import 'package:raft_flutter/features/computer_runtime_pi_sign_in_dialog.dart';
import 'package:raft_flutter/features/computer_runtime_sign_in_dialog.dart';

import 'close_dialogs_test.dart' show inWorkspace, registerNoScrimTests;
import 'support/close_registry_dialogs.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';

/// The Computer's runtime sign-in dialogs (Web RuntimeSignInDialog,
/// PiSignInDialog): Esc, the X and the system back close them; a press on the
/// overlay and a drag down do not (`disablePointerDismissal`). Their own file
/// so the six `close_dialogs` parts keep their deal.
void main() {
  const ids = {'runtime-sign-in-dialog', 'runtime-pi-sign-in-dialog'};
  final surfaces = [
    for (final surface in dialogSurfaces)
      if (ids.contains(surface.id)) surface,
  ];
  RuntimeAuthClient client() => RuntimeAuthClient(
    get: (path) async => {'kind': 'listed', 'providers': []},
    post: (path, body) async => {'loginId': 'login-1'},
    events: StreamController<RaftEvent>.broadcast().stream,
  );
  final harness = <String, OpenSurface>{
    'runtime-sign-in-dialog': (t, size) => inWorkspace(
      t,
      size,
      ComputerRuntimeSignInView,
      (context, w) => unawaited(
        showComputerRuntimeSignInDialog(
          context,
          controller: w,
          client: client(),
          serverId: 's1',
          machineId: 'm1',
          runtimeId: 'claude',
          runtime: 'claude',
        ),
      ),
    ),
    'runtime-pi-sign-in-dialog': (t, size) => inWorkspace(
      t,
      size,
      ComputerRuntimePiSignInView,
      (context, w) => unawaited(
        showComputerRuntimePiSignInDialog(
          context,
          controller: w,
          client: client(),
          serverId: 's1',
          machineId: 'm1',
          runtimeId: 'pi',
          runtime: 'pi',
        ),
      ),
    ),
  };
  registerCloseTests(surfaces, harness);
  registerNoScrimTests(surfaces, harness);
}
