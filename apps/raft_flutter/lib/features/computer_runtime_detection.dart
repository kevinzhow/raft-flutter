// Runtime detection state of one Computer (Web Machine.runtimeDetection,
// task #1268) and the rescan that recovers an incomplete detection. Product
// rules only; raft_ui draws the notice.
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

/// The daemon's runtime detection state as the server sends it. `pending` and
/// `incomplete` mean the runtime list is the last confirmed one (unconfirmed,
/// not unavailable); absent / null / `complete` leaves the page as it was.
RaftRuntimeDetection? computerRuntimeDetection(
  Map machine,
  String Function(String runtimeId) runtimeLabel,
) {
  final raw = machine['runtimeDetection'];
  if (raw is! Map) return null;
  final status = switch (raw['status']) {
    'pending' => RaftRuntimeDetectionStatus.pending,
    'incomplete' => RaftRuntimeDetectionStatus.incomplete,
    _ => null,
  };
  if (status == null) return null;
  final unfinished = raw['unfinishedRuntimes'];
  return RaftRuntimeDetection(
    status: status,
    unfinishedLabels: [
      if (unfinished is List)
        ...unfinished.whereType<String>().map(runtimeLabel),
    ],
    reason: switch (raw['reason']) {
      'deadline' => RaftRuntimeDetectionReason.deadline,
      'cancelled' => RaftRuntimeDetectionReason.cancelled,
      // Web: a missing reason reads as a failed detection process.
      _ => RaftRuntimeDetectionReason.childFailed,
    },
  );
}

/// The rescan route's own eligibility (servers.ts): the Computer's creator or
/// someone with the Edit Machines capability, never the broader "can manage".
bool canRescanComputerRuntimes(WorkspaceController w, Map machine) {
  final me = w.client.user?.id;
  final creator = machine['creator'];
  return w.can('editMachines') ||
      machine['computerAttachedByCurrentUser'] == true ||
      (me != null && creator is Map && creator['id'] == me);
}

/// `POST /servers/:id/machines/:id/runtimes/rescan`. The daemon answers by
/// re-emitting its capabilities, which land through the normal
/// `machine:capabilities` push. A refusal throws [RaftRuntimeRescanFailure]
/// (Web describeRescanError: 403 is its own message).
Future<void> rescanComputerRuntimes(
  WorkspaceController w,
  String machineId,
) async {
  final serverId = w.server?.id;
  if (serverId == null) return;
  try {
    await w.command(
      'POST',
      '/servers/$serverId/machines/$machineId/runtimes/rescan',
    );
  } catch (e) {
    if (e is RaftApiException && e.staleScope) return;
    throw RaftRuntimeRescanFailure(
      forbidden: e is RaftApiException && e.status == 403,
    );
  }
}

/// Machines that share one physical host get the same label
/// (`computer_host_identity_v0`; the server leaves the field out while the
/// flag is off). The Web page does not read it yet; the value rides on the row
/// for the grouping UI.
String? computerSameMachineGroup(Map machine) {
  final group = machine['sameMachineGroup'];
  return group is String && group.isNotEmpty ? group : null;
}
