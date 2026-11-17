// The Delete Account page's body (Web features/settings/account/
// AccountDeletionChecklist.tsx, v7), from GET /me/account/deletion: one list,
// a row per thing of the person's, "now -> after the deletion":
//
// - Needs action, what holds up the deletion: each server the person is the
//   only owner of, with other members (`soleOwnerServers`, or the 409's list
//   from an older server), gets another Owner here ([SoleOwnerTransferRow]; a
//   handled row stays, marked Handled); then other members' agents on the
//   person's computers ([OthersAgentsOnComputers], from `computers`, or the
//   409 `others_agents_on_computers` until the next read): only their owners
//   can move them, the person can only have Raft notify them. A row goes once
//   its agent has left.
// - The rest happens by itself: the servers that close with the account
//   (`soleMemberServers`); the person's agents, by computer of theirs, then by
//   server (`agents`, `computers`; [AccountDeletionAgentRow], with the
//   optional Move and Archive); paid servers whose billing stops at the end of
//   the period (`paidServersEndingAtPeriodEnd`).
//
// While other people's agents are on the person's computers, Force unbind and
// request deletion is the other way on: it confirms the list and sends the
// request with `forceAgentIds`.
//
// Then "Learn more" (messages, signing out, keys, the profile), the red
// button (off, with the reason under it, until every server is handed over
// and every other member's agent has left the person's computers) and how to
// cancel. With the server's `graceDays` the intro, the button and the cancel
// line say when ("Delete account · Effective November 9"); an older server's
// GET has none, and they name no date.
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'account_deletion_agent_groups.dart';
import 'account_deletion_agent_row.dart';
import 'account_deletion_frame.dart';
import 'account_deletion_rows.dart';

/// The attention dot (`AttentionDot`): a 9px square, ink edge.
class _AttentionDot extends StatelessWidget {
  const _AttentionDot();

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ExcludeSemantics(
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: t.colors['attention-400'],
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: t.colors['sticker-ink']!, width: 1.5),
        ),
      ),
    );
  }
}

/// The list's group labels (Web `GroupLabel`).
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {this.todo = false});
  final String text;
  final bool todo;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
        child: Row(
          spacing: 8,
          children: [
            if (todo) const _AttentionDot(),
            Flexible(
              child: Text(
                text,
                style:
                    RaftTypography.heading(
                      t,
                      size: 13,
                      line: 18,
                      weight: FontWeight.w600,
                    ).copyWith(
                      color: todo
                          ? t.colors['attention-strong']
                          : t.colors['foreground-hint'],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountDeletionChecklistView extends StatefulWidget {
  const AccountDeletionChecklistView({
    super.key,
    required this.controller,
    required this.checklist,
    required this.loaded,
    required this.refusedSoleOwners,
    required this.refusedOthersAgents,
    required this.autoMoveAgentId,
    required this.onAutoMoveHandled,
    required this.onReload,
    required this.onDelete,
    required this.onForceUnbind,
    required this.busy,
    required this.notice,
    this.onOpenServerSettings,
    this.onMoveElsewhere,
    this.now = DateTime.now,
  });
  final WorkspaceController controller;

  /// What GET answered; null before it does, or when it failed (the list is
  /// then the general lines).
  final AccountDeletionChecklist? checklist;

  /// GET has settled, either way: until then Delete account waits.
  final bool loaded;

  /// The 409's servers, when the request was refused (an older server sends
  /// no `soleOwnerServers`).
  final List<SoleOwnerServer> refusedSoleOwners;

  /// The 409's other members' agents on the person's computers; null once a
  /// read lands after it (GET says again).
  final List<AccountDeletionOthersAgent>? refusedOthersAgents;
  final String? autoMoveAgentId;
  final VoidCallback onAutoMoveHandled, onReload, onDelete;

  /// Force unbind and request deletion, confirmed for exactly these agents.
  final void Function(List<String> agentIds) onForceUnbind;
  final bool busy;

  /// A failed request's banner, under the button.
  final Widget notice;
  final void Function(AccountDeletionServer server)? onOpenServerSettings;
  final void Function(AccountDeletionServer server, String agentId)?
  onMoveElsewhere;
  final DateTime Function() now;

  @override
  State<AccountDeletionChecklistView> createState() =>
      _AccountDeletionChecklistState();
}

class _AccountDeletionChecklistState
    extends State<AccountDeletionChecklistView> {
  /// Servers handed over here, kept as done rows after GET stops listing them.
  final transferred =
      <String, ({SoleOwnerServer server, String newOwnerName})>{};
  bool learnMoreOpen = false;

  RaftClient get client => widget.controller.client;

  List<SoleOwnerServer> get listed {
    final fromGet = widget.checklist?.soleOwnerServers ?? const [];
    final ids = {for (final server in fromGet) server.id};
    return [
      ...fromGet,
      for (final server in widget.refusedSoleOwners)
        if (!ids.contains(server.id)) server,
    ];
  }

  void handleTransferred(String serverId, String newOwnerName) {
    final server = listed.where((entry) => entry.id == serverId).firstOrNull;
    if (server == null) return;
    setState(
      () =>
          transferred[serverId] = (server: server, newOwnerName: newOwnerName),
    );
    widget.onReload();
  }

  Future<void> openForce(List<AccountDeletionOthersAgent> agents) async {
    // The force list is frozen when the dialog opens: the request sends
    // exactly what it showed.
    String tr(String s) => raftText(context, s);
    await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('account-deletion-force-dialog'),
        confirmKey: const ValueKey('force-unbind-confirm'),
        title: raftFormat(
          context,
          agents.length == 1
              ? 'Force unbind {count} agent?'
              : 'Force unbind {count} agents?',
          {'count': agents.length},
        ),
        content: RaftForceUnbindAgentList(
          message: tr(
            'Their workspaces on your computers are lost. The agents themselves stay, with their messages and settings, and their owners can keep using them on another computer. Each owner gets a system notice.',
          ),
          listLabel: tr('Agents to unbind'),
          agents: [
            for (final agent in agents)
              (
                id: agent.id,
                name: agent.name,
                meta: agent.owner == null
                    ? raftFormat(context, 'No owner · {computerName}', {
                        'computerName': agent.computer.name,
                      })
                    : raftFormat(
                        context,
                        'Owner: {ownerName} · {computerName}',
                        {
                          'ownerName': agent.owner!.name,
                          'computerName': agent.computer.name,
                        },
                      ),
              ),
          ],
        ),
        confirmLabel: tr('Force unbind and request deletion'),
        loadingLabel: tr('Unbinding…'),
        confirmVariant: RaftButtonRecipeVariant.danger,
        onConfirm: () async =>
            widget.onForceUnbind([for (final agent in agents) agent.id]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final t = RaftTokens.of(context);
    final checklist = widget.checklist;
    final mustResolve =
        [
          ...listed,
          for (final entry in transferred.values)
            if (!listed.any((server) => server.id == entry.server.id))
              entry.server,
        ]..sort((a, b) {
          final byName = a.name.compareTo(b.name);
          return byName != 0 ? byName : a.id.compareTo(b.id);
        });
    final blocking = [
      for (final server in listed)
        if (!transferred.containsKey(server.id)) server,
    ];
    final othersAgents = widget.refusedOthersAgents != null
        ? ([...widget.refusedOthersAgents!]
            ..sort(accountDeletionOthersAgentOrder))
        : accountDeletionOthersAgents(checklist);
    final needsAction = blocking.length + othersAgents.length;

    // v7: the date a request made now takes effect, from the server's grace
    // period (never counted here).
    final graceDays = checklist?.graceDays;
    final effectiveDate = graceDays == null
        ? ''
        : accountDeletionDate(
            context,
            widget.now().add(Duration(days: graceDays)).toIso8601String(),
          );
    final newOwners = {
      for (final entry in transferred.entries)
        entry.key: entry.value.newOwnerName,
    };
    final agentGroups = accountDeletionAgentGroups(checklist, newOwners);
    final soleMemberServers = checklist?.soleMemberServers ?? const [];
    final paidServers = checklist?.paidServersEndingAtPeriodEnd ?? const [];
    // The general agents line stands in when GET didn't list them (an older
    // server, or a failed read).
    final automatic =
        soleMemberServers.length +
        (agentGroups == null ? 1 : agentGroups.length) +
        paidServers.length;
    var effectRows = 0;
    bool firstEffect() => effectRows++ == 0;

    final body = Text(
      graceDays == null
          ? tr(
              "Here's what happens to your servers and agents when the deletion takes effect.",
            )
          : accountDeletionCountText(
              context,
              graceDays,
              "It takes effect {count} day after you confirm. Here's what happens to your servers and agents then.",
              "It takes effect {count} days after you confirm. Here's what happens to your servers and agents then.",
            ),
      key: const ValueKey('account-deletion-lead'),
      style: RaftTypography.heading(
        t,
        size: 15,
        line: 22,
        weight: FontWeight.w400,
      ).copyWith(color: t.muted),
    );
    final rowsStyleHint = RaftTypography.heading(
      t,
      size: 14,
      line: 20,
      weight: FontWeight.w400,
    ).copyWith(color: t.muted);

    return Column(
      key: const ValueKey('account-deletion-page'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 20,
      children: [
        body,
        RaftCard(
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (needsAction > 0)
                _GroupLabel(
                  raftFormat(context, 'Needs action ({count})', {
                    'count': needsAction,
                  }),
                  todo: true,
                ),
              if (mustResolve.isNotEmpty)
                Column(
                  key: const ValueKey('account-deletion-must-resolve'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, server) in mustResolve.indexed)
                      SoleOwnerTransferRow(
                        key: ValueKey(
                          'account-deletion-transfer-row-${server.id}',
                        ),
                        client: client,
                        server: server,
                        first: index == 0,
                        newOwnerName: transferred[server.id]?.newOwnerName,
                        onTransferred: handleTransferred,
                        onOpenServerSettings: widget.onOpenServerSettings,
                      ),
                  ],
                ),
              if (othersAgents.isNotEmpty)
                OthersAgentsOnComputers(
                  client: client,
                  agents: othersAgents,
                  onChanged: widget.onReload,
                ),
              if (needsAction > 0 && automatic > 0) ...[
                const SizedBox(height: 12),
                _GroupLabel(
                  raftFormat(
                    context,
                    'The rest happens automatically ({count})',
                    {'count': automatic},
                  ),
                ),
              ],
              DecoratedBox(
                key: const ValueKey('account-deletion-effects'),
                // Handled rows above with no group labels: the hairline
                // between the two lists, as between rows.
                decoration: BoxDecoration(
                  border: mustResolve.isNotEmpty && needsAction == 0
                      ? Border(
                          top: BorderSide(color: t.colors['line-hairline']!),
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final server in soleMemberServers)
                      AccountDeletionChecklistRow(
                        key: ValueKey(
                          'account-deletion-sole-member-${server.id}',
                        ),
                        first: firstEffect(),
                        glyph: RaftGlyph.building2,
                        name: server.name,
                        detail: tr('Only you'),
                        outcome: Text(
                          tr(
                            'Closes, and its channels and files can no longer be opened',
                          ),
                        ),
                      ),
                    if (agentGroups == null)
                      AccountDeletionChecklistRow(
                        key: const ValueKey('account-deletion-agents-general'),
                        first: firstEffect(),
                        glyph: RaftGlyph.bot,
                        name: tr('Your agents'),
                        outcome: Text(
                          tr(
                            "Go to their server's Owner; your personal assistant is archived",
                          ),
                        ),
                        children: [
                          AccountDeletionRowNote(tr('They stop now.')),
                        ],
                      )
                    else
                      for (final group in agentGroups)
                        AccountDeletionAgentRow(
                          key: ValueKey(
                            'account-deletion-agent-row-${group.key}',
                          ),
                          controller: widget.controller,
                          group: group,
                          first: firstEffect(),
                          autoMoveAgentId: widget.autoMoveAgentId,
                          onAutoMoveHandled: widget.onAutoMoveHandled,
                          onChanged: widget.onReload,
                          onMoveElsewhere: widget.onMoveElsewhere,
                        ),
                    for (final server in paidServers)
                      AccountDeletionChecklistRow(
                        key: ValueKey('account-deletion-paid-${server.id}'),
                        first: firstEffect(),
                        glyph: RaftGlyph.creditCard,
                        name: raftFormat(context, 'Billing for {serverName}', {
                          'serverName': server.name,
                        }),
                        detail: tr('Paid by you'),
                        outcome: Text(
                          server.periodEnd == null
                              ? tr(
                                  'Billing stops at the end of the current period',
                                )
                              : raftFormat(context, 'Billing stops on {date}', {
                                  'date': accountDeletionDate(
                                    context,
                                    server.periodEnd,
                                  ),
                                }),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RaftButton(
              key: const ValueKey('account-deletion-more-toggle'),
              label: tr('Learn more: messages, sign-in and keys'),
              glyph: learnMoreOpen
                  ? RaftGlyph.chevronDown
                  : RaftGlyph.chevronRight,
              variant: RaftControlVariant.ghost,
              onPressed: () => setState(() => learnMoreOpen = !learnMoreOpen),
            ),
            if (learnMoreOpen)
              Padding(
                key: const ValueKey('account-deletion-more'),
                padding: const EdgeInsets.fromLTRB(20, 10, 0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    for (final line in const [
                      'Messages you sent stay, shown as “Deleted user”.',
                      "Once you confirm, you're signed out on every device.",
                      "Your computers' and agents' keys stop working right away; on the deletion date your computers are deleted.",
                      'On the deletion date your profile and avatar are deleted.',
                    ])
                      Text('•  ${tr(line)}', style: rowsStyleHint),
                  ],
                ),
              ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            RaftButton(
              key: const ValueKey('account-deletion-confirm'),
              label: effectiveDate.isEmpty
                  ? tr('Delete account')
                  : raftFormat(context, 'Delete account · Effective {date}', {
                      'date': effectiveDate,
                    }),
              glyph: RaftGlyph.trash2,
              variant: RaftControlVariant.danger,
              size: RaftButtonRecipeSize.lg,
              expand: true,
              busy: widget.busy,
              onPressed: !widget.loaded || needsAction > 0 || widget.busy
                  ? null
                  : widget.onDelete,
            ),
            if (needsAction > 0)
              Column(
                key: const ValueKey('account-deletion-why'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 4,
                children: [
                  if (blocking.isNotEmpty)
                    _Why(
                      raftFormat(
                        context,
                        'First choose a new Owner for {servers}',
                        {
                          'servers': accountDeletionList(context, [
                            for (final server in blocking) server.name,
                          ]),
                        },
                      ),
                    ),
                  if (othersAgents.isNotEmpty)
                    _Why(
                      key: const ValueKey('account-deletion-why-others-agents'),
                      accountDeletionCountText(
                        context,
                        othersAgents.length,
                        "First wait for {count} other person's agent to leave your computers",
                        "First wait for {count} other people's agents to leave your computers",
                      ),
                    ),
                ],
              ),
            if (othersAgents.isNotEmpty)
              RaftButton(
                key: const ValueKey('account-deletion-force-unbind'),
                label: tr('Force unbind and request deletion'),
                glyph: RaftGlyph.unlink,
                // An ink border: only the dialog's own confirm is red.
                variant: RaftControlVariant.outline,
                size: RaftButtonRecipeSize.lg,
                expand: true,
                // Only the server's other block left: forcing can't get past
                // a server to hand over.
                onPressed: !widget.loaded || blocking.isNotEmpty || widget.busy
                    ? null
                    : () => openForce(othersAgents),
              ),
            Row(
              spacing: 6,
              children: [
                ExcludeSemantics(
                  child: RaftIcon(
                    RaftGlyph.undo2,
                    size: 16,
                    color: t.colors['foreground-hint'],
                  ),
                ),
                Expanded(
                  child: Text(
                    graceDays == null
                        ? tr('Sign in before the deletion date to cancel')
                        : accountDeletionCountText(
                            context,
                            graceDays,
                            'Sign in within {count} day to cancel',
                            'Sign in within {count} days to cancel',
                          ),
                    style: rowsStyleHint,
                  ),
                ),
              ],
            ),
            widget.notice,
          ],
        ),
      ],
    );
  }
}

class _Why extends StatelessWidget {
  const _Why(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Row(
      spacing: 8,
      children: [
        const _AttentionDot(),
        Expanded(
          child: Text(
            text,
            style: RaftTypography.heading(
              t,
              size: 14,
              line: 20,
              weight: FontWeight.w400,
            ).copyWith(color: t.semantic.foreground),
          ),
        ),
      ],
    );
  }
}
