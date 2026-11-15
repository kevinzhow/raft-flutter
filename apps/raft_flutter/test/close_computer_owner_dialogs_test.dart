import 'dart:async';

import 'package:raft_flutter/features/agent_owner_notify.dart';
import 'package:raft_flutter/features/computer_delete_dialog.dart';
import 'package:raft_flutter/features/computer_owner.dart';
import 'package:raft_ui/raft_ui.dart';

import 'close_dialogs_test.dart' show inWorkspace, registerNoScrimTests;
import 'support/close_registry_dialogs.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';

/// The Computer page's Transfer owner dialog and Delete Computer's other
/// people's agents list (Web TransferComputerOwnerDialog,
/// OthersAgentsOnComputerDialog): Esc, the X, a press on the overlay (the
/// transfer only) and the system back. They have their own file so the six
/// `close_dialogs` parts keep their deal.
void main() {
  const ids = {'transfer-computer-owner-dialog', 'computer-others-agents-dialog'};
  final surfaces = [
    for (final surface in dialogSurfaces)
      if (ids.contains(surface.id)) surface,
  ];
  final harness = <String, OpenSurface>{
    'transfer-computer-owner-dialog': (t, size) => inWorkspace(
      t,
      size,
      RaftFormDialog,
      (context, w) => unawaited(
        showTransferComputerOwnerDialog(context, w, const {
          'id': 'm1',
          'name': 'Studio Mac',
          'isComputer': true,
        }),
      ),
    ),
    'computer-others-agents-dialog': (t, size) => inWorkspace(
      t,
      size,
      RaftConfirmDialog,
      (context, w) => unawaited(
        showOthersAgentsDialog(
          context,
          agents: const [
            OthersAgent(
              id: 'a1',
              name: 'Zed',
              owner: (id: 'bob', name: 'Bob'),
            ),
          ],
          notifier: AgentOwnerNotifier(
            send: (ids) => postNotifyAgentOwners(
              (method, path, {data}) async => {},
              '/x',
              ids,
            ),
          ),
        ),
      ),
    ),
  };
  registerCloseTests(surfaces, harness);
  registerNoScrimTests(surfaces, harness);
}
