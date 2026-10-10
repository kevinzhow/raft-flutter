import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Keeps a visible row at the same screen position across one content change
/// (Web keeps the reader's place when messages arrive while scrolled up).
///
/// [capture] records a row's offset inside its lazy list before rows are
/// inserted. The next layout of [RaftReadingAnchor] reads the row's new offset
/// and moves the scroll position by the same amount within the same frame, so
/// no displaced frame is painted. Works in scroll space, for either direction.
class RaftReadingAnchorController {
  RenderBox? _row;
  double? _offset;
  ScrollPosition? _position;
  int _layouts = 0;

  /// The mounted anchor box (set when it attaches).
  RenderBox? host;

  bool get pending => _row != null || _resolve != null;

  /// Identity-based anchor: resolves the anchored row's current scroll
  /// offset by identity (exact when it is laid out, otherwise estimated from
  /// the rows that are), so the hold survives the row's render box being
  /// rebuilt or collected (e.g. rows inserted before it re-index the list).
  ({double offset, bool exact})? Function()? _resolve;

  void captureResolved(
    double offset,
    ({double offset, bool exact})? Function() resolve,
    ScrollPosition position,
  ) {
    _row = null;
    _resolve = resolve;
    _offset = offset - position.pixels;
    _position = position;
    _layouts = 0;
    host?.markNeedsLayout();
  }

  static double? scrollOffsetOf(RenderBox row) {
    final data = row.parentData;
    final sliver = row.parent;
    if (data is! SliverMultiBoxAdaptorParentData ||
        sliver is! RenderSliverMultiBoxAdaptor) {
      return null;
    }
    final offset = data.layoutOffset;
    if (offset == null) return null;
    return offset + sliver.constraints.precedingScrollExtent;
  }

  void capture(RenderBox row, ScrollPosition position) {
    final offset = scrollOffsetOf(row);
    if (offset == null) return;
    _row = row;
    // The row stays put while (its offset in the list - scroll pixels) holds.
    _offset = offset - position.pixels;
    _position = position;
    _layouts = 0;
    // The scroll view is a relayout boundary; make the next frame lay out the
    // anchor box too so the correction runs before anything is painted.
    host?.markNeedsLayout();
  }

  void clear() {
    _row = null;
    _resolve = null;
    _offset = null;
    _position = null;
  }
}

/// A scroll controller whose positions keep a captured [RaftReadingAnchor]
/// row in place inside the viewport's own layout: the correction is applied
/// in [ScrollPosition.applyContentDimensions] and the viewport lays out again
/// in the same pass, so estimated-then-real extents never show a displaced
/// frame.
class RaftAnchoredScrollController extends ScrollController {
  RaftAnchoredScrollController(
    this.anchor, {
    super.initialScrollOffset,
    super.debugLabel,
    this.startAtEnd = false,
  }) : super(keepScrollOffset: !startAtEnd);
  final RaftReadingAnchorController anchor;

  /// Begins at the actual end in layout (a freshly mounted top-anchored
  /// window, cf. RaftInitialEndScrollController) and keeps the reading
  /// anchor afterwards.
  final bool startAtEnd;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _AnchoredScrollPosition(
    anchor: anchor,
    startAtEnd: startAtEnd,
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
  );
}

class _AnchoredScrollPosition extends ScrollPositionWithSingleContext {
  _AnchoredScrollPosition({
    required this.anchor,
    this.startAtEnd = false,
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });
  final RaftReadingAnchorController anchor;
  bool startAtEnd;
  int _rounds = 0;

  /// Any real scroll (drag, fling, animation via [setPixels]; jumps via
  /// [forcePixels]) ends the hold; only [correctPixels] keeps it.
  @override
  double setPixels(double newPixels) {
    final before = pixels;
    final overscroll = super.setPixels(newPixels);
    // A drag or fling keeps the hold: the held row moves with the user's
    // scroll, so its gap follows the applied delta and only content shifts
    // (rows inserted before it) are corrected. Programmatic jumps
    // ([forcePixels]) end it.
    final applied = pixels - before;
    if (applied != 0 &&
        identical(anchor._position, this) &&
        anchor._offset != null) {
      anchor._offset = anchor._offset! - applied;
    }
    return overscroll;
  }

  @override
  void forcePixels(double value) {
    if (value != pixels && identical(anchor._position, this)) anchor.clear();
    super.forcePixels(value);
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final resolve = anchor._resolve, held = anchor._offset;
    if (resolve != null &&
        held != null &&
        identical(anchor._position, this) &&
        hasPixels) {
      final at = resolve();
      if (at != null) {
        final delta = (at.offset - pixels) - held;
        // Never hold the list outside its scroll range (a held row near an
        // edge cannot be kept exactly where it was).
        final target = (pixels + delta).clamp(minScrollExtent, maxScrollExtent);
        if ((target - pixels).abs() >= .5 && _rounds < 8) {
          // Estimate first if the row is not built here; the next round
          // lays out around it and reads its real offset.
          _rounds++;
          correctPixels(target);
          return false;
        }
      }
      _rounds = 0;
      return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
    }
    if (startAtEnd) {
      if (maxScrollExtent.isFinite && pixels != maxScrollExtent) {
        correctPixels(maxScrollExtent);
        return false;
      }
      final accepted = super.applyContentDimensions(
        minScrollExtent,
        maxScrollExtent,
      );
      if (accepted) startAtEnd = false;
      return accepted;
    }
    final row = anchor._row, gap = anchor._offset;
    if (row != null &&
        gap != null &&
        identical(anchor._position, this) &&
        row.attached &&
        hasPixels &&
        _rounds < 4) {
      final offset = RaftReadingAnchorController.scrollOffsetOf(row);
      if (offset != null) {
        final delta = (offset - pixels) - gap;
        final target = (pixels + delta).clamp(minScrollExtent, maxScrollExtent);
        if ((target - pixels).abs() >= .5) {
          _rounds++;
          correctPixels(target);
          return false; // The viewport lays out again in this pass.
        }
      }
    }
    _rounds = 0;
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}

class RaftReadingAnchor extends SingleChildRenderObjectWidget {
  const RaftReadingAnchor({
    super.key,
    required this.controller,
    required super.child,
  });
  final RaftReadingAnchorController controller;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReadingAnchor(controller);
  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    final anchor = renderObject as _RenderReadingAnchor;
    anchor.controller = controller;
    if (anchor.attached) controller.host = anchor;
  }
}

class _RenderReadingAnchor extends RenderProxyBox {
  _RenderReadingAnchor(this.controller);
  RaftReadingAnchorController controller;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    controller.host = this;
  }

  @override
  void detach() {
    if (identical(controller.host, this)) controller.host = null;
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    final c = controller, row = c._row, before = c._offset;
    final position = c._position;
    if (c._resolve != null) {
      // Resolved anchors correct inside the anchored position; this box only
      // keeps them for a few frames of late extent changes, then releases.
      if (position == null || !position.hasPixels || ++c._layouts > 8) {
        c.clear();
        return;
      }
      final resolve = c._resolve;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (identical(c._resolve, resolve) && attached) markNeedsLayout();
      });
      return;
    }
    if (row == null || before == null || position == null) return;
    if (!row.attached || !position.hasPixels || ++c._layouts > 8) {
      c.clear();
      return;
    }
    // Anchored positions correct inside the viewport's own layout; this box
    // only counts frames. Plain controllers fall back to correcting here,
    // which can leave a late extent change for the next frame.
    for (
      var round = 0;
      round < 3 && position is! _AnchoredScrollPosition;
      round++
    ) {
      final offset = RaftReadingAnchorController.scrollOffsetOf(row);
      if (offset == null) break;
      final delta = (offset - position.pixels) - before;
      if (delta.abs() < .5) break;
      position.correctBy(delta);
      final viewport = RenderAbstractViewport.maybeOf(row);
      if (viewport is RenderObject) {
        invokeLayoutCallback<BoxConstraints>((_) {
          (viewport as RenderObject).markNeedsLayout();
        });
      }
      super.performLayout();
    }
    // Rows below the anchor can settle their height a frame later (grouping,
    // measured content). Keep checking for a few frames, then release.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (identical(c._row, row) && attached) markNeedsLayout();
    });
  }
}
