import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Marks a small control as a touch target of at least [minSize], resolved by
/// the nearest [RaftTapSlopHost] above it. Layout and paint are untouched, so
/// Web-sized controls keep their visual box.
///
/// [RaftTouchTarget] cannot do this for a control whose parents are no larger
/// than the control (a toolbar row): every ancestor rejects a pointer outside
/// its own bounds before the control sees it. The host sits above those
/// ancestors, so it can route a pointer that lands near an anchor to it.
class RaftTapSlopAnchor extends SingleChildRenderObjectWidget {
  const RaftTapSlopAnchor({
    super.key,
    required this.minSize,
    required super.child,
  });

  final Size minSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderTapSlopAnchor(minSize);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderTapSlopAnchor renderObject,
  ) => renderObject.minSize = minSize;
}

class RenderTapSlopAnchor extends RenderProxyBox {
  RenderTapSlopAnchor(this._minSize);

  Size _minSize;
  Size get minSize => _minSize;
  set minSize(Size value) {
    if (value == _minSize) return;
    _minSize = value;
  }
}

/// Gives the whole visible control priority over a neighbour's expanded tap
/// target, including padding that is outside its inner editable render box.
class RaftTapSlopGuard extends SingleChildRenderObjectWidget {
  const RaftTapSlopGuard({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderTapSlopGuard();
}

class RenderTapSlopGuard extends RenderProxyBox {}

/// Routes a pointer that lands within an anchor's [RaftTapSlopAnchor.minSize]
/// box (but not on the anchor itself) to the nearest anchor, so adjacent
/// anchors split the gap between them instead of overlapping.
///
/// Only pointers that no anchor owns outright are rerouted; a pointer directly
/// on any other control keeps going to that control.
class RaftTapSlopHost extends SingleChildRenderObjectWidget {
  const RaftTapSlopHost({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderTapSlopHost();
}

class RenderTapSlopHost extends RenderProxyBox {
  bool _protectingDirectHit = false;

  /// True only during a hit test inside a guarded control's visible bounds.
  bool get protectingDirectHit => _protectingDirectHit;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    final anchors = <RenderTapSlopAnchor>[];
    var guardAtPosition = false;
    final globalPosition = localToGlobal(position);
    void collect(RenderObject node) {
      if (node is RenderTapSlopAnchor && node.attached && node.hasSize) {
        anchors.add(node);
      }
      if (node is RenderTapSlopGuard &&
          node.attached &&
          node.hasSize &&
          (Offset.zero & node.size).contains(
            node.globalToLocal(globalPosition),
          )) {
        guardAtPosition = true;
      }
      node.visitChildren(collect);
    }

    visitChildren(collect);
    final previous = _protectingDirectHit;
    try {
      // Probe normal visual bounds first with expansion disabled. This keeps
      // a hidden input behind an overlay from taking priority over it.
      var protected = false;
      if (guardAtPosition) {
        _protectingDirectHit = true;
        final direct = BoxHitTestResult();
        super.hitTest(direct, position: position);
        protected = direct.path.any(
          (entry) => entry.target is RenderTapSlopGuard,
        );
      }
      _protectingDirectHit = protected;
      // The direct hit test retains normal child and scrollable gestures; the
      // host must not redirect this point to a neighbour's expanded target.
      if (protected) return super.hitTest(result, position: position);
      return _hitTestSlop(result, position, anchors);
    } finally {
      _protectingDirectHit = previous;
    }
  }

  bool _hitTestSlop(
    BoxHitTestResult result,
    Offset position,
    List<RenderTapSlopAnchor> anchors,
  ) {
    RenderTapSlopAnchor? best;
    Rect? bestVisual;
    var bestDistance = double.infinity;
    for (final anchor in anchors) {
      final origin = anchor.localToGlobal(Offset.zero, ancestor: this);
      final visual = origin & anchor.size;
      if (visual.contains(position)) {
        // Directly on an anchor: the normal hit test resolves it.
        return super.hitTest(result, position: position);
      }
      final target = Rect.fromCenter(
        center: visual.center,
        width: math.max(visual.width, anchor.minSize.width),
        height: math.max(visual.height, anchor.minSize.height),
      );
      if (!target.contains(position)) continue;
      final dx = math.max(
        0.0,
        math.max(visual.left - position.dx, position.dx - visual.right),
      );
      final dy = math.max(
        0.0,
        math.max(visual.top - position.dy, position.dy - visual.bottom),
      );
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = anchor;
        bestVisual = visual;
      }
    }
    if (best != null && bestVisual != null) {
      // A neighboring target must not take a pointer from editable input.
      // Probe at the actual position before routing blank-space touches.
      final direct = BoxHitTestResult();
      if (super.hitTest(direct, position: position) &&
          direct.path.any((entry) => entry.target is RenderEditable)) {
        return super.hitTest(result, position: position);
      }
      // Inset both closed and open edges: a fractional ancestor transform
      // can round the exact near edge just below zero during the inverse
      // hit-test transform. The routing point must be strictly inside.
      final insetX = math.min(1e-3, bestVisual.width / 2);
      final insetY = math.min(1e-3, bestVisual.height / 2);
      final inside = Offset(
        position.dx.clamp(bestVisual.left + insetX, bestVisual.right - insetX),
        position.dy.clamp(bestVisual.top + insetY, bestVisual.bottom - insetY),
      );
      if (super.hitTest(result, position: inside)) return true;
    }
    return super.hitTest(result, position: position);
  }
}
