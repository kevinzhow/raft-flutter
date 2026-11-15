// Web features/computer/RackMoveDialog.tsx + ComputersRackList.tsx drag rules:
// an agent slot dragged onto another online computer's row or card opens the
// Move to Another Computer dialog for that one agent with the computer
// preselected. A started move opens the agent's profile, where its progress
// shows.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/migration_error.dart';
import '../../data/raft_location.dart' show RaftProfileKind;
import '../../data/user_error.dart' show logUserError;
import '../../data/workspace_controller.dart';
import '../../data/workspace_entity_directory.dart';
import '../agent_migration_presentation.dart';
import '../agent_migration_start_dialog.dart';
import '../billing_view.dart' show RaftBillingPlans;

/// A computer can take a dragged agent: another, online, managed Computer.
bool isRackDropTarget(Map machine, Map? agent) =>
    agent != null &&
    agent['machineId'] != machine['id'] &&
    machine['isComputer'] == true &&
    machine['status'] == 'online';

/// Who may move an agent is who may manage it; a move needs its computer
/// online, and a cloud or external agent has none.
bool canDragRackAgent(
  WorkspaceController w,
  Map agent,
  Map<String, Map<String, dynamic>> machineById,
) {
  final machineId = agent['machineId'];
  if (machineId is! String || agent['deletedAt'] != null) return false;
  if (agent['external'] == true || agent['runtime'] == 'external') {
    return false;
  }
  if (machineById[machineId]?['status'] != 'online') return false;
  if (w.can('editAgents')) return true;
  final me = w.client.user?.id;
  return me != null &&
      agent['creatorType'] == 'user' &&
      agent['creatorId'] == me;
}

/// A drop: the upgrade prompt on a plan that cannot move agents, else the move
/// dialog with [targetId] preselected.
Future<void> showRackMoveDialog(
  BuildContext context,
  WorkspaceController w, {
  required Map<String, dynamic> agent,
  required String targetId,
}) async {
  Map<String, dynamic>? billing;
  try {
    final value = await w.query('/billing/subscription');
    if (value is Map) billing = Map<String, dynamic>.from(value);
  } catch (_) {
    // A failed read leaves the gate undecided, as on the agent's profile.
  }
  if (!context.mounted) return;
  if (agentMigrationRequiresUpgrade(
    billing?['plan'],
    trialActive: RaftBillingPlans.trialActive(DateTime.now().toUtc()),
  )) {
    final viewPlans = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        title: raftText(context, 'Upgrade to Pro to migrate agents'),
        message: raftText(
          context,
          'After upgrading, you can migrate an agent and its workspace to another computer.',
        ),
        confirmLabel: raftText(context, 'Upgrade to Pro'),
        confirmVariant: RaftButtonRecipeVariant.accent,
        maxWidth: 448,
      ),
    );
    if (viewPlans == true) w.setSection('billing');
    return;
  }
  final computers = w.services.entityDirectory.rows(
    WorkspaceEntityKind.computers,
  );
  String? name(Object? id) =>
      computers.where((m) => m['id'] == id).firstOrNull?['name'] as String?;
  final targets = [
    for (final m in computers)
      if (m['isComputer'] == true && m['id'] != agent['machineId']) m,
  ];
  var proRequired = false;
  final agentId = '${agent['id']}';
  var started = false;
  await showRaftDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => AgentMigrationStartDialog(
      targets: targets,
      initialTarget: targetId,
      controller: w,
      sourceName: name(agent['machineId']),
      openComputers: (_) {},
      start: (target) async {
        try {
          await w.command(
            'POST',
            '/agents/$agentId/migrate',
            data: {'targetComputer': target},
          );
          started = true;
        } catch (e) {
          if (isMigrationProPlanRequiredError(e)) {
            proRequired = true;
            return;
          }
          if (e is RaftApiException && const [401, 403].contains(e.status)) {
            rethrow;
          }
          logUserError(e, where: 'agent migration start');
          throw AgentMigrationStartFailure(
            migrationStartErrorPresentation(
              e,
              MigrationComputers(
                sourceName: name(agent['machineId']),
                targetName: name(target),
                sourceId: agent['machineId'] as String?,
                targetId: target,
              ),
            ),
          );
        }
      },
    ),
  );
  if (proRequired && context.mounted) {
    w.setSection('billing');
    return;
  }
  // A started move opens the agent's profile, where its progress shows.
  if (started) w.openProfile(RaftProfileKind.agent, agentId);
}
