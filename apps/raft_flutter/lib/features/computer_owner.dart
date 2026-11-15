// Computer owner v1 on the Computer page (Web v1.24 ComputerOwnerField.tsx,
// TransferComputerOwnerDialog.tsx, machineStore setMachineOwner).
//
// The Owner row shows who Raft records as the owner, or Public. Transfer owner
// is for the owner and for whoever has `editMachines`; Make it mine is for
// whoever connected a Public Computer (the attacher of a managed Computer, the
// machine row's registrant for a raw daemon). The server checks the same.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart' show RaftProfileKind;
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import '../data/user_error.dart';

/// The row's owner: `machine.owner`, read only while an owner is recorded.
RaftComputerOwner? computerOwnerOf(Map<String, dynamic> machine) {
  if (RaftMachineFields(machine).ownerUserId == null) return null;
  final owner = RaftMachineFields(machine).owner;
  if (owner == null || owner.id.isEmpty) return null;
  return RaftComputerOwner(
    name: owner.name,
    handle: '${owner.json['name'] ?? owner.id}',
    avatarUrl: owner.avatarUrl,
  );
}

/// Who connected it, by the server's rule.
bool _isConnector(Map<String, dynamic> machine, String? me) {
  if (me == null) return false;
  return machine['isComputer'] == true
      ? machine['computerAttachedByCurrentUser'] == true
      : machine['userId'] == me;
}

/// The Owner row's actions for [machine], wired into the detail page.
({
  VoidCallback? openOwner,
  VoidCallback? transferOwner,
  Future<void> Function()? makeMine,
})
computerOwnerActions(
  BuildContext context,
  WorkspaceController w,
  Map<String, dynamic> machine,
) {
  final me = w.client.user?.id;
  final ownerUserId = RaftMachineFields(machine).ownerUserId;
  final owner = computerOwnerOf(machine);
  return (
    openOwner: owner == null
        ? null
        : () => w.openProfile(RaftProfileKind.human, ownerUserId!),
    transferOwner: w.can('editMachines') || (me != null && ownerUserId == me)
        ? () => unawaited(showTransferComputerOwnerDialog(context, w, machine))
        : null,
    makeMine: ownerUserId == null && _isConnector(machine, me)
        ? () => claimComputer(context, w, machine)
        : null,
  );
}

/// machineStore setMachineOwner: PUT the owner, then merge the returned
/// machine, else patch the owner locally. Throws when the request fails.
Future<void> setComputerOwner(
  WorkspaceController w,
  Map<String, dynamic> machine,
  String? ownerUserId,
) async {
  final serverId = w.server?.id;
  if (serverId == null) throw const RaftApiException('No server selected');
  final id = '${machine['id']}';
  final apply = w.services.entityDirectory.computerPatchReceiver();
  final answer = await w.command(
    'PUT',
    '/servers/$serverId/machines/$id/owner',
    data: {'ownerUserId': ownerUserId},
  );
  final returned = answer is Map ? answer['machine'] : null;
  if (returned is Map) {
    apply(id, Map<String, dynamic>.from(returned));
    return;
  }
  Map<String, dynamic>? owner;
  if (ownerUserId != null) {
    final member = w.services.entityDirectory.member(ownerUserId);
    owner = {
      'id': ownerUserId,
      'name': member?['name'] ?? ownerUserId,
      'displayName': ?member?['displayName'],
      'avatarUrl': ?member?['avatarUrl'],
    };
  }
  apply(id, {'ownerUserId': ownerUserId, 'owner': owner});
}

/// Make it mine: the failure is a toast; the button shows loading meanwhile.
Future<void> claimComputer(
  BuildContext context,
  WorkspaceController w,
  Map<String, dynamic> machine,
) async {
  final me = w.client.user?.id;
  if (me == null) return;
  final failed = raftText(
    context,
    'Couldn’t make this computer yours. Try again.',
  );
  try {
    await setComputerOwner(w, machine, me);
  } catch (error) {
    logUserError(error, where: 'make computer mine');
    if (context.mounted) {
      showRaftToast(context, failed, tone: RaftToastRecipeTone.error);
    }
  }
}

/// Transfer owner: hand the Computer to another person in the server, or make
/// it Public. Resolves once the dialog closed.
Future<void> showTransferComputerOwnerDialog(
  BuildContext context,
  WorkspaceController w,
  Map<String, dynamic> machine,
) {
  final directory = w.services.entityDirectory
    ..ensure(const [WorkspaceEntityKind.members]);
  return showRaftForm<void>(
    context,
    builder: (dialog) => _TransferOwnerDialog(
      computerName: '${machine['name'] ?? ''}',
      ownerUserId: RaftMachineFields(machine).ownerUserId,
      me: w.client.user?.id,
      directory: directory,
      transfer: (next) => setComputerOwner(w, machine, next),
    ),
  );
}

class _TransferOwnerDialog extends StatefulWidget {
  const _TransferOwnerDialog({
    required this.computerName,
    required this.ownerUserId,
    required this.me,
    required this.directory,
    required this.transfer,
  });
  final String computerName;

  /// The current owner; null for a Public Computer.
  final String? ownerUserId;
  final String? me;
  final WorkspaceEntityDirectory directory;
  final Future<void> Function(String? ownerUserId) transfer;

  @override
  State<_TransferOwnerDialog> createState() => _TransferOwnerDialogState();
}

class _TransferOwnerDialogState extends State<_TransferOwnerDialog> {
  static const _person = 'person', _public = 'public';
  String choice = _person;
  String personId = '';

  @override
  void initState() {
    super.initState();
    widget.directory.addListener(_members);
  }

  @override
  void dispose() {
    widget.directory.removeListener(_members);
    super.dispose();
  }

  void _members() {
    if (mounted) setState(() {});
  }

  /// The server's members who are not Guests and not the current owner.
  List<Map<String, dynamic>> get people => [
    for (final m in widget.directory.rows(WorkspaceEntityKind.members))
      if (m['role'] != 'guest' && m['userId'] != widget.ownerUserId) m,
  ];

  String label(Map<String, dynamic> member) {
    final name = '${member['displayName'] ?? ''}'.isNotEmpty
        ? '${member['displayName']}'
        : '${member['name'] ?? member['userId']}';
    return member['userId'] == widget.me
        ? raftFormat(context, '{name} (you)', {'name': name})
        : name;
  }

  bool get ready =>
      choice == _public ? widget.ownerUserId != null : personId.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final items = [
      for (final m in people) RaftComboboxItem('${m['userId']}', label(m)),
    ];
    return RaftFormDialog(
      key: const ValueKey('transfer-computer-owner-dialog'),
      title: 'Transfer owner',
      fields: const [],
      submitLabel: choice == _public ? 'Make public' : 'Transfer',
      busyLabel: 'Saving…',
      submitEnabled: ready,
      errorContent: (context, error) => RaftBanner(
        key: const ValueKey('transfer-owner-failed'),
        status: RaftBannerRecipeStatus.warning,
        size: RaftBannerRecipeSize.sm,
        description: 'The owner wasn’t changed. Try again.',
      ),
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            raftFormat(
              context,
              'Raft records one person as the owner of {computer}. Choose who, or make it Public with no owner.',
              {'computer': widget.computerName},
            ),
            style: RaftTypography.body(
              t,
              size: 14,
              line: 14 * 1.625,
              color: t.colors['foreground-muted'] ?? t.strong,
            ),
          ),
          const SizedBox(height: RaftSpace.x4),
          RaftRadioGroup<String>(
            value: choice,
            semanticLabel: raftText(context, 'New owner'),
            onChanged: (value) => setState(() => choice = value),
            spacing: 0,
            children: [
              RaftRadioGroupItem<String>(
                key: const ValueKey('transfer-owner-choice-person'),
                value: _person,
                minHeight: 44,
                child: Text(
                  raftText(context, 'A person in this server'),
                  style: _choiceStyle(t),
                ),
              ),
              RaftRadioGroupItem<String>(
                key: const ValueKey('transfer-owner-choice-public'),
                value: _public,
                enabled: widget.ownerUserId != null,
                minHeight: 44,
                child: Text(
                  raftText(context, 'Public (no owner)'),
                  style: _choiceStyle(t),
                ),
              ),
            ],
          ),
          if (choice == _person) ...[
            const SizedBox(height: RaftSpace.x4),
            RaftField(
              label: raftText(context, 'Person'),
              child: RaftUnsavedGuardIgnore(
                child: RaftAgentCombobox(
                  key: const ValueKey('transfer-owner-person'),
                  label: 'Person',
                  semanticLabel: raftText(context, 'Person'),
                  emptyLabel: 'No one matches',
                  placeholder: raftText(context, 'Search members by name'),
                  value: personId,
                  items: items,
                  onSelected: (id) => setState(() => personId = id),
                ),
              ),
            ),
          ],
          const SizedBox(height: RaftSpace.x4),
          RaftBanner(
            key: const ValueKey('transfer-owner-credentials'),
            status: RaftBannerRecipeStatus.warning,
            size: RaftBannerRecipeSize.sm,
            glyph: RaftGlyph.alertTriangle,
            description:
                'Claude and Codex logins and git credentials on this computer stay those of whoever is signed in on it. Transferring only changes who Raft records as its owner.',
          ),
        ],
      ),
      onSubmit: (_) => widget.transfer(choice == _public ? null : personId),
    );
  }

  TextStyle _choiceStyle(RaftTokens t) => RaftTypography.body(
    t,
    size: 14,
    line: 20,
    color: t.strong,
    weight: FontWeight.w600,
  );
}
