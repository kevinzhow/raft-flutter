import 'dart:async';

import 'package:raft_flutter/features/computer_runtime_limit_reset_dialog.dart';
import 'package:raft_flutter/features/computer_runtime_provider_connect_dialog.dart';
import 'package:raft_flutter/features/computer_runtime_sign_out_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'close_dialogs_test.dart' show inWorkspace, registerNoScrimTests;
import 'support/close_registry_dialogs.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';
import 'support/runtime_auth_fixture.dart';

/// The Computer runtime dialogs (Web RuntimeSignOutDialog,
/// RuntimeLimitResetDialog, RuntimeProviderConnectDialog): Esc, the X and the
/// system back close them; a press on the overlay does not. They have their
/// own file so the six `close_dialogs` parts keep their deal.
void main() {
  const ids = {
    'runtime-sign-out-dialog',
    'runtime-limit-reset-dialog',
    'runtime-provider-connect-dialog',
  };
  final surfaces = [
    for (final surface in dialogSurfaces)
      if (ids.contains(surface.id)) surface,
  ];
  final api = FakeComputerApi()
    ..answers['GET /qwen/providers'] = (_) => {
      'kind': 'listed',
      'providers': <Object>[],
    };
  final harness = <String, OpenSurface>{
    'runtime-sign-out-dialog': (t, size) => inWorkspace(
      t,
      size,
      RaftConfirmDialog,
      (context, w) => unawaited(
        showComputerRuntimeSignOutDialog(
          context,
          controller: w,
          client: api.auth,
          serverId: 's1',
          machineId: 'm1',
          runtimeId: 'claude',
          runtime: 'claude',
        ),
      ),
    ),
    'runtime-limit-reset-dialog': (t, size) => inWorkspace(
      t,
      size,
      RaftConfirmDialog,
      (context, w) => unawaited(
        showComputerRuntimeLimitResetDialog(
          context,
          client: api.auth,
          serverId: 's1',
          machineId: 'm1',
          runtimeId: 'codex',
          provider: 'codex',
          account: 'ali****@example.com',
          resetsAvailable: 2,
          idempotencyKey: 'attempt-key-0123456789',
          onOutcome: (_) {},
        ),
      ),
    ),
    'runtime-provider-connect-dialog': (t, size) => inWorkspace(
      t,
      size,
      RuntimeProviderConnectForm,
      (context, w) => unawaited(
        showComputerRuntimeProviderConnectDialog(
          context,
          controller: w,
          client: api.auth,
          serverId: 's1',
          machineId: 'm1',
          runtimeId: 'qwen',
          runtime: 'qwen',
        ),
      ),
    ),
  };
  registerCloseTests(surfaces, harness);
  registerNoScrimTests(surfaces, harness);
}
