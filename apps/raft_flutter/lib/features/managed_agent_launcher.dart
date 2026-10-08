import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'private_route_guard.dart';
import 'runtime_form_dialog.dart';

/// The same mounted runtime catalog and protocol-v2 form used by the fleet.
/// A required computer never silently falls back to a different computer.
Future<Map<String, dynamic>?> showManagedAgentForm(
  BuildContext context,
  WorkspaceController w, {
  String? initialName,
  String? initialDescription,
  String? suggestedComputer,
  String? requiredComputer,
  String? actionCardMessageId,
  int? actionCardConfirmationVersion,
}) async {
  final authority = workspaceAuthority(w);
  bool current() =>
      context.mounted &&
      authority == workspaceAuthority(w) &&
      w.can('createAgents');
  if (!context.mounted || !current()) return null;
  final result = await w.query('/servers/${w.server!.id}/machines');
  if (!context.mounted || !current()) return null;
  final machines = (result['machines'] as List)
      .whereType<Map>()
      .where(
        (m) =>
            m['status'] == 'online' &&
            (requiredComputer == null || m['id'] == requiredComputer),
      )
      .toList();
  if (machines.isEmpty) {
    throw const RaftApiException(
      'Connect a computer before creating a managed agent.',
    );
  }
  machines.sort(
    (a, b) => a['id'] == suggestedComputer
        ? -1
        : b['id'] == suggestedComputer
        ? 1
        : 0,
  );
  final machine = requiredComputer != null
      ? machines.first
      : await showDialog<Map>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(raftText(context, 'Choose computer')),
            children: [
              for (final m in machines)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, m),
                  child: Text('${m['name']} · ${m['hostname'] ?? ''}'),
                ),
            ],
          ),
        );
  if (machine == null || !context.mounted || !current()) return null;
  final catalog = await w.query(
    '/servers/${w.server!.id}/machines/${machine['id']}/runtime-options',
  );
  if (!context.mounted || !current()) return null;
  final options = (catalog['options'] as List)
      .whereType<Map>()
      .where((o) => o['canSelectInThisContext'] == true)
      .toList();
  if (options.isEmpty) {
    throw const RaftApiException(
      'This computer has no runtime available for new agents.',
    );
  }
  final runtime = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(raftText(context, 'Choose runtime')),
      children: [
        for (final o in options)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, o['runtimeId']),
            child: Text('${o['runtimeId']}'),
          ),
      ],
    ),
  );
  if (runtime == null || !context.mounted || !current()) return null;
  Map<String, dynamic>? created;
  await showDialog(
    context: context,
    builder: (_) => RuntimeFormDialog(
      controller: w,
      machineId: machine['id'],
      runtimeId: runtime,
      initialName: initialName,
      initialDescription: initialDescription,
      actionCardMessageId: actionCardMessageId,
      actionCardConfirmationVersion: actionCardConfirmationVersion,
      onCreated: (value) => created = value,
    ),
  );
  return current() ? created : null;
}
