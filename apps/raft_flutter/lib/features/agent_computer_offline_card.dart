import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_time_formatter.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'computer_setup_commands.dart';

/// Web `computerOwnerId` (useAgentComputerOffline.ts): whose Computer it is,
/// the machine row's owner (`userId`), else the person who attached it (the
/// `creator`, when a person). Not the server's Owner role.
String? computerOwnerId(Map machine) {
  final userId = machine['userId'];
  if (userId is String && userId.isNotEmpty) return userId;
  final creator = machine['creator'];
  if (creator is Map && creator['type'] == 'human') {
    final id = creator['id'];
    if (id is String && id.isNotEmpty) return id;
  }
  return null;
}

/// The name of the person [computerOwnerId] names: the member's, else the
/// creator's when the creator is that person. Null when unknown (a departed
/// member, an older server): the steps then name no one.
String? computerOwnerName(WorkspaceController w, Map machine) {
  final ownerId = computerOwnerId(machine);
  if (ownerId == null) return null;
  String? nameOf(Map m) {
    for (final key in const ['displayName', 'name']) {
      final value = m[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  final member = w.services.entityDirectory
      .rows(WorkspaceEntityKind.members)
      .where((m) => m['userId'] == ownerId)
      .firstOrNull;
  if (member != null) return nameOf(member);
  final creator = machine['creator'];
  return creator is Map && creator['id'] == ownerId ? nameOf(creator) : null;
}

/// Web `agentComputerRestartCommand` (agentComputerCommands.ts): the command
/// the Computer page's recovery card gives for an offline Computer
/// (`raft-computer restart /<server>`, which also starts a stopped service).
/// Null without a server slug.
String? agentComputerRestartCommand(WorkspaceController w, Map machine) {
  final windows = '${machine['os'] ?? ''}'.toLowerCase().startsWith('win');
  return ComputerCommands.build(
    slug: w.server?.string('slug') ?? '',
    serverUrl: w.client.origin,
    windows: windows,
    machineId: machine['isComputer'] == true ? null : '${machine['id']}',
  )?.restart;
}

/// Web `AgentComputerOfflineCard` (features/agent/AgentComputerOfflineCard.tsx):
/// the profile's card while the agent's Computer is offline (#triage:#206), in
/// place of Start. Which Computer, since when, and the same two steps for
/// everyone: turn that computer on and keep it awake, then open Raft Desktop on
/// it or run the Computer page's restart command. It draws nothing while the
/// Computer is online, unknown or unassigned.
class AgentComputerOfflineCard extends StatelessWidget {
  const AgentComputerOfflineCard({
    super.key,
    required this.controller,
    required this.machine,
    required this.formatter,
    this.onOpenComputer,
  });
  final WorkspaceController controller;

  /// The agent's Computer row; null while unknown or unassigned.
  final Map<String, dynamic>? machine;
  final SourceTimeFormatter formatter;
  final VoidCallback? onOpenComputer;

  /// "Since when": the moment this client saw the live online to offline change,
  /// else the row's last heartbeat. A Computer held offline only because a Start
  /// was refused has no known moment (the refusal says only that it is offline
  /// now).
  Object? _since(Map<String, dynamic> m) {
    final id = m['id'];
    if (id is! String) return null;
    final directory = controller.services.entityDirectory;
    if (directory.computerOfflineFromRefusal(id)) return null;
    final observed = directory.computerOfflineObservedAtMs(id);
    if (observed != null) {
      return DateTime.fromMillisecondsSinceEpoch(observed);
    }
    return m['lastHeartbeat'];
  }

  /// A catalog line with one `{piece}` placeholder, split around it.
  RaftAgentOfflineSentence _around(String line, String piece) {
    final parts = line.split('{$piece}');
    return RaftAgentOfflineSentence(
      parts.first,
      parts.length > 1 ? parts[1] : '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = machine;
    if (m == null || m['status'] != 'offline') return const SizedBox.shrink();
    final name = '${m['name'] ?? ''}';
    final owner = computerOwnerName(controller, m);
    final sinceRaw = _since(m);
    final since = sinceRaw == null || '$sinceRaw'.isEmpty
        ? null
        : formatter.messageTime(sinceRaw);
    return RaftAgentComputerOfflineCard(
      title: _around(
        since == null
            ? raftText(context, '{computer} is offline')
            : raftText(
                context,
                '{computer} has been offline since {time}',
              ).replaceAll('{time}', since),
        'computer',
      ),
      computerName: name,
      onOpenComputer: onOpenComputer,
      owner: owner,
      powerStep: owner == null
          ? RaftAgentOfflineSentence(
              raftFormat(
                context,
                'Turn on the computer {computer} and keep it from sleeping',
                {'computer': name},
              ),
            )
          : _around(
              raftText(
                context,
                "Turn on {owner}'s computer {computer} and keep it from sleeping",
              ).replaceAll('{computer}', name),
              'owner',
            ),
      runStep: raftText(context, 'On that computer, open Raft Desktop or run:'),
      command: agentComputerRestartCommand(controller, m),
      copyLabel: raftText(context, 'Copy command'),
    );
  }
}
