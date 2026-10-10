import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'reading_anchor.dart';

/// Key of one Activity/Saved row inside its lazy list, so a row keeps its
/// element (and render box) when rows are inserted or moved above it.
class ResourceRowListKey extends ValueKey<String> {
  const ResourceRowListKey(super.value);
}

/// Web ThreadsInbox reading position and "N new updates" pill for a
/// top-anchored (newest-first) list.
///
/// Web keeps the reader's place through the browser's scroll anchoring and
/// counts updates that land above the reader while they are away from the top
/// (`isNearTopRef`: `scrollTop < 50`); reaching the top clears the count.
///
/// [observe] runs while the host builds the next rows, before they are laid
/// out: it captures a visible row that keeps its place so the next layout moves
/// the scroll position by the rows that landed above it (no displaced frame).
class ResourceListUpdates {
  /// Web `isNearTopRef.current = target.scrollTop < 50`.
  static const nearTopExtent = 50.0;

  final anchor = RaftReadingAnchorController();

  /// Rows that arrived or moved above the reader since they left the top.
  int count = 0;

  List<String?> _keys = const [];
  Object? _view;
  Map<String, int> _index = const {};

  /// Item index of a keyed row for `findItemIndexCallback`.
  int? indexOf(Key key) => key is ResourceRowListKey ? _index[key.value] : null;

  /// The list key of the row with [rowKey], when it is unique in the list.
  Key? keyOf(String? rowKey) => rowKey != null && _index.containsKey(rowKey)
      ? ResourceRowListKey(rowKey)
      : null;

  static bool nearTop(ScrollPosition position) =>
      position.pixels - position.minScrollExtent < nearTopExtent;

  /// Records the next rows of [view]. A different [view] (filter, query,
  /// section) starts over: its rows are not updates of the previous ones.
  /// Returns whether [count] changed.
  bool observe({
    required Object? view,
    required List<String?> keys,
    ScrollPosition? position,
  }) {
    if (view == _view && listEquals(keys, _keys)) return false;
    final previous = _keys, sameView = view == _view && previous.isNotEmpty;
    _keys = List.unmodifiable(keys);
    _view = view;
    final index = <String, int>{}, repeated = <String>{};
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      if (key == null) continue;
      if (index.containsKey(key)) repeated.add(key);
      index[key] = i;
    }
    // A repeated key cannot identify one row; such rows follow their index.
    _index = {
      for (final entry in index.entries)
        if (!repeated.contains(entry.key)) entry.key: entry.value,
    };
    final before = count;
    if (!sameView) {
      count = 0;
      anchor.clear();
      return before != count;
    }
    if (position == null || !position.hasPixels) return false;
    // Rows now above the previous first row that is still listed: new rows
    // and rows moved to the top.
    final oldTop = previous.firstWhere(
      (key) => key != null && _index.containsKey(key),
      orElse: () => null,
    );
    final above = <String>{
      if (oldTop != null)
        for (final key in keys.takeWhile((key) => key != oldTop)) ?key,
    };
    if (nearTop(position)) {
      // Web: a reader at the top sees the newest row (`scrollTop = 0`).
      if (above.isNotEmpty && position.pixels > position.minScrollExtent) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (position.hasPixels && nearTop(position)) {
            position.jumpTo(position.minScrollExtent);
          }
        });
      }
      return false;
    }
    count += above.length;
    _capture(position, previous, above);
    return before != count;
  }

  /// Reaching the top clears the count (Web `handleScroll`).
  bool scrolled(ScrollPosition position) {
    if (count == 0 || !position.hasPixels || !nearTop(position)) return false;
    count = 0;
    return true;
  }

  /// The reader asked to see the updates: the list returns to the top.
  void reveal(ScrollPosition position, {required bool animate}) {
    count = 0;
    anchor.clear();
    if (!position.hasPixels) return;
    if (animate) {
      position.animateTo(
        position.minScrollExtent,
        duration: RaftPrimitives.smoothScrollDuration,
        curve: RaftPrimitives.smoothScrollCurve,
      );
    } else {
      position.jumpTo(position.minScrollExtent);
    }
  }

  /// Captures the first visible row (preferring a fully visible one) that is
  /// still listed and did not move above the reader.
  void _capture(
    ScrollPosition position,
    List<String?> previous,
    Set<String> above,
  ) {
    final host = anchor.host;
    if (host == null || !host.attached) return;
    RenderSliverMultiBoxAdaptor? list;
    void visit(RenderObject node) {
      if (list == null && node is RenderSliverMultiBoxAdaptor) {
        list = node;
        return;
      }
      node.visitChildren(visit);
    }

    host.visitChildren(visit);
    final sliver = list;
    if (sliver == null) return;
    final low = position.pixels,
        high = position.pixels + position.viewportDimension;
    RenderBox? partial;
    for (
      var child = sliver.firstChild;
      child != null;
      child = sliver.childAfter(child)
    ) {
      // ListView.separated: even children are items, odd ones separators.
      final childIndex = sliver.indexOf(child);
      if (!child.hasSize || childIndex.isOdd) continue;
      final itemIndex = childIndex ~/ 2;
      if (itemIndex >= previous.length) continue;
      final key = previous[itemIndex];
      if (key == null || !_index.containsKey(key) || above.contains(key)) {
        continue;
      }
      final offset = RaftReadingAnchorController.scrollOffsetOf(child);
      if (offset == null) continue;
      final end = offset + child.size.height;
      if (end <= low || offset >= high) continue;
      if (offset >= low && end <= high) {
        anchor.capture(child, position);
        return;
      }
      partial ??= child;
    }
    if (partial != null) anchor.capture(partial, position);
  }
}
