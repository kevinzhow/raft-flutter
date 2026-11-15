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
// shows them (OthersAgentsOnComputerDialog) with Notify owner to move it (once
// a day, shared with Delete Account) and Force unbind and delete, which asks
// again (ForceUnbindAgentsDialog) and sends exactly those as `forceAgentIds`.
// Cancel in that confirmation goes back to the list; a 409 on it means more
// arrived and nothing happened: it shows the newer list and says so. A DELETE
// that fails after the key was revoked says so in our words.
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'agent_owner_notify.dart';

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

/// The 409 `others_agents_on_computer` list, or null for any other answer.
List<OthersAgent>? othersAgentsOf(Object error) {
  if (error is! RaftApiException || error.status != 409) return null;
  if (error.details['code'] != 'others_agents_on_computer') return null;
  final listed = error.details['agents'];
  if (listed is! List) return null;
  final agents = [for (final a in listed) ?OthersAgent.fromJson(a)];
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
  Listenable? changes,
}) async {
  bool valid() =>
      context.mounted &&
      (authorized?.call() ?? true) &&
      // A computer another admin deleted first cannot be deleted again.
      w.services.entityDirectory.computer('${machine['id']}') != null;
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
  Future<List<OthersAgent>?> remove(List<String> force) async {
    if (!valid()) throw const RaftApiException('Fleet access changed.');
    if (mine) {
      try {
        await w.command(
          'POST',
          '$base/revoke-computer-key',
          data: force.isEmpty ? {} : {'forceAgentIds': force},
        );
      } catch (error) {
        final others = othersAgentsOf(error);
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
      throw RaftComputerActionError(
        fmt(
          "This computer's key is revoked and it's offline now, but it couldn't be removed from the list: {reason} Trying again is safe.",
          {'reason': tr(_refusal(error))},
        ),
      );
    }
    deleted = true;
    return null;
  }

  List<OthersAgent>? others;
  if (!context.mounted) return false;
  await showRaftDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => _CloseWhenGone(
      changes: changes,
      gone: () => !valid(),
      child: RaftConfirmDialog(
        surfaceKey: const ValueKey('computer-delete-confirm'),
        title: raftText(dialog, 'Delete computer'),
        message: raftFormat(
          dialog,
          'Are you sure you want to delete "{name}"?',
          {'name': name},
        ),
        confirmLabel: raftText(dialog, 'Delete computer'),
        loadingLabel: raftText(dialog, 'Deleting…'),
        confirmVariant: RaftButtonRecipeVariant.danger,
        onConfirm: () async {
          if (!valid()) return;
          try {
            others = await remove(const []);
          } catch (error) {
            throw RaftComputerActionError(
              userErrorText(
                error,
                fallback: raftGenericErrorText,
                where: 'delete computer',
              ),
            );
          }
        },
      ),
    ),
  );
  // The notify state outlives a trip to the force confirmation and back.
  final notifier = AgentOwnerNotifier(
    send: (ids) =>
        postNotifyAgentOwners(w.command, '$base/notify-agent-owners', ids),
  );
  try {
    while (others != null && !deleted && valid()) {
      if (!context.mounted) break;
      final force = await showOthersAgentsDialog(
        context,
        agents: others!,
        notifier: notifier,
        changes: changes,
        gone: () => !valid(),
      );
      if (force != true || !valid() || !context.mounted) break;
      // The confirmation shows the newest list; Cancel goes back to the list.
      final listed = _ListedAgents(others!);
      try {
        await showForceUnbindAgentsDialog(
          context,
          agents: listed,
          computerName: name,
          confirmLabel: tr('Force unbind and delete'),
          changes: changes,
          gone: () => !valid(),
          onConfirm: () async {
            final again = await remove([for (final a in listed.value) a.id]);
            if (again != null) {
              others = again;
              listed.value = again;
              throw RaftComputerActionError(
                tr(
                  'More agents were added to this computer, so nothing was unbound. Check the list and confirm again.',
                ),
              );
            }
          },
        );
      } finally {
        listed.dispose();
      }
    }
  } finally {
    notifier.dispose();
  }
  return deleted;
}

/// OthersAgentsOnComputerDialog: other people's agents on the Computer, each
/// with its owner and Notify owner to move it. True: Force unbind and delete
/// was chosen; false or null: closed.
Future<bool?> showOthersAgentsDialog(
  BuildContext context, {
  required List<OthersAgent> agents,
  required AgentOwnerNotifier notifier,
  Listenable? changes,
  bool Function()? gone,
}) => showRaftDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (dialog) => _CloseWhenGone(
    changes: changes,
    gone: gone ?? () => false,
    child: ListenableBuilder(
      listenable: notifier,
      builder: (dialog, _) => RaftConfirmDialog(
        surfaceKey: const ValueKey('computer-others-agents'),
        confirmKey: const ValueKey('computer-others-agents-force'),
        title: raftText(dialog, "Other people's agents on this computer"),
        maxWidth: 448,
        plainMessage: true,
        content: RaftOthersAgentsList(
          message: raftText(
            dialog,
            'Only their owners can move them to another computer. Raft can remind each owner with a system message, or you can force unbind them and delete the computer now.',
          ),
          listLabel: raftText(dialog, "Other people's agents"),
          agents: [
            for (final a in agents)
              (
                id: a.id,
                name: a.name,
                ownerLine: switch (notifier.ownerNow(a)) {
                  final owner? => raftFormat(dialog, 'Owner: {ownerName}', {
                    'ownerName': owner.name,
                  }),
                  null => raftText(dialog, 'No owner'),
                },
                actions: AgentOwnerNotifyActions(
                  agent: a,
                  notifier: notifier,
                  testIdPrefix: 'computer',
                ),
              ),
          ],
        ),
        confirmLabel: raftText(dialog, 'Force unbind and delete'),
        confirmVariant: RaftButtonRecipeVariant.outline,
      ),
    ),
  ),
);

/// The agents the force confirmation lists; a newer list replaces them.
class _ListedAgents implements ValueListenable<List<OthersAgent>> {
  _ListedAgents(this._value);
  List<OthersAgent> _value;
  final _listeners = <VoidCallback>{};
  @override
  List<OthersAgent> get value => _value;
  set value(List<OthersAgent> next) {
    _value = next;
    for (final listener in _listeners.toList()) {
      listener();
    }
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
  void dispose() => _listeners.clear();
}

/// ForceUnbindAgentsDialog: the destructive confirmation listing every agent
/// it unbinds with its owner and computer. An [onConfirm] that throws keeps
/// it open with the reason.
Future<void> showForceUnbindAgentsDialog(
  BuildContext context, {
  required ValueListenable<List<OthersAgent>> agents,
  required String computerName,
  required String confirmLabel,
  required Future<void> Function() onConfirm,
  Listenable? changes,
  bool Function()? gone,
}) => showRaftDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (dialog) => _CloseWhenGone(
    changes: changes,
    gone: gone ?? () => false,
    child: ValueListenableBuilder<List<OthersAgent>>(
      valueListenable: agents,
      builder: (dialog, listed, _) => RaftConfirmDialog(
        surfaceKey: const ValueKey('force-unbind-dialog'),
        confirmKey: const ValueKey('force-unbind-confirm'),
        title: raftFormat(
          dialog,
          listed.length == 1
              ? 'Force unbind {count} agent?'
              : 'Force unbind {count} agents?',
          {'count': listed.length},
        ),
        content: RaftForceUnbindAgentList(
          message: raftText(
            dialog,
            'Their workspaces on your computers are lost. The agents themselves stay, with their messages and settings, and their owners can keep using them on another computer. Each owner gets a system notice.',
          ),
          listLabel: raftText(dialog, 'Agents to unbind'),
          agents: [
            for (final a in listed)
              (
                id: a.id,
                name: a.name,
                meta: a.owner == null
                    ? raftFormat(dialog, 'No owner · {computerName}', {
                        'computerName': computerName,
                      })
                    : raftFormat(
                        dialog,
                        'Owner: {ownerName} · {computerName}',
                        {
                          'ownerName': a.owner!.name,
                          'computerName': computerName,
                        },
                      ),
              ),
          ],
        ),
        confirmLabel: confirmLabel,
        loadingLabel: raftText(dialog, 'Unbinding…'),
        confirmVariant: RaftButtonRecipeVariant.danger,
        onConfirm: onConfirm,
      ),
    ),
  ),
);

/// Closes its own dialog route (and only it) once [gone] says the computer
/// or the authority it was opened for no longer exists: Web's dialog lives in
/// the Computer page, which unmounts with it.
class _CloseWhenGone extends StatefulWidget {
  const _CloseWhenGone({
    required this.changes,
    required this.gone,
    required this.child,
  });
  final Listenable? changes;
  final bool Function() gone;
  final Widget child;

  @override
  State<_CloseWhenGone> createState() => _CloseWhenGoneState();
}

class _CloseWhenGoneState extends State<_CloseWhenGone> {
  @override
  void initState() {
    super.initState();
    widget.changes?.addListener(_check);
  }

  @override
  void dispose() {
    widget.changes?.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (!mounted || !widget.gone()) return;
    final route = ModalRoute.of(context);
    if (route?.isActive == true) route!.navigator?.removeRoute(route);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
