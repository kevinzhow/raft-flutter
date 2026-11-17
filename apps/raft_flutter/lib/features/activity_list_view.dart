// Source: packages/web/src/features/thread/ThreadsInbox.tsx:751-760 at v1.24.0.
// The Activity list: one group per day under a heading that sticks under the
// phone's pinned filter row (at the top on desktop), 2px between rows.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:raft_ui/raft_ui.dart';

import '../data/source_time_formatter.dart';
import 'activity_day_groups.dart';

/// Web `ThreadsInbox`'s list `pt-2 pb-1` on a phone, `py-1` on desktop.
const double _phoneTop = 8, _desktopTop = 4, _bottom = 4;

/// `InboxItemListGroup` margin between two days.
const double _groupGap = 6;

/// Rows already in the order they are shown (newest first); a list that is
/// not is sorted by the time the rows show, stably (Web `sortInboxRowsByTime`).
List<Map<String, dynamic>> activityRowsInShownOrder(
  List<Map<String, dynamic>> rows,
) {
  DateTime? previous;
  var unreadable = false;
  for (final row in rows) {
    final at = activityRowTime(row);
    if (at == null) {
      unreadable = true;
      continue;
    }
    if (unreadable || (previous != null && at.isAfter(previous))) {
      return sortActivityRowsByTime(rows);
    }
    previous = at;
  }
  return rows;
}

typedef ActivityRowBuilder =
    Widget Function(BuildContext context, Map<String, dynamic> row, int index);

/// The scroller of the Activity page. [rows] are in shown order; [phoneBar] is
/// its first, pinned child on a phone. [indexOfKey] maps a row's list key to
/// its index in [rows].
class ActivityListView extends StatelessWidget {
  const ActivityListView({
    super.key,
    required this.controller,
    required this.rows,
    required this.rowBuilder,
    required this.keyFor,
    required this.indexOfKey,
    required this.surface,
    required this.formatter,
    required this.now,
    this.phoneBar,
    this.physics,
    this.tail,
    this.lead,
  });

  final ScrollController? controller;
  final List<Map<String, dynamic>> rows;
  final ActivityRowBuilder rowBuilder;
  final Key? Function(Map<String, dynamic> row) keyFor;
  final int? Function(Key key) indexOfKey;

  /// The list's own surface: a stuck heading paints it, so no row shows through.
  final Color surface;
  final SourceTimeFormatter formatter;
  final DateTime now;
  final Widget? phoneBar, tail, lead;
  final ScrollPhysics? physics;

  /// Rows built beyond the viewport, so Up/Down can move to the next row.
  static const double cacheExtent = 600;

  @override
  Widget build(BuildContext context) {
    final groups = groupActivityRowsByDay(
      rows,
      formatter: formatter,
      now: now,
    );
    final padding = raftScrollPadding(
      context,
      EdgeInsets.only(
        top: phoneBar != null ? _phoneTop : _desktopTop,
        bottom: _bottom,
      ),
    );
    var start = 0;
    final slivers = <Widget>[
      ?(phoneBar == null ? null : PinnedHeaderSliver(child: phoneBar!)),
      ?(lead == null ? null : SliverToBoxAdapter(child: lead)),
      SliverToBoxAdapter(child: SizedBox(height: padding.top)),
    ];
    for (final (g, group) in groups.indexed) {
      final first = start;
      start += group.rows.length;
      slivers.add(
        SliverPadding(
          key: ValueKey(group.key),
          padding: EdgeInsets.only(top: g == 0 ? 0 : _groupGap),
          sliver: SliverMainAxisGroup(
            slivers: [
              if (group.label.isNotEmpty)
                PinnedHeaderSliver(
                  child: ColoredBox(
                    color: surface,
                    child: RaftInboxItemListGroup(
                      key: ValueKey('inbox-day-heading-${group.day}'),
                      first: true,
                      heading: group.label,
                      children: const [],
                    ),
                  ),
                ),
              SliverList.separated(
                itemCount: group.rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                findItemIndexCallback: (key) {
                  final at = indexOfKey(key);
                  return at == null || at < first || at >= first + group.rows.length
                      ? null
                      : at - first;
                },
                itemBuilder: (context, i) {
                  final row = group.rows[i];
                  return KeyedSubtree(
                    key: keyFor(row),
                    child: rowBuilder(context, row, first + i),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }
    if (tail != null) slivers.add(SliverToBoxAdapter(child: tail));
    slivers.add(SliverToBoxAdapter(child: SizedBox(height: padding.bottom)));
    return CustomScrollView(
      controller: controller,
      physics: physics,
      scrollCacheExtent: const ScrollCacheExtent.pixels(cacheExtent),
      slivers: slivers,
    );
  }
}
