import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'icons.dart';
import 'localization.dart';
import 'message_read_faces.dart';
import 'message_rule_row.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/ui_tokens.dart';
import 'text_scaling.dart';
import 'theme.dart';
import 'tokens/tokens.dart';
import 'tooltip.dart';

enum RaftAgentReadReason { stoppedFollowing, muted }

/// Web MessageItem `dm-read-status`: a separate right-aligned line below the
/// last DM message's footer and inline replies. Visibility belongs to the app.
class RaftMessageReadStatus extends StatelessWidget {
  const RaftMessageReadStatus({super.key}) : entries = const [];

  const RaftMessageReadStatus.agents({super.key, required this.entries});

  final List<(RaftAgentReadReason, String)> entries;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final label = raftText(context, 'Read');
    final style = t.scale(t.typeSlot('caption'), color: t.ui.foregroundHint);
    final agentStatus = entries.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(top: RaftScale.space(1)),
      child: KeyedSubtree(
        key: ValueKey(agentStatus ? 'agent-read-status' : 'dm-read-status'),
        child: RaftScaled.lineBox(
          context,
          height: RaftScale.space(5),
          child: Align(
            alignment: Alignment.centerRight,
            child: agentStatus
                ? _AgentStatus(entries: entries, style: style)
                : Semantics(
                    container: true,
                    label: label,
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RaftIcon(
                            RaftGlyph.checkCircle,
                            size: RaftScale.space(3),
                            color: t.ui.foregroundHint,
                          ),
                          SizedBox(width: RaftScale.space(1)),
                          RaftCssText(label, style: style),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _AgentStatus extends StatelessWidget {
  const _AgentStatus({required this.entries, required this.style});
  final List<(RaftAgentReadReason, String)> entries;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final namesByReason = <RaftAgentReadReason, List<String>>{};
    for (final (reason, name) in entries) {
      (namesByReason[reason] ??= []).add(readAgentName(context, name));
    }
    final hint = raftText(context, 'Mention them to reach them');
    final separator = '·';
    String reasonText(RaftAgentReadReason reason, String names) => raftFormat(
      context,
      switch (reason) {
        RaftAgentReadReason.stoppedFollowing => 'Stopped following: {names}',
        RaftAgentReadReason.muted => 'Muted: {names}',
      },
      {'names': names},
    );
    final full = [
      for (final entry in namesByReason.entries)
        reasonText(entry.key, readAgentNames(context, entry.value)),
    ].join(' $separator ');
    final label = raftFormat(context, 'Agents on this message: {status}', {
      'status': '$full $separator $hint',
    });
    final gap = RaftScale.space(1);
    final iconSize = RaftScale.space(3);
    final icon = entries.first.$1 == RaftAgentReadReason.stoppedFollowing
        ? RaftGlyph.unfollowThread
        : RaftGlyph.bellOff;
    return LayoutBuilder(
      builder: (context, constraints) {
        var budget = 3;
        var ahead = namesByReason.length;
        final segments =
            <({String verb, String names, String? more, String count})>[];
        for (final entry in namesByReason.entries) {
          final names = entry.value;
          ahead--;
          final take = (budget - ahead).clamp(1, names.length);
          budget -= take;
          final remaining = names.length - take;
          final shown = readAgentNames(
            context,
            names.take(take).toList(),
            open: remaining > 0,
          );
          segments.add((
            verb: reasonText(entry.key, ''),
            names: shown,
            more: remaining > 0
                ? raftFormat(context, '+{count}', {'count': remaining})
                : null,
            count: reasonText(
              entry.key,
              raftFormat(
                context,
                names.length == 1 ? '{count} agent' : '{count} agents',
                {'count': names.length},
              ),
            ),
          ));
        }
        double width(String value) =>
            raftMessageTextWidth(context, value, style);
        final captionSize = MediaQuery.textScalerOf(context)
            .scale(style.fontSize!);
        final separatorWidth = width(separator);
        final hintWidth = width(hint);
        final fixed =
            iconSize + gap + segments.length * (2 * gap + separatorWidth);
        final verbWidths = segments
            .map((segment) => width(segment.verb))
            .toList();
        final nameWidths = segments
            .map((segment) => width(segment.names))
            .toList();
        final minimumNames = nameWidths
            .map((size) => math.min(size, 2 * captionSize))
            .toList();
        final moreWidths = segments
            .map(
              (segment) =>
                  segment.more == null ? 0.0 : gap + width(segment.more!),
            )
            .toList();
        final useCount = List.filled(segments.length, false);
        var required = fixed + hintWidth;
        for (var index = 0; index < segments.length; index++) {
          required +=
              verbWidths[index] + minimumNames[index] + moreWidths[index];
        }
        final available = constraints.maxWidth;
        for (
          var index = segments.length - 1;
          index >= 0 && required > available;
          index--
        ) {
          useCount[index] = true;
          required +=
              width(segments[index].count) -
              verbWidths[index] -
              minimumNames[index] -
              moreWidths[index];
        }
        var spare = math.max(0.0, available - required);
        var abbreviated = false;
        final parts = <Widget>[];
        for (var index = 0; index < segments.length; index++) {
          final segment = segments[index];
          if (useCount[index]) {
            abbreviated = true;
            parts.add(_text(segment.count));
          } else {
            final extra = math.min(
              spare,
              nameWidths[index] - minimumNames[index],
            );
            final shownWidth = minimumNames[index] + extra;
            spare -= extra;
            abbreviated |=
                shownWidth < nameWidths[index] || segment.more != null;
            parts.addAll([
              _text(segment.verb),
              SizedBox(width: shownWidth, child: _text(segment.names)),
              if (segment.more case final more?) ...[
                SizedBox(width: gap),
                _text(more),
              ],
            ]);
          }
          parts.addAll([
            SizedBox(width: gap),
            _text(separator),
            SizedBox(width: gap),
          ]);
        }
        final fitsCounts = required - hintWidth <= available;
        return RaftTooltip(
          message: full,
          enabled: abbreviated,
          excludeFromSemantics: true,
          child: Semantics(
            container: true,
            label: label,
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RaftIcon(icon, size: iconSize, color: style.color),
                  SizedBox(width: gap),
                  if (fitsCounts) ...[
                    ...parts,
                    Flexible(child: _text(hint)),
                  ] else
                    Flexible(
                      child: _text(
                        '${segments.map((segment) => segment.count).join(' $separator ')} '
                        '$separator $hint',
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _text(String text) =>
      Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
}
