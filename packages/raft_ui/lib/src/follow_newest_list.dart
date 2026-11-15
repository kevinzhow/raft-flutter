// Web v1.24 components/agent/useFollowNewest.ts: following the newest for a
// timeline with the newest at the bottom. It opens at the newest entry and
// keeps it in view while the end is in view; once the reader scrolls up, the
// row they read stays where it is (entries dropped off the top at a limit, or
// loaded above, do not move it) and the number of entries that arrived below
// is counted for the Back to bottom pill. It follows the newest entry
// changing, not the count: at a limit the count stays the same while entries
// keep arriving.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'localization.dart';
import 'timeline_bottom_button.dart';

/// How close to the end still counts as reading the newest (and follows it).
const double raftFollowNewestEndSlack = 24;

/// A scrolling list of keyed rows, newest last, that follows the newest like
/// Web's `useFollowNewest`. [rowKeys] are the rows' stable keys in order (an
/// entry keeps its key across live appends, reloads and dropping off the top);
/// [itemBuilder] builds row `i`.
class RaftFollowNewestList extends StatefulWidget {
  const RaftFollowNewestList({
    super.key,
    required this.rowKeys,
    required this.itemBuilder,
    this.newStepsLabel,
    this.padding = EdgeInsets.zero,
    this.semanticLabel,
  });

  final List<String> rowKeys;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// The pill's text for [count] arrivals ("3 new steps"); the plain "Back to
  /// bottom" when null or when nothing arrived.
  final String Function(int count)? newStepsLabel;
  final EdgeInsets padding;

  /// The scroll region's name (Web `role="region"` + `aria-label`).
  final String? semanticLabel;

  @override
  State<RaftFollowNewestList> createState() => RaftFollowNewestListState();
}

class RaftFollowNewestListState extends State<RaftFollowNewestList> {
  final ScrollController scroll = ScrollController();
  final Map<String, BuildContext> _rows = {};

  bool _following = true;
  ({String key, double offset})? _reading;
  String? _newestKey;
  bool _atEnd = true;
  int _newCount = 0;

  /// Whether the end is in view (the pill is hidden).
  bool get atEnd => _atEnd;

  /// How many entries arrived below since the reader left the end.
  int get newCount => _newCount;

  @override
  void initState() {
    super.initState();
    _newestKey = widget.rowKeys.isEmpty ? null : widget.rowKeys.last;
    scroll.addListener(_onScroll);
    _pinToEnd();
  }

  @override
  void dispose() {
    scroll.removeListener(_onScroll);
    scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RaftFollowNewestList old) {
    super.didUpdateWidget(old);
    final keys = widget.rowKeys;
    final previousNewest = _newestKey;
    final newest = keys.isEmpty ? null : keys.last;
    _newestKey = newest;
    if (newest == null) {
      // Cleared (a reset): the next entries open at the newest again.
      _following = true;
      _reading = null;
      _atEnd = true;
      _newCount = 0;
      return;
    }
    if (_following) {
      _pinToEnd();
      return;
    }
    if (_reading != null) _keepReading();
    if (previousNewest != null && previousNewest != newest) {
      var arrived = 0;
      for (var i = keys.length - 1; i >= 0 && keys[i] != previousNewest; i--) {
        arrived++;
      }
      // The newest the reader saw is gone (replaced by another copy): one
      // entry.
      if (arrived == keys.length) arrived = 1;
      _newCount += arrived;
    }
  }

  /// A built row's place in the list's own coordinates: where the sliver laid
  /// it out (independent of how far the list is scrolled, so it is exact even
  /// between a scroll and the next layout) and how tall it is.
  ({double offset, double extent})? _place(BuildContext? context) {
    RenderObject? node = context?.findRenderObject();
    while (node != null &&
        node.parentData is! SliverMultiBoxAdaptorParentData) {
      node = node.parent;
    }
    final data = node?.parentData;
    if (node is! RenderBox ||
        data is! SliverMultiBoxAdaptorParentData ||
        !node.hasSize) {
      return null;
    }
    final offset = data.layoutOffset;
    return offset == null ? null : (offset: offset, extent: node.size.height);
  }

  /// Rows build lazily, so the extent can still grow after the first jump:
  /// jump again once it settles. A reader at the end stays there.
  void _pinToEnd({int again = 2}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_following || !scroll.hasClients) return;
      final end = scroll.position.maxScrollExtent;
      if (scroll.offset != end) scroll.jumpTo(end);
      if (again > 0) _pinToEnd(again: again - 1);
    });
  }

  /// The row the reader reads stays where it is: after the frame that changed
  /// the rows, move by the distance its place in the list shifted (entries
  /// dropped off the top, or loaded above, move everything below them).
  void _keepReading() {
    final reading = _reading;
    if (reading == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _following || !scroll.hasClients) return;
      final place = _place(_rows[reading.key]);
      if (place == null) return;
      final shift = place.offset - reading.offset;
      if (shift.abs() < 1) return;
      final position = scroll.position;
      scroll.jumpTo(
        (position.pixels + shift).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  void _onScroll() {
    if (!scroll.hasClients) return;
    final position = scroll.position;
    final end =
        position.maxScrollExtent - position.pixels <= raftFollowNewestEndSlack;
    _following = end;
    if (end) {
      _reading = null;
      if (!_atEnd || _newCount != 0) {
        setState(() {
          _atEnd = true;
          _newCount = 0;
        });
      }
      return;
    }
    if (_atEnd) setState(() => _atEnd = false);
    _reading = _readingRow();
  }

  /// The row at the top of the view: the first, in order, whose bottom is
  /// below the view's top.
  ({String key, double offset})? _readingRow() {
    final pixels = scroll.position.pixels;
    final order = {
      for (var i = 0; i < widget.rowKeys.length; i++) widget.rowKeys[i]: i,
    };
    String? bestKey;
    var bestIndex = 1 << 30;
    var bestOffset = 0.0;
    for (final MapEntry(:key, value: context) in _rows.entries) {
      final index = order[key];
      final place = _place(context);
      if (index == null || place == null || index >= bestIndex) continue;
      if (place.offset + place.extent <= pixels) continue;
      bestKey = key;
      bestIndex = index;
      bestOffset = place.offset;
    }
    return bestKey == null ? null : (key: bestKey, offset: bestOffset);
  }

  void jumpToNewest() {
    setState(() {
      _following = true;
      _reading = null;
      _atEnd = true;
      _newCount = 0;
    });
    _pinToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final keys = widget.rowKeys;
    final label = _newCount > 0 && widget.newStepsLabel != null
        ? widget.newStepsLabel!(_newCount)
        : raftText(context, 'Back to bottom');
    return Stack(
      children: [
        Positioned.fill(
          child: Semantics(
            container: true,
            label: widget.semanticLabel,
            child: ListView.builder(
              controller: scroll,
              padding: widget.padding,
              itemCount: keys.length,
              // The reader's rows keep their state when entries shift.
              findChildIndexCallback: (key) {
                if (key is! ValueKey<String>) return null;
                final index = keys.indexOf(key.value);
                return index < 0 ? null : index;
              },
              itemBuilder: (context, index) => _RowAnchor(
                key: ValueKey(keys[index]),
                owner: this,
                rowKey: keys[index],
                child: widget.itemBuilder(context, index),
              ),
            ),
          ),
        ),
        if (!_atEnd)
          RaftTimelineBottomButton(label: label, onPressed: jumpToNewest),
      ],
    );
  }
}

/// Registers a built row with the list, so the reading row can be found.
class _RowAnchor extends StatefulWidget {
  const _RowAnchor({
    super.key,
    required this.owner,
    required this.rowKey,
    required this.child,
  });
  final RaftFollowNewestListState owner;
  final String rowKey;
  final Widget child;

  @override
  State<_RowAnchor> createState() => _RowAnchorState();
}

class _RowAnchorState extends State<_RowAnchor> {
  @override
  void initState() {
    super.initState();
    widget.owner._rows[widget.rowKey] = context;
  }

  @override
  void dispose() {
    if (widget.owner._rows[widget.rowKey] == context) {
      widget.owner._rows.remove(widget.rowKey);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
