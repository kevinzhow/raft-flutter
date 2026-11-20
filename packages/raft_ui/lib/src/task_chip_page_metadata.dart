part of 'task_chip_list.dart';

class _PageMetadata extends StatelessWidget {
  const _PageMetadata({
    super.key,
    required this.alignBaselines,
    required this.children,
  });

  final bool alignBaselines;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => alignBaselines
      ? _BaselineWrap(direction: Directionality.of(context), children: children)
      : Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: _RenderBaselineWrap.itemGap,
          runSpacing: _RenderBaselineWrap.runGap,
          children: children,
        );
}

class _BaselineWrap extends MultiChildRenderObjectWidget {
  const _BaselineWrap({required this.direction, required super.children});

  final TextDirection direction;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBaselineWrap(direction);

  @override
  void updateRenderObject(BuildContext context, _RenderBaselineWrap render) {
    render.direction = direction;
  }
}

class _BaselineWrapParentData extends ContainerBoxParentData<RenderBox> {}

typedef _BaselineMember = ({RenderBox box, double start, double baseline});
typedef _BaselineRun = ({
  List<_BaselineMember> members,
  double width,
  double ascent,
  double descent,
});

// COMPACT_ROW_TRAILING is baseline-aligned. When the phone cannot fit all
// metadata at a larger text size, keep the wrap and align each run separately.
class _RenderBaselineWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BaselineWrapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BaselineWrapParentData> {
  _RenderBaselineWrap(this._direction);

  static const itemGap = 8.0;
  static const runGap = 4.0;
  TextDirection _direction;
  double? _baseline;

  set direction(TextDirection value) {
    if (_direction == value) return;
    _direction = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BaselineWrapParentData) {
      child.parentData = _BaselineWrapParentData();
    }
  }

  @override
  void performLayout() {
    final result = _layout(constraints, dry: false);
    size = result.size;
    _baseline = result.baseline;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, dry: true).size;

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => _layout(constraints, dry: true).baseline;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => _baseline;

  ({Size size, double? baseline}) _layout(
    BoxConstraints constraints, {
    required bool dry,
  }) {
    final loose = BoxConstraints(maxWidth: constraints.maxWidth);
    final runs = <_BaselineRun>[];
    var members = <_BaselineMember>[];
    var width = 0.0, ascent = 0.0, descent = 0.0;

    void finishRun() {
      runs.add((
        members: members,
        width: width,
        ascent: ascent,
        descent: descent,
      ));
      members = [];
      width = ascent = descent = 0;
    }

    for (var box = firstChild; box != null; box = childAfter(box)) {
      if (!dry) box.layout(loose, parentUsesSize: true);
      final childSize = dry ? box.getDryLayout(loose) : box.size;
      final baseline =
          (dry
              ? box.getDryBaseline(loose, TextBaseline.alphabetic)
              : box.getDistanceToBaseline(
                  TextBaseline.alphabetic,
                  onlyReal: true,
                )) ??
          childSize.height / 2;
      if (members.isNotEmpty &&
          width + itemGap + childSize.width > loose.maxWidth) {
        finishRun();
      }
      final start = members.isEmpty ? 0.0 : width + itemGap;
      members.add((box: box, start: start, baseline: baseline));
      width = start + childSize.width;
      if (baseline > ascent) ascent = baseline;
      final below = childSize.height - baseline;
      if (below > descent) descent = below;
    }
    if (members.isNotEmpty) finishRun();
    if (runs.isEmpty) return (size: constraints.smallest, baseline: null);

    var maxWidth = 0.0;
    var totalHeight = -runGap;
    for (final run in runs) {
      if (run.width > maxWidth) maxWidth = run.width;
      totalHeight += run.ascent + run.descent + runGap;
    }
    final result = constraints.constrain(Size(maxWidth, totalHeight));
    if (!dry) {
      var top = 0.0;
      for (final run in runs) {
        for (final member in run.members) {
          final dx = _direction == TextDirection.ltr
              ? result.width - run.width + member.start
              : run.width - member.start - member.box.size.width;
          final data = member.box.parentData! as _BaselineWrapParentData;
          data.offset = Offset(dx, top + run.ascent - member.baseline);
        }
        top += run.ascent + run.descent + runGap;
      }
    }
    return (size: result, baseline: runs.first.ascent);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
