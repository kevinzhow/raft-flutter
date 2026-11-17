// The rows of Delete Account's list (Web features/settings/account/
// AccountDeletionChecklistRow.tsx, SoleOwnerTransferRow.tsx,
// OthersAgentsOnComputers.tsx, v7): a thing of the person's, as it is now (a
// name, a line under it), an arrow, and what becomes of it (a sentence, and
// anything the row needs under that: a line, a control, optional actions).
// Four columns on a wider screen; on a phone the arrow and the outcome go
// under the name.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'agent_owner_notify.dart';

enum AccountDeletionRowTone { normal, todo, done }

/// Web `AccountDeletionChecklistRow`.
class AccountDeletionChecklistRow extends StatelessWidget {
  const AccountDeletionChecklistRow({
    super.key,
    required this.glyph,
    required this.name,
    required this.outcome,
    this.tone = AccountDeletionRowTone.normal,
    this.detail,
    this.children = const [],
    this.first = false,
  });
  final RaftGlyph glyph;

  /// `todo`: it holds up the deletion; `done`: it did, and is handled.
  final AccountDeletionRowTone tone;

  /// What it is now, and a line under it.
  final String name;
  final String? detail;

  /// What becomes of it: a sentence, or [outcomeWidget]-style content.
  final Widget outcome;

  /// Under the outcome: a line, a control, optional actions.
  final List<Widget> children;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 640;
    final iconColor = switch (tone) {
      AccountDeletionRowTone.todo => t.colors['attention-strong']!,
      AccountDeletionRowTone.done => t.colors['success-strong']!,
      AccountDeletionRowTone.normal => t.muted,
    };
    final nameText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: RaftTypography.heading(
            t,
            size: 14,
            line: 20,
            weight: FontWeight.w600,
          ).copyWith(color: t.semantic.foreground),
        ),
        if (detail != null)
          Text(
            detail!,
            style: RaftTypography.heading(
              t,
              size: 13,
              line: 18,
              weight: FontWeight.w400,
            ).copyWith(color: t.muted),
          ),
      ],
    );
    final arrow = ExcludeSemantics(
      child: RaftIcon(
        RaftGlyph.arrowRight,
        size: 16,
        color: t.colors['foreground-hint'] ?? t.muted,
      ),
    );
    final outcomeColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        DefaultTextStyle.merge(
          style: RaftTypography.heading(
            t,
            size: 14,
            line: 20,
            weight: FontWeight.w400,
          ).copyWith(color: t.semantic.foreground),
          child: outcome,
        ),
        ...children,
      ],
    );
    final icon = Padding(
      padding: const EdgeInsets.only(top: 2),
      child: ExcludeSemantics(
        child: RaftIcon(glyph, size: 16, color: iconColor),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(top: BorderSide(color: t.colors['line-hairline']!)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 20, child: icon),
                  const SizedBox(width: 12),
                  Expanded(flex: 5, child: nameText),
                  const SizedBox(width: 12),
                  Padding(padding: const EdgeInsets.only(top: 4), child: arrow),
                  const SizedBox(width: 12),
                  Expanded(flex: 7, child: outcomeColumn),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 20, child: icon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        nameText,
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: arrow,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: outcomeColumn),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A line under a row's outcome (Web `AccountDeletionRowNote`).
class AccountDeletionRowNote extends StatelessWidget {
  const AccountDeletionRowNote(this.text, {super.key, this.danger = false});
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Text(
      text,
      style: RaftTypography.heading(
        t,
        size: 13,
        line: 18,
        weight: FontWeight.w400,
      ).copyWith(color: danger ? t.colors['danger-strong']! : t.muted),
    );
  }
}

/// A server the person is the only owner of, with other members: the one thing
/// that holds up the deletion (v7). It must get another Owner first. The
/// choice lists that server's people (not the person, not guests); Make owner
/// is the member-role change Settings > Administration > Admins makes. Once
/// it is done the row turns into its outcome, marked Handled, and the list
/// reads the deletion again.
class SoleOwnerTransferRow extends StatefulWidget {
  const SoleOwnerTransferRow({
    super.key,
    required this.client,
    required this.server,
    required this.newOwnerName,
    required this.onTransferred,
    this.onOpenServerSettings,
    this.first = false,
  });
  final RaftClient client;
  final SoleOwnerServer server;

  /// Set once an Owner was made here: the row is done.
  final String? newOwnerName;
  final void Function(String serverId, String newOwnerName) onTransferred;

  /// Opens that server's settings (Web: a link to `/s/<slug>/settings/server`).
  final void Function(AccountDeletionServer server)? onOpenServerSettings;
  final bool first;

  @override
  State<SoleOwnerTransferRow> createState() => _SoleOwnerTransferRowState();
}

class _SoleOwnerTransferRowState extends State<SoleOwnerTransferRow> {
  List<TransferCandidate>? candidates;
  bool loadFailed = false, busy = false, failed = false;
  String? chosen;
  bool live = true;

  bool get done => widget.newOwnerName != null;

  @override
  void initState() {
    super.initState();
    if (!done) unawaited(load());
  }

  @override
  void dispose() {
    live = false;
    super.dispose();
  }

  Future<void> load() async {
    try {
      final list = await widget.client.accountDeletionTransferCandidates(
        widget.server.id,
        widget.client.user?.id,
      );
      if (live) setState(() => candidates = list);
    } catch (_) {
      if (live) setState(() => loadFailed = true);
    }
  }

  Future<void> transfer() async {
    final candidate = candidates
        ?.where((entry) => entry.userId == chosen)
        .firstOrNull;
    if (candidate == null || busy) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await widget.client.makeServerOwner(widget.server.id, candidate.userId);
      widget.onTransferred(widget.server.id, candidate.name);
    } catch (_) {
      if (live) {
        setState(() {
          busy = false;
          failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final server = widget.server;
    final others = server.memberCount - 1 < 1 ? 1 : server.memberCount - 1;
    final noCandidates = candidates != null && candidates!.isEmpty;
    return AccountDeletionChecklistRow(
      key: ValueKey('account-deletion-transfer-${server.id}'),
      first: widget.first,
      glyph: done ? RaftGlyph.circleCheck : RaftGlyph.crown,
      tone: done ? AccountDeletionRowTone.done : AccountDeletionRowTone.todo,
      name: server.name,
      detail: accountDeletionCountText(
        context,
        others,
        done
            ? '{count} other member'
            : "{count} other member, and you're the only Owner",
        done
            ? '{count} other members'
            : "{count} other members, and you're the only Owner",
      ),
      outcome: done
          ? Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  raftFormat(
                    context,
                    'Goes to {memberName}, who manages it from now on',
                    {'memberName': widget.newOwnerName},
                  ),
                ),
                RaftBadge(
                  label: tr('Handled'),
                  appearance: RaftBadgeRecipeAppearance.soft,
                  variant: RaftBadgeRecipeVariant.success,
                  glyph: RaftGlyph.check,
                ),
              ],
            )
          : Text(tr('Choose a new Owner to take it over first')),
      children: [
        if (!done && noCandidates)
          Wrap(
            spacing: 4,
            children: [
              AccountDeletionRowNote(
                tr(
                  'No one here can become an Owner. Delete the server instead.',
                ),
              ),
              if (widget.onOpenServerSettings != null)
                RaftTextLink(
                  key: ValueKey('account-deletion-open-settings-${server.id}'),
                  label: tr('Open server settings'),
                  onPressed: () => widget.onOpenServerSettings!(server),
                ),
            ],
          )
        else if (!done)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 160,
                    maxWidth: 240,
                  ),
                  child: RaftSelectField<String>(
                    key: ValueKey(
                      'account-deletion-transfer-select-${server.id}',
                    ),
                    label: raftFormat(context, 'New owner of {serverName}', {
                      'serverName': server.name,
                    }),
                    placeholder: tr('Transfer to…'),
                    value: chosen,
                    items: [
                      for (final candidate
                          in candidates ?? const <TransferCandidate>[])
                        RaftSelectItem(
                          value: candidate.userId,
                          label: candidate.name,
                        ),
                    ],
                    onChanged: busy || candidates == null
                        ? null
                        : (value) => setState(() {
                            chosen = value;
                            failed = false;
                          }),
                  ),
                ),
                RaftButton(
                  key: ValueKey(
                    'account-deletion-transfer-confirm-${server.id}',
                  ),
                  label: tr('Make owner'),
                  variant: RaftControlVariant.outline,
                  size: RaftButtonRecipeSize.lg,
                  busy: busy,
                  loadingLabel: tr('Making owner…'),
                  onPressed: chosen == null || busy ? null : transfer,
                ),
              ],
            ),
          ),
        if (loadFailed)
          AccountDeletionRowNote(
            tr("Couldn't load this server's members."),
            danger: true,
          ),
        if (failed)
          AccountDeletionRowNote(
            tr("Couldn't make them an Owner. Try again."),
            danger: true,
          ),
      ],
    );
  }
}

/// The count's one / other sentence (the catalog does not interpret ICU).
String accountDeletionCountText(
  BuildContext context,
  int count,
  String one,
  String other,
) => raftFormat(context, count == 1 ? one : other, {'count': count});

/// Delete Account's Needs action group "Other people's agents on your
/// computers": another member's agent bound to one of the person's computers.
/// The request revokes the computer's keys at once, so the agent has to leave
/// first, and only its owner can move it. The person's one action is Notify
/// owner to move it: Raft sends the owner a system message (once per agent per
/// 24 hours; the person sends nothing themselves). A row goes once GET stops
/// listing the agent (it moved). With no owner nobody is notified: the button
/// stays off and only the who-can-act line shows.
class OthersAgentsOnComputers extends StatefulWidget {
  const OthersAgentsOnComputers({
    super.key,
    required this.client,
    required this.agents,
    required this.onChanged,
  });
  final RaftClient client;

  /// The agents still on the person's computers: GET's, or the 409's until
  /// the next read.
  final List<AccountDeletionOthersAgent> agents;

  /// A notify call settled: read the list again.
  final VoidCallback onChanged;

  @override
  State<OthersAgentsOnComputers> createState() =>
      _OthersAgentsOnComputersState();
}

class _OthersAgentsOnComputersState extends State<OthersAgentsOnComputers> {
  late final AgentOwnerNotifier notifier = AgentOwnerNotifier(
    send: (ids) async {
      try {
        return await postNotifyAgentOwners(
          (method, path, {data}) =>
              widget.client.request(method, path, data: data),
          accountDeletionNotifyPath,
          ids,
        );
      } finally {
        // Answered or refused: read the list again.
        if (mounted) widget.onChanged();
      }
    },
  );

  @override
  void dispose() {
    notifier.dispose();
    super.dispose();
  }

  OthersAgent othersAgent(AccountDeletionOthersAgent agent) => OthersAgent(
    id: agent.id,
    name: agent.name,
    owner: agent.owner,
    ownerNotifiedAt: agent.ownerNotifiedAt,
    ownerNextNotifyAt: agent.ownerNextNotifyAt,
    personalAssistant: agent.personalAssistant,
  );

  /// Web `canNotifyNow`: an owner that may be reminded now.
  bool canNotifyNow(OthersAgent agent) =>
      notifier.ownerNow(agent) != null &&
      !notifier.nextReminder(agent).limited &&
      !notifier.busy.contains(agent.id);

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final t = RaftTokens.of(context);
    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        final agents = [for (final a in widget.agents) othersAgent(a)];
        final notifiable = [
          for (final agent in agents)
            if (canNotifyNow(agent)) agent.id,
        ];
        final withOwner = agents
            .where((agent) => notifier.ownerNow(agent) != null)
            .length;
        return Column(
          key: const ValueKey('account-deletion-others-agents'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text(
                    tr("Other people's agents on your computers"),
                    style: RaftTypography.heading(
                      t,
                      size: 13,
                      line: 18,
                      weight: FontWeight.w600,
                    ).copyWith(color: t.muted),
                  ),
                  if (withOwner > 1)
                    RaftButton(
                      key: const ValueKey('account-deletion-notify-all'),
                      label: tr('Notify all owners'),
                      glyph: RaftGlyph.send,
                      variant: RaftControlVariant.ghost,
                      onPressed: notifiable.isEmpty
                          ? null
                          : () => notifier.notify(notifiable),
                    ),
                ],
              ),
            ),
            for (final (index, agent) in widget.agents.indexed)
              AccountDeletionChecklistRow(
                key: ValueKey('account-deletion-others-agent-${agent.id}'),
                first: index == 0,
                glyph: RaftGlyph.bot,
                tone: AccountDeletionRowTone.todo,
                name: agent.name,
                detail: _otherAgentDetail(
                  context,
                  agent,
                  notifier.ownerNow(othersAgent(agent)),
                ),
                outcome: Text(tr('Has to move to another computer first')),
                children: [
                  AgentOwnerNotifyActions(
                    agent: othersAgent(agent),
                    notifier: notifier,
                    testIdPrefix: 'account-deletion',
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

String _otherAgentDetail(
  BuildContext context,
  AccountDeletionOthersAgent agent,
  AgentOwner owner,
) {
  final values = {
    'ownerName': owner?.name,
    'serverName': agent.server.name,
    'computerName': agent.computer.name,
  };
  return raftFormat(
    context,
    owner == null
        ? 'No owner · {serverName} · {computerName}'
        : 'Owner: {ownerName} · {serverName} · {computerName}',
    values,
  );
}
