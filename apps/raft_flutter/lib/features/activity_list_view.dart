// Source: packages/web/src/features/thread/ThreadsInbox.tsx:751-760 at v1.24.0.
// The Activity list: one group per day under a heading that sticks under the
// phone's pinned filter row (at the top on desktop), 2px between rows.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:raft_ui/raft_ui.dart';

import 'activity_day_groups.dart';

// ThreadsInbox combines the list's own insets with its ScrollArea padding.
const double _listTopInset = 8;
const double _listBottomInset = 4;
const double _scrollAreaBottomInset = 16;
const _listPadding = EdgeInsets.only(
  top: _listTopInset,
  bottom: _listBottomInset + _scrollAreaBottomInset,
);

/// `InboxItemListGroup` margin between two days.
const double _groupGap = 6;

/// `first:mt-0`: the first day has no margin above it.
const double _firstGroupGap = 0;

/// `gap-0.5` between the rows of a day.
const double _rowGap = 2;

typedef ActivityRowBuilder = Widget Function(
  BuildContext context,
  Map<String, dynamic> row,
  int index,
);

/// Web ActivityInboxSkeleton: a heading and ten compact rows, delayed by
/// one second so a fast read goes straight to the actual list.
class ActivityInboxLoadingList extends StatefulWidget {
  const ActivityInboxLoadingList({super.key});

  @override
  State<ActivityInboxLoadingList> createState() =>
      _ActivityInboxLoadingListState();
}

class _ActivityInboxLoadingListState extends State<ActivityInboxLoadingList> {
  Timer? _delay;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _delay = Timer(const Duration(seconds: 1), () {
      setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !_visible
      ? const SizedBox.expand()
      : ListView(
          padding: raftScrollPadding(context, _listPadding),
          children: [
            RaftInboxItemListGroup.loading(
              children: [
                // The day heading is the first child of the Web list group.
                for (var i = 1; i <= 10; i++) RaftInboxItemSkeleton(index: i),
              ],
            ),
          ],
        );
}

/// The scroller of the Activity page. [groups] hold the rows in shown order; [phoneBar] is
/// its first, pinned child on a phone. [indexOfKey] maps a row's list key to
/// its index in the shown rows.
class ActivityListView extends StatelessWidget {
  const ActivityListView({
    super.key,
    required this.controller,
    required this.groups,
    required this.rowBuilder,
    required this.keyFor,
    required this.indexOfKey,
    required this.surface,
    this.phoneBar,
    this.physics,
    this.tail,
    this.lead,
  });

  final ScrollController? controller;
  final List<ActivityDayGroup> groups;
  final ActivityRowBuilder rowBuilder;
  final Key? Function(Map<String, dynamic> row) keyFor;
  final int? Function(Key key) indexOfKey;

  /// The list's own surface: a stuck heading paints it, so no row shows through.
  final Color surface;
  final Widget? phoneBar, tail, lead;
  final ScrollPhysics? physics;

  /// Rows built beyond the viewport, so Up/Down can move to the next row.
  static const double cacheExtent = 600;

  @override
  Widget build(BuildContext context) {
    final padding = raftScrollPadding(context, _listPadding);
    var start = 0;
    final slivers = <Widget>[
      ?(phoneBar == null ? null : PinnedHeaderSliver(child: phoneBar)),
      ?(lead == null ? null : SliverToBoxAdapter(child: lead)),
      SliverToBoxAdapter(child: SizedBox(height: padding.top)),
    ];
    for (final (g, group) in groups.indexed) {
      final first = start;
      final gapBefore = g == 0 ? _firstGroupGap : _groupGap;
      start += group.rows.length;
      slivers.add(
        SliverPadding(
          key: ValueKey(group.key),
          padding: EdgeInsets.only(top: gapBefore),
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
              if (group.label.isNotEmpty)
                const SliverToBoxAdapter(child: SizedBox(height: _rowGap)),
              SliverList.separated(
                itemCount: group.rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: _rowGap),
                findItemIndexCallback: (key) {
                  final at = indexOfKey(key);
                  return at == null ||
                          at < first ||
                          at >= first + group.rows.length
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
    if (tail != null) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.only(top: _rowGap),
          sliver: SliverToBoxAdapter(child: tail),
        ),
      );
    }
    slivers.add(SliverToBoxAdapter(child: SizedBox(height: padding.bottom)));
    return CustomScrollView(
      controller: controller,
      physics: physics,
      scrollCacheExtent: const ScrollCacheExtent.pixels(cacheExtent),
      slivers: slivers,
    );
  }
}
