import 'dart:async';

import 'package:raft_flutter/features/computer_runtime_claude_limit_resets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'close_dialogs_test.dart' show inWorkspace, registerNoScrimTests;
import 'support/close_registry_dialogs.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';
import 'support/runtime_auth_fixture.dart';

/// The Claude limit-reset dialogs (Web ClaudeLimitResetsDialog and its
/// confirm): Esc, the X and the system back close them; a press on the
/// overlay does not. They have their own file so the six `close_dialogs`
/// parts keep their deal.
void main() {
  const ids = {
    'claude-limit-resets-dialog',
    'claude-limit-reset-confirm-dialog',
  };
  final surfaces = [
    for (final surface in dialogSurfaces)
      if (ids.contains(surface.id)) surface,
  ];
  final api = FakeComputerApi();
  final harness = <String, OpenSurface>{
    'claude-limit-resets-dialog': (t, size) => inWorkspace(
      t,
      size,
      RaftDialog,
      (context, w) => unawaited(
        showComputerClaudeLimitResetsDialog(
          context,
          client: api.auth,
          serverId: 's1',
          machineId: 'm1',
          atFiveHourLimit: true,
          canUse: true,
          canConsent: true,
          onLegacy: (_) {},
          onNotSupported: () {},
          onUse: (_, _) async => false,
        ),
      ),
    ),
    'claude-limit-reset-confirm-dialog': (t, size) => inWorkspace(
      t,
      size,
      RaftConfirmDialog,
      (context, w) => unawaited(
        showComputerClaudeLimitResetConfirmDialog(
          context,
          client: api.auth,
          serverId: 's1',
          machineId: 'm1',
          kind: 'five_hour',
          account: 'ali****@example.com',
          atFiveHourLimit: true,
          idempotencyKey: 'attempt-key-0123456789',
          onOutcome: (_) {},
        ),
      ),
    ),
  };
  registerCloseTests(surfaces, harness);
  registerNoScrimTests(surfaces, harness);
}
