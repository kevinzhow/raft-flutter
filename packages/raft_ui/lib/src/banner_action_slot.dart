import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'recipes/recipe_runtime.dart' show RaftSlotStyle;

/// Internal renderer for the published BannerAction slot.
///
/// Canonical Banner supplies the resolved style; there is no new public
/// Banner parameter or theme capability for replacing it. The slot is
/// `flex flex-wrap justify-end gap-2`: its buttons end at the right edge of
/// whatever width it is given. [inline] is the slot beside the text
/// (`not-data-wrap:mt-0`): no vertical margin.
class RaftBannerActionSlot extends StatelessWidget {
  const RaftBannerActionSlot({
    super.key,
    required this.style,
    required this.children,
    this.inline = false,
  });

  final RaftSlotStyle style;
  final List<Widget> children;
  final bool inline;

  @override
  Widget build(BuildContext context) => Padding(
    padding: inline ? style.margin.copyWith(top: 0, bottom: 0) : style.margin,
    child: Wrap(
      alignment: WrapAlignment.end,
      spacing: style.columnGap ?? 0,
      runSpacing: style.rowGap ?? 0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    ),
  );
}

/// The two halves of a raft-ui Banner body: the text (`BannerDescription`,
/// first child) and `BannerAction` (second child, a [RaftBannerActionSlot]).
/// The action sits at the end of the text's last line, centred on it, while
/// the container is at least 452px wide ([besideAllowed]) and the text fits on
/// one line next to it; in every other case it takes its own row under the
/// text, [belowGap] (`mt-2`) away, end aligned (`useWrapsBesideText` of raft-ui
/// `banner`).
class RaftBannerBody extends MultiChildRenderObjectWidget {
  const RaftBannerBody({
    super.key,
    required this.besideAllowed,
    required this.gap,
    required this.belowGap,
    required super.children,
  });

  final bool besideAllowed;
  final double gap, belowGap;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBannerBody(
    besideAllowed: besideAllowed,
    gap: gap,
    belowGap: belowGap,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderBannerBody render) {
    render
      ..besideAllowed = besideAllowed
      ..gap = gap
      ..belowGap = belowGap;
  }
}

class _BodyParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderBannerBody extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BodyParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BodyParentData> {
  _RenderBannerBody({
    required bool besideAllowed,
    required double gap,
    required double belowGap,
  }) : _besideAllowed = besideAllowed,
       _gap = gap,
       _belowGap = belowGap;

  bool _besideAllowed;
  double _gap, _belowGap;
  set besideAllowed(bool v) {
    if (v == _besideAllowed) return;
    _besideAllowed = v;
    markNeedsLayout();
  }

  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  set belowGap(double v) {
    if (v == _belowGap) return;
    _belowGap = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BodyParentData) {
      child.parentData = _BodyParentData();
    }
  }

  RenderBox get _text => firstChild!;
  RenderBox get _action => lastChild!;

  @override
  double computeMinIntrinsicWidth(double height) =>
      _text.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _text.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _text.getMinIntrinsicHeight(width) +
      _belowGap +
      _action.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, dry: true);

  @override
  void performLayout() {
    size = _layout(constraints, dry: false);
  }

  bool _isBeside(double width, Size actionSize) =>
      _besideAllowed &&
      width.isFinite &&
      _text.getMaxIntrinsicWidth(double.infinity) +
              _gap +
              actionSize.width +
              1 <=
          width;

  Size _layout(BoxConstraints constraints, {required bool dry}) {
    final width = constraints.maxWidth;
    final loose = BoxConstraints(maxWidth: width);
    final natural = _action.getDryLayout(loose);
    if (_isBeside(width, natural)) {
      final textWidth = width - _gap - natural.width;
      final textBox = BoxConstraints.tightFor(width: textWidth);
      if (dry) {
        return constraints.constrain(
          Size(width, _text.getDryLayout(textBox).height),
        );
      }
      _text.layout(textBox, parentUsesSize: true);
      _action.layout(loose, parentUsesSize: true);
      _at(_text, Offset.zero);
      // `h-lh items-center`: centred on the text's last line; a taller button
      // spills into the banner's padding (the sm padding allows for it) and
      // does not grow the row.
      _at(
        _action,
        Offset(
          width - _action.size.width,
          (_text.size.height - _action.size.height) / 2,
        ),
      );
      return constraints.constrain(Size(width, _text.size.height));
    }
    final textBox = BoxConstraints(
      minWidth: width.isFinite ? width : 0,
      maxWidth: width,
    );
    final below = BoxConstraints(
      minWidth: width.isFinite ? width : 0,
      maxWidth: width,
    );
    if (dry) {
      final text = _text.getDryLayout(textBox);
      return constraints.constrain(
        Size(
          width.isFinite ? width : text.width,
          text.height + _belowGap + _action.getDryLayout(below).height,
        ),
      );
    }
    _text.layout(textBox, parentUsesSize: true);
    _action.layout(below, parentUsesSize: true);
    _at(_text, Offset.zero);
    _at(_action, Offset(0, _text.size.height + _belowGap));
    return constraints.constrain(
      Size(
        width.isFinite ? width : math.max(_text.size.width, _action.size.width),
        _text.size.height + _belowGap + _action.size.height,
      ),
    );
  }

  void _at(RenderBox child, Offset offset) =>
      (child.parentData! as _BodyParentData).offset = offset;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _text.getDistanceToActualBaseline(baseline);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  // A button taller than the text line spills over the body's box; it must
  // still take the pointer there.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return super.hitTest(result, position: position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// A box of [width] x [height] whose [child] may be larger and spills over it,
/// centred vertically and starting at the left edge: the Web's negative margin
/// (`BannerClose`: `-my-[calc((8-1lh)/2)] -me-icon-inset`) takes the button out
/// of the row's size without clipping it. The part outside the box still takes
/// the pointer.
class RaftOverhang extends SingleChildRenderObjectWidget {
  const RaftOverhang({
    super.key,
    required this.width,
    required this.height,
    required super.child,
  });

  final double width, height;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderOverhang(width, height);

  @override
  void updateRenderObject(BuildContext context, _RenderOverhang render) {
    render
      ..width = width
      ..height = height;
  }
}

class _RenderOverhang extends RenderShiftedBox {
  _RenderOverhang(this._width, this._height) : super(null);
  double _width, _height;
  set width(double v) {
    if (v == _width) return;
    _width = v;
    markNeedsLayout();
  }

  set height(double v) {
    if (v == _height) return;
    _height = v;
    markNeedsLayout();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(Size(_width, _height));

  @override
  void performLayout() {
    size = constraints.constrain(Size(_width, _height));
    final child = this.child;
    if (child == null) return;
    child.layout(const BoxConstraints(), parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = Offset(
      0,
      (size.height - child.size.height) / 2,
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

/// Routes pointer hits inside a banner's padded box to overhanging children
/// ([RaftBannerBody] inline actions and [RaftOverhang] close buttons) even
/// when intermediate [Row]/[Column]/[Padding] boxes are shorter than the
/// overhanging button.
class RaftBannerOverhangHost extends SingleChildRenderObjectWidget {
  const RaftBannerOverhangHost({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBannerOverhangHost();
}

class _RenderBannerOverhangHost extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    final overhangs = <RenderBox>[];
    void collect(RenderObject node) {
      if (node is _RenderBannerBody || node is _RenderOverhang) {
        overhangs.add(node as RenderBox);
      }
      node.visitChildren(collect);
    }

    visitChildren(collect);
    for (final target in overhangs.reversed) {
      if (!target.attached || !target.hasSize) continue;
      final transform = target.getTransformTo(this);
      final inverted = Matrix4.tryInvert(transform);
      if (inverted == null) continue;
      final local = MatrixUtils.transformPoint(inverted, position);
      if (target.hitTestChildren(result, position: local)) {
        result.add(BoxHitTestEntry(this, position));
        return true;
      }
    }
    return super.hitTest(result, position: position);
  }
}
