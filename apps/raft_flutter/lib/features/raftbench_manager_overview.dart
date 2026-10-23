// RaftBench "Tasks and cost" (Web raftbench/ManagerOverview.tsx): the task
// snapshot, the 7-day completion comparison and the server-wide cloud-agent
// spend, read from existing database and billing aggregates.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raftbench_overview_controller.dart';
import 'raftbench_parts.dart';

class RaftbenchManagerOverview extends StatelessWidget {
  const RaftbenchManagerOverview({super.key, required this.controller});
  final RaftbenchOverviewController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => _Overview(controller: controller),
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.controller});
  final RaftbenchOverviewController controller;

  static const _tabular = [FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), ty = RaftbenchType(t);
    final pad = RaftbenchCard.inset(context);
    return RaftbenchCard(
      padded: false,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(context, t, ty, pad),
          Padding(
            padding: EdgeInsets.all(pad),
            // `space-y-5`: adjacent block margins collapse, so every direct
            // child is 20 apart whatever its own `mt-*`.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              spacing: 20,
              children: [
                ..._snapshot(context, t, ty),
                ..._periods(context, t, ty),
                ..._cost(context, t, ty),
                _limits(context, t, ty),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _hours(BuildContext context, double? v) {
    if (v == null) return raftText(context, 'Unavailable');
    return raftFormat(context, '{value} h', {
      'value': RaftbenchFormat(context).number(v, maximumFractionDigits: 1),
    });
  }

  Widget _heading(RaftbenchType ty, String text, {Widget? icon}) {
    final label = Semantics(
      header: true,
      child: Text(text, style: ty.body(weight: FontWeight.w700)),
    );
    return icon == null
        ? label
        : Row(
            children: [
              icon,
              const SizedBox(width: 8),
              Flexible(child: label),
            ],
          );
  }

  Widget _status(RaftbenchType ty, String text, {Color? color}) => Semantics(
    liveRegion: true,
    child: Text(text, style: ty.body(color: color)),
  );

  Widget _header(
    BuildContext context,
    RaftTokens t,
    RaftbenchType ty,
    double pad,
  ) {
    String tr(String s) => raftText(context, s);
    return Container(
      key: const ValueKey('raftbench-manager-header'),
      color: t.colors['info-soft'],
      padding: EdgeInsets.all(pad),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RaftIcon(RaftGlyph.barChart3, size: 24, color: t.ink),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(tr('Tasks and cost'), style: ty.headline()),
                    ),
                    Text(
                      tr('Database metrics · no AI scan needed'),
                      style: ty.caption(weight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
            ],
          ),
          RaftbenchButton(
            tr('Refresh task and cost metrics'),
            onPressed: controller.anyLoading ? null : controller.load,
          ),
        ],
      ),
    );
  }

  List<Widget> _snapshot(BuildContext context, RaftTokens t, RaftbenchType ty) {
    String tr(String s) => raftText(context, s);
    final fmt = RaftbenchFormat(context);
    final state = controller.snapshot, snap = state.value;
    final out = <Widget>[
      _heading(ty, tr('Task history from the database')),
      if (state.kind == RaftbenchLoadKind.loading)
        _status(ty, tr('Aggregating all accessible task sources…')),
      if (state.kind == RaftbenchLoadKind.error)
        _status(
          ty,
          tr(
            'Task aggregation is unavailable. No task totals have been inferred from a partial sample.',
          ),
          color: ty.danger,
        ),
    ];
    if (snap == null) return out;
    final tiles = [
      (tr('All tasks'), snap.total, true),
      (tr('Awaiting review'), snap.inReview, false),
      (tr('In progress'), snap.inProgress, false),
      (tr('To do'), snap.todo, false),
      (tr('Done'), snap.done, false),
      (tr('Closed'), snap.closed, false),
    ];
    final caption = ty.caption(color: ty.hint, weight: FontWeight.w400);
    out.add(
      KeyedSubtree(
        key: const ValueKey('raftbench-task-snapshot'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Grid(
              columns: 3,
              children: [
                for (final (label, value, total) in tiles)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.sidebar,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: ty.caption()),
                        const SizedBox(height: 4),
                        Text(
                          fmt.number(value),
                          style: ty.title().copyWith(fontFeatures: _tabular),
                        ),
                        if (!total && snap.total > 0) ...[
                          const SizedBox(height: 8),
                          RaftbenchBar(
                            height: 6,
                            track: t.canvas,
                            fill: ty.brand,
                            fraction: value / snap.total,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
            if (snap.durationSamples > 0) ...[
              const SizedBox(height: 12),
              Text(
                raftFormat(
                  context,
                  'Creation → done: median {median}, 90th percentile {p90} ({count} valid completed tasks). Calendar time includes waiting.',
                  {
                    'median': _hours(context, snap.medianHours),
                    'p90': _hours(context, snap.p90Hours),
                    'count': snap.durationSamples,
                  },
                ),
                style: ty.callout(),
              ),
            ],
            const SizedBox(height: 12),
            RaftbenchDetails(
              summaryStyle: ty.caption(weight: FontWeight.w600),
              summary: Text(tr('Sources and limits')),
              child: DefaultTextStyle.merge(
                style: caption,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(
                        tr(
                          'Current task states across accessible task sources. This is available without starting AI analysis or scanning messages.',
                        ),
                      ),
                      Text(
                        raftFormat(
                          context,
                          '{surfaces} accessible task sources · created {first}–{latest} · last task update {updated} (UTC). This is a historical snapshot, not a current activity trend.',
                          {
                            'first':
                                snap.firstCreatedAt?.substring(0, 10) ?? '—',
                            'latest':
                                snap.latestCreatedAt?.substring(0, 10) ?? '—',
                            'updated':
                                snap.latestUpdatedAt?.substring(0, 10) ?? '—',
                            'surfaces': snap.surfaces,
                          },
                        ),
                      ),
                      Text(
                        raftFormat(
                          context,
                          'Created by people: {human} · by agents: {agent}.',
                          {
                            'human': fmt.number(snap.humanCreated),
                            'agent': fmt.number(snap.agentCreated),
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return out;
  }

  List<Widget> _periods(BuildContext context, RaftTokens t, RaftbenchType ty) {
    String tr(String s) => raftText(context, s);
    final state = controller.tasks, periods = state.value;
    final out = <Widget>[
      _heading(ty, tr('Task efficiency · period comparison')),
      if (state.kind == RaftbenchLoadKind.loading)
        _status(ty, tr('Aggregating all accessible task sources…')),
      if (state.kind == RaftbenchLoadKind.error)
        _status(
          ty,
          tr(
            'Task aggregation is unavailable. No task totals have been inferred from a partial sample.',
          ),
          color: ty.danger,
        ),
    ];
    if (periods == null) return out;
    final empty =
        periods.current.completed == 0 && periods.previous.completed == 0;
    final cards = [
      (
        tr('Completed · current / previous'),
        '${periods.current.completed} / ${periods.previous.completed}',
      ),
      (
        tr('Median creation → done · current / previous'),
        '${_hours(context, periods.current.medianHours)} / ${_hours(context, periods.previous.medianHours)}',
      ),
      (
        tr('Mean creation → done · current / previous'),
        '${_hours(context, periods.current.meanHours)} / ${_hours(context, periods.previous.meanHours)}',
      ),
    ];
    out.add(
      KeyedSubtree(
        key: const ValueKey('raftbench-task-comparison'),
        child: empty
            ? _status(
                ty,
                tr('No tasks were completed in either comparison period.'),
              )
            : _Grid(
                columns: 3,
                single: true,
                children: [
                  for (final (label, value) in cards)
                    RaftbenchCard(
                      padded: false,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(label, style: ty.caption()),
                            const SizedBox(height: 8),
                            Text(
                              value,
                              style: ty.title().copyWith(
                                fontFeatures: _tabular,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
    return out;
  }

  List<Widget> _cost(BuildContext context, RaftTokens t, RaftbenchType ty) {
    String tr(String s) => raftText(context, s);
    final fmt = RaftbenchFormat(context);
    final state = controller.costs, cost = state.value;
    final below = tr('under {amount}');
    return [
      _heading(
        ty,
        tr('Cloud agent cost · whole server'),
        icon: RaftIcon(RaftGlyph.wallet, size: 18, color: t.ink),
      ),
      if (state.kind == RaftbenchLoadKind.loading)
        _status(ty, tr('Reading cloud agent billing…')),
      if (state.kind == RaftbenchLoadKind.error)
        _status(
          ty,
          tr(
            'Could not read the requested scope. Check your access and retry. Previous evidence has been cleared.',
          ),
          color: ty.danger,
        ),
      if (state.kind == RaftbenchLoadKind.unavailable)
        _status(
          ty,
          tr(
            'Cloud agent billing is not available for this server. This does not mean zero cost.',
          ),
        ),
      if (cost != null) ...[
        Text(
          '${fmt.usd(cost.currentUsd, below)} / ${fmt.usd(cost.previousUsd, below)}',
          key: const ValueKey('raftbench-cost-comparison'),
          style: ty.title().copyWith(fontFeatures: _tabular),
        ),
        Text(
          tr(
            cost.estimated
                ? 'Estimated, in USD by UTC day, as reported by the cloud agent provider. For reference, not a bill.'
                : 'In USD by UTC day, as reported by the cloud agent provider. For reference, not a bill.',
          ),
          style: ty.caption(color: ty.hint, weight: FontWeight.w400),
        ),
        if (cost.unpriced)
          _status(
            ty,
            tr('Some usage has no price and is not included.'),
            color: ty.warning,
          ),
      ],
    ];
  }

  Widget _limits(BuildContext context, RaftTokens t, RaftbenchType ty) {
    String tr(String s) => raftText(context, s);
    final periods = controller.tasks.value;
    return RaftbenchDetails(
      summaryStyle: ty.caption(weight: FontWeight.w600),
      summary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RaftIcon(RaftGlyph.circleHelp, size: 16, color: t.ink),
          const SizedBox(width: 8),
          Flexible(child: Text(tr('Sources and limits'))),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: ty.caption(color: ty.hint, weight: FontWeight.w400),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(
                tr(
                  'Task and cost comparison: latest 7 complete UTC days / previous 7 days. Today is excluded. This is separate from the AI historical start date.',
                ),
              ),
              if (periods != null) ...[
                Text(
                  raftFormat(
                    context,
                    'Source aggregation over {count} accessible task surfaces; no task-page cap.',
                    {'count': periods.surfaces},
                  ),
                ),
                Text(
                  raftFormat(
                    context,
                    'Duration samples: {current} / {previous}. Calendar time includes waiting. Current done tasks only; reopened tasks and historical backlog are not reconstructed.',
                    {
                      'current': periods.current.durationSamples,
                      'previous': periods.previous.durationSamples,
                    },
                  ),
                ),
              ],
              Text(
                tr(
                  'Uses existing billing, separately from task/message reads. Always server-wide, even when a channel is selected.',
                ),
              ),
              Text(
                tr(
                  'PR merges and tokens are not connected. Cloud agent spend excludes other runtimes and is not attributed to tasks; no cost-per-task or savings are inferred. ',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `grid grid-cols-2 gap-3 sm:grid-cols-3` (`grid-cols-1` with [single]): the
/// items of a row are as tall as the tallest of that row.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.columns,
    required this.children,
    this.single = false,
  });
  final int columns;
  final bool single;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Tailwind `sm` is 640.
    final wide = raftBreakpointWidth(context) >= 640;
    final count = wide ? columns : (single ? 1 : 2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        for (var i = 0; i < children.length; i += count)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                for (var j = i; j < i + count; j++)
                  Expanded(
                    child: j < children.length ? children[j] : const SizedBox(),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
