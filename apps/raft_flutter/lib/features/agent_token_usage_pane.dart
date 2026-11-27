import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_token_usage.dart';
import '../data/feature_flag_client_facts.dart';
import '../data/source_time_formatter.dart';
import '../data/workspace_controller.dart';
import 'agent_runtime_labels.dart';
import 'agent_runtime_models.dart' show runtimeModelLabel;
import 'agent_usage_day_bars.dart';
import 'icu_message.dart';
import 'management_support.dart';
import 'members_page_entries.dart';
import 'members_usage_filter.dart';
import 'members_usage_table.dart';

mixin AgentUsageFlag<T extends StatefulWidget> on State<T> {
  WorkspaceController get usageWorkspace;
  bool get mayReadUsage;
  (WorkspaceController, String)? _requestedUsageFlag;

  bool get usageEnabled =>
      mayReadUsage &&
      cachedServerFlag(usageWorkspace, RaftFeatureFlags.agentUsage) == true;

  void checkUsageFlag() {
    final workspace = usageWorkspace;
    final server = workspace.server?.id;
    if (!mayReadUsage || server == null) {
      _requestedUsageFlag = null;
      return;
    }
    final identity = pageIdentity(workspace);
    final scope = (workspace, identity);
    if (scope == _requestedUsageFlag) return;
    _requestedUsageFlag = scope;
    unawaited(_readUsageFlag(workspace, server, identity));
  }

  Future<void> _readUsageFlag(
    WorkspaceController workspace,
    String server,
    String identity,
  ) async {
    try {
      final response = await workspace.command(
        'POST',
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(
          keys: const [RaftFeatureFlags.agentUsage],
          serverId: server,
        ),
      );
      if (!mounted ||
          !mayReadUsage ||
          _requestedUsageFlag != (workspace, identity) ||
          pageIdentity(workspace) != identity) {
        return;
      }
      final evaluations = response is Map ? response['evaluations'] : null;
      if (evaluations is! List) return;
      for (final row in evaluations.whereType<Map>()) {
        if (row['key'] == RaftFeatureFlags.agentUsage &&
            row['enabled'] is bool) {
          setState(() {
            rememberServerFlag(
              workspace,
              RaftFeatureFlags.agentUsage,
              row['enabled'] as bool,
              identity,
            );
          });
          return;
        }
      }
    } on RaftApiException catch (error) {
      if (mounted &&
          _requestedUsageFlag == (workspace, identity) &&
          (error.status == 401 || error.status == 403)) {
        setState(() {
          rememberServerFlag(
            workspace,
            RaftFeatureFlags.agentUsage,
            false,
            identity,
          );
        });
      }
    }
  }
}

class AgentTokenUsagePane extends StatefulWidget {
  const AgentTokenUsagePane({
    super.key,
    required this.workspace,
    this.agentId,
    this.agents = const [],
    this.agentGroups = const [],
    this.clock,
    this.onOpenComputer,
    this.onOpenAgent,
    this.toolbar,
  });

  final WorkspaceController workspace;
  final String? agentId;
  final List<MemberPageEntry> agents;
  final List<(String, List<MemberPageEntry>)> agentGroups;
  final DateTime Function()? clock;
  final VoidCallback? onOpenComputer;
  final ValueChanged<String>? onOpenAgent;
  final Widget Function(List<Widget>)? toolbar;

  @override
  State<AgentTokenUsagePane> createState() => _AgentTokenUsagePaneState();
}

class _AgentTokenUsagePaneState extends State<AgentTokenUsagePane> {
  static const _days = '{count, plural, one {# day} other {# days}}';
  static const _summaryDetailsWidth = 300.0;
  static const _summaryChartMinWidth = 280.0;
  static const _summaryGap = RaftSpace.x4 * 2;
  AgentUsagePeriod _period = AgentUsagePeriod.week;
  String? _selectedDay;
  bool _includeCache = false;
  final _filters = <String>{};
  Future<AgentUsageReport>? _request;
  AgentUsageReport? _cached;
  WorkspaceController get _workspace => widget.workspace;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final workspace = _workspace;
    final identity = pageIdentity(workspace);
    final agent = widget.agentId;
    final query = agentUsageQuery(
      _period,
      (widget.clock ?? DateTime.now)(),
      agentId: agent,
    );
    final key =
        'agent-token-usage/${agent ?? ''}/${query['from']}/${query['to']}';
    final cached = readPageSnapshot(workspace, key)?['report'];
    _cached = cached is AgentUsageReport ? cached : null;
    _request =
        Future.sync(
          () => workspace.query(
            '/servers/${workspace.server!.id}/agent-usage',
            query: query,
          ),
        ).then((raw) {
          final report = AgentUsageReport.parse(raw);
          writePageSnapshot(workspace, key, identity, {'report': report});
          return report;
        });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AgentUsageReport>(
    future: _request,
    builder: (context, snapshot) {
      final ready = snapshot.connectionState == ConnectionState.done;
      final report = ready && snapshot.hasData ? snapshot.data : _cached;
      final listed = report == null
          ? const <MemberPageEntry>[]
          : widget.agents
                .where((agent) => report.agentIds.contains(agent.target.id))
                .toList();
      final options = _filterOptions(listed);
      final active = options
          .where((entry) => _filters.contains(entry.id))
          .toList();
      final filtered = active.isNotEmpty;
      final keptIds = {for (final entry in active) ...entry.agents};
      final single = filtered && keptIds.length == 1
          ? keptIds.firstOrNull
          : widget.agentId;
      final listedIds = listed.map((entry) => entry.target.id).toSet();
      final visibleIds = filtered ? keptIds : listedIds;
      final noFigures = report == null || widget.agentId == null
          ? null
          : report.figures(_period, agentId: widget.agentId);
      final emptyDetail =
          noFigures != null && (!noFigures.supported || noFigures.empty);
      final controls = _controls(context, report, options);
      final scroll = CustomScrollView(
        key: const ValueKey('agent-usage-tab'),
        slivers: [
          for (final child in [
            if (widget.toolbar == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: controls.last),
                    _cacheReadSwitch(context),
                  ],
                ),
              ),
            if (ready && snapshot.hasError)
              RaftPanelSection(
                children: [
                  RaftBanner(
                    description: raftText(context, 'Could not load usage'),
                    action: RaftButton(
                      label: 'Retry',
                      uiVariant: RaftButtonVariant.standard,
                      onPressed: () => setState(_load),
                    ),
                  ),
                ],
              ),
            if (report != null && !emptyDetail)
              ..._sections(
                context,
                report,
                agentId: single,
                listedIds: listedIds,
                selectedIds: filtered ? keptIds : null,
              )
            else if (!ready)
              if (report == null)
                const RaftPanelSection(
                  topBorder: false,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: RaftSkeleton(
                        variant: RaftSkeletonVariant.line,
                        width: 96,
                        fromRecipe: true,
                      ),
                    ),
                    RaftSkeleton(height: 132, fromRecipe: true),
                  ],
                ),
          ])
            SliverToBoxAdapter(child: child),
          if (emptyDetail)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _emptyState(context, noFigures.supported),
            ),
          if (report != null && single == null && widget.onOpenAgent != null)
            MembersUsageTable(
              groups: [
                for (final (heading, agents) in widget.agentGroups)
                  (
                    heading,
                    agents
                        .where((agent) => visibleIds.contains(agent.target.id))
                        .toList(),
                  ),
              ],
              report: report,
              period: _period,
              selectedDay: _selectedDay,
              withCacheReads: _includeCache,
              visibleCount: listedIds.length,
              total: report
                  .figures(
                    _period,
                    listedAgents: listedIds,
                    selectedDay: _selectedDay,
                    withCacheReads: _includeCache,
                  )
                  .counts
                  .total(withCacheReads: _includeCache),
              origin: _workspace.client.origin,
              onOpen: widget.onOpenAgent!,
            ),
          SliverPadding(padding: raftScrollPadding(context, EdgeInsets.zero)),
        ],
      );
      final toolbar = widget.toolbar;
      return toolbar == null
          ? scroll
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                toolbar(controls),
                Expanded(child: scroll),
              ],
            );
    },
  );

  List<Widget> _controls(
    BuildContext context,
    AgentUsageReport? report,
    List<MembersUsagePick> options,
  ) => [
    if (options.isNotEmpty)
      MembersUsageFilter(
        key: const ValueKey('members-usage-filter'),
        options: options,
        selected: _filters,
        onToggle: (id) => setState(() {
          if (!_filters.remove(id)) _filters.add(id);
        }),
        onClear: () => setState(_filters.clear),
      ),
    SizedBox(
      width: 136,
      child: RaftSelectField<int>(
        key: const ValueKey('agent-usage-period'),
        label: raftText(context, 'Time range'),
        value: _selectedDay == report?.to && _selectedDay != null
            ? 0
            : _period.days,
        items: [
          if (report != null)
            RaftSelectItem(value: 0, label: raftText(context, 'Today')),
          for (final period in AgentUsagePeriod.values)
            RaftSelectItem(
              value: period.days,
              label: icuText(context, _days, {'count': period.days}),
            ),
        ],
        onChanged: (value) {
          if (value == null) return;
          final period = AgentUsagePeriod.values
              .where((period) => period.days == value)
              .firstOrNull;
          setState(() {
            _selectedDay = value == 0 ? report?.to : null;
            if (period == null || period == _period) return;
            _period = period;
            _load();
          });
        },
      ),
    ),
  ];

  Widget _cacheReadSwitch(BuildContext context) => RaftGapRow(
    shrinkWrap: true,
    gap: 8,
    children: [
      RaftSwitch(
        key: const ValueKey('agent-usage-cache-reads'),
        value: _includeCache,
        semanticLabel: raftText(context, 'Cache reads'),
        onChanged: (value) => setState(() => _includeCache = value),
      ),
      Text(
        raftText(context, 'Cache reads'),
        style: RaftPanelText.caption(RaftTokens.of(context)),
      ),
    ],
  );

  Widget _emptyState(BuildContext context, bool supported) => RaftEmptyState(
    title: supported
        ? icuText(
            context,
            'No usage in the last {count, plural, one {day} other {# days}}',
            {'count': _period.days},
          )
        : raftText(context, 'Update Raft Computer to see usage.'),
    glyph: RaftGlyph.chartColumn,
    action: !supported && widget.onOpenComputer != null
        ? RaftButton(
            label: 'Open computer',
            uiVariant: RaftButtonVariant.outline,
            onPressed: widget.onOpenComputer,
          )
        : null,
  );

  List<Widget> _sections(
    BuildContext context,
    AgentUsageReport report, {
    required String? agentId,
    required Set<String> listedIds,
    required Set<String>? selectedIds,
  }) {
    final figures = report.figures(
      _period,
      agentId: agentId,
      listedAgents: selectedIds ?? listedIds,
      selectedDay: _selectedDay,
      withCacheReads: _includeCache,
    );
    if (agentId != null && (!figures.supported || figures.empty)) {
      return [_emptyState(context, figures.supported)];
    }
    final t = RaftTokens.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final numbers = NumberFormat.compact(locale: locale)
      ..maximumFractionDigits = 1;
    final largeNumbers = NumberFormat.compact(locale: locale)
      ..maximumFractionDigits = 2;
    final percentages = NumberFormat.percentPattern(locale)
      ..maximumFractionDigits = 1;
    final dates = DateFormat.MEd(locale);
    final counts = figures.counts;
    final modelTotal = figures.models.fold<int>(
      0,
      (sum, model) => sum + (model.tokens ?? 0),
    );
    final total = counts.total();
    final input =
        (counts.inputNew ?? 0) +
        (counts.cacheRead ?? 0) +
        (counts.cacheWrite ?? 0);
    final reading = figures.context;
    String format(num? number) => number == null
        ? '—'
        : (number >= 1e9 ? largeNumbers : numbers).format(number);
    String dayName(String day) => day == report.to
        ? raftText(context, 'Today')
        : dates.format(DateTime.parse(day));
    final hint = t.scale(RaftTypeScale.caption, color: t.ui.foregroundHint);
    final muted = t.scale(RaftTypeScale.caption, color: t.ui.foregroundMuted);
    final meta = t.scale(
      RaftTypeScale.monoMeta,
      mono: true,
      color: t.ui.foregroundHint,
    );
    final mono = t.scale(
      RaftTypeScale.callout,
      mono: true,
      color: t.ui.foreground,
    );
    final cacheShare = counts.cacheRead != null && input > 0
        ? raftFormat(context, '{percent} of input', {
            'percent': percentages.format(counts.cacheRead! / input),
          })
        : '—';
    Widget fact(
      String label,
      num? value, {
      AgentUsageKind? kind,
      String? suffix,
      String? note,
      Widget? child,
    }) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        SizedBox(
          width: 116,
          child: Row(
            spacing: 6,
            children: [
              if (kind != null) AgentUsageSwatch(kind),
              Flexible(child: Text(raftText(context, label), style: muted)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              child ??
                  Text.rich(
                    TextSpan(
                      text: format(value),
                      children: [
                        if (suffix != null)
                          TextSpan(text: ' · $suffix', style: muted),
                      ],
                    ),
                    style: mono,
                  ),
              if (note != null) Text(note, style: hint),
            ],
          ),
        ),
      ],
    );
    Widget kindFact(AgentUsageKind kind, {bool breakdown = false}) {
      final amount = kind.amount(counts);
      return fact(
        kind.label,
        amount,
        kind: kind,
        suffix: amount == null
            ? null
            : breakdown
            ? percentages.format(
                total == null || total == 0 ? 0 : amount / total,
              )
            : kind == AgentUsageKind.cacheRead
            ? cacheShare
            : null,
        note: kind == AgentUsageKind.output && counts.reasoning != null
            ? raftFormat(context, 'Includes {tokens} reasoning', {
                'tokens': format(counts.reasoning),
              })
            : null,
      );
    }

    Widget section(String title, List<Widget> body, {Widget? aside}) =>
        RaftPanelSection(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: 8,
              children: [
                Flexible(
                  child: RaftSectionEyebrow(
                    _selectedDay == null
                        ? raftText(context, title)
                        : raftFormat(context, '{day} · {heading}', {
                            'day': dayName(_selectedDay!),
                            'heading': raftText(context, title),
                          }),
                  ),
                ),
                ?aside,
              ],
            ),
            ...body,
          ],
        );
    final shownTotal = counts.total(withCacheReads: _includeCache);
    final base = figures.base;
    final compared = figures.compared;
    final change = base == null || base <= 0 || compared == null
        ? null
        : (compared - base) / base;
    final heading = RaftSectionEyebrow(
      icuText(
        context,
        selectedIds == null
            ? '{count, plural, one {# agent you can see} other {# agents you can see}} · {period}'
            : 'Selected agents · {count} · {period}',
        {
          'count': (selectedIds ?? listedIds).length,
          'period': _selectedDay == null
              ? icuText(context, _days, {'count': _period.days})
              : dayName(_selectedDay!),
        },
      ),
    );
    final headline = Text(
      format(shownTotal),
      key: const ValueKey('agent-usage-headline'),
      style: t
          .scale(RaftTypeScale.title, color: t.ui.foreground)
          .copyWith(fontFamily: t.monoFont),
    );
    final user = _workspace.client.user;
    final formatter = SourceTimeFormatter(
      locale: locale,
      preferredTimezone:
          user?.string('preferredTimezone') ?? user?.string('timezone'),
      preferredTimeFormat: sourceTimeFormatPreference(
        user?.string('preferredTimeFormat') ?? user?.string('timeFormat'),
      ),
      systemTimeFormat: SourceTimeFormat.twentyFourHour,
    );
    final freshness = [
      if (_selectedDay == null || _selectedDay == report.to)
        Text(
          raftFormat(context, 'As of {time}', {
            'time': formatter.shortDateTime(report.asOf),
          }),
          style: meta,
        ),
      if (figures.since case final String since
          when figures.days.first.day.compareTo(since) < 0)
        Text(
          raftFormat(context, 'Usage since {date}', {'date': dayName(since)}),
          style: meta,
        ),
    ];
    final comparison = change == null
        ? null
        : Text(
            raftFormat(
              context,
              figures.baseDay == null
                  ? '{change} vs prior period'
                  : '{change} vs {day}',
              {
                'change':
                    '${change > 0 ? '+' : ''}${NumberFormat.percentPattern(locale).format(change)}',
                'day': figures.baseDay == null ? '' : dayName(figures.baseDay!),
              },
            ),
            style: meta,
          );
    final chart = AgentUsageDayBars(
      days: figures.days,
      withCacheReads: _includeCache,
      selected: _selectedDay,
      onSelect: (day) => setState(() => _selectedDay = day),
      formatTokens: format,
    );
    if (agentId == null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x5)
              .copyWith(top: RaftSpace.x3, bottom: RaftSpace.x3),
          child: RaftCard(
            key: const ValueKey('members-usage-summary'),
            padding: const EdgeInsets.all(RaftSpace.x4),
            child: LayoutBuilder(
              builder: (context, bounds) {
                final details = RaftGapColumn(
                  gap: 12,
                  children: [
                    Wrap(
                      spacing: RaftSpace.x3,
                      runSpacing: RaftSpace.x2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [heading, _cacheReadSwitch(context)],
                    ),
                    Wrap(
                      spacing: RaftSpace.x2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        headline,
                        Text(
                          raftText(
                            context,
                            _includeCache ? 'all tokens' : 'excl. cache reads',
                          ),
                          style: muted,
                        ),
                        comparison ?? Text('—', style: meta),
                      ],
                    ),
                    Column(
                      spacing: 4,
                      children: [
                        kindFact(AgentUsageKind.inputNew),
                        if (counts.cacheWrite != null)
                          kindFact(AgentUsageKind.cacheWrite),
                        kindFact(AgentUsageKind.output),
                        kindFact(AgentUsageKind.cacheRead),
                        fact('Agents reporting', figures.reporting),
                      ],
                    ),
                    ...freshness,
                  ],
                );
                if (bounds.maxWidth <
                    _summaryDetailsWidth +
                        _summaryGap +
                        _summaryChartMinWidth) {
                  return RaftGapColumn(gap: 16, children: [details, chart]);
                }
                return Row(
                  spacing: _summaryGap,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(width: _summaryDetailsWidth, child: details),
                    Expanded(child: chart),
                  ],
                );
              },
            ),
          ),
        ),
      ];
    }
    return [
      section(
        'Tokens',
        [
          if (widget.agentId == null) ...[heading, _cacheReadSwitch(context)],
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              headline,
              comparison ?? Text('—', style: meta),
            ],
          ),
          chart,
        ],
        aside: Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: freshness,
          ),
        ),
      ),
      section('Token types', [
        kindFact(AgentUsageKind.inputNew, breakdown: true),
        if (counts.cacheWrite != null)
          kindFact(AgentUsageKind.cacheWrite, breakdown: true),
        kindFact(AgentUsageKind.cacheRead, breakdown: true),
        kindFact(AgentUsageKind.output, breakdown: true),
        fact('Total tokens', total),
      ]),
      section('Context', [
        fact('Cache reads', null, child: Text(cacheShare, style: muted)),
        fact(
          'Per turn',
          total == null || counts.turns == 0
              ? null
              : (total / counts.turns).round(),
          child: total == null || counts.turns == 0
              ? null
              : Text(
                  icuText(
                    context,
                    '{tokens} · {turns, plural, one {# turn} other {# turns}}',
                    {
                      'tokens': format((total / counts.turns).round()),
                      'turns': counts.turns,
                    },
                  ),
                  style: mono,
                ),
        ),
        if (reading != null)
          RaftMeter(
            label: raftText(context, 'Context window'),
            used: reading.used,
            max: reading.window,
            valueText: raftFormat(context, '{percent} used', {
              'percent': NumberFormat.percentPattern(locale)
                  .format(reading.used / reading.window),
            }),
          )
        else
          fact('Context window', null),
      ]),
      section('Models', [
        if (figures.models.isEmpty) Text('—', style: mono),
        for (final model in figures.models)
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.model.model.isEmpty
                          ? raftText(context, 'Unknown model')
                          : runtimeModelLabel(
                              model.model.runtime ?? '',
                              model.model.model,
                            ),
                      style: t.scale(
                        RaftTypeScale.callout,
                        weight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      model.model.runtime == null
                          ? '—'
                          : runtimeDisplayNameOf(model.model.runtime!),
                      style: meta,
                    ),
                  ],
                ),
              ),
              Text(format(model.tokens), style: meta),
              SizedBox(
                width: 48,
                child: Text(
                  model.tokens == null || modelTotal <= 0
                      ? '—'
                      : NumberFormat.percentPattern(locale)
                            .format(model.tokens! / modelTotal),
                  style: mono,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
      ]),
    ];
  }
}

List<MembersUsagePick> _filterOptions(List<MemberPageEntry> agents) {
  final picks = <String, MembersUsagePick>{};
  for (final agent in agents) {
    final id = agent.target.id;
    if (agent.record['managedByAppInstallId'] != null) continue;
    for (final kind in ['runtime', 'model']) {
      if (agent.record[kind] case final String value when value.isNotEmpty) {
        final key = '$kind:$value';
        picks
            .putIfAbsent(
              key,
              () => (
                id: key,
                label: kind == 'runtime' ? runtimeDisplayNameOf(value) : value,
                agents: <String>{},
              ),
            )
            .agents
            .add(id);
      }
    }
  }
  return [
    ...picks.values,
    for (final agent in agents)
      (
        id: 'agent:${agent.target.id}',
        label: agent.name,
        agents: {agent.target.id},
      ),
  ];
}
