import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_token_usage.dart';
import '../data/feature_flag_client_facts.dart';
import '../data/workspace_controller.dart';
import 'agent_runtime_labels.dart';
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
  });

  final WorkspaceController workspace;
  final String? agentId;
  final List<MemberPageEntry> agents;
  final List<(String, List<MemberPageEntry>)> agentGroups;
  final DateTime Function()? clock;
  final VoidCallback? onOpenComputer;
  final ValueChanged<String>? onOpenAgent;

  @override
  State<AgentTokenUsagePane> createState() => _AgentTokenUsagePaneState();
}

class _AgentTokenUsagePaneState extends State<AgentTokenUsagePane> {
  static const _days = '{count, plural, one {# day} other {# days}}';
  static const _rangePickerWidth = 144.0;
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
      return CustomScrollView(
        key: const ValueKey('agent-usage-tab'),
        slivers: [
          for (final child in [
            RaftPanelSection(
              topBorder: false,
              children: [_controls(context, report, options)],
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
            if (report != null)
              ..._sections(
                context,
                report,
                agentId: single,
                listedIds: listedIds,
                selectedIds: filtered ? keptIds : null,
              )
            else if (!ready)
              const RaftPanelSection(children: [RaftSidebarRowsSkeleton()]),
          ])
            SliverToBoxAdapter(child: child),
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
              total: report
                  .figures(
                    _period,
                    listedAgents: listedIds,
                    selectedDay: _selectedDay,
                    withCacheReads: _includeCache,
                  )
                  .counts
                  .total(withCacheReads: _includeCache),
              onOpen: widget.onOpenAgent!,
            ),
          SliverPadding(padding: raftScrollPadding(context, EdgeInsets.zero)),
        ],
      );
    },
  );

  Widget _controls(
    BuildContext context,
    AgentUsageReport? report,
    List<MembersUsagePick> options,
  ) => Wrap(
    spacing: RaftSpace.x3,
    runSpacing: RaftSpace.x2,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
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
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _rangePickerWidth),
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
      if (widget.agentId != null) _cacheReadSwitch(context),
    ],
  );

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
      return [
        RaftPanelSection(
          children: [
            Text(
              !figures.supported
                  ? raftText(context, 'Update Raft Computer to see usage.')
                  : icuText(
                      context,
                      'No usage in the last {count, plural, one {day} other {# days}}',
                      {'count': _period.days},
                    ),
            ),
            if (!figures.supported && widget.onOpenComputer != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: RaftButton(
                  label: 'Open computer',
                  uiVariant: RaftButtonVariant.standard,
                  onPressed: widget.onOpenComputer,
                ),
              ),
          ],
        ),
      ];
    }
    final t = RaftTokens.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final numbers = NumberFormat.compact(locale: locale);
    final dates = DateFormat.MMMd(locale);
    final counts = figures.counts;
    final total = counts.total();
    final input =
        (counts.inputNew ?? 0) +
        (counts.cacheRead ?? 0) +
        (counts.cacheWrite ?? 0);
    final reading = figures.context;
    String format(num? number) => number == null ? '—' : numbers.format(number);
    String dayName(String day) => day == report.to
        ? raftText(context, 'Today')
        : dates.format(DateTime.parse(day));
    Widget fact(String label, num? value, {bool share = false}) => RaftInfoRow(
      label: raftText(context, label),
      child: Text(
        share && value != null && total != null && total > 0
            ? raftFormat(context, '{tokens} · {percent}', {
                'tokens': format(value),
                'percent': NumberFormat.percentPattern(locale)
                    .format(value / total),
              })
            : format(value),
        style: RaftPanelText.profileMono(t),
      ),
    );
    Widget section(String title, List<Widget> body) => RaftPanelSection(
      children: [
        RaftSectionEyebrow(
          _selectedDay == null
              ? raftText(context, title)
              : raftFormat(context, '{day} · {heading}', {
                  'day': dayName(_selectedDay!),
                  'heading': raftText(context, title),
                }),
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
    final freshness = [
      if (_selectedDay == null || _selectedDay == report.to)
        Text(
          raftFormat(context, 'As of {time}', {
            'time': DateFormat.MMMd(locale)
                .add_jm()
                .format(report.asOf.toLocal()),
          }),
          style: RaftPanelText.caption(t),
        ),
      if (figures.since case final String since
          when figures.days.first.day.compareTo(since) < 0)
        Text(
          raftFormat(context, 'Usage since {date}', {'date': dayName(since)}),
          style: RaftPanelText.caption(t),
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
              .copyWith(bottom: RaftSpace.x3),
          child: RaftCard(
            key: const ValueKey('members-usage-summary'),
            padding: const EdgeInsets.all(RaftSpace.x4),
            child: LayoutBuilder(
              builder: (context, bounds) {
                final details = RaftGapColumn(
                  gap: 8,
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
                        ),
                        ?comparison,
                      ],
                    ),
                    fact('New input', counts.inputNew),
                    if (counts.cacheWrite != null)
                      fact('Cache write', counts.cacheWrite),
                    fact('Output', counts.output),
                    if (counts.reasoning case final int reasoning)
                      Text(
                        raftFormat(context, 'Includes {tokens} reasoning', {
                          'tokens': format(reasoning),
                        }),
                        style: RaftPanelText.caption(t),
                      ),
                    fact('Cache reads', counts.cacheRead),
                    fact('Agents reporting', figures.reporting),
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
      section('Tokens', [
        if (widget.agentId == null) ...[heading, _cacheReadSwitch(context)],
        headline,
        ?comparison,
        ...freshness,
        chart,
      ]),
      section('Token types', [
        fact('New input', counts.inputNew, share: true),
        if (counts.cacheWrite != null)
          fact('Cache write', counts.cacheWrite, share: true),
        fact('Cache reads', counts.cacheRead, share: true),
        fact('Output', counts.output, share: true),
        if (counts.reasoning case final int reasoning)
          Text(
            raftFormat(context, 'Includes {tokens} reasoning', {
              'tokens': format(reasoning),
            }),
          ),
        fact('Total tokens', total),
      ]),
      section('Context', [
        if (counts.cacheRead != null && input > 0)
          RaftInfoRow(
            label: raftText(context, 'Cache reads'),
            child: Text(
              raftFormat(context, '{percent} of input', {
                'percent': NumberFormat.percentPattern(locale)
                    .format(counts.cacheRead! / input),
              }),
            ),
          ),
        fact(
          'Per turn',
          total == null || counts.turns == 0
              ? null
              : (total / counts.turns).round(),
        ),
        if (reading != null)
          RaftMeter(
            label: raftText(context, 'Context window'),
            used: reading.used,
            max: reading.window,
            valueText: raftFormat(context, '{used} of {window}', {
              'used': format(reading.used),
              'window': format(reading.window),
            }),
          )
        else
          fact('Context window', null),
      ]),
      section('Models', [
        for (final model in figures.models)
          fact(
            model.model.model.isEmpty ? 'Unknown model' : model.model.model,
            model.tokens,
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
