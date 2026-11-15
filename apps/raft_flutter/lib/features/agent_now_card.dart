// Web components/agent/AgentNowCard.tsx: what the agent is doing now, in
// words, then who the running (else the last) turn answers and what it has
// done. The Activity overview shows it at the bottom, the profile's "Recent
// activity" card (agent_recent_activity.dart) adds the status chip as its
// first line, the last turns one line each and a way to the Activity tab.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_time_formatter.dart';
import '../data/workspace_controller.dart';
import 'agent_activity_summaries.dart';
import 'agent_detail_view.dart' show agentTimeFormatter;
import 'icu_message.dart';

/// Web `useTurnTime`: a clock time today, else a short date and time (a turn
/// three days ago is not "15:53"). "Today" is the viewer's time zone's.
String agentTurnTime(SourceTimeFormatter f, num ms, DateTime now) {
  final at = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
  return f.dayKey(at) == f.dayKey(now) ? f.clock(ms) : f.shortDateTime(ms);
}

class AgentNowCard extends StatefulWidget {
  const AgentNowCard({
    super.key,
    required this.controller,
    required this.activity,
    required this.activityText,
    required this.turns,
    required this.running,
    this.status,
    this.onOpenActivity,
    this.recentRows = 0,
    this.clock,
  });
  final WorkspaceController controller;

  /// The agent's live activity (`online`, `working`, `thinking`, `error`,
  /// `offline`, ...) and the words for it (the header's status line).
  final String activity, activityText;

  /// Finished turns, newest first, and the turn still running.
  final List<TurnSummary> turns;
  final TurnSummary? running;

  /// The profile's status chip row, in place of the headline.
  final Widget? status;
  final VoidCallback? onOpenActivity;

  /// How many finished turns to list under it (the profile); none on the overview.
  final int recentRows;
  final DateTime Function()? clock;

  @override
  State<AgentNowCard> createState() => _AgentNowCardState();
}

class _AgentNowCardState extends State<AgentNowCard> {
  RaftForegroundPeriodic? _second;

  bool get _busy =>
      widget.activity == 'working' || widget.activity == 'thinking';

  /// The 1 s tick only runs while the elapsed time is on screen: a running
  /// turn on a busy agent, no status chip (the chip says it), and a visible
  /// subtree (a tab kept alive but hidden mutes its tickers).
  bool _wanted(BuildContext context) =>
      widget.status == null &&
      _busy &&
      widget.running != null &&
      TickerMode.valuesOf(context).enabled;

  void _sync(BuildContext context) {
    if (_wanted(context)) {
      // A second tick only re-renders; the clock is read when building.
      _second ??= RaftForegroundPeriodic(const Duration(seconds: 1), () {
        if (mounted) setState(() {});
      });
    } else {
      _second?.dispose();
      _second = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(context);
  }

  @override
  void didUpdateWidget(covariant AgentNowCard old) {
    super.didUpdateWidget(old);
    _sync(context);
  }

  @override
  void dispose() {
    _second?.dispose();
    super.dispose();
  }

  Widget _badge(BuildContext context, String label, RaftBadgeRecipeVariant v) =>
      RaftBadge(
        label: raftText(context, label),
        appearance: RaftBadgeRecipeAppearance.soft,
        variant: v,
      );

  /// Web `TurnRowBadges`: how it ended, and that it sent nothing.
  List<Widget> _rowBadges(BuildContext context, TurnSummary turn) {
    final problems = turn.problemsShown;
    return [
      if (turn.outcome == 'failed')
        _badge(context, 'Ended with an error', RaftBadgeRecipeVariant.warning)
      else if (turn.outcome == 'completed' && problems > 0)
        RaftBadge(
          label: icuText(
            context,
            '{count, plural, one {# step} other {# steps}} went wrong',
            {'count': problems},
          ),
          appearance: RaftBadgeRecipeAppearance.soft,
          variant: RaftBadgeRecipeVariant.warning,
        )
      else if (turn.outcome != 'completed')
        _badge(
          context,
          turn.outcome == 'interrupted' ? 'Stopped' : 'Ended, outcome unknown',
          RaftBadgeRecipeVariant.muted,
        ),
      if (turn.lastReplyMessageId == null)
        _badge(context, 'No message sent', RaftBadgeRecipeVariant.muted),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final f = agentTimeFormatter(context, widget.controller);
    final now = (widget.clock ?? DateTime.now)();
    final running = widget.running;
    final last = widget.turns.firstOrNull;
    final activity = widget.activity;
    final busy = _busy;
    final elapsed = running == null
        ? 0
        : now.millisecondsSinceEpoch - running.startedAt.toInt();
    // The running turn's endedAt is when the server read it: the card counts
    // on from its start.
    final headline = busy && running != null
        ? raftFormat(context, '{state} · for {duration}', {
            'state': raftText(context, 'Working'),
            'duration': formatTurnDuration(context, elapsed),
          })
        : activity == 'online' && last != null
        ? raftFormat(context, '{state} · last turn ended {time}', {
            'state': raftText(context, 'Idle'),
            'time': agentTurnTime(f, last.endedAt, now),
          })
        // Any other state reads as the overview always read it (a sign-in, a
        // crash, a limit).
        : widget.activityText;
    final focus = running ?? last;
    final focusLine = focus == null
        ? null
        : raftFormat(
            context,
            running != null
                ? '{trigger} · {actions}'
                : 'Last turn: {trigger} · {actions}',
            {
              'trigger':
                  formatCompactTrigger(context, focus) ??
                  raftText(context, 'a message'),
              'actions': formatTurnActions(
                context,
                focus.actions,
                messagesSent: focus.messagesSent,
              ),
            },
          );
    final skip = running != null ? 0 : 1;
    final rows = widget.recentRows > 0
        ? widget.turns.skip(skip).take(widget.recentRows).toList()
        : const <TurnSummary>[];
    final hasStatus = widget.status != null;
    return RaftNowCard(
      otter: busy
          ? RaftOtterStatus.process
          : activity == 'error'
          ? RaftOtterStatus.error
          : RaftOtterStatus.wait,
      eyebrow: widget.onOpenActivity == null
          ? null
          : raftText(context, 'Recent activity'),
      onOpenEyebrow: widget.onOpenActivity,
      lead: hasStatus
          ? KeyedSubtree(
              key: const ValueKey('agent-now-status'),
              child: widget.status!,
            )
          : RaftCssText(
              headline,
              key: const ValueKey('agent-now-headline'),
              style: t.scale(
                RaftTypeScale.subhead,
                weight: FontWeight.w700,
                color: t.ui.foreground,
              ),
            ),
      // The step it is on: the status chip says it when there is one, and
      // without a running turn the headline already does.
      step:
          !hasStatus &&
              busy &&
              running != null &&
              widget.activityText.isNotEmpty
          ? widget.activityText
          : null,
      focus: focusLine,
      rows: [
        for (final turn in rows)
          RaftNowTurnRow(
            key: ValueKey('agent-now-row-${turn.key}'),
            time: agentTurnTime(f, turn.startedAt, now),
            trigger: formatCompactTrigger(context, turn),
            actions: formatTurnActions(
              context,
              turn.actions,
              messagesSent: turn.messagesSent,
            ),
            badges: _rowBadges(context, turn),
          ),
      ],
    );
  }
}
