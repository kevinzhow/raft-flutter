import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'private_route_guard.dart';
import 'create_agent_dialog.dart';

/// Web CreateAgentDialog: computer, name, description, runtime and the
/// runtime's protocol-v2 fields in one dialog (zero computers shows the
/// "Connect a computer first" branch). A required computer never silently
/// falls back to a different computer.
Future<Map<String, dynamic>?> showManagedAgentForm(
  BuildContext context,
  WorkspaceController w, {
  String? initialName,
  String? initialDescription,
  String? suggestedComputer,
  String? requiredComputer,
  String? actionCardMessageId,
  int? actionCardConfirmationVersion,
  VoidCallback? onConnectComputer,
}) async {
  final authority = workspaceAuthority(w);
  bool current() =>
      context.mounted &&
      authority == workspaceAuthority(w) &&
      w.can('createAgents');
  if (!context.mounted || !current()) return null;
  final result = await w.query('/servers/${w.server!.id}/machines');
  if (!context.mounted || !current()) return null;
  // The endpoint answers `{machines: [...]}` or a bare array (Web accepts both).
  final rows = result is Map ? result['machines'] : result;
  final machines = [
    for (final m in (rows is List ? rows : const []).whereType<Map>())
      if (requiredComputer == null || m['id'] == requiredComputer)
        Map<String, dynamic>.from(m),
  ];
  Map<String, dynamic>? created;
  await showRaftAgentModal<bool>(
    context,
    builder: (_) => CreateAgentDialog(
      controller: w,
      machines: machines,
      initialMachineId: suggestedComputer,
      requiredMachineId: requiredComputer,
      initialName: initialName,
      initialDescription: initialDescription,
      actionCardMessageId: actionCardMessageId,
      actionCardConfirmationVersion: actionCardConfirmationVersion,
      onCreated: (value) => created = value,
      onConnectComputer: onConnectComputer,
    ),
  );
  return current() ? created : null;
}
