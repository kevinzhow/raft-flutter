import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// raft-ui `stacked-actions`: a footer's row of buttons that does not fit on
/// one line becomes a full-width column, the commit on top (`flex-col-reverse`),
/// and the ghost Cancel gains the stacked frame (`in-data-stacked:` on Button).
/// Buttons read [RaftStackedActions.of] for that state.
class RaftStackedActions extends InheritedWidget {
  const RaftStackedActions({
    super.key,
    required this.stacked,
    required super.child,
  });
  final bool stacked;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<RaftStackedActions>()
          ?.stacked ??
      false;

  @override
  bool updateShouldNotify(RaftStackedActions oldWidget) =>
      stacked != oldWidget.stacked;
}

/// `justify-end` row of [children]; when the row is wider than the space it
/// has, [RaftStackedActions] and a reversed full-width column instead.
///
/// The decision is made in layout (as a `LayoutBuilder` builds), so the first
/// painted frame is already the final one: no post-frame `setState`.
class RaftActionRow extends AbstractLayoutBuilder<_RowInfo> {
  const RaftActionRow({super.key, required this.children, this.gap = 8});
  final List<Widget> children;
  final double gap;

  @override
  Widget Function(BuildContext context, _RowInfo info) get builder =>
      (context, info) => info.stacked
      ? RaftStackedActions(
          stacked: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            verticalDirection: VerticalDirection.up,
            spacing: gap,
            children: children,
          ),
        )
      : Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: gap,
          children: children,
        );

  @override
  bool updateShouldRebuild(covariant RaftActionRow oldWidget) => true;

  @override
  RenderAbstractLayoutBuilderMixin<_RowInfo, RenderObject> createRenderObject(
    BuildContext context,
  ) => _RenderActionRow();
}

@immutable
class _RowInfo {
  const _RowInfo(this.constraints, this.stacked);
  final BoxConstraints constraints;
  final bool stacked;
  @override
  bool operator ==(Object other) =>
      other is _RowInfo &&
      other.constraints == constraints &&
      other.stacked == stacked;
  @override
  int get hashCode => Object.hash(constraints, stacked);
}

class _RenderActionRow extends RenderBox
    with
        RenderObjectWithChildMixin<RenderBox>,
        RenderObjectWithLayoutCallbackMixin,
        RenderAbstractLayoutBuilderMixin<_RowInfo, RenderBox> {
  bool _stacked = false;

  @override
  _RowInfo get layoutInfo => _RowInfo(constraints, _stacked);

  @override
  double computeMinIntrinsicWidth(double height) => 0;
  @override
  double computeMaxIntrinsicWidth(double height) => 0;
  @override
  double computeMinIntrinsicHeight(double width) => 0;
  @override
  double computeMaxIntrinsicHeight(double width) => 0;
  @override
  Size computeDryLayout(BoxConstraints constraints) => Size.zero;

  @override
  void performLayout() {
    final c = constraints;
    _stacked = false;
    runLayoutCallback();
    var child = this.child!;
    child.layout(BoxConstraints(maxHeight: c.maxHeight), parentUsesSize: true);
    if (c.hasBoundedWidth && child.size.width > c.maxWidth + .5) {
      _stacked = true;
      runLayoutCallback();
      child = this.child!;
      child.layout(
        BoxConstraints(
          minWidth: c.maxWidth,
          maxWidth: c.maxWidth,
          maxHeight: c.maxHeight,
        ),
        parentUsesSize: true,
      );
    }
    size = c.constrain(
      Size(
        c.hasBoundedWidth ? c.maxWidth : child.size.width,
        child.size.height,
      ),
    );
    // `justify-end`.
    (child.parentData! as BoxParentData).offset = Offset(
      size.width - child.size.width,
      0,
    );
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      child?.getDistanceToActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    final offset = (child.parentData! as BoxParentData).offset;
    return result.addWithPaintOffset(
      offset: offset,
      position: position,
      hitTest: (result, transformed) =>
          child.hitTest(result, position: transformed),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    context.paintChild(
      child,
      offset + (child.parentData! as BoxParentData).offset,
    );
  }
}
