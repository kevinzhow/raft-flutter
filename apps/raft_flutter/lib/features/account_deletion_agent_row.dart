// One agent row of Delete Account (Web features/settings/account/
// AccountDeletionAgentRow.tsx, accountDeletionMove.ts, v7): the person's
// agents on one of their computers, or on one server otherwise, and what
// becomes of them. They go to the server's owner (the personal assistant is
// archived); nothing here holds up the deletion (other members' agents on the
// computer do: they are Needs action rows). On the person's own computer,
// which is deleted on the deletion date, the new owner runs them on another
// computer, so the row also offers, optionally:
//
// - Move to another computer: the existing dialog
//   ([AgentMigrationStartDialog]), only where the server's plan can move
//   agents (an unknown plan does not hide it, the server decides). It reads
//   the agent and the target computers from the current server, so on another
//   server it opens Delete Account there with the dialog (`?move=<agentId>`).
// - Archive: the DELETE every Archive sends, confirmed as Archive confirms.
//
// With more than one of the person's agents on it, each action is a menu of
// them. Either reads the list again.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_archive.dart' show archiveRequestErrorText;
import '../data/migration_error.dart';
import '../data/user_error.dart' show logUserError;
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'account_deletion_agent_groups.dart';
import 'account_deletion_frame.dart' show accountDeletionList;
import 'account_deletion_rows.dart';
import 'agent_migration_presentation.dart';
import 'agent_migration_start_dialog.dart';
import 'billing_view.dart' show RaftBillingPlans;

/// Agent names shown in a row before "and N more".
const accountDeletionNamesShown = 5;

/// The query that opens Move to another computer for an agent on arrival
/// (Web `MOVE_AGENT_PARAM`).
const accountDeletionMoveParam = 'move';

typedef _RowAgent = ({String id, String name});

/// One optional action: a button for a single agent, else a menu of them.
class _AgentAction extends StatelessWidget {
  const _AgentAction({
    super.key,
    required this.agents,
    required this.glyph,
    required this.label,
    required this.onChoose,
    this.badge,
  });
  final List<_RowAgent> agents;
  final RaftGlyph glyph;
  final String label;

  /// After the label, in the button.
  final String? badge;
  final void Function(_RowAgent agent) onChoose;

  @override
  Widget build(BuildContext context) {
    Widget button(
      VoidCallback? onPressed, {
      FocusNode? focusNode,
      bool menu = false,
    }) => RaftButton(
      focusNode: focusNode,
      variant: RaftControlVariant.outline,
      glyph: glyph,
      label: label,
      trailingGlyph: menu ? RaftGlyph.chevronDown : null,
      onPressed: onPressed,
      leading: null,
      // Web `{icon}{label}{badge}<ChevronDown/>`: the tag is in the button.
      child: badge == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: RaftSpace.x1_5,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                RaftBadge(
                  label: badge!,
                  appearance: RaftBadgeRecipeAppearance.outline,
                ),
              ],
            ),
    );
    if (agents case [final only]) {
      return button(() => onChoose(only));
    }
    return RaftDropdownMenu(
      label: label,
      width: 240,
      triggerBuilder: (context, focusNode, open) =>
          button(open, focusNode: focusNode, menu: true),
      entries: [
        for (final agent in agents)
          RaftMenuEntry(
            label: agent.name,
            glyph: RaftGlyph.bot,
            onPressed: () => onChoose(agent),
          ),
      ],
    );
  }
}

class AccountDeletionAgentRow extends StatefulWidget {
  const AccountDeletionAgentRow({
    super.key,
    required this.controller,
    required this.group,
    required this.autoMoveAgentId,
    required this.onAutoMoveHandled,
    required this.onChanged,
    this.onMoveElsewhere,
    this.first = false,
  });
  final WorkspaceController controller;
  final AccountDeletionAgentGroup group;

  /// An agent whose Move to another computer opens on arrival (`?move=`), if
  /// it is in this row.
  final String? autoMoveAgentId;
  final VoidCallback onAutoMoveHandled;

  /// An agent moved or archived: read the list again.
  final VoidCallback onChanged;

  /// Opens Delete Account on another server with that agent's move (Web
  /// `moveAgentElsewhereHref`); null hides Move there.
  final void Function(AccountDeletionServer server, String agentId)?
  onMoveElsewhere;
  final bool first;

  @override
  State<AccountDeletionAgentRow> createState() =>
      _AccountDeletionAgentRowState();
}

class _AccountDeletionAgentRowState extends State<AccountDeletionAgentRow> {
  WorkspaceController get w => widget.controller;
  AccountDeletionAgentGroup get group => widget.group;
  bool movingOpen = false;

  bool get onCurrentServer => w.server?.id == group.server.id;

  /// Web: the current server's billing plan, else the server list's.
  Object? get plan =>
      (onCurrentServer
              ? w.server
              : w.servers.where((s) => s.id == group.server.id).firstOrNull)
          ?.json['plan'];

  bool get moveOffered => !agentMigrationRequiresUpgrade(
    plan,
    trialActive: RaftBillingPlans.trialActive(DateTime.now().toUtc()),
  );

  Map<String, dynamic>? storeAgent(String agentId) {
    if (!onCurrentServer) return null;
    final agent = w.services.entityDirectory.agent(agentId);
    return agent == null || agent['deletedAt'] != null ? null : agent;
  }

  /// Arrived from another server's row (`?move=`): its move is open while the
  /// query names one of the person's agents here, once that agent has loaded.
  String? get autoMoveId =>
      group.computer != null &&
          widget.autoMoveAgentId != null &&
          group.agents.any((agent) => agent.id == widget.autoMoveAgentId)
      ? widget.autoMoveAgentId
      : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => maybeAutoMove());
  }

  @override
  void didUpdateWidget(AccountDeletionAgentRow old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => maybeAutoMove());
  }

  void maybeAutoMove() {
    final id = autoMoveId;
    if (!mounted || movingOpen || id == null || !moveOffered) return;
    final agent = storeAgent(id);
    if (agent != null) unawaited(move(agent, auto: true));
  }

  Future<void> move(Map<String, dynamic> agent, {bool auto = false}) async {
    if (movingOpen) return;
    movingOpen = true;
    final started = await showAccountDeletionMove(context, w, agent);
    movingOpen = false;
    if (auto) widget.onAutoMoveHandled();
    if (started && mounted) widget.onChanged();
  }

  Future<void> archive(_RowAgent agent) async {
    final done = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('account-deletion-archive-confirm'),
        confirmKey: const ValueKey('account-deletion-archive-confirm-button'),
        title: raftFormat(context, 'Archive {name}?', {'name': agent.name}),
        message: raftText(
          context,
          "The agent stops and no longer counts toward your plan's agent limit. Its profile and message history stay visible, read-only.",
        ),
        maxWidth: 448,
        confirmLabel: raftText(context, 'Archive'),
        loadingLabel: raftText(context, 'Archiving…'),
        confirmGlyph: RaftGlyph.archive,
        confirmVariant: RaftButtonRecipeVariant.warning,
        onConfirm: () async {
          try {
            await w.client.archiveAgentForDeletion(group.server.id, agent.id);
          } catch (error) {
            logUserError(error, where: 'archive agent for account deletion');
            throw RaftUserError(
              archiveRequestErrorText(
                error,
                fallback: 'Failed to archive the agent',
              ),
            );
          }
        },
      ),
    );
    if (done == true && mounted) widget.onChanged();
  }

  String namesOf(BuildContext context, List<AccountDeletionAgent> list) {
    final shown = [
      for (final agent in list.take(accountDeletionNamesShown)) agent.name,
    ];
    final more = list.length - shown.length;
    return accountDeletionList(context, [
      ...shown,
      if (more > 0) raftFormat(context, '{count} more', {'count': more}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final agents = group.agents, computer = group.computer;
    final count = agents.length, handedOver = group.handedOver;
    final owner = group.owner;
    final name = computer != null
        ? count > 0
              ? accountDeletionCountText(
                  context,
                  count,
                  '{count} agent on {computerName}',
                  '{count} agents on {computerName}',
                ).replaceAll('{computerName}', computer.name)
              : computer.name
        : accountDeletionCountText(
            context,
            count,
            '{count} agent in {serverName}',
            '{count} agents in {serverName}',
          ).replaceAll('{serverName}', group.server.name);
    String outcomeText() {
      if (handedOver == 0) {
        return count > 0
            ? tr('Your personal assistant is archived')
            : tr('Deleted on the deletion date');
      }
      final values = {
        'ownerName': owner?.name,
        'serverName': group.server.name,
      };
      final (one, other) = owner != null
          ? computer != null
                ? (
                    'Goes to {ownerName}, who needs another computer to run it',
                    'Go to {ownerName}, who needs another computer to run them',
                  )
                : ('Goes to {ownerName}', 'Go to {ownerName}')
          : computer != null
          ? (
              'Goes to the new Owner of {serverName}, who needs another computer to run it',
              'Go to the new Owner of {serverName}, who needs another computer to run them',
            )
          : (
              'Goes to the new Owner of {serverName}',
              'Go to the new Owner of {serverName}',
            );
      return raftFormat(context, handedOver == 1 ? one : other, values);
    }

    final rowAgents = [
      for (final agent in agents) (id: agent.id, name: agent.name),
    ];
    // Moving needs the agent in this server's store; on another server the
    // row links there.
    final canMove = computer != null && moveOffered;
    final movable = canMove
        ? [
            for (final agent in rowAgents)
              if (onCurrentServer
                  ? storeAgent(agent.id) != null
                  : widget.onMoveElsewhere != null)
                agent,
          ]
        : const <_RowAgent>[];
    return AccountDeletionChecklistRow(
      key: ValueKey(
        'account-deletion-agents-${group.key.replaceFirst(':', '-')}',
      ),
      first: widget.first,
      glyph: computer != null ? RaftGlyph.monitor : RaftGlyph.bot,
      name: name,
      detail: count > 0
          ? namesOf(context, agents)
          : raftFormat(context, 'Connected to {serverName}', {
              'serverName': group.server.name,
            }),
      outcome: Text(outcomeText()),
      children: [
        if (count > 0)
          AccountDeletionRowNote(
            '${accountDeletionCountText(context, count, 'It stops now.', 'They stop now.')}'
            '${group.hasAssistant && handedOver > 0 ? '${Localizations.localeOf(context).languageCode == 'zh' ? '' : ' '}${tr('Your personal assistant is archived.')}' : ''}',
          ),
        if (computer != null && count > 0)
          Padding(
            padding: const EdgeInsets.only(top: RaftSpace.x2),
            child: Wrap(
              key: ValueKey('account-deletion-agent-actions-${computer.id}'),
              spacing: RaftSpace.x2,
              runSpacing: RaftSpace.x2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  tr('You can also'),
                  style:
                      RaftTypography.heading(
                        RaftTokens.of(context),
                        size: 12,
                        line: 16,
                        weight: FontWeight.w400,
                      ).copyWith(
                        color: RaftTokens.of(context).colors['foreground-hint'],
                      ),
                ),
                if (movable.isNotEmpty)
                  _AgentAction(
                    key: ValueKey('account-deletion-move-${computer.id}'),
                    agents: movable,
                    glyph: RaftGlyph.monitor,
                    label: tr('Move to another computer'),
                    // Moving is a Pro feature: the neutral tag the agent's
                    // migration section shows.
                    badge: tr('Pro'),
                    onChoose: (agent) {
                      final stored = storeAgent(agent.id);
                      if (stored != null) {
                        unawaited(move(stored));
                      } else {
                        widget.onMoveElsewhere?.call(group.server, agent.id);
                      }
                    },
                  ),
                _AgentAction(
                  key: ValueKey('account-deletion-archive-${computer.id}'),
                  agents: rowAgents,
                  glyph: RaftGlyph.archive,
                  label: tr('Archive'),
                  onChoose: (agent) => unawaited(archive(agent)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Move to another computer from Delete Account (Web `MoveAgentDialog`): the
/// existing dialog for an agent of the current server. True once a move was
/// started (the list is read again).
Future<bool> showAccountDeletionMove(
  BuildContext context,
  WorkspaceController w,
  Map<String, dynamic> agent,
) async {
  final computers = w.services.entityDirectory.rows(
    WorkspaceEntityKind.computers,
  );
  String? name(Object? id) =>
      computers.where((m) => m['id'] == id).firstOrNull?['name'] as String?;
  final targets = [
    for (final m in computers)
      if (m['isComputer'] == true && m['id'] != agent['machineId']) m,
  ];
  final agentId = '${agent['id']}';
  var started = false, proRequired = false;
  await showRaftForm<void>(
    context,
    builder: (dialog) => AgentMigrationStartDialog(
      targets: targets,
      controller: w,
      sourceMachineId: agent['machineId'] as String?,
      sourceName: name(agent['machineId']),
      openComputers: (_) {},
      start: (target) async {
        try {
          await w.client.post(
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
  // Web handleProRequired: the server is the authority on the plan; the
  // dialog closes and the upgrade prompt takes over.
  if (proRequired && context.mounted) w.setSection('billing');
  return started;
}
