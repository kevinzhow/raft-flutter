import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class RaftMessageBodyTrailing extends MultiChildRenderObjectWidget {
  RaftMessageBodyTrailing({
    super.key,
    required Widget body,
    required Widget trailing,
  }) : super(children: [body, trailing]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMessageBodyTrailing(Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMessageBodyTrailing renderObject,
  ) {
    renderObject.direction = Directionality.of(context);
  }
}

class _Slot extends ContainerBoxParentData<RenderBox> {}

class _RenderMessageBodyTrailing extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _Slot>,
        RenderBoxContainerDefaultsMixin<RenderBox, _Slot> {
  _RenderMessageBodyTrailing(this._direction);

  TextDirection _direction;
  set direction(TextDirection value) {
    if (_direction == value) return;
    _direction = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _Slot) child.parentData = _Slot();
  }

  @override
  void performLayout() {
    final body = firstChild!, trailing = lastChild!;
    final loose = constraints.loosen();
    body.layout(loose, parentUsesSize: true);
    trailing.layout(loose, parentUsesSize: true);
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : body.size.width + trailing.size.width;
    final left = _direction == TextDirection.ltr
        ? width - trailing.size.width
        : 0.0;
    final bodyLeft = _direction == TextDirection.ltr
        ? 0.0
        : width - body.size.width;
    var top = body.size.height;
    if (trailing.size.height > 0 && body.size.height > 0) {
      final paragraph = _lastParagraph(body);
      if (paragraph != null) {
        final end = paragraph.text.toPlainText().length;
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: end),
        );
        if (boxes.isNotEmpty) {
          final last = boxes.last;
          final origin = paragraph.localToGlobal(Offset.zero, ancestor: body);
          final occupied = boxes.where((box) => box.bottom == last.bottom);
          final room = _direction == TextDirection.ltr
              ? occupied.every(
                  (box) => bodyLeft + origin.dx + box.right <= left,
                )
              : occupied.every(
                  (box) =>
                      bodyLeft + origin.dx + box.left >= trailing.size.width,
                );
          final lineBottom = origin.dy + last.bottom;
          if (room && lineBottom + trailing.size.height >= body.size.height) {
            top =
                (origin.dy +
                        (last.top + last.bottom - trailing.size.height) / 2)
                    .clamp(0.0, body.size.height);
          }
        }
      }
    }
    (body.parentData! as _Slot).offset = Offset(bodyLeft, 0);
    (trailing.parentData! as _Slot).offset = Offset(left, top);
    final bottom = top + trailing.size.height;
    size = constraints.constrain(
      Size(width, bottom > body.size.height ? bottom : body.size.height),
    );
  }

  RenderParagraph? _lastParagraph(RenderObject node) {
    if (node is RenderParagraph) return node;
    if (node is RenderAbstractViewport) return null;
    RenderObject? last;
    node.visitChildren((child) => last = child);
    return last == null ? null : _lastParagraph(last!);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final body = firstChild!.getDryLayout(constraints.loosen());
    final trailing = lastChild!.getDryLayout(constraints.loosen());
    return constraints.constrain(
      Size(
        constraints.hasBoundedWidth
            ? constraints.maxWidth
            : body.width + trailing.width,
        body.height + trailing.height,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
