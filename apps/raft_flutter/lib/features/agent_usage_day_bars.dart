import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_token_usage.dart';

class AgentUsageDayBars extends StatefulWidget {
  const AgentUsageDayBars({
    super.key,
    required this.days,
    required this.withCacheReads,
    required this.selected,
    required this.onSelect,
    required this.formatTokens,
  });

  final List<AgentUsageDay> days;
  final bool withCacheReads;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final String Function(num?) formatTokens;

  @override
  State<AgentUsageDayBars> createState() => _AgentUsageDayBarsState();
}

class _AgentUsageDayBarsState extends State<AgentUsageDayBars> {
  static const _minDayWidth = 18.0;
  static const _plotHeight = 96.0;
  static const _maxBarWidth = 28.0;
  static const _slotFill = .56;
  static const _stackHeight = 84.0;
  static const _segmentGap = RaftSpace.half;
  static const _segmentRadius = RaftRadius.chip / 2;
  static const _segmentStroke = RaftSpace.hairline * 1.5;
  static const _captionLines = 2;

  final _scroll = ScrollController();
  final _focus = List.generate(AgentUsagePeriod.month.days, (_) => FocusNode());
  int? _hovered;

  @override
  void dispose() {
    _scroll.dispose();
    for (final node in _focus) {
      node.dispose();
    }
    super.dispose();
  }

  KeyEventResult _move(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        widget.selected != null) {
      widget.onSelect(null);
      return KeyEventResult.handled;
    }
    final index = _focus.indexWhere((node) => node.hasFocus);
    if (index < 0) return KeyEventResult.ignored;
    final last = widget.days.length - 1;
    final next = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight ||
      LogicalKeyboardKey.arrowDown => index + 1,
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.arrowUp => index - 1,
      LogicalKeyboardKey.home => 0,
      LogicalKeyboardKey.end => last,
      _ => null,
    };
    if (next == null) return KeyEventResult.ignored;
    final target = next.clamp(0, last);
    widget.onSelect(widget.days[target].day);
    if (_scroll.hasClients) {
      final position = _scroll.position;
      final slot = _slotWidth(position.viewportDimension);
      final start = (last - target) * slot;
      final end = start + slot;
      if (start < position.pixels ||
          end > position.pixels + position.viewportDimension) {
        _scroll.jumpTo(
          (start - (position.viewportDimension - slot) / 2).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
      }
    }
    _focus[target].requestFocus();
    return KeyEventResult.handled;
  }

  double _slotWidth(double viewport) =>
      math.max(_minDayWidth, viewport / widget.days.length);

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    if (days.isEmpty) return const SizedBox.shrink();
    final tokens = RaftTokens.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final weekday = DateFormat.E(locale);
    final date = DateFormat.Md(locale);
    final series =
        [
              if (widget.withCacheReads)
                (
                  'Cache reads',
                  'palette-stone-400',
                  (AgentTokenCounts counts) => counts.cacheRead,
                ),
              (
                'New input',
                'palette-lavender-600',
                (AgentTokenCounts counts) => counts.inputNew,
              ),
              (
                'Cache write',
                'palette-lavender-300',
                (AgentTokenCounts counts) => counts.cacheWrite,
              ),
              (
                'Output',
                'palette-cyan-500',
                (AgentTokenCounts counts) => counts.output,
              ),
            ]
            .where(
              (series) => days.any((day) => (series.$3(day.counts) ?? 0) > 0),
            )
            .toList();
    final totals = [
      for (final day in days)
        day.counts.total(withCacheReads: widget.withCacheReads) ?? 0,
    ];
    final peak = totals.fold(1, math.max);
    final picked = days.indexWhere((day) => day.day == widget.selected);
    final shown = _hovered != null && _hovered! < days.length
        ? _hovered!
        : picked;
    final current = shown < 0 ? null : days[shown];
    final values = [
      for (final (label, _, amount) in series)
        raftFormat(context, '{kind} {tokens}', {
          'kind': raftText(context, label),
          'tokens': widget.formatTokens(
            current == null
                ? days.fold<int>(
                    0,
                    (sum, day) => sum + (amount(day.counts) ?? 0),
                  )
                : amount(current.counts) ?? 0,
          ),
        }),
    ].join(' · ');
    final readout = current == null
        ? values
        : raftFormat(context, '{day} · {figures}', {
            'day':
                '${weekday.format(DateTime.parse(current.day))} ${date.format(DateTime.parse(current.day))}',
            'figures': current.noData ? '—' : values,
          });
    final last = days.length - 1;
    final style = RaftPanelText.caption(tokens);
    final captionLine =
        MediaQuery.textScalerOf(context).scale(RaftTypeScale.caption.fontSize) *
        (style.height ?? 1);
    final plotAndLabels = _plotHeight + captionLine;
    return Column(
      spacing: RaftSpace.x2,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(readout, style: RaftPanelText.profileMono(tokens)),
        ),
        Semantics(
          label: raftText(context, 'Tokens per day'),
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: _move,
            child: LayoutBuilder(
              builder: (context, bounds) {
                final slot = _slotWidth(bounds.maxWidth);
                return SizedBox(
                  height:
                      plotAndLabels +
                      captionLine * _captionLines +
                      RaftSpace.hairline,
                  child: ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    itemExtent: slot,
                    itemCount: days.length,
                    itemBuilder: (context, offset) {
                      final index = last - offset;
                      final day = days[index];
                      return RaftInteractive(
                        key: ValueKey('agent-usage-day-${day.day}'),
                        focusNode: _focus[index]
                          ..skipTraversal =
                              index != (picked < 0 ? last : picked),
                        expandTouchTarget: false,
                        inMutuallyExclusiveGroup: true,
                        checked: picked == index,
                        semanticLabel: raftFormat(
                          context,
                          day.partial
                              ? '{day}, partial day: {tokens}'
                              : '{day}: {tokens}',
                          {
                            'day': date.format(DateTime.parse(day.day)),
                            'tokens': widget.formatTokens(
                              day.noData ? null : totals[index],
                            ),
                          },
                        ),
                        onShowHoverHighlight: (hover) => setState(() {
                          if (hover || _hovered == index) {
                            _hovered = hover ? index : null;
                          }
                        }),
                        onPressed: () =>
                            widget.onSelect(picked == index ? null : day.day),
                        builder: (_, state) => Column(
                          children: [
                            SizedBox(
                              height: plotAndLabels,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: picked == index
                                      ? tokens.ui.fillMuted
                                      : null,
                                  border: state.focusVisible
                                      ? Border.all(color: tokens.ui.foreground)
                                      : null,
                                  borderRadius: BorderRadius.circular(
                                    RaftRadius.chip,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (!day.noData &&
                                        (days.length == 7 ||
                                            shown == index ||
                                            (shown < 0 &&
                                                totals[index] == peak)))
                                      Text(
                                        widget.formatTokens(totals[index]),
                                        style: style,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (!day.noData)
                                      for (final (_, color, amount)
                                          in series.reversed)
                                        if ((amount(day.counts) ?? 0) > 0)
                                          Container(
                                            width: math.min(
                                              _maxBarWidth,
                                              slot * _slotFill,
                                            ),
                                            height: math.max(
                                              _segmentGap,
                                              _stackHeight *
                                                      amount(day.counts)! /
                                                      peak -
                                                  _segmentGap,
                                            ),
                                            margin: const EdgeInsets.only(
                                              bottom: _segmentGap,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  (tokens.colors[color] ??
                                                          tokens.ui.info)
                                                      .withValues(
                                                        alpha:
                                                            shown < 0 ||
                                                                shown == index
                                                            ? 1
                                                            : .32,
                                                      ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    _segmentRadius,
                                                  ),
                                              border: Border.all(
                                                color: tokens
                                                    .colors['sticker-ink']!,
                                                width: _segmentStroke,
                                              ),
                                            ),
                                          ),
                                  ],
                                ),
                              ),
                            ),
                            ColoredBox(
                              color: tokens.ui.lineHairline,
                              child: const SizedBox(
                                height: RaftSpace.hairline,
                                width: double.infinity,
                              ),
                            ),
                            if (days.length <= 14 ||
                                index == picked ||
                                (last - index) % 7 == 0)
                              Text(
                                days.length == 7 && index == last
                                    ? '${raftText(context, 'Today')}${day.partial ? '*' : ''}'
                                    : date.format(DateTime.parse(day.day)),
                                style: style,
                                textAlign: TextAlign.center,
                                maxLines: _captionLines,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
        if (days.any((day) => day.partial))
          Text(raftText(context, '* Partial day'), style: style),
      ],
    );
  }
}
