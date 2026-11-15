// Web components/agent/AgentActivityOverview.tsx (v1.24): the Activity tab's
// "Overview": one block per finished turn in time order, oldest at the top
// like the raw log, then the turn still running (`current` on the newest
// page), what people did to the agent between them (operator events), and what
// the agent is doing now at the bottom. It follows the bottom as turns finish;
// someone reading earlier turns stays put and gets a "New turn" button. Earlier
// turns load above without moving what is on screen. Detail stays in the raw
// log. The turns are held per server scope, so a revisit shows them at once
// while a read refreshes them in place.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'agent_activity_reload.dart';
import 'agent_activity_summaries.dart';
import 'agent_activity_turn_extras.dart';
import 'agent_detail_view.dart' show agentTimeFormatter;
import 'agent_now_card.dart';
import 'agent_operator_events.dart';
import 'agent_quiet_failure_runs.dart';
import 'icu_message.dart';

enum _Load { loading, loaded, error }

/// How close to the bottom still counts as "at the bottom" for following new
/// turns (`NEAR_BOTTOM_PX`).
const _nearBottom = 80.0;

/// What the overview last read for one agent, held per server scope.
class AgentOverviewSnapshot {
  /// Newest first, every page read, each turn once.
  List<TurnSummary> turns = const [];
  String? next;

  /// The turn still running (only the newest page carries it).
  TurnSummary? running;
  List<AgentOperatorEvent> events = const [];
  bool loaded = false;
}

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
    this.clock,
  });
  final WorkspaceController controller;
  final String agentId;

  /// The agent's live `activity` and its words (the header's status line).
  final String activity, activityText;
  final String? machineId;
  final bool hasRawActivity;
  final VoidCallback onShowRaw;
  final ValueChanged<String>? onOpenComputer;
  final DateTime Function()? clock;

  @override
  State<AgentActivityOverview> createState() => _AgentActivityOverviewState();
}

class _AgentActivityOverviewState extends State<AgentActivityOverview> {
  WorkspaceController get w => widget.controller;
  late AgentOverviewSnapshot snap;
  _Load status = _Load.loading;
  AgentActivityReload? _reload;
  int _request = 0, _generation = 0;
  bool _loadingEarlier = false, _newTurnBelow = false;

  bool _earlierLoaded = false;
  Timer? _keepPlace;
  final _scroll = _OverviewScrollController();

  AgentOverviewSnapshot _snapshot() => w.agentTabCache.putIfAbsent(
    'activity-overview/${widget.agentId}',
    AgentOverviewSnapshot.new,
  ) as AgentOverviewSnapshot;

  @override
  void initState() {
    super.initState();
    _open();
  }

  void _open() {
    snap = _snapshot();
    status = snap.loaded ? _Load.loaded : _Load.loading;
    _earlierLoaded = false;
    _newTurnBelow = false;
    _scroll.pinNext = true;
    _reload?.dispose();
    _reload = AgentActivityReload(
      events: w.client.events,
      agentId: widget.agentId,
      load: _loadLatest,
    );
    unawaited(_loadLatest());
  }

  @override
  void didUpdateWidget(covariant AgentActivityOverview old) {
    super.didUpdateWidget(old);
    if (old.agentId != widget.agentId) {
      _request++;
      _generation++;
      _open();
    }
  }

  @override
  void dispose() {
    _request++;
    _reload?.dispose();
    _keepPlace?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  String? _latestKey() {
    final running = snap.running;
    if (running != null) return 'running:${running.id ?? running.startedAt}';
    return snap.turns.firstOrNull?.key;
  }

  bool get _atBottom {
    if (!_scroll.hasClients) return true;
    final p = _scroll.position;
    return p.maxScrollExtent - p.pixels < _nearBottom;
  }

  /// Web `loadLatest`: the newest page, merged into what is held.
  Future<void> _loadLatest() async {
    final request = ++_request, id = widget.agentId;
    try {
      final result = await w.query(
        '/agents/$id/activity-summaries',
        query: {'limit': '$activitySummariesPageSize'},
      );
      if (!mounted || request != _request || id != widget.agentId) return;
      final page = TurnSummaryPage.parse(result);
      final held = snap.turns.map((t) => t.key).toSet();
      final gap =
          page.next != null &&
          held.isNotEmpty &&
          !page.summaries.any((t) => held.contains(t.key));
      final before = _latestKey(), wasAtBottom = _atBottom;
      setState(() {
        if (gap) {
          // More turns finished than one page while away (a reconnect): start
          // again from the newest page instead of keeping a hidden gap. What
          // was being read is gone: show the newest, like a first load.
          _generation++;
          _earlierLoaded = false;
          _newTurnBelow = false;
          _scroll.pinNext = true;
          snap
            ..turns = page.summaries
            ..next = page.next;
        } else {
          // Merge, never replace: earlier pages already loaded stay, and a
          // reload racing "Show earlier turns" cannot drop a page.
          snap.turns = mergeTurnPages([page.summaries, snap.turns]);
          if (!_earlierLoaded) snap.next = page.next;
        }
        snap
          ..running = page.current
          ..loaded = true;
        status = _Load.loaded;
        // A turn finished while the reader is above the bottom: a hint, not a
        // jump (the layout follows the bottom by itself while it is near).
        if (!gap && snap.loaded && before != _latestKey() && !wasAtBottom) {
          _newTurnBelow = true;
        }
      });
      unawaited(_loadEvents());
    } catch (_) {
      if (!mounted || request != _request) return;
      // A failed refresh never replaces turns already shown.
      if (status != _Load.loaded) setState(() => status = _Load.error);
    }
  }

  /// Web `loadEarlier`.
  Future<void> _loadEarlier() async {
    final before = snap.next, id = widget.agentId;
    if (before == null || _loadingEarlier) return;
    setState(() => _loadingEarlier = true);
    final asked = _generation;
    try {
      final result = await w.query(
        '/agents/$id/activity-summaries',
        query: {'limit': '$activitySummariesPageSize', 'before': before},
      );
      if (!mounted || id != widget.agentId || asked != _generation) return;
      final page = TurnSummaryPage.parse(result);
      setState(() {
        _earlierLoaded = true;
        // What the reader sees stays where it is: the view moves down by what
        // was added above it (the position applies this at the next layout).
        _scroll.keepPlace = true;
        snap
          ..turns = mergeTurnPages([snap.turns, page.summaries])
          ..next = page.next;
      });
      // The turns above settle for a moment (each one's reply loads and grows
      // its card): the view keeps its place until they have, or the reader
      // scrolls.
      _keepPlace?.cancel();
      _keepPlace = Timer(const Duration(seconds: 2), () {
        _scroll.keepPlace = false;
      });
      unawaited(_loadEvents());
    } catch (_) {
      // Stays where it is; the button is still there.
    } finally {
      if (mounted) setState(() => _loadingEarlier = false);
    }
  }

  /// Operator events as far back as the turns held: all of them once no
  /// earlier page is left. A refusal (a member sees none) or an older server
  /// leaves the turns alone.
  Future<void> _loadEvents() async {
    final id = widget.agentId;
    final since = snap.next != null && snap.turns.isNotEmpty
        ? snap.turns.map((t) => t.startedAt).reduce((a, b) => a < b ? a : b)
        : null;
    final events = await loadOperatorEvents(w, id, since: since);
    if (events == null || !mounted || id != widget.agentId) return;
    setState(() => snap.events = events);
  }

  void _jumpToNewest() {
    if (_scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
    setState(() => _newTurnBelow = false);
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
        RaftIcon(RaftGlyph.history, size: size, color: color),
    action: action,
  );

  Widget _now(BuildContext context, List<TurnSummary> finished) => AgentNowCard(
    controller: w,
    activity: widget.activity,
    activityText: widget.activityText,
    turns: finished,
    running: snap.running,
    clock: widget.clock,
  );

  /// The Now card stays above an empty state: it is what shows a live error
  /// (a usage limit), and it is already on screen while loading.
  Widget _withNow(BuildContext context, List<TurnSummary> finished, Widget e) =>
      Padding(
        key: const ValueKey('activity-overview'),
        // ds-allow: Web `px-4 py-4` of the overview scroller
        padding: raftScrollPadding(context, const EdgeInsets.all(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          // ds-allow: Web overview `gap-6`
          spacing: 24,
          children: [
            _now(context, finished),
            Expanded(child: Center(child: e)),
          ],
        ),
      );

  Widget _badges(BuildContext context, TurnSummary turn) =>
      TurnBadges(turn: turn);

  Widget _turn(TurnSummary turn) =>
      TurnSection(key: ValueKey('turn-${turn.key}'), controller: w, turn: turn);

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
          size: RaftButtonRecipeSize.md,
          onPressed: () => unawaited(_loadLatest()),
        ),
      );
    }
    final running = snap.running;
    // The empty wake a running turn took over shows only as that turn.
    final runningId = running?.id;
    final finished = runningId == null
        ? snap.turns
        : snap.turns.where((t) => t.id != runningId).toList();
    final loaded = status == _Load.loaded;
    if (loaded && finished.isEmpty && running == null) {
      if (!widget.hasRawActivity) {
        return _withNow(
          context,
          finished,
          _empty(context, title: 'No activity yet'),
        );
      }
      final machineId = widget.machineId;
      return _withNow(
        context,
        finished,
        _empty(
          context,
          title: 'No overview yet',
          description: machineId != null
              ? "Each finished turn shows here as one line. If new turns don't show up, update Raft on this agent's computer from the computer's page."
              : "The overview shows one line per finished turn. This agent hasn't reported a finished turn yet.",
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
                  size: RaftButtonRecipeSize.md,
                  onPressed: () => widget.onOpenComputer!(machineId),
                ),
              RaftButton(
                key: const ValueKey('activity-overview-show-raw'),
                label: raftText(context, 'Show raw log'),
                tone: RaftButtonRecipeVariant.outline,
                size: RaftButtonRecipeSize.md,
                onPressed: widget.onShowRaw,
              ),
            ],
          ),
        ),
      );
    }

    // The API pages newest first; the overview reads in time order like the log.
    final oldestFirst = finished.reversed.toList();
    final interleaved = interleaveOperatorEvents<TurnSummary>(
      oldestFirst,
      snap.events,
      (t) => t.startedAt,
    );
    final runningStart = running?.startedAt;
    final eventsBefore = runningStart == null
        ? interleaved.after
        : interleaved.after.where((e) => e.at < runningStart).toList();
    final eventsDuring = runningStart == null
        ? const <AgentOperatorEvent>[]
        : interleaved.after.where((e) => e.at >= runningStart).toList();

    // (widget, key of its first turn) in time order.
    final items = <(Widget, String?)>[];
    for (final segment in interleaved.segments) {
      switch (segment) {
        case EventsSegment<TurnSummary>(:final events):
          items.add((
            OperatorEventLines(
              key: ValueKey('events:${events.first.id}'),
              controller: w,
              events: events,
            ),
            null,
          ));
        case TurnsSegment<TurnSummary>(:final turns):
          for (final item in groupQuietFailures(turns)) {
            if (item.turn != null) {
              items.add((_turn(item.turn!), item.turn!.key));
            } else {
              final run = item.turns!;
              items.add((
                QuietFailureRun(
                  key: ValueKey('retries-${run.first.key}'),
                  controller: w,
                  turns: run,
                  turnBuilder: _turn,
                  badges: _badges,
                ),
                run.first.key,
              ));
            }
          }
      }
    }
    // ds-allow: Web `px-4 py-4` of the overview scroller
    final pad = raftScrollPadding(context, const EdgeInsets.all(16));
    // ds-allow: Web overview `gap-6`
    const gap = 24.0;
    final loadMore = snap.next == null
        ? null
        : Align(
            alignment: Alignment.centerLeft,
            child: RaftButton(
              key: const ValueKey('activity-overview-load-more'),
              label: raftText(context, 'Show earlier turns'),
              size: RaftButtonRecipeSize.md,
              onPressed: _loadingEarlier
                  ? null
                  : () => unawaited(_loadEarlier()),
            ),
          );
    final children = [
      ?loadMore,
      for (final item in items) item.$1,
      if (eventsBefore.isNotEmpty)
        OperatorEventLines(controller: w, events: eventsBefore),
      if (running != null)
        TurnSection(
          key: ValueKey('turn-running:${running.id ?? running.startedAt}'),
          controller: w,
          turn: running,
        ),
      if (eventsDuring.isNotEmpty)
        OperatorEventLines(controller: w, events: eventsDuring),
      _now(context, finished),
    ];
    return Stack(
      key: const ValueKey('activity-overview'),
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            // Back at the bottom: the hint has done its job.
            if (n is ScrollStartNotification && n.dragDetails != null) {
              // The reader took over: nothing to keep any more.
              _scroll.keepPlace = false;
            }
            if (_newTurnBelow &&
                (n is ScrollUpdateNotification || n is ScrollEndNotification) &&
                _atBottom) {
              setState(() => _newTurnBelow = false);
            }
            return false;
          },
          child: CustomScrollView(
            key: const ValueKey('activity-overview-scroll'),
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: pad,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: gap,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_newTurnBelow)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: RaftButton(
                key: const ValueKey('activity-overview-new-turn'),
                label: raftText(context, 'New turn ↓'),
                tone: RaftButtonRecipeVariant.primary,
                size: RaftButtonRecipeSize.md,
                onPressed: _jumpToNewest,
              ),
            ),
          ),
      ],
    );
  }
}

/// Web `TurnBadges`: only a turn that needs a look gets a badge ("Done" read as
/// "the work is done" when it only meant "this turn ended"). Steps that went
/// wrong, an error ending, a stop or an unknown ending get their own badge; a
/// turn that sent nothing gets a muted one.
class TurnBadges extends StatelessWidget {
  const TurnBadges({super.key, required this.turn});
  final TurnSummary turn;

  Widget _badge(
    BuildContext context,
    String label,
    RaftBadgeRecipeVariant variant,
    RaftPresence light, {
    Key? key,
    Color? fill,
  }) => RaftBadge(
    key: key,
    label: label,
    appearance: RaftBadgeRecipeAppearance.soft,
    variant: variant,
    fill: fill,
    leading: RaftStatus(presence: light),
  );

  @override
  Widget build(BuildContext context) {
    if (turn.running) {
      return _badge(
        context,
        raftText(context, 'In progress'),
        RaftBadgeRecipeVariant.accent,
        RaftPresence.busy,
        key: const ValueKey('activity-overview-running'),
        fill: RaftTokens.of(context).ui['presence-busy-soft'],
      );
    }
    final problems = turn.problemsShown;
    return Wrap(
      // ds-allow: Web badge row `gap-2`
      spacing: 8,
      // ds-allow: Web badge row `gap-y-1`
      runSpacing: 4,
      children: [
        if (turn.outcome == 'completed' && problems > 0)
          // Steps that went wrong along the way are not a failed turn: amber.
          _badge(
            context,
            icuText(
              context,
              '{count, plural, one {# step} other {# steps}} went wrong',
              {'count': problems},
            ),
            RaftBadgeRecipeVariant.warning,
            RaftPresence.error,
          )
        else if (turn.outcome == 'failed')
          // A problem, not an irreversible consequence: orange, never red.
          _badge(
            context,
            raftText(context, 'Ended with an error'),
            RaftBadgeRecipeVariant.warning,
            RaftPresence.error,
          )
        else if (turn.outcome != 'completed')
          _badge(
            context,
            raftText(
              context,
              turn.outcome == 'interrupted'
                  ? 'Stopped'
                  : 'Ended, outcome unknown',
            ),
            RaftBadgeRecipeVariant.muted,
            RaftPresence.offline,
          ),
        if (turn.lastReplyMessageId == null)
          _badge(
            context,
            raftText(context, 'No message sent'),
            RaftBadgeRecipeVariant.muted,
            RaftPresence.offline,
            key: const ValueKey('activity-overview-no-message'),
          ),
      ],
    );
  }
}

/// One turn (finished, or the one still running) as the overview shows it.
class TurnSection extends StatelessWidget {
  const TurnSection({super.key, required this.controller, required this.turn});
  final WorkspaceController controller;
  final TurnSummary turn;

  /// Web `ProblemLine`.
  Widget _problem(BuildContext context, int index, TurnProblem p) {
    final t = RaftTokens.of(context);
    final f = agentTimeFormatter(context, controller);
    final time = f.clock(p.at);
    // A test run that reports failures is ordinary work, not an agent error.
    final text = p.reason == 'exit_nonzero' && p.kind == 'run_checks'
        ? raftFormat(context, '{time} some tests or checks failed', {
            'time': time,
          })
        : raftFormat(context, '{time} a tool call failed', {'time': time});
    final hint = t.colors['foreground-hint'] ?? t.muted;
    return Row(
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
            text,
            style: RaftPanelText.caption(t).copyWith(color: t.muted),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final f = agentTimeFormatter(context, controller);
    // A running turn has no end yet: its start time only.
    final range = turn.running
        ? (start: f.clock(turn.startedAt), end: null)
        : formatClockRange(f.clock(turn.startedAt), f.clock(turn.endedAt));
    final trigger = formatTurnTrigger(context, turn);
    final duration = formatTurnDuration(context, turn.endedAt - turn.startedAt);
    final hint = t.colors['foreground-hint'] ?? t.muted;
    // The exact waking message, only where the viewer may see it (the server
    // hides the rest).
    final canOpen =
        turn.hiddenTrigger == null &&
        !turn.triggerUnresolved &&
        turn.triggerMessageId != null &&
        turn.triggerChannelId != null;
    final triggerText = trigger == null
        ? raftFormat(
            context,
            turn.running ? 'running for {duration}' : 'took {duration}',
            {'duration': duration},
          )
        : raftFormat(
            context,
            turn.running
                ? '{trigger} · running for {duration}'
                : '{trigger} · took {duration}',
            {'trigger': trigger, 'duration': duration},
          );
    final captionStyle = RaftPanelText.caption(t).copyWith(color: hint);
    final sentIds = turn.sentMessageIds;
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
            // Badges sit right after the time so they stay on the first line.
            TurnBadges(turn: turn),
            RaftCssText(triggerText, style: captionStyle),
            if (canOpen)
              RaftTextLink(
                key: const ValueKey('activity-overview-trigger-open'),
                label: raftText(context, 'Open message'),
                onPressed: () => unawaited(
                  controller.jumpToMessage(
                    turn.triggerChannelId ?? '',
                    turn.triggerMessageId ?? '',
                  ),
                ),
              ),
          ],
        ),
        RaftCssText(
          formatTurnActions(
            context,
            turn.actions,
            messagesSent: turn.messagesSent,
          ),
          style: RaftPanelText.muted(t),
        ),
        // What lies past the capped list is of unknown kind: no "N more".
        for (final (index, p) in turn.problems.indexed)
          if (p.listed) _problem(context, index, p),
        if (turn.lastText != null) TurnOutput(text: turn.lastText!),
        // What the turn received, then what it sent: two lists, each in time order.
        if (turn.appEvents.isNotEmpty)
          TurnAppEvents(
            controller: controller,
            events: turn.appEvents,
            count: turn.appEventCount ?? turn.appEvents.length,
          ),
        if (sentIds.isNotEmpty || turn.hiddenSentCount > 0)
          TurnSentMessages(
            controller: controller,
            ids: sentIds,
            visible: turn.sentMessageCount ?? sentIds.length,
            hidden: turn.hiddenSentCount,
          )
        else if (turn.lastReplyMessageId != null)
          TurnLastReply(
            key: ValueKey('reply-${turn.lastReplyMessageId}'),
            controller: controller,
            messageId: turn.lastReplyMessageId!,
            count: turn.messagesSent,
          ),
      ],
    );
  }
}

/// The overview's one scroller. Its position follows the bottom: on the first
/// layout, and whenever the content grows while the view is within
/// [_nearBottom] of the end, the view stays at the end in the same frame (no
/// frame at the old place). A reader above that keeps their place.
class _OverviewScrollController extends ScrollController {
  /// Pin to the end at the next layout that has something to scroll.
  bool pinNext = true;

  /// Content was added above the view: while this is set, whatever the extent
  /// grows by moves the view by as much, so the reader keeps their place.
  bool keepPlace = false;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _OverviewScrollPosition(
    controller: this,
    physics: physics,
    context: context,
    oldPosition: oldPosition,
  );
}

class _OverviewScrollPosition extends ScrollPositionWithSingleContext {
  _OverviewScrollPosition({
    required this.controller,
    required super.physics,
    required super.context,
    super.oldPosition,
  });
  final _OverviewScrollController controller;

  /// The pass after a place-keeping correction only applies the new extents:
  /// the corrected offset is far from the old end, not "near the bottom".
  bool _settling = false;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    if (_settling) {
      _settling = false;
      return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
    }
    if (hasPixels) {
      final following =
          controller.pinNext ||
          (hasContentDimensions &&
              pixels >= this.maxScrollExtent - _nearBottom);
      if (following && maxScrollExtent > pixels + 0.5) {
        if (maxScrollExtent > 0) controller.pinNext = false;
        correctPixels(maxScrollExtent);
        // Dimensions are applied by the pass that sees the corrected offset.
        return false;
      }
    }
    if (hasPixels && hasContentDimensions && controller.keepPlace) {
      final added = maxScrollExtent - this.maxScrollExtent;
      if (added.abs() > 0.5) {
        _settling = true;
        correctPixels(pixels + added);
        return false;
      }
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}
