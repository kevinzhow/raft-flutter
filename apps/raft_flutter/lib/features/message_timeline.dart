import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;

/// A two-sided message timeline: older history grows away from a fixed
/// center, so loading it never moves the rows on screen.
///
/// Rows `[0, centerIndex)` live in the history sliver, built outward from the
/// center (history child `i` is row `centerIndex - 1 - i`); rows from
/// `centerIndex` on live in the forward (center) sliver. Prepending older rows
/// only appends children at the far end of the history sliver: no existing
/// child changes index or offset and no scroll position is corrected. Rows
/// arriving at the latest end are appended to the forward sliver, below the
/// reader. The center only moves on an explicit jump ([epoch]).
class RaftMessageTimeline extends StatefulWidget {
  const RaftMessageTimeline({
    super.key,
    required this.controller,
    required this.messages,
    required this.centerIndex,
    required this.epoch,
    required this.rowBuilder,
    required this.indexOfId,
    required this.slivers,
    this.estimateRow,
    this.empty,
    this.hasOlder = false,
    this.loadingOlder = false,
    this.onLoadOlder,
    this.cacheExtent,
  });

  final RaftTimelineScrollController controller;
  final List<chat.Message> messages;
  final int centerIndex;

  /// Changes whenever the center is re-chosen; both lists are rebuilt so no
  /// child keeps an offset measured against the previous center.
  final int epoch;
  final Widget Function(BuildContext context, int index) rowBuilder;
  final int? Function(String id) indexOfId;
  final double Function(int index)? estimateRow;

  /// The scroll view's slivers, top to bottom, around the history and the
  /// forward (center) lists (e.g. header, sentinels, footer).
  final List<Widget> Function(Widget history, Widget forward) slivers;
  final Widget? empty;
  final bool hasOlder, loadingOlder;
  final VoidCallback? onLoadOlder;
  final double? cacheExtent;

  /// Older history is requested within this many viewports of the top.
  static const double prefetchViewports = 2;

  @override
  State<RaftMessageTimeline> createState() => _RaftMessageTimelineState();
}

class _RaftMessageTimelineState extends State<RaftMessageTimeline> {
  final edges = _TimelineEdges();
  bool armed = false;

  @override
  void didUpdateWidget(RaftMessageTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) armed = false;
    if (oldWidget.loadingOlder && !widget.loadingOlder) {
      // The page has landed; prefetch the next one if still near the top.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) maybeLoadOlder();
      });
    }
  }

  void maybeLoadOlder() {
    final load = widget.onLoadOlder, controller = widget.controller;
    if (!armed ||
        load == null ||
        !widget.hasOlder ||
        widget.loadingOlder ||
        controller.positions.length != 1) {
      return;
    }
    final position = controller.position;
    if (!position.hasContentDimensions ||
        !position.hasViewportDimension ||
        controller.pending != null) {
      return;
    }
    final threshold = math.max(
      200.0,
      position.viewportDimension * RaftMessageTimeline.prefetchViewports,
    );
    if (position.extentBefore <= threshold) load();
  }

  bool onNotification(Notification notification) {
    if (notification is OverscrollIndicatorNotification &&
        notification.leading &&
        edges.olderPending) {
      // The top is a temporary edge while history is still loading: no
      // stretch or glow there (it would move the rows as history lands).
      notification.disallowIndicator();
    }
    if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.forward) {
      // Toward the top (older history).
      armed = true;
    }
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification ||
        notification is ScrollMetricsNotification) {
      maybeLoadOlder();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    edges.olderPending = widget.controller.olderPending = widget.hasOlder;
    final messages = widget.messages;
    final center = widget.centerIndex.clamp(0, messages.length);
    final estimate = widget.estimateRow;
    Widget row(BuildContext context, int index) => KeyedSubtree(
      key: ValueKey<String>(messages[index].id),
      child: widget.rowBuilder(context, index),
    );
    final history = SliverList(
      key: ValueKey('timeline-history-${widget.epoch}'),
      delegate: _EstimatingChildDelegate(
        (context, i) => row(context, center - 1 - i),
        childCount: center,
        estimate: estimate == null ? null : (i) => estimate(center - 1 - i),
        findChildIndexCallback: (key) {
          if (key is! ValueKey<String>) return null;
          final index = widget.indexOfId(key.value);
          return index == null || index >= center ? null : center - 1 - index;
        },
      ),
    );
    final forwardKey = ValueKey('timeline-forward-${widget.epoch}');
    final forward = SliverList(
      key: forwardKey,
      delegate: _EstimatingChildDelegate(
        (context, i) => row(context, center + i),
        childCount: messages.length - center,
        estimate: estimate == null ? null : (i) => estimate(center + i),
        findChildIndexCallback: (key) {
          if (key is! ValueKey<String>) return null;
          final index = widget.indexOfId(key.value);
          return index == null || index < center ? null : index - center;
        },
      ),
    );
    final slivers = widget.slivers(history, forward);
    final list = NotificationListener<Notification>(
      onNotification: onNotification,
      child: _TimelineScrollView(
        controller: widget.controller,
        center: forwardKey,
        anchor: widget.controller.anchor,
        physics: _TimelinePhysics(edges),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        semanticChildCount: messages.length,
        scrollCacheExtent: widget.cacheExtent == null
            ? null
            : ScrollCacheExtent.pixels(widget.cacheExtent!),
        slivers: slivers,
      ),
    );
    final empty = widget.empty;
    if (empty == null || messages.isNotEmpty) return list;
    return Stack(
      children: [
        list,
        Positioned.fill(child: empty),
      ],
    );
  }
}

/// One-shot position for the next layout of a timeline: applied inside the
/// viewport's layout from actual geometry, so the first painted frame is
/// already in place.
sealed class RaftTimelineAlignment {
  const RaftTimelineAlignment();

  /// The latest end (newest row and footer at the bottom edge).
  static const RaftTimelineAlignment end = _EndAlignment();

  /// The oldest end (history state at the top edge).
  static const RaftTimelineAlignment start = _StartAlignment();

  /// The row found by [find] (default: the first row of the center sliver),
  /// at [alignment] of the free space (0.5 = vertically centered, Source
  /// `scrollIntoView({block: "center"})`), or with its top [leading] pixels
  /// below the viewport's top edge.
  const factory RaftTimelineAlignment.row({
    RenderBox? Function()? find,
    double alignment,
    double? leading,
  }) = _RowAlignment;
}

class _EndAlignment extends RaftTimelineAlignment {
  const _EndAlignment();
}

class _StartAlignment extends RaftTimelineAlignment {
  const _StartAlignment();
}

class _RowAlignment extends RaftTimelineAlignment {
  const _RowAlignment({this.find, this.alignment = .5, this.leading});
  final RenderBox? Function()? find;
  final double alignment;
  final double? leading;
}

/// Scroll controller of a [RaftMessageTimeline].
///
/// The scroll range is the actual content range on both sides of the center
/// (no blank space beyond either end). A timeline shorter than its viewport
/// rests at its latest end ([bottomAnchored]) or at its top. While the reader
/// is at the latest end, layout keeps it there ([RaftTimelinePosition.followEnd]).
class RaftTimelineScrollController extends ScrollController {
  RaftTimelineScrollController({
    required this.bottomAnchored,
    RaftTimelineAlignment? initial = RaftTimelineAlignment.end,
    super.debugLabel,
  }) : _pending = initial,
       super(keepScrollOffset: false);

  /// Channels keep their bottom edge fixed (resize, short content); threads
  /// keep their top edge fixed.
  final bool bottomAnchored;
  double get anchor => bottomAnchored ? 1 : 0;

  RaftTimelineAlignment? _pending;
  RaftTimelineAlignment? get pending => _pending;

  /// More history may load above: the top is not the real beginning, so it
  /// is never held (history lands above the reader instead).
  bool olderPending = false;

  /// Positions the next layout (after a re-centered rebuild) at [alignment].
  /// Starts from the center so the rebuilt lists never lay out the distance
  /// between the old and the new position.
  void align(RaftTimelineAlignment alignment) {
    _pending = alignment;
    if (positions.length == 1) {
      final p = position as RaftTimelinePosition;
      p.followEnd = p.followStart = false;
      p.jumpTo(0);
    }
  }

  /// Keeps the latest end pinned from the next layout on.
  void followEnd() {
    for (final p in positions) {
      (p as RaftTimelinePosition).followEnd = true;
    }
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => RaftTimelinePosition(
    owner: this,
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
  );
}

class RaftTimelinePosition extends ScrollPositionWithSingleContext {
  RaftTimelinePosition({
    required this.owner,
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  final RaftTimelineScrollController owner;
  RaftTimelineRenderViewport? viewport;

  /// The reader is at the latest end: content changes keep it there.
  bool followEnd = false;

  /// The reader is at the top: while it is the real beginning, content
  /// changes keep it there (a growing head never pushes the rows up).
  bool followStart = false;
  int _rounds = 0;

  void _trackEnd() {
    if (owner._pending == null && hasContentDimensions) {
      followEnd = pixels >= maxScrollExtent - .5;
      // Reaching a temporary top never holds it: the page landing there
      // goes above the reader, even when it turns out to be the last one.
      followStart = !owner.olderPending && pixels <= minScrollExtent + .5;
    }
  }

  @override
  double setPixels(double newPixels) {
    final overscroll = super.setPixels(newPixels);
    _trackEnd();
    return overscroll;
  }

  @override
  void forcePixels(double value) {
    super.forcePixels(value);
    _trackEnd();
  }

  double? _rowTarget(_RowAlignment align, RaftTimelineRenderViewport view) =>
      view.measure(() {
        final box = align.find?.call() ?? view.centerLeadingRow();
        if (box == null || !box.attached || !box.hasSize) return null;
        final Object? host = RenderAbstractViewport.maybeOf(box);
        if (!identical(host, view)) return null;
        // Laid out in this pass: its current offset from the viewport's top.
        final top = MatrixUtils.transformPoint(
          box.getTransformTo(view),
          Offset.zero,
        ).dy;
        final want =
            align.leading ??
            (viewportDimension - box.size.height) * align.alignment;
        return pixels + top - want;
      });

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    var lo = minScrollExtent, hi = maxScrollExtent;
    var short = false;
    final view = viewport;
    if (view != null && view.attached && identical(view.offset, this)) {
      if (view.refreshSparseFill()) return false;
      final (reverse, forward) = view.contentExtents();
      final extent = viewportDimension, anchor = view.anchor;
      // The content edges, without the viewport's floor at the center.
      lo = extent * anchor - reverse;
      hi = forward - extent * (1 - anchor);
      if (lo > hi) {
        short = true;
        lo = hi = owner.bottomAnchored ? hi : lo;
      }
    }
    final pending = owner._pending;
    final dragging = activity is DragScrollActivity;
    double? target;
    if (pending != null && view != null) {
      target = switch (pending) {
        _EndAlignment() => hi,
        _StartAlignment() => lo,
        final _RowAlignment row => _rowTarget(row, view),
      };
    } else if (followEnd && !dragging) {
      target = hi;
    } else if (followStart && !dragging) {
      target = lo;
    } else if (short && !dragging) {
      target = lo;
    }
    if (target != null) {
      final clamped = target.clamp(lo, hi);
      if ((clamped - pixels).abs() > .5 && _rounds < 12) {
        _rounds++;
        correctPixels(clamped);
        return false;
      }
    }
    _rounds = 0;
    if (pending != null && view != null) {
      owner._pending = null;
      followEnd = pending is _EndAlignment || (pixels - hi).abs() <= .5;
      followStart = !owner.olderPending && (pixels - lo).abs() <= .5;
    }
    return super.applyContentDimensions(lo, hi);
  }
}

class _TimelineScrollView extends CustomScrollView {
  const _TimelineScrollView({
    super.controller,
    super.physics,
    super.center,
    super.anchor,
    super.keyboardDismissBehavior,
    super.semanticChildCount,
    super.scrollCacheExtent,
    super.slivers,
  });

  @override
  Widget buildViewport(
    BuildContext context,
    ViewportOffset offset,
    AxisDirection axisDirection,
    List<Widget> slivers,
  ) => _TimelineViewport(
    axisDirection: axisDirection,
    offset: offset,
    slivers: slivers,
    center: center,
    anchor: anchor,
    scrollCacheExtent: scrollCacheExtent,
    paintOrder: paintOrder,
    clipBehavior: clipBehavior,
  );
}

class _TimelineViewport extends Viewport {
  _TimelineViewport({
    super.axisDirection,
    super.anchor,
    required super.offset,
    super.center,
    super.scrollCacheExtent,
    super.paintOrder,
    super.clipBehavior,
    super.slivers,
  });

  @override
  RenderViewport createRenderObject(BuildContext context) =>
      RaftTimelineRenderViewport(
        axisDirection: axisDirection,
        crossAxisDirection:
            crossAxisDirection ??
            Viewport.getDefaultCrossAxisDirection(context, axisDirection),
        anchor: anchor,
        offset: offset,
        scrollCacheExtent: scrollCacheExtent,
        paintOrder: paintOrder,
        clipBehavior: clipBehavior,
      );
}

/// The timeline's viewport: reports its content extents to its
/// [RaftTimelinePosition], which owns the scroll range.
class RaftTimelineRenderViewport extends RenderViewport {
  RaftTimelineRenderViewport({
    super.axisDirection,
    required super.crossAxisDirection,
    required super.offset,
    super.anchor,
    super.scrollCacheExtent,
    super.paintOrder,
    super.clipBehavior,
  });

  @override
  void performLayout() {
    final position = offset;
    if (position is RaftTimelinePosition) position.viewport = this;
    super.performLayout();
  }

  /// [RenderViewport.getOffsetToReveal] measures from the center as if it
  /// sat at the leading edge; with an [anchor] the zero offset sits
  /// `anchor * extent` below it. Without this, `ensureVisible`, focus
  /// traversal and accessibility `showOnScreen` miss in a bottom-anchored
  /// timeline.
  @override
  RevealedOffset getOffsetToReveal(
    RenderObject target,
    double alignment, {
    Rect? rect,
    Axis? axis,
  }) {
    final revealed = super.getOffsetToReveal(
      target,
      alignment,
      rect: rect,
      axis: axis,
    );
    final shift =
        anchor * (this.axis == Axis.vertical ? size.height : size.width);
    if (shift == 0 || !revealed.offset.isFinite) return revealed;
    final delta = switch (axisDirection) {
      AxisDirection.down => Offset(0, -shift),
      AxisDirection.up => Offset(0, shift),
      AxisDirection.right => Offset(-shift, 0),
      AxisDirection.left => Offset(shift, 0),
    };
    return RevealedOffset(
      offset: revealed.offset + shift,
      rect: revealed.rect.shift(delta),
    );
  }

  /// Reads the geometry of rows laid out in this pass (allowed inside the
  /// viewport's own layout callback).
  T measure<T>(T Function() read) {
    late T result;
    invokeLayoutCallback<BoxConstraints>((_) => result = read());
    return result;
  }

  /// Scroll extents before and after the center, from the last layout.
  (double, double) contentExtents() {
    var reverse = 0.0, forward = 0.0, after = false;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if (identical(child, center)) after = true;
      final extent = child.geometry?.scrollExtent ?? 0;
      if (after) {
        forward += extent;
      } else {
        reverse += extent;
      }
    }
    return (reverse, forward);
  }

  /// The first row of the center sliver, if it is laid out.
  RenderBox? centerLeadingRow() {
    final sliver = center;
    if (sliver is! RenderSliverMultiBoxAdaptor) return null;
    final first = sliver.firstChild;
    return first != null && sliver.indexOf(first) == 0 ? first : null;
  }

  /// A sparse fill sizes itself from its siblings; one laid out before later
  /// siblings changed is laid out again within this layout.
  bool refreshSparseFill() {
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if (child is _RenderSparseFill && child.stale()) {
        final fill = child;
        invokeLayoutCallback<BoxConstraints>((_) => fill.markNeedsLayout());
        return true;
      }
    }
    return false;
  }
}

/// Fills the viewport space the rest of the timeline leaves empty, so a
/// short timeline keeps [child] at its edge (Source flex-grow spacer). For a
/// timeline longer than its viewport it is just [child]'s own height.
///
/// Its extent never moves rows: it sits on the outer side of the history.
class RaftTimelineSparseFill extends SingleChildRenderObjectWidget {
  const RaftTimelineSparseFill({super.key, super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSparseFill();
}

class _RenderSparseFill extends RenderSliverSingleBoxAdapter {
  double _others = 0;

  double _siblingExtents() {
    final view = parent;
    if (view is! RenderViewport) return 0;
    var total = 0.0;
    for (
      var child = view.firstChild;
      child != null;
      child = view.childAfter(child)
    ) {
      if (!identical(child, this)) total += child.geometry?.scrollExtent ?? 0;
    }
    return total;
  }

  bool stale() => (_siblingExtents() - _others).abs() > .5;

  @override
  void performLayout() {
    final c = constraints;
    _others = _siblingExtents();
    final spare = math.max(0.0, c.viewportMainAxisExtent - _others);
    var extent = spare;
    final box = child;
    if (box != null) {
      box.layout(c.asBoxConstraints(), parentUsesSize: true);
      final natural = c.axis == Axis.vertical
          ? box.size.height
          : box.size.width;
      extent = math.max(natural, spare);
      if (extent != natural) {
        box.layout(
          c.asBoxConstraints(minExtent: extent, maxExtent: extent),
          parentUsesSize: true,
        );
      }
    }
    final painted = calculatePaintOffset(c, from: 0, to: extent);
    geometry = SliverGeometry(
      scrollExtent: extent,
      paintExtent: painted,
      cacheExtent: calculateCacheOffset(c, from: 0, to: extent),
      maxPaintExtent: extent,
      hitTestExtent: painted,
      hasVisualOverflow: extent > c.remainingPaintExtent || c.scrollOffset > 0,
    );
    if (box != null) setChildParentData(box, c, geometry!);
  }
}

class _TimelineEdges {
  /// More history may still load above: no overscroll at the top edge, so a
  /// spring never fights the history that lands there.
  bool olderPending = false;
}

class _TimelinePhysics extends ScrollPhysics {
  const _TimelinePhysics(this.edges, {super.parent});
  final _TimelineEdges edges;

  @override
  _TimelinePhysics applyTo(ScrollPhysics? ancestor) =>
      _TimelinePhysics(edges, parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (edges.olderPending && value < position.pixels) {
      if (position.pixels <= position.minScrollExtent) {
        return value - position.pixels;
      }
      if (value < position.minScrollExtent) {
        return value - position.minScrollExtent;
      }
    }
    return super.applyBoundaryConditions(position, value);
  }
}

/// Builder delegate whose total extent sums per-row estimates for the rows
/// after the last laid-out child, instead of the framework's average-based
/// extrapolation (stable scrollbar for rows of very different heights).
class _EstimatingChildDelegate extends SliverChildBuilderDelegate {
  _EstimatingChildDelegate(
    super.builder, {
    required int super.childCount,
    required this.estimate,
    super.findChildIndexCallback,
  });
  final double Function(int index)? estimate;

  @override
  double? estimateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) {
    final perItem = estimate;
    final count = childCount;
    if (perItem == null || count == null) return null;
    var extent = trailingScrollOffset;
    for (var i = lastIndex + 1; i < count; i++) {
      extent += perItem(i);
    }
    return extent;
  }
}
