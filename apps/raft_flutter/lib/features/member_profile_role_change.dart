import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'member_removal_impact.dart';

const humanRoleRanks = {'guest': 0, 'member': 1, 'admin': 2, 'owner': 3};

String memberRoleLabel(BuildContext context, String role) =>
    raftText(context, '${role[0].toUpperCase()}${role.substring(1)}');

class MemberProfileRoleChange {
  MemberProfileRoleChange({
    required this.workspace,
    required this.server,
    required this.member,
    required this.name,
    required this.previous,
    required this.next,
  }) : _principal = workspace.client.user?.id;

  final WorkspaceController workspace;
  final String server, member, name, previous, next;
  final String? _principal;

  String get _path => '/servers/$server/members/$member';
  bool get _samePrincipal =>
      _principal != null && workspace.client.user?.id == _principal;

  Future<void> apply() => _patch(next);

  Future<void> _patch(String role) async {
    await workspace.command('PATCH', _path, data: {'role': role});
    if (_samePrincipal && workspace.server?.id == server) {
      await workspace.entityDirectory.refresh(
        WorkspaceEntityKind.members,
        force: true,
      );
    }
  }

  void showReceipt(
    BuildContext context, {
    required bool allowUndo,
    required Future<void> Function() onRestored,
  }) {
    final toast = RaftToastHost.maybeOf(context);
    if (toast == null) return;
    final role = memberRoleLabel(context, next);
    final restored = raftFormat(
      context,
      "Changed {name}'s role back to {role}",
      {'name': name, 'role': memberRoleLabel(context, previous)},
    );
    final superseded = raftFormat(
      context,
      "{name}'s role has changed since, so it wasn't changed back",
      {'name': name},
    );
    final failed = raftText(context, 'Failed to undo the role change');
    var used = false;
    toast.show(
      raftFormat(context, "Changed {name}'s role to {role}", {
        'name': name,
        'role': role,
      }),
      tone: RaftToastRecipeTone.success,
      actionLabel: allowUndo && previous != 'guest'
          ? raftText(context, 'Undo')
          : null,
      onAction: !allowUndo || previous == 'guest'
          ? null
          : () {
              if (used || !_samePrincipal) return;
              used = true;
              unawaited(() async {
                try {
                  final current = await RaftClient.runFresh(
                    () => workspace.query('$_path/profile'),
                  );
                  if (!_samePrincipal) return;
                  if (current is! Map || current['role'] != next) {
                    toast.show(superseded, tone: RaftToastRecipeTone.info);
                    return;
                  }
                  await _patch(previous);
                  if (_samePrincipal) {
                    toast.show(restored, tone: RaftToastRecipeTone.success);
                  }
                  await onRestored();
                } catch (_) {
                  if (_samePrincipal) {
                    toast.show(failed, tone: RaftToastRecipeTone.error);
                  }
                }
              }());
            },
    );
  }
}

Widget memberRoleConfirmation(
  BuildContext context, {
  required MemberProfileRoleChange change,
  required bool selfDemotion,
  required MemberRemovalImpactRead? impact,
  required Listenable changes,
  required Future<void> Function() onConfirm,
}) {
  final key = selfDemotion ? 'human-self-demote' : 'human-owner-grant';
  return RaftConfirmDialog(
    surfaceKey: ValueKey('$key-dialog'),
    confirmKey: ValueKey('$key-confirm'),
    title: selfDemotion
        ? raftText(context, 'Change your role')
        : raftFormat(context, 'Make {name} an owner?', {'name': change.name}),
    content: ListenableBuilder(
      listenable: changes,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selfDemotion)
            RaftCssText(
              raftFormat(
                context,
                "You'll become {role}, and may no longer be able to change roles, including changing yours back.",
                {'role': memberRoleLabel(context, change.next)},
              ),
            ),
          ?(impact == null ? null : ownComputersTransferNote(context, impact)),
        ],
      ),
    ),
    confirmLabel: raftText(
      context,
      selfDemotion ? 'Change role' : 'Make owner',
    ),
    onConfirm: onConfirm,
  );
}
