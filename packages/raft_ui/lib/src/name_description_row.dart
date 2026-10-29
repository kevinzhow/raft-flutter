import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Sidebar row title line: a name, an optional chip and a description
/// (`flex min-w-0 flex-1 items-baseline gap-1` with a `min-w-0 truncate` name
/// and a `min-w-0 flex-1 truncate` description, Web v1.21.12 Sidebar.tsx).
///
/// The name keeps its natural width and only gives way when the line is full;
/// the description takes whatever is left, so a short name never hands its
/// room to the description's cap. (Up to v1.21.2 the name was capped at 70%
/// of the line, `shrink-0 max-w-[70%]`.)
///
/// [children] are the name, the description and, when [hasTag], the chip
/// (`shrink-0`, between the two). Without a chip the line is
/// baseline-aligned, with one every child is centred (`self-center`).
class RaftNameDescriptionRow extends MultiChildRenderObjectWidget {
  const RaftNameDescriptionRow({
    super.key,
    required this.hasTag,
    required super.children,
    this.gap = 4,
  });
  final bool hasTag;
  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderNameDescriptionRow(hasTag: hasTag, gap: gap);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderNameDescriptionRow renderObject,
  ) {
    renderObject
      ..hasTag = hasTag
      ..gap = gap;
  }
}

class _RowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderNameDescriptionRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _RowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _RowParentData> {
  _RenderNameDescriptionRow({required bool hasTag, required double gap})
    : _hasTag = hasTag,
      _gap = gap;

  bool _hasTag;
  set hasTag(bool value) {
    if (_hasTag == value) return;
    _hasTag = value;
    markNeedsLayout();
  }

  double _gap;
  set gap(double value) {
    if (_gap == value) return;
    _gap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RowParentData) {
      child.parentData = _RowParentData();
    }
  }

  RenderBox get _name => firstChild!;
  RenderBox get _description => childAfter(_name)!;
  RenderBox? get _tag => _hasTag ? childAfter(_description) : null;

  /// Lays the row out with [layout] / [baseline] standing for the real or the
  /// dry measurement of a child; returns the row size and child offsets.
  ({Size size, Offset name, Offset description, Offset? tag, double? baseline})
  _arrange(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) layout,
    double? Function(RenderBox child, BoxConstraints constraints) baseline,
  ) {
    final bounded = constraints.hasBoundedWidth;
    final tag = _tag;
    final loose = BoxConstraints(maxHeight: constraints.maxHeight);
    final tagConstraints = bounded
        ? loose.copyWith(maxWidth: constraints.maxWidth)
        : loose;
    final tagSize = tag == null ? Size.zero : layout(tag, tagConstraints);
    final fixed = _gap + (tag == null ? 0 : _gap + tagSize.width);
    final available = bounded
        ? math.max(0.0, constraints.maxWidth - fixed)
        : double.infinity;
    // The name takes its natural width up to the whole line ...
    final nameConstraints = loose.copyWith(maxWidth: available);
    final nameSize = layout(_name, nameConstraints);
    // ... and the description the rest.
    final descriptionWidth = bounded
        ? math.max(0.0, available - nameSize.width)
        : null;
    final descriptionConstraints = descriptionWidth == null
        ? loose
        : loose.copyWith(
            minWidth: descriptionWidth,
            maxWidth: descriptionWidth,
          );
    final descriptionSize = layout(_description, descriptionConstraints);

    final nameLeft = 0.0;
    final tagLeft = nameLeft + nameSize.width + _gap;
    final descriptionLeft =
        (tag == null ? nameLeft + nameSize.width : tagLeft + tagSize.width) +
        _gap;
    final width = bounded
        ? constraints.maxWidth
        : descriptionLeft + descriptionSize.width;

    double nameTop, descriptionTop, tagTop = 0, height;
    double? rowBaseline;
    if (tag == null) {
      final nameBase = baseline(_name, nameConstraints) ?? nameSize.height;
      final descriptionBase =
          baseline(_description, descriptionConstraints) ??
          descriptionSize.height;
      final base = math.max(nameBase, descriptionBase);
      nameTop = base - nameBase;
      descriptionTop = base - descriptionBase;
      height = math.max(
        nameTop + nameSize.height,
        descriptionTop + descriptionSize.height,
      );
      rowBaseline = nameTop + nameBase;
    } else {
      height = math.max(
        nameSize.height,
        math.max(descriptionSize.height, tagSize.height),
      );
      nameTop = (height - nameSize.height) / 2;
      descriptionTop = (height - descriptionSize.height) / 2;
      tagTop = (height - tagSize.height) / 2;
      final nameBase = baseline(_name, nameConstraints);
      rowBaseline = nameBase == null ? null : nameTop + nameBase;
    }
    return (
      size: constraints.constrain(Size(width, height)),
      name: Offset(nameLeft, nameTop),
      description: Offset(descriptionLeft, descriptionTop),
      tag: tag == null ? null : Offset(tagLeft, tagTop),
      baseline: rowBaseline,
    );
  }

  @override
  void performLayout() {
    final result = _arrange(constraints, (child, c) {
      child.layout(c, parentUsesSize: true);
      return child.size;
    }, (child, c) => child.getDistanceToBaseline(TextBaseline.alphabetic));
    (_name.parentData! as _RowParentData).offset = result.name;
    (_description.parentData! as _RowParentData).offset = result.description;
    if (_tag case final tag? when result.tag != null) {
      (tag.parentData! as _RowParentData).offset = result.tag!;
    }
    size = result.size;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _arrange(
    constraints,
    (child, c) => child.getDryLayout(c),
    (child, c) => child.getDryBaseline(c, TextBaseline.alphabetic),
  ).size;

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => baseline != TextBaseline.alphabetic
      ? null
      : _arrange(
          constraints,
          (child, c) => child.getDryLayout(c),
          (child, c) => child.getDryBaseline(c, TextBaseline.alphabetic),
        ).baseline;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    if (baseline != TextBaseline.alphabetic) return null;
    final inner = _name.getDistanceToActualBaseline(baseline);
    return inner == null
        ? null
        : inner + (_name.parentData! as _RowParentData).offset.dy;
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) {
    final tag = _tag;
    return _name.getMaxIntrinsicWidth(height) +
        _gap +
        (tag == null ? 0 : tag.getMaxIntrinsicWidth(height) + _gap) +
        _description.getMaxIntrinsicWidth(height);
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
