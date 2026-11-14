// Delete Computer, from the Computer page and the rack row's … menu (Web
// v1.24 features/computer/DeleteComputerDialog.tsx, ForceUnbindAgentsDialog.tsx,
// othersAgentsApi.ts).
//
// Someone else's computer: DELETE, which the server refuses while any agent is
// on it, so while the list shows one the dialog only says so. The person's own
// Computer (its machine row is theirs, `userId`): only their own agents (ones
// they created, or their personal assistant) block it; confirming revokes the
// Computer's key first (revoke-computer-key), and while other people's agents
// are on it the server answers 409 with them: the force-unbind confirmation
// lists them and sends exactly those as `forceAgentIds`. A DELETE that fails
// after the key was revoked says so in our words.
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';

/// othersAgentsApi.ts isOwnAgent.
bool isOwnAgent(Map agent, String? userId) {
  if (userId == null) return false;
  final creator = agent['creator'];
  final createdByMe =
      (agent['creatorType'] == 'user' && agent['creatorId'] == userId) ||
      (creator is Map && creator['type'] == 'human' && creator['id'] == userId);
  return createdByMe || agent['assistantOwnerUserId'] == userId;
}

/// A person's own Computer: the server's revoke test (`userId`), not
/// `computerAttachedByCurrentUser`.
bool computerAttachedByMe(Map machine, String? userId) =>
    machine['isComputer'] == true &&
    userId != null &&
    machine['userId'] == userId;

/// One agent the force-unbind confirmation lists.
typedef ForceUnbindAgent = ({
  String id,
  String name,
  String? ownerName,
  String computerName,
});

/// The 409 `others_agents_on_computer` list, or null for any other answer.
List<ForceUnbindAgent>? othersAgentsOf(Object error, String computerName) {
  if (error is! RaftApiException || error.status != 409) return null;
  if (error.details['code'] != 'others_agents_on_computer') return null;
  final listed = error.details['agents'];
  if (listed is! List) return null;
  final agents = <ForceUnbindAgent>[
    for (final a in listed.whereType<Map>())
      if (a['id'] is String)
        (
          id: a['id'] as String,
          name: a['name'] is String ? a['name'] as String : a['id'] as String,
          ownerName: switch (a['owner']) {
            {'name': final String name} when name.isNotEmpty => name,
            {'id': final String id} => id,
            _ => null,
          },
          computerName: computerName,
        ),
  ];
  return agents.isEmpty ? null : agents;
}

/// Why DELETE refused (MachineDeleteConflictError).
String _refusal(Object error) {
  final code = error is RaftApiException ? error.details['code'] : null;
  return switch (code) {
    'MACHINE_HAS_ASSIGNED_AGENTS' =>
      'an agent is still on it. Move or remove that agent first.',
    'MACHINE_HAS_ACTIVE_MIGRATION' =>
      'an agent is moving to or from it. Wait for the move to finish.',
    'MACHINE_HAS_ACTIVE_RUNTIME_PROFILE' =>
      "an agent's settings still point to it. Move or remove that agent first.",
    _ => 'something went wrong on our side.',
  };
}

/// Opens Delete Computer for [machine] with the live [agents] on it the
/// viewer can see. Resolves true once the computer was deleted.
Future<bool> showDeleteComputerDialog(
  BuildContext context,
  WorkspaceController w, {
  required Map<String, dynamic> machine,
  required List<Map<String, dynamic>> agents,
  bool Function()? authorized,
}) async {
  bool valid() => context.mounted && (authorized?.call() ?? true);
  if (!valid()) return false;
  final me = w.client.user?.id;
  final mine = computerAttachedByMe(machine, me);
  final holding = mine
      ? [
          for (final a in agents)
            if (isOwnAgent(a, me)) a,
        ]
      : agents;
  final name = '${machine['name'] ?? ''}';
  // The words are the opening page's; it may be gone by the time they show.
  String tr(String s) => context.mounted ? raftText(context, s) : s;
  String fmt(String s, Map<String, Object?> values) =>
      context.mounted ? raftFormat(context, s, values) : s;
  if (holding.isNotEmpty) {
    await showRaftDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => RaftConfirmDialog(
        surfaceKey: const ValueKey('computer-cannot-delete'),
        title: raftText(dialog, 'Cannot delete computer'),
        message: raftFormat(
          dialog,
          holding.length == 1
              ? 'This computer has {count} agent assigned. Remove all agents before deleting the computer.'
              : 'This computer has {count} agents assigned. Remove all agents before deleting the computer.',
          {'count': holding.length},
        ),
        confirmLabel: raftText(dialog, 'OK'),
        confirmVariant: RaftButtonRecipeVariant.outline,
        showCancel: false,
        onConfirm: () async {},
      ),
    );
    return false;
  }
  final serverId = w.server?.id;
  final base = '/servers/$serverId/machines/${machine['id']}';
  var revoked = false;
  var deleted = false;

  /// Deletes it; the others' agents still on it when the server refused.
  Future<List<ForceUnbindAgent>?> remove(List<String> force) async {
    if (!valid()) throw const RaftApiException('Fleet access changed.');
    if (mine) {
      try {
        await w.command(
          'POST',
          '$base/revoke-computer-key',
          data: force.isEmpty ? {} : {'forceAgentIds': force},
        );
      } catch (error) {
        final others = othersAgentsOf(error, name);
        if (others != null) return others;
        final key = error is RaftApiException ? error.details['code'] : null;
        if (!(error is RaftApiException &&
            error.status == 409 &&
            key == 'no_live_computer_key')) {
          rethrow;
        }
      }
      revoked = true;
    }
    try {
      await w.command('DELETE', base);
    } catch (error) {
      if (!revoked) rethrow;
      throw RaftApiException(
        fmt(
          "This computer's key is revoked and it's offline now, but it couldn't be removed from the list: {reason} Trying again is safe.",
          {'reason': tr(_refusal(error))},
        ),
      );
    }
    deleted = true;
    return null;
  }

  List<ForceUnbindAgent>? others;
  if (!context.mounted) return false;
  await showRaftDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => RaftConfirmDialog(
      surfaceKey: const ValueKey('computer-delete-confirm'),
      title: raftText(dialog, 'Delete computer'),
      message: raftFormat(dialog, 'Are you sure you want to delete "{name}"?', {
        'name': name,
      }),
      confirmLabel: raftText(dialog, 'Delete computer'),
      loadingLabel: raftText(dialog, 'Deleting…'),
      confirmVariant: RaftButtonRecipeVariant.danger,
      onConfirm: () async {
        try {
          others = await remove(const []);
        } catch (error) {
          throw RaftApiException(
            userErrorText(
              error,
              fallback: raftGenericErrorText,
              where: 'delete computer',
            ),
          );
        }
      },
    ),
  );
  while (others != null && !deleted && valid()) {
    final listed = others!;
    others = null;
    if (!context.mounted) break;
    await showForceUnbindAgentsDialog(
      context,
      agents: listed,
      confirmLabel: tr('Force unbind and delete'),
      onConfirm: () async {
        final again = await remove([for (final a in listed) a.id]);
        if (again != null) {
          others = again;
          throw RaftApiException(
            tr(
              'More agents were added to this computer, so nothing was unbound. Check the list and confirm again.',
            ),
          );
        }
      },
    );
  }
  return deleted;
}

/// ForceUnbindAgentsDialog: the destructive confirmation listing every agent
/// it unbinds with its owner and computer. An [onConfirm] that throws keeps
/// it open with the reason.
Future<void> showForceUnbindAgentsDialog(
  BuildContext context, {
  required List<ForceUnbindAgent> agents,
  required String confirmLabel,
  required Future<void> Function() onConfirm,
}) => showRaftDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (dialog) => RaftConfirmDialog(
    surfaceKey: const ValueKey('force-unbind-dialog'),
    confirmKey: const ValueKey('force-unbind-confirm'),
    title: raftFormat(
      dialog,
      agents.length == 1
          ? 'Force unbind {count} agent?'
          : 'Force unbind {count} agents?',
      {'count': agents.length},
    ),
    content: RaftForceUnbindAgentList(
      message: raftText(
        dialog,
        'Their workspaces on your computers are lost. The agents themselves stay, with their messages and settings, and their owners can keep using them on another computer. Each owner gets a system notice.',
      ),
      listLabel: raftText(dialog, 'Agents to unbind'),
      agents: [
        for (final a in agents)
          (
            id: a.id,
            name: a.name,
            meta: a.ownerName == null
                ? raftFormat(dialog, 'No owner · {computerName}', {
                    'computerName': a.computerName,
                  })
                : raftFormat(dialog, 'Owner: {ownerName} · {computerName}', {
                    'ownerName': a.ownerName,
                    'computerName': a.computerName,
                  }),
          ),
      ],
    ),
    confirmLabel: confirmLabel,
    loadingLabel: raftText(dialog, 'Unbinding…'),
    confirmVariant: RaftButtonRecipeVariant.danger,
    onConfirm: onConfirm,
  ),
);
