import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_token_usage.dart';
import 'members_page_entries.dart';

enum MembersUsageColumn {
  agent('Agent'),
  tokens('Tokens'),
  share('Share of total'),
  perTurn('Per turn'),
  context('Context'),
  change('vs prior period');

  const MembersUsageColumn(this.label);
  final String label;
}

class MembersUsageTable extends StatefulWidget {
  const MembersUsageTable({
    super.key,
    required this.groups,
    required this.report,
    required this.period,
    required this.selectedDay,
    required this.withCacheReads,
    required this.total,
    required this.onOpen,
  });

  final List<(String, List<MemberPageEntry>)> groups;
  final AgentUsageReport report;
  final AgentUsagePeriod period;
  final String? selectedDay;
  final bool withCacheReads;
  final int? total;
  final ValueChanged<String> onOpen;

  @override
  State<MembersUsageTable> createState() => _MembersUsageTableState();
}

class _MembersUsageTableState extends State<MembersUsageTable> {
  MembersUsageColumn _sort = MembersUsageColumn.tokens;
  var _ascending = false;
  late List<(String, List<(MemberPageEntry, AgentUsageFigures)>)> _groups;

  @override
  void initState() {
    super.initState();
    _project();
  }

  @override
  void didUpdateWidget(MembersUsageTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report != widget.report ||
        oldWidget.period != widget.period ||
        oldWidget.selectedDay != widget.selectedDay ||
        oldWidget.withCacheReads != widget.withCacheReads ||
        oldWidget.total != widget.total ||
        !_sameGroups(oldWidget.groups)) {
      _project();
    }
  }

  bool _sameGroups(List<(String, List<MemberPageEntry>)> previous) {
    final groups = widget.groups;
    if (groups.length != previous.length) return false;
    for (final (index, (heading, entries)) in groups.indexed) {
      final (oldHeading, oldEntries) = previous[index];
      if (heading != oldHeading || !listEquals(entries, oldEntries)) {
        return false;
      }
    }
    return true;
  }

  num? _value(AgentUsageFigures figures, MembersUsageColumn column) {
    if (figures.noData || !figures.supported) return null;
    final counts = figures.counts;
    final tokens = counts.total(withCacheReads: widget.withCacheReads);
    final total = counts.total();
    final reading = figures.context;
    final compared = figures.compared;
    final base = figures.base;
    return switch (column) {
      MembersUsageColumn.agent => null,
      MembersUsageColumn.tokens => tokens,
      MembersUsageColumn.share =>
        tokens != null && (widget.total ?? 0) > 0
            ? tokens / widget.total!
            : null,
      MembersUsageColumn.perTurn =>
        counts.turns == 0 || total == null
            ? null
            : (total / counts.turns).round(),
      MembersUsageColumn.context =>
        reading == null ? null : reading.used / reading.window,
      MembersUsageColumn.change =>
        compared == null || base == null || base <= 0
            ? null
            : (compared - base) / base,
    };
  }

  void _project() {
    _groups = [
      for (final (heading, agents) in widget.groups)
        if (agents.isNotEmpty) (heading, _sortedRows(agents)),
    ];
  }

  List<(MemberPageEntry, AgentUsageFigures)> _sortedRows(
    List<MemberPageEntry> agents,
  ) =>
      [
        for (final agent in agents)
          (
            agent,
            widget.report.figures(
              widget.period,
              agentId: agent.target.id,
              selectedDay: widget.selectedDay,
              withCacheReads: widget.withCacheReads,
            ),
          ),
      ]..sort((first, second) {
        if (_sort != MembersUsageColumn.agent) {
          final left = _value(first.$2, _sort);
          final right = _value(second.$2, _sort);
          if (left == null && right != null) return 1;
          if (right == null && left != null) return -1;
          if (left != null && right != null) {
            final order = left.compareTo(right);
            if (order != 0) return _ascending ? order : -order;
          }
        }
        final byName = first.$1.name.toLowerCase().compareTo(
          second.$1.name.toLowerCase(),
        );
        return _sort == MembersUsageColumn.agent && !_ascending
            ? -byName
            : byName;
      });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final numbers = NumberFormat.decimalPattern(locale);
    final percentages = NumberFormat.percentPattern(locale);
    final tokens = RaftTokens.of(context);
    String display(AgentUsageFigures figures, MembersUsageColumn column) {
      final value = _value(figures, column);
      if (value == null) return '—';
      return switch (column) {
        MembersUsageColumn.share ||
        MembersUsageColumn.context => percentages.format(value),
        MembersUsageColumn.change =>
          '${value > 0 ? '+' : ''}${percentages.format(value)}',
        _ => numbers.format(value),
      };
    }

    return SliverLayoutBuilder(
      builder: (context, bounds) {
        final columns = [
          MembersUsageColumn.agent,
          MembersUsageColumn.tokens,
          MembersUsageColumn.share,
          if (bounds.crossAxisExtent >= 760) ...[
            MembersUsageColumn.perTurn,
            MembersUsageColumn.context,
          ],
          MembersUsageColumn.change,
        ];
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x5),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: Row(
                  children: [
                    for (final column in columns)
                      Expanded(
                        flex: column == MembersUsageColumn.agent ? 3 : 2,
                        child: RaftInteractive(
                          key: ValueKey('members-usage-sort-${column.name}'),
                          selected: _sort == column,
                          onPressed: () => setState(() {
                            _ascending = column == _sort
                                ? !_ascending
                                : column == MembersUsageColumn.agent;
                            _sort = column;
                            _project();
                          }),
                          builder: (_, state) => Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: RaftSpace.x2,
                            ),
                            child: Text(
                              raftText(
                                context,
                                column == MembersUsageColumn.change &&
                                        widget.selectedDay != null
                                    ? 'vs week earlier'
                                    : column.label,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: column == MembersUsageColumn.agent
                                  ? TextAlign.start
                                  : TextAlign.end,
                              style: _sort == column || state.focusVisible
                                  ? RaftPanelText.caption(tokens).copyWith(
                                      fontWeight: tokens
                                          .scale(RaftTypeScale.title)
                                          .fontWeight,
                                    )
                                  : RaftPanelText.caption(tokens),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              for (final (heading, rows) in _groups) ...[
                if (heading.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: RaftSpace.x2,
                      ),
                      child: RaftSectionEyebrow('$heading  ${rows.length}'),
                    ),
                  ),
                RaftListRowGroup.sliver(
                  sliver: SliverList.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final (agent, figures) = rows[index];
                      return RaftListRow(
                        key: ValueKey('members-usage-agent-${agent.target.id}'),
                        onPressed: () => widget.onOpen(agent.target.id),
                        children: [
                          for (final column in columns)
                            Expanded(
                              flex: column == MembersUsageColumn.agent ? 3 : 2,
                              child: column == MembersUsageColumn.agent
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        RaftListRowTitle(agent.name),
                                        if (!figures.supported)
                                          RaftListRowMeta(
                                            raftText(context, 'No usage yet'),
                                          ),
                                      ],
                                    )
                                  : Semantics(
                                      label: raftText(context, column.label),
                                      child: Text(
                                        display(figures, column),
                                        textAlign: TextAlign.end,
                                        style: RaftPanelText.profileMono(
                                          tokens,
                                        ),
                                      ),
                                    ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
