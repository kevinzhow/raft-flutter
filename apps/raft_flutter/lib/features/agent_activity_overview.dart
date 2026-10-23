// Web components/agent/AgentActivityOverview.tsx: the Activity tab's
// "Overview" (flag `activity_overview_web_v0`): what the agent is doing now,
// then one block per finished turn, newest first, from the per-turn summaries
// (`GET /agents/:id/activity-summaries`). Detail stays in the raw log.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_time_formatter.dart';
import '../data/workspace_controller.dart';
import 'agent_activity_summaries.dart';
import 'agent_detail_view.dart' show agentTimeFormatter;
import 'icu_message.dart';

enum _Load { loading, loaded, error }

class AgentActivityOverview extends StatefulWidget {
  const AgentActivityOverview({
    super.key,
    required this.controller,
    required this.agentId,
    required this.activity,
    required this.activityText,
    required this.hasRawActivity,
    required this.onShowRaw,
    this.machineId,
    this.onOpenComputer,
  });
  final WorkspaceController controller;
  final String agentId;

  /// The agent's live `activity` and its words (the header's status line).
  final String activity, activityText;
  final String? machineId;
  final bool hasRawActivity;
  final VoidCallback onShowRaw;
  final ValueChanged<String>? onOpenComputer;

  @override
  State<AgentActivityOverview> createState() => _AgentActivityOverviewState();
}

class _AgentActivityOverviewState extends State<AgentActivityOverview> {
  WorkspaceController get w => widget.controller;
  List<TurnSummary> turns = const [];
  String? next;
  _Load status = _Load.loading;
  StreamSubscription<RaftEvent>? _events;
  Timer? _reload;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _events = w.client.events.listen(_event);
    unawaited(_loadLatest());
  }

  @override
  void didUpdateWidget(covariant AgentActivityOverview old) {
    super.didUpdateWidget(old);
    if (old.agentId != widget.agentId) {
      turns = const [];
      next = null;
      status = _Load.loading;
      unawaited(_loadLatest());
    }
  }

  @override
  void dispose() {
    _request++;
    _reload?.cancel();
    _events?.cancel();
    super.dispose();
  }

  /// A finished turn arrives with the agent's activity push, and a reconnect
  /// may have missed some: refresh the same way the raw log does.
  void _event(RaftEvent e) {
    final p = e.payload;
    final live =
        e.name == 'agent:activity' &&
        p is Map &&
        p['agentId'] == widget.agentId &&
        p['isHeartbeat'] != true;
    if (!live && e.name != 'connected') return;
    _reload?.cancel();
    _reload = Timer(const Duration(milliseconds: 500), () {
      if (mounted) unawaited(_loadLatest());
    });
  }

  Future<void> _loadLatest() async {
    final request = ++_request, id = widget.agentId;
    try {
      final result = await w.query(
        '/agents/$id/activity-summaries',
        query: {'limit': '$activitySummariesPageSize'},
      );
      if (!mounted || request != _request) return;
      final rows = result is Map ? result['summaries'] : null;
      setState(() {
        turns = [
          for (final r in rows as List? ?? const []) ?TurnSummary.tryParse(r),
        ];
        next = result is Map && result['next'] is String
            ? result['next'] as String
            : null;
        status = _Load.loaded;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      // A failed refresh never replaces turns already shown.
      if (status != _Load.loaded) setState(() => status = _Load.error);
    }
  }

  Future<void> _loadEarlier() async {
    final before = next, id = widget.agentId;
    if (before == null) return;
    try {
      final result = await w.query(
        '/agents/$id/activity-summaries',
        query: {'limit': '$activitySummariesPageSize', 'before': before},
      );
      if (!mounted || id != widget.agentId) return;
      final rows = result is Map ? result['summaries'] : null;
      setState(() {
        turns = [
          ...turns,
          for (final r in rows as List? ?? const []) ?TurnSummary.tryParse(r),
        ];
        next = result is Map && result['next'] is String
            ? result['next'] as String
            : null;
      });
    } catch (_) {}
  }

  Widget _empty(
    BuildContext context, {
    required String title,
    String? description,
    Widget? action,
  }) => RaftProductEmptyState(
    title: raftText(context, title),
    description: description == null ? null : raftText(context, description),
    icon: (context, size, color) =>
        RaftIcon(RaftGlyph.activity, size: size, color: color),
    action: action,
  );

  @override
  Widget build(BuildContext context) {
    if (status == _Load.error) {
      return _empty(
        context,
        title: "Couldn't load the overview.",
        action: RaftButton(
          key: const ValueKey('activity-overview-retry'),
          label: raftText(context, 'Retry'),
          tone: RaftButtonRecipeVariant.outline,
          size: RaftButtonRecipeSize.sm,
          onPressed: () => unawaited(_loadLatest()),
        ),
      );
    }
    // While loading Web shows the Now card alone (no turns yet).
    final loaded = status == _Load.loaded;
    if (loaded && turns.isEmpty && !widget.hasRawActivity) {
      return _empty(
        context,
        title: 'No activity yet',
        description: 'Start the agent to see its activity log.',
      );
    }
    if (loaded && turns.isEmpty) {
      final machineId = widget.machineId;
      return _empty(
        context,
        title: 'No overview yet',
        description: machineId != null
            ? "The overview shows one line per finished turn. The Raft on this agent's computer needs an upgrade before it records turns."
            : "The overview shows one line per finished turn. This agent hasn't reported any turns yet.",
        action: Wrap(
          alignment: WrapAlignment.center,
          // ds-allow: Web empty-state action row `gap-2`
          spacing: 8,
          // ds-allow: Web empty-state action row `gap-2`
          runSpacing: 8,
          children: [
            if (machineId != null && widget.onOpenComputer != null)
              RaftButton(
                key: const ValueKey('activity-overview-open-computer'),
                label: raftText(context, 'Open the computer to upgrade'),
                tone: RaftButtonRecipeVariant.outline,
                size: RaftButtonRecipeSize.sm,
                onPressed: () => widget.onOpenComputer!(machineId),
              ),
            RaftButton(
              key: const ValueKey('activity-overview-show-raw'),
              label: raftText(context, 'Show raw log'),
              tone: RaftButtonRecipeVariant.outline,
              size: RaftButtonRecipeSize.sm,
              onPressed: widget.onShowRaw,
            ),
          ],
        ),
      );
    }
    return ListView(
      key: const ValueKey('activity-overview'),
      // ds-allow: Web `px-4 py-4` of the overview scroller
      padding: raftScrollPadding(context, const EdgeInsets.all(16)),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          // ds-allow: Web overview `gap-6`
          spacing: 24,
          children: [
            _NowCard(
              controller: w,
              turns: turns,
              activityText: widget.activityText,
              activity: widget.activity,
            ),
            for (final turn in turns)
              _TurnSection(
                key: ValueKey(
                  'turn-${turn.id ?? '${turn.startedAt}-${turn.endedAt}'}',
                ),
                controller: w,
                turn: turn,
              ),
            if (next != null)
              Align(
                alignment: Alignment.centerLeft,
                child: RaftButton(
                  key: const ValueKey('activity-overview-load-more'),
                  label: raftText(context, 'Show earlier turns'),
                  size: RaftButtonRecipeSize.sm,
                  onPressed: () => unawaited(_loadEarlier()),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _NowCard extends StatelessWidget {
  const _NowCard({
    required this.controller,
    required this.turns,
    required this.activityText,
    required this.activity,
  });
  final WorkspaceController controller;
  final List<TurnSummary> turns;
  final String activityText, activity;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final f = agentTimeFormatter(context, controller);
    final last = turns.firstOrNull;
    final trigger = last == null ? null : formatTurnTrigger(context, last);
    final steps = turns.fold<int>(0, (sum, turn) => sum + turn.toolCalls);
    final problems = turns.fold<int>(
      0,
      (sum, turn) => sum + turn.problemsShown,
    );
    final hint = t.colors['foreground-hint'] ?? t.muted;
    return RaftSurfaceListItem(
      key: const ValueKey('activity-overview-now'),
      interactive: false,
      // ds-allow: Web Card `py-5` content with `gap-4`
      padding: const EdgeInsets.all(20),
      child: Row(
        // ds-allow: Web Now card `gap-4`
        spacing: 16,
        children: [
          RaftActivityDot(color: raftActivityDotColor(t, activity)),
          Expanded(
            child: RaftGapColumn(
              gap: 4,
              children: [
                RaftCssText(activityText, style: RaftPanelText.bold(t)),
                if (last != null)
                  RaftCssText(
                    trigger == null
                        ? raftFormat(context, 'Last turn ended at {time}', {
                            'time': f.clock(last.endedAt),
                          })
                        : raftFormat(
                            context,
                            'Last turn ended at {time}: {trigger}',
                            {'time': f.clock(last.endedAt), 'trigger': trigger},
                          ),
                    style: RaftPanelText.muted(t),
                  ),
                if (turns.isNotEmpty)
                  RaftCssText(
                    icuText(
                      context,
                      '{turns, plural, one {# turn} other {# turns}} below · {steps, plural, one {# step} other {# steps}} · {problems, plural, =0 {nothing went wrong} one {# step went wrong} other {# steps went wrong}}',
                      {
                        'turns': turns.length,
                        'steps': steps,
                        'problems': problems,
                      },
                    ),
                    style: RaftPanelText.caption(t).copyWith(color: hint),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnSection extends StatelessWidget {
  const _TurnSection({super.key, required this.controller, required this.turn});
  final WorkspaceController controller;
  final TurnSummary turn;

  Widget _outcome(BuildContext context) {
    final problems = turn.problemsShown;
    if (turn.outcome == 'completed' && problems == 0) {
      return RaftRecipeBadge(
        raftText(context, 'Done'),
        variant: RaftBadgeRecipeVariant.success,
      );
    }
    if (turn.outcome == 'completed') {
      // Steps that went wrong along the way are not a failed turn: amber.
      return RaftRecipeBadge(
        icuText(
          context,
          'Done, {count, plural, one {# step} other {# steps}} went wrong',
          {'count': problems},
        ),
        variant: RaftBadgeRecipeVariant.warning,
      );
    }
    if (turn.outcome == 'failed') {
      return RaftRecipeBadge(
        raftText(context, 'Ended with an error'),
        variant: RaftBadgeRecipeVariant.warning,
      );
    }
    return RaftRecipeBadge(
      raftText(
        context,
        turn.outcome == 'interrupted' ? 'Stopped' : 'Ended, outcome unknown',
      ),
      variant: RaftBadgeRecipeVariant.muted,
    );
  }

  String _problem(BuildContext context, TurnProblem p, SourceTimeFormatter f) {
    final time = f.clock(p.at);
    if (p.reason == 'send_held') {
      return raftFormat(
        context,
        '{time} a message was held as a draft: there were unread messages first',
        {'time': time},
      );
    }
    if (p.reason == 'exit_nonzero' && p.kind == 'run_checks') {
      return raftFormat(context, '{time} some tests or checks failed', {
        'time': time,
      });
    }
    if (p.reason == 'exit_nonzero') {
      return raftFormat(context, '{time} a command exited with code {code}', {
        'time': time,
        'code': p.exitCode ?? '',
      });
    }
    return raftFormat(context, '{time} a tool call failed', {'time': time});
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final f = agentTimeFormatter(context, controller);
    final range = formatClockRange(
      f.clock(turn.startedAt),
      f.clock(turn.endedAt),
    );
    final trigger = formatTurnTrigger(context, turn);
    final duration = formatTurnDuration(context, turn.endedAt - turn.startedAt);
    final hint = t.colors['foreground-hint'] ?? t.muted;
    final more = turn.problemCount - turn.problems.length;
    return Column(
      key: const ValueKey('activity-overview-turn'),
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
              range.end == null
                  ? range.start
                  : raftFormat(context, '{start}–{end}', {
                      'start': range.start,
                      'end': range.end,
                    }),
              style: RaftPanelText.boldMono(t),
            ),
            // The outcome sits right after the time so it stays on the first line.
            _outcome(context),
            RaftCssText(
              trigger == null
                  ? raftFormat(context, 'took {duration}', {
                      'duration': duration,
                    })
                  : raftFormat(context, '{trigger} · took {duration}', {
                      'trigger': trigger,
                      'duration': duration,
                    }),
              style: RaftPanelText.caption(t).copyWith(color: hint),
            ),
          ],
        ),
        RaftCssText(
          formatTurnActions(context, turn.actions),
          style: RaftPanelText.muted(t),
        ),
        for (final (index, p) in turn.problems.indexed)
          Row(
            key: ValueKey('activity-overview-problem-$index'),
            // ds-allow: Web problem line `gap-1.5`
            spacing: 6,
            children: [
              RaftIcon(
                p.counts ? RaftGlyph.triangleAlert : RaftGlyph.flaskConical,
                size: 14,
                color: p.counts ? t.colors['warning-strong'] ?? t.strong : hint,
              ),
              Expanded(
                child: RaftCssText(
                  _problem(context, p, f),
                  style: RaftPanelText.caption(t).copyWith(color: t.muted),
                ),
              ),
            ],
          ),
        if (more > 0)
          RaftCssText(
            icuText(
              context,
              'and {count, plural, one {# more} other {# more}}',
              {'count': more},
            ),
            style: RaftPanelText.caption(t).copyWith(color: hint),
          ),
        turn.lastReplyMessageId == null
            ? RaftCssText(
                raftText(context, 'No message sent this turn'),
                style: RaftPanelText.caption(t).copyWith(color: hint),
              )
            : _LastReply(
                key: ValueKey('reply-${turn.lastReplyMessageId}'),
                controller: controller,
                messageId: turn.lastReplyMessageId!,
                count: turn.messagesSent,
              ),
      ],
    );
  }
}

/// The turn's last reply, fetched by id under the message's own permissions.
class _LastReply extends StatefulWidget {
  const _LastReply({
    super.key,
    required this.controller,
    required this.messageId,
    required this.count,
  });
  final WorkspaceController controller;
  final String messageId;
  final int count;
  @override
  State<_LastReply> createState() => _LastReplyState();
}

class _LastReplyState extends State<_LastReply> {
  Map<String, dynamic>? message;
  bool unavailable = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final id = widget.messageId;
    try {
      final data = await widget.controller.query(
        '/messages/context/$id',
        query: {'before': '0', 'after': '0'},
      );
      if (!mounted || id != widget.messageId) return;
      final target = data is Map ? (data['targetMessageId'] ?? id) : id;
      final found = data is Map
          ? (data['messages'] as List? ?? const [])
                .whereType<Map>()
                .where((m) => m['id'] == target)
                .firstOrNull
          : null;
      setState(() {
        message = found == null ? null : Map<String, dynamic>.from(found);
        unavailable = found == null;
      });
    } catch (_) {
      if (mounted) setState(() => unavailable = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final f = agentTimeFormatter(context, widget.controller);
    final loaded = message != null;
    final label = loaded
        ? raftFormat(context, 'Last reply · {time}', {
            'time': f.clock(message!['createdAt']),
          })
        : raftText(context, 'Last reply');
    final hint = t.colors['foreground-hint'] ?? t.muted;
    return RaftSurfaceListItem(
      key: const ValueKey('activity-overview-reply'),
      interactive: false,
      // ds-allow: Web reply Card `p-3`
      padding: const EdgeInsets.all(12),
      child: RaftGapColumn(
        gap: 4,
        children: [
          RaftCssText(
            widget.count > 1
                ? '$label ${icuText(context, '· {count, plural, one {# message} other {# messages}} sent this turn', {'count': widget.count})}'
                : label,
            style: RaftPanelText.caption(t).copyWith(color: hint),
          ),
          RaftCssText(
            loaded
                ? '${message!['content'] ?? ''}'
                : raftText(
                    context,
                    unavailable
                        ? "The reply is in a conversation you can't see."
                        : 'Loading the reply…',
                  ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: RaftPanelText.value(t),
          ),
        ],
      ),
    );
  }
}
