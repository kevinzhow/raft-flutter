import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../data/workspace_controller.dart';
import 'resource_list_updates.dart';

/// Web `components/thread/activityRetap.ts`: tapping Activity again on a phone
/// goes to the next unread row below the current position, puts it at the top
/// of the list and flashes it; after the last one it goes back to the top.
/// Nothing is marked read.

/// A row of the list, in list order.
class ActivityRetapRow {
  const ActivityRetapRow({
    required this.key,
    required this.top,
    required this.unread,
  });
  final String key;

  /// The scroll position that puts this row at the top of the list.
  final double top;
  final bool unread;
}

/// Where the previous tap sent the list: a row ([key]) or the top (null), the
/// scroll position it was headed to, and when (milliseconds).
class ActivityRetapAnchor {
  const ActivityRetapAnchor({
    required this.key,
    required this.to,
    required this.at,
  });
  final String? key;
  final double to;
  final int at;
}

sealed class ActivityRetapTarget {
  const ActivityRetapTarget();
}

class ActivityRetapRowTarget extends ActivityRetapTarget {
  const ActivityRetapRowTarget(this.key, this.top);
  final String key;
  final double top;

  @override
  bool operator ==(Object other) =>
      other is ActivityRetapRowTarget && other.key == key && other.top == top;
  @override
  int get hashCode => Object.hash(key, top);
  @override
  String toString() => 'row($key, $top)';
}

class ActivityRetapTopTarget extends ActivityRetapTarget {
  const ActivityRetapTopTarget();
  @override
  bool operator ==(Object other) => other is ActivityRetapTopTarget;
  @override
  int get hashCode => 0;
  @override
  String toString() => 'top';
}

/// How far a row must be below the current position to count as below it.
const activityRetapEpsilon = 4.0;

/// How long a tap's smooth scroll may still be on its way.
const activityRetapInFlightMs = 700;

/// Most pages a tap loads looking for unread rows not yet loaded.
const activityRetapMaxPageLoads = 3;

/// Web `nextActivityRetapTarget`.
ActivityRetapTarget nextActivityRetapTarget({
  required List<ActivityRetapRow> rows,
  required double scrollTop,
  required double maxScrollTop,
  required ActivityRetapAnchor? anchor,
  required int now,
  double epsilon = activityRetapEpsilon,
}) {
  final holds =
      anchor != null &&
      ((scrollTop - anchor.to).abs() <= epsilon ||
          now - anchor.at <= activityRetapInFlightMs);
  final anchorKey = holds ? anchor.key : null;
  final anchorRow = anchorKey == null
      ? null
      : rows.where((row) => row.key == anchorKey).firstOrNull;
  final ActivityRetapRow? next;
  if (anchorRow != null) {
    next = rows
        .where((row) => row.unread && row.top > anchorRow.top + epsilon)
        .firstOrNull;
  } else if ((holds && anchor.key == null) || scrollTop <= epsilon) {
    next = rows.where((row) => row.unread).firstOrNull;
  } else {
    next = rows
        .where((row) => row.unread && row.top > scrollTop + epsilon)
        .firstOrNull;
  }
  if (next == null) return const ActivityRetapTopTarget();
  final limit = maxScrollTop < 0 ? 0.0 : maxScrollTop;
  final top = next.top < limit ? next.top : limit;
  return ActivityRetapRowTarget(next.key, top < 0 ? 0 : top);
}

/// Web `hasUnloadedUnread`: more unread rows may be in pages not loaded yet.
bool hasUnloadedUnread({
  required int loadedUnreadCount,
  required int totalUnreadCount,
  required bool hasMore,
}) => hasMore && totalUnreadCount > loadedUnreadCount;

/// What the Activity list gives a re-tap to work with (the list registers it
/// while mounted; Web `useActivityNextUnread`).
class ActivityRetapHost {
  const ActivityRetapHost({
    required this.scroll,
    required this.rowKeys,
    required this.isUnread,
    required this.totalUnreadCount,
    required this.hasMore,
    required this.loadMore,
    required this.locate,
    required this.context,
    this.now = _wallClock,
  });

  final ScrollController? Function() scroll;

  /// The row keys in shown order.
  final List<String> Function() rowKeys;
  final bool Function(String key) isUnread;
  final int Function() totalUnreadCount;
  final bool Function() hasMore;

  /// Loads the next page; completes when it is in the list.
  final Future<void> Function() loadMore;

  /// Lights the row's "located" highlight (Web `setRetapTarget`).
  final void Function(String key) locate;
  final BuildContext context;
  final int Function() now;

  static int _wallClock() => DateTime.now().millisecondsSinceEpoch;
}

/// The row tops of [keys] under the list's top edge. Built rows are measured;
/// the ones the lazy list has not built are estimated from the built rows'
/// average height so their order stays right, and are made exact by the scroll
/// that follows ([ActivityRetap.trigger] reveals them once built).
List<ActivityRetapRow> activityRetapRows(
  BuildContext context,
  List<String> keys,
  bool Function(String key) isUnread,
) {
  final measured = <int, double>{};
  RenderAbstractViewport? viewport;
  void visit(Element e) {
    final key = e.widget.key;
    if (key is ResourceRowListKey) {
      final i = keys.indexOf(key.value);
      final box = e.renderObject;
      if (i != -1 && box is RenderBox && box.attached) {
        viewport ??= RenderAbstractViewport.maybeOf(box);
        final v = viewport;
        if (v != null) measured[i] = v.getOffsetToReveal(box, 0).offset;
      }
      return;
    }
    e.visitChildren(visit);
  }

  (context as Element).visitChildren(visit);
  if (measured.isEmpty) return const [];
  final order = measured.keys.toList()..sort();
  final span = order.length > 1
      ? (measured[order.last]! - measured[order.first]!) /
            (order.last - order.first)
      : 0.0;
  final first = order.first, last = order.last;
  return [
    for (var i = 0; i < keys.length; i++)
      ActivityRetapRow(
        key: keys[i],
        unread: isUnread(keys[i]),
        top:
            measured[i] ??
            (i < first
                ? measured[first]! - (first - i) * span
                : measured[last]! + (i - last) * span),
      ),
  ];
}

/// Web `retapTabRoot("activity")` and the phone title bar's tap: goes to the
/// next unread row below the current position, scrolls it to the top and
/// lights it; after the last one back to the top. One per workspace, as
/// [ActivityFirstUnread]; the Activity list registers its [ActivityRetapHost].
class ActivityRetap {
  ActivityRetap._();
  static final _owners = Expando<ActivityRetap>();
  static ActivityRetap of(WorkspaceController w) =>
      _owners[w] ??= ActivityRetap._();

  ActivityRetapHost? _host;
  ActivityRetapAnchor? _anchor;
  bool _busy = false;

  /// The list mounted; returns the call that unmounts it.
  VoidCallback register(ActivityRetapHost host) {
    _host = host;
    return () {
      if (identical(_host, host)) {
        _host = null;
        _anchor = null;
      }
    };
  }

  /// A filter or channel change, or the user scrolling, ends the previous
  /// tap's anchor (Web `RETAP_ANCHOR_DROPPING_INPUT`).
  void dropAnchor() => _anchor = null;

  @visibleForTesting
  ActivityRetapAnchor? get anchor => _anchor;

  /// Whether a list is registered (a tap on the tab with no list does nothing).
  bool get ready => _host != null;

  Future<void> trigger() async {
    final host = _host;
    if (host == null || _busy || host.scroll()?.hasClients != true) return;
    _busy = true;
    try {
      await _step(host);
    } finally {
      _busy = false;
    }
  }

  List<ActivityRetapRow> _rows(ActivityRetapHost host) => activityRetapRows(
    host.context,
    host.rowKeys(),
    host.isUnread,
  );

  Future<void> _step(ActivityRetapHost host) async {
    var loads = 0;
    while (true) {
      final scroll = host.scroll();
      if (scroll == null || !scroll.hasClients || !host.context.mounted) return;
      final position = scroll.position;
      final now = host.now();
      final target = nextActivityRetapTarget(
        rows: _rows(host),
        scrollTop: position.pixels,
        maxScrollTop: position.maxScrollExtent,
        anchor: _anchor,
        now: now,
      );
      final keys = host.rowKeys();
      final loadedUnread = keys.where(host.isUnread).length;
      if (target is ActivityRetapTopTarget &&
          loads < activityRetapMaxPageLoads &&
          hasUnloadedUnread(
            loadedUnreadCount: loadedUnread,
            totalUnreadCount: host.totalUnreadCount(),
            hasMore: host.hasMore(),
          )) {
        loads++;
        await host.loadMore();
        await SchedulerBinding.instance.endOfFrame;
        continue;
      }
      switch (target) {
        case ActivityRetapRowTarget(:final key, :final top):
          _anchor = ActivityRetapAnchor(key: key, to: top, at: now);
          unawaited(_scrollTo(host, top, key));
          host.locate(key);
        case ActivityRetapTopTarget():
          _anchor = ActivityRetapAnchor(key: null, to: 0, at: now);
          unawaited(_scrollTo(host, 0, null));
      }
      return;
    }
  }

  Future<void> _scrollTo(ActivityRetapHost host, double to, String? key) async {
    final scroll = host.scroll();
    if (scroll == null || !scroll.hasClients) return;
    final position = scroll.position;
    await position.animateTo(
      to.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    if (key == null || !host.context.mounted) return;
    // An estimated top is made exact once the row is built.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!host.context.mounted) return;
      final rows = _rows(host).where((r) => r.key == key);
      final row = rows.firstOrNull;
      final scroll = host.scroll();
      if (row == null || scroll == null || !scroll.hasClients) return;
      final p = scroll.position;
      final exact = row.top.clamp(p.minScrollExtent, p.maxScrollExtent);
      if ((p.pixels - exact).abs() > activityRetapEpsilon) {
        p.jumpTo(exact);
      }
    });
  }
}
