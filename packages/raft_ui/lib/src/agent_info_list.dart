import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'panel_layout.dart' show RaftCssText, RaftInfoRow, RaftInlineIconButton;
import 'theme.dart';

/// raft-ui `DescriptionList direction="horizontal"` as the agent profile's
/// Info and Runtime config lists use it (Web v1.24 `features/agent/InfoRow.tsx`,
/// `AgentProfileInfo.tsx` `<DescriptionList direction="horizontal">`): one term
/// column per list, as wide as its widest term (88px at least, 160px at most),
/// 16px before the details, 2px between the rows. The Elegant and Brutal looks
/// keep the frozen 124px term grid of Web v1.21.12.
///
/// Rows are real [RaftInfoRow]s; any other child (a banner) ends one run of
/// rows and starts the next, as Web's `col-span-full` item does.
class RaftInfoList extends StatelessWidget {
  const RaftInfoList({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!RaftTokens.of(context).isRaftLook) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    final out = <Widget>[];
    var run = <RaftInfoRow>[];
    var first = true;
    void flush() {
      if (run.isEmpty) return;
      final width = raftInfoTermWidth(context, run);
      for (final row in run) {
        out.add(
          RaftInfoColumnScope(termWidth: width, first: first, child: row),
        );
        first = false;
      }
      run = [];
    }

    for (final child in children) {
      if (child is RaftInfoRow) {
        run.add(child);
      } else {
        flush();
        out.add(child);
        first = true;
      }
    }
    flush();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: out,
    );
  }
}

/// What a list tells its rows: the shared term column width and whether the
/// row is the first of its run (no 2px gap above it).
class RaftInfoColumnScope extends InheritedWidget {
  const RaftInfoColumnScope({
    super.key,
    required this.termWidth,
    required this.first,
    required super.child,
  });
  final double termWidth;
  final bool first;

  static RaftInfoColumnScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RaftInfoColumnScope>();

  @override
  bool updateShouldNotify(RaftInfoColumnScope old) =>
      termWidth != old.termWidth || first != old.first;
}

/// The term column of [rows]: the widest label plus its action icons, clamped
/// to 88..160 (the grid's `minmax(88px, max-content)` with a 160px cap).
double raftInfoTermWidth(BuildContext context, List<RaftInfoRow> rows) {
  final style = RaftInfoRow.termStyleOf(context);
  final scaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  var widest = 0.0;
  for (final row in rows) {
    final painter = TextPainter(
      text: TextSpan(text: row.label, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    var width = painter.width;
    painter.dispose();
    for (final action in row.actions) {
      width += 6 + (action is RaftInlineIconButton ? action.size : 12);
    }
    widest = math.max(widest, width);
  }
  return widest.clamp(88.0, 160.0);
}

/// One Raft-look row: term | 16px | details (callout, 32px at least, centred
/// on the term's baseline).
class RaftInfoRowBody extends StatelessWidget {
  const RaftInfoRowBody({super.key, required this.row});
  final RaftInfoRow row;

  @override
  Widget build(BuildContext context) {
    final scope = RaftInfoColumnScope.maybeOf(context);
    final width = scope?.termWidth ?? raftInfoTermWidth(context, [row]);
    return Padding(
      padding: EdgeInsets.only(top: (scope?.first ?? true) ? 0 : 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: width,
            child: Row(
              children: [
                Flexible(
                  child: RaftCssText(
                    row.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RaftInfoRow.termStyleOf(context),
                  ),
                ),
                for (final a in row.actions) ...[const SizedBox(width: 6), a],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: DefaultTextStyle.merge(
                  style: RaftInfoRow.detailsStyleOf(context),
                  child: row.child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
