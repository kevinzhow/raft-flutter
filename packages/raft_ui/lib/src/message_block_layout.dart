import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class RaftMessageBlockLimit extends InheritedWidget {
  const RaftMessageBlockLimit({required this.height, required super.child});

  final double? height;

  static RaftMessageBlockLimit? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RaftMessageBlockLimit>();

  @override
  bool updateShouldNotify(RaftMessageBlockLimit oldWidget) =>
      height != oldWidget.height;
}

class RaftMessageBlockList extends MultiChildRenderObjectWidget {
  RaftMessageBlockList({required this.limit, required List<Widget> blocks})
    : super(
        children: [
          for (final block in blocks)
            LayoutBuilder(
              builder: (_, constraints) =>
                  constraints.maxHeight == 0 ? const SizedBox.shrink() : block,
            ),
        ],
      );

  final double? limit;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMessageBlockList(limit);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMessageBlockList renderObject,
  ) => renderObject.limit = limit;
}

class _BlockParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderMessageBlockList extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BlockParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BlockParentData> {
  _RenderMessageBlockList(this._limit);

  double? _limit;
  set limit(double? value) {
    if (_limit == value) return;
    _limit = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _BlockParentData) {
      child.parentData = _BlockParentData();
    }
  }

  @override
  void performLayout() {
    final visible = BoxConstraints(maxWidth: constraints.maxWidth);
    final clipped = visible.tighten(height: 0);
    final limit = _limit ?? double.infinity;
    var height = 0.0;
    var width = 0.0;
    var laidOut = 0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final hidden = height >= limit;
      child.layout(hidden ? clipped : visible, parentUsesSize: true);
      final data = child.parentData! as _BlockParentData;
      data.offset = Offset(0, height);
      if (hidden) continue;
      width = math.max(width, child.size.width);
      height += child.size.height;
      laidOut++;
    }
    final natural = laidOut == childCount
        ? height
        : height * childCount / laidOut;
    size = constraints.constrain(Size(width, natural));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
