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

  bool get pending => _row != null;

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
    _offset = offset;
    _position = position;
    _layouts = 0;
    // The scroll view is a relayout boundary; make the next frame lay out the
    // anchor box too so the correction runs before anything is painted.
    host?.markNeedsLayout();
  }

  void clear() {
    _row = null;
    _offset = null;
    _position = null;
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
    if (row == null || before == null || position == null) return;
    if (!row.attached || !position.hasPixels || ++c._layouts > 8) {
      c.clear();
      return;
    }
    final after = RaftReadingAnchorController.scrollOffsetOf(row);
    if (after != null && (after - before).abs() >= .5) {
      position.correctBy(after - before);
      final viewport = RenderAbstractViewport.maybeOf(row);
      if (viewport is RenderObject) {
        invokeLayoutCallback<BoxConstraints>((_) {
          (viewport as RenderObject).markNeedsLayout();
        });
      }
      super.performLayout();
      c._offset = RaftReadingAnchorController.scrollOffsetOf(row) ?? after;
    }
    // Rows below the anchor can settle their height a frame later (grouping,
    // measured content). Keep checking for a few frames, then release.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (identical(c._row, row) && attached) markNeedsLayout();
    });
  }
}
