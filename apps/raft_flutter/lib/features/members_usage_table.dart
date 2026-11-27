import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_token_usage.dart';
import 'agent_metadata_projection.dart' show agentRowAmbientDisplay;
import 'agent_runtime_labels.dart' show runtimeDisplayNameOf;
import 'agent_runtime_models.dart' show runtimeModelLabel;
import 'icu_message.dart';
import 'members_page_entries.dart';

enum MembersUsageColumn {
  agent('Agent', 0),
  tokens('Tokens', 104),
  share('Share of total', 60),
  perTurn('Per turn', 84),
  context('Context', 70),
  change('vs prior period', 124);

  const MembersUsageColumn(this.label, this.width);
  final String label;
  final double width;
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
    required this.visibleCount,
    required this.origin,
    required this.onOpen,
  });

  final List<(String, List<MemberPageEntry>)> groups;
  final AgentUsageReport report;
  final AgentUsagePeriod period;
  final String? selectedDay;
  final bool withCacheReads;
  final int? total;
  final int visibleCount;
  final String origin;
  final ValueChanged<String> onOpen;

  @override
  State<MembersUsageTable> createState() => _MembersUsageTableState();
}

class _MembersUsageTableState extends State<MembersUsageTable> {
  static const _statusWidth = 90.0;
  static const _modelWidth = 176.0;
  static const _trendWidth = 84.0;
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
    final numbers = NumberFormat.compact(locale: locale)
      ..maximumFractionDigits = 1;
    final largeNumbers = NumberFormat.compact(locale: locale)
      ..maximumFractionDigits = 2;
    final percentages = NumberFormat.percentPattern(locale);
    final shares = NumberFormat.percentPattern(locale)
      ..maximumFractionDigits = 1;
    final tokens = RaftTokens.of(context);
    String display(AgentUsageFigures figures, MembersUsageColumn column) {
      final value = _value(figures, column);
      if (value == null) return '—';
      return switch (column) {
        MembersUsageColumn.share => shares.format(value),
        MembersUsageColumn.context => percentages.format(value),
        MembersUsageColumn.change =>
          '${value > 0 ? '+' : ''}${percentages.format(value)}',
        _ => (value >= 1e9 ? largeNumbers : numbers).format(value),
      };
    }

    return SliverLayoutBuilder(
      builder: (context, bounds) {
        final width = bounds.crossAxisExtent - 2 * RaftSpace.x5;
        final wide = width >= 1040;
        final showStatus = width >= 360;
        final columns = [
          MembersUsageColumn.agent,
          if (width >= 240) MembersUsageColumn.tokens,
          if (width >= 470) MembersUsageColumn.share,
          if (width >= 760) ...[
            MembersUsageColumn.perTurn,
            MembersUsageColumn.context,
          ],
          if (width >= 470) MembersUsageColumn.change,
        ];
        final headingStyle = tokens.scale(
          RaftTypeScale.footnote,
          color: tokens.ui.foregroundHint,
          weight: FontWeight.w700,
        );
        Widget fixedLabel(String text, double width) => SizedBox(
          width: width,
          child: Text(
            text,
            style: headingStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
        List<Widget> tracks({
          required Widget identity,
          required Widget status,
          required Widget model,
          required Widget Function(MembersUsageColumn) figure,
          required Widget trend,
        }) => [
          Expanded(child: identity),
          if (showStatus) SizedBox(width: _statusWidth, child: status),
          if (wide) SizedBox(width: _modelWidth, child: model),
          for (final column in columns.skip(1))
            SizedBox(width: column.width, child: figure(column)),
          if (wide) SizedBox(width: _trendWidth, child: trend),
        ];
        Widget sortHeading(MembersUsageColumn column) => RaftInteractive(
          key: ValueKey('members-usage-sort-${column.name}'),
          selected: _sort == column,
          onPressed: () => setState(() {
            _ascending = column == _sort
                ? !_ascending
                : column == MembersUsageColumn.agent;
            _sort = column;
            _project();
          }),
          builder: (_, state) => Row(
            spacing: RaftSpace.x1,
            mainAxisAlignment: column == MembersUsageColumn.agent
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            children: [
              if (_sort == column)
                RaftIcon(
                  _ascending ? RaftGlyph.arrowUp : RaftGlyph.arrowDown,
                  size: 12,
                ),
              Flexible(
                child: Text(
                  raftText(
                    context,
                    column == MembersUsageColumn.change &&
                            widget.selectedDay != null
                        ? 'vs week earlier'
                        : column.label,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _sort == column || state.focusVisible
                      ? headingStyle.copyWith(color: tokens.ui.foreground)
                      : headingStyle,
                ),
              ),
            ],
          ),
        );
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x5),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: RaftSpace.x1,
                    right: RaftSpace.x4,
                    bottom: RaftSpace.x2,
                  ),
                  child: Row(
                    spacing: RaftSpace.x3,
                    children: tracks(
                      identity: sortHeading(MembersUsageColumn.agent),
                      status: fixedLabel(
                        raftText(context, 'Status'),
                        _statusWidth,
                      ),
                      model: fixedLabel(
                        raftText(context, 'Model'),
                        _modelWidth,
                      ),
                      figure: sortHeading,
                      trend: fixedLabel(
                        icuText(
                          context,
                          '{count, plural, one {# day} other {# days}}',
                          {'count': widget.period.days},
                        ),
                        _trendWidth,
                      ),
                    ),
                  ),
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
                      final record = agent.record;
                      final runtime = record['runtime'] as String?;
                      final modelName = record['model'] as String?;
                      final description = record['description'] as String?;
                      final ambient = agentRowAmbientDisplay(record);
                      final (tone, statusLabel) = switch (ambient.activity) {
                        'working' => (RaftActivityTone.working, 'Working…'),
                        'thinking' => (RaftActivityTone.thinking, 'Thinking…'),
                        'offline' => (RaftActivityTone.offline, 'Offline'),
                        'error' => (RaftActivityTone.error, 'Error'),
                        _ => (RaftActivityTone.online, 'Online'),
                      };
                      final model = modelName == null
                          ? '—'
                          : runtimeModelLabel(runtime ?? '', modelName);
                      return RaftListRow(
                        key: ValueKey('members-usage-agent-${agent.target.id}'),
                        onPressed: () => widget.onOpen(agent.target.id),
                        children: tracks(
                          identity: Row(
                            spacing: RaftSpace.x3,
                            children: [
                              usageAgentAvatar(
                                agent,
                                widget.origin,
                                35,
                                badge: RaftStatusDot(
                                  activity: tone,
                                  size: RaftStatusDotSize.sm,
                                ),
                              ),
                              Expanded(
                                child: RaftListRowBody(
                                  children: [
                                    RaftListRowTitle(agent.name),
                                    if (description != null &&
                                        description.isNotEmpty)
                                      RaftListRowSubtitle(description),
                                    if (!wide && modelName != null)
                                      RaftListRowMeta(
                                        runtime == null
                                            ? model
                                            : '$model · ${runtimeDisplayNameOf(runtime)}',
                                      ),
                                    if (!figures.supported || figures.empty)
                                      RaftListRowMeta(
                                        raftText(context, 'No usage yet'),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          status: Row(
                            spacing: RaftSpace.x2,
                            children: [
                              RaftStatusDot(
                                activity: tone,
                                size: RaftStatusDotSize.sm,
                              ),
                              Expanded(
                                child: RaftCssText(
                                  raftText(
                                    context,
                                    ambient.heldText ?? statusLabel,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tokens.scale(
                                    RaftTypeScale.caption,
                                    color: tokens.ui.foregroundMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          model: RaftListRowMeta(model),
                          figure: (column) => Semantics(
                            label: raftText(context, column.label),
                            child: Row(
                              spacing: RaftSpace.x1,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if ((column == MembersUsageColumn.change
                                        ? _value(figures, column)
                                        : null)
                                    case final num change)
                                  RaftIcon(
                                    change < 0
                                        ? RaftGlyph.arrowDownRight
                                        : RaftGlyph.arrowUpRight,
                                    size: 12,
                                  ),
                                Flexible(
                                  child: column == MembersUsageColumn.tokens
                                      ? RaftCssText(
                                          display(figures, column),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: tokens.scale(
                                            RaftTypeScale.monoMeta,
                                            mono: true,
                                            color: tokens.ui.foreground,
                                          ),
                                        )
                                      : RaftListRowMeta(
                                          display(figures, column),
                                        ),
                                ),
                              ],
                            ),
                          ),
                          trend: wide
                              ? _trend(figures, tokens)
                              : const SizedBox.shrink(),
                        ),
                      );
                    },
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: RaftSpace.x3),
                  child: Text(
                    icuText(
                      context,
                      'Share of total counts the {count, plural, one {# agent} other {# agents}} you can see.',
                      {'count': widget.visibleCount},
                    ),
                    style: tokens.scale(
                      RaftTypeScale.monoMeta,
                      mono: true,
                      color: tokens.ui.foregroundHint,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _trend(AgentUsageFigures figures, RaftTokens tokens) {
    final values = [
      for (final day in figures.days)
        day.noData
            ? null
            : day.counts.total(withCacheReads: widget.withCacheReads) ?? 0,
    ];
    return ExcludeSemantics(
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: CustomPaint(
          size: _UsageTrend.extent,
          painter: _UsageTrend(
            values: values,
            mark: widget.selectedDay == null
                ? values.length - 1
                : figures.days.indexWhere(
                    (day) => day.day == widget.selectedDay,
                  ),
            partial: figures.days.indexWhere((day) => day.partial),
            color: tokens.colors['palette-lavender-600']!,
            ink: tokens.ui.stickerInk,
          ),
        ),
      ),
    );
  }
}

class _UsageTrend extends CustomPainter {
  static const extent = Size(80, 20);

  const _UsageTrend({
    required this.values,
    required this.mark,
    required this.partial,
    required this.color,
    required this.ink,
  });

  final List<int?> values;
  final int mark, partial;
  final Color color, ink;

  @override
  void paint(Canvas canvas, Size size) {
    final peak = values.fold<int>(
      1,
      (max, value) => value != null && value > max ? value : max,
    );
    final step =
        (size.width - 4) / (values.length - 1).clamp(1, values.length + 1);
    final points = [
      for (final (index, value) in values.indexed)
        value == null
            ? null
            : Offset(
                2 + index * step,
                size.height - 3 - (size.height - 6) * value / peak,
              ),
    ];
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final whole = points
        .take(partial < 0 ? points.length : partial)
        .whereType<Offset>();
    if (whole.length > 1) {
      final path = Path()..addPolygon(whole.toList(), false);
      canvas.drawPath(path, paint);
    }
    if (partial > 0 && points[partial] != null && points[partial - 1] != null) {
      final start = points[partial - 1]!;
      final end = points[partial]!;
      final distance = (end - start).distance;
      for (var offset = 0.0; offset < distance; offset += 5) {
        canvas.drawLine(
          Offset.lerp(start, end, offset / distance)!,
          Offset.lerp(start, end, ((offset + 2) / distance).clamp(0.0, 1.0))!,
          paint,
        );
      }
    }
    final index = mark >= 0 && points[mark] != null
        ? mark
        : points.lastIndexWhere((point) => point != null);
    if (index < 0) return;
    final point = points[index]!;
    if (index != partial) {
      canvas.drawCircle(point, 2.5, Paint()..color = color);
    }
    canvas.drawCircle(
      point,
      2.5,
      paint
        ..color = index == partial ? color : ink
        ..strokeWidth = index == partial ? 1.5 : 1,
    );
  }

  @override
  bool shouldRepaint(_UsageTrend oldDelegate) =>
      !listEquals(values, oldDelegate.values) ||
      mark != oldDelegate.mark ||
      partial != oldDelegate.partial ||
      color != oldDelegate.color ||
      ink != oldDelegate.ink;
}
