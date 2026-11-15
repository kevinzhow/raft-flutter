// Web components/agent/ActivityQuietFailureRuns.tsx + activityQuietFailures.ts:
// a runtime that cannot start (a used-up quota, a provider outage) ends one
// turn per retry, each with no tool call and no message. Two or more in a row
// fold into one entry ("Usage limit reached · resets … · N attempts"), with
// "Show each turn" to read them one by one.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'agent_activity_summaries.dart';
import 'agent_detail_view.dart' show agentTimeFormatter;
import 'icu_message.dart';

/// Web `isQuietFailure`: a turn that failed having done nothing.
bool isQuietFailure(TurnSummary turn) =>
    turn.outcome == 'failed' &&
    turn.toolCalls == 0 &&
    turn.messagesSent == 0 &&
    turn.lastReplyMessageId == null &&
    turn.sentMessageIds.isEmpty &&
    turn.hiddenSentCount == 0 &&
    turn.problemCount == 0;

/// An item of [groupQuietFailures]: one turn, or a run of two or more.
class QuietFailureItem {
  const QuietFailureItem.turn(TurnSummary this.turn) : turns = null;
  const QuietFailureItem.run(List<TurnSummary> this.turns) : turn = null;
  final TurnSummary? turn;
  final List<TurnSummary>? turns;
}

/// Web `groupQuietFailures`: [turns] in order, with each run of two or more
/// quiet failures in a row as one item. Turns that ended on the usage limit
/// and turns that did not are not one run: they say different things.
List<QuietFailureItem> groupQuietFailures(List<TurnSummary> turns) {
  final items = <QuietFailureItem>[];
  var run = <TurnSummary>[];
  void flush() {
    if (run.length >= 2) {
      items.add(QuietFailureItem.run(run));
    } else {
      items.addAll(run.map(QuietFailureItem.turn));
    }
    run = [];
  }

  for (final turn in turns) {
    if (!isQuietFailure(turn)) {
      flush();
      items.add(QuietFailureItem.turn(turn));
      continue;
    }
    if (run.isNotEmpty && run.first.usageLimit != turn.usageLimit) flush();
    run.add(turn);
  }
  flush();
  return items;
}

/// Web `QuietFailureRun`: one entry for a run of retries that did nothing.
/// [turnBuilder] draws one turn; [badges] the outcome badges of the last.
class QuietFailureRun extends StatefulWidget {
  const QuietFailureRun({
    super.key,
    required this.controller,
    required this.turns,
    required this.turnBuilder,
    required this.badges,
  });
  final WorkspaceController controller;
  final List<TurnSummary> turns;
  final Widget Function(TurnSummary turn) turnBuilder;
  final Widget Function(BuildContext context, TurnSummary turn) badges;

  @override
  State<QuietFailureRun> createState() => _QuietFailureRunState();
}

class _QuietFailureRunState extends State<QuietFailureRun> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final f = agentTimeFormatter(context, widget.controller);
    final turns = widget.turns;
    final first = turns.first, last = turns.last;
    // The latest report wins: a later retry may have heard a newer reset.
    final resetsAt = turns.reversed
        .map((turn) => turn.usageResetsAt)
        .whereType<num>()
        .firstOrNull;
    final summary = last.usageLimit
        ? resetsAt != null
              ? icuText(
                  context,
                  'Usage limit reached · resets {reset} · {count, plural, one {# attempt} other {# attempts}}',
                  {'reset': f.shortDateTime(resetsAt), 'count': turns.length},
                )
              : icuText(
                  context,
                  'Usage limit reached · {count, plural, one {# attempt} other {# attempts}}',
                  {'count': turns.length},
                )
        : raftFormat(
            context,
            '{count} turns in a row ended with an error, with no tools used and no message sent',
            {'count': turns.length},
          );
    return Column(
      key: const ValueKey('activity-overview-retries'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      // ds-allow: Web turn section `gap-2`
      spacing: 8,
      children: [
        Wrap(
          // ds-allow: Web turn heading row `gap-2`
          spacing: 8,
          // ds-allow: Web turn heading row `gap-2`
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            RaftCssText(
              raftFormat(context, '{start}–{end}', {
                'start': f.clock(first.startedAt),
                'end': f.clock(last.endedAt),
              }),
              style: RaftPanelText.boldMono(t),
            ),
            widget.badges(context, last),
          ],
        ),
        RaftCssText(summary, style: RaftPanelText.muted(t)),
        Align(
          alignment: Alignment.centerLeft,
          child: RaftTextLink(
            key: const ValueKey('activity-overview-retries-toggle'),
            label: raftText(context, open ? 'Hide turns' : 'Show each turn'),
            onPressed: () => setState(() => open = !open),
          ),
        ),
        if (open)
          Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: t.colors['border'] ?? t.muted),
              ),
            ),
            // ds-allow: Web `border-l pl-4`
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              // ds-allow: Web `gap-4`
              spacing: 16,
              children: [for (final turn in turns) widget.turnBuilder(turn)],
            ),
          ),
      ],
    );
  }
}
