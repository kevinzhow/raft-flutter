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

/// A background gesture layer that yields to nearby controls' touch targets.
/// Wrap the background [GestureDetector] directly. Only its own listener yields;
/// visible interactive descendants retain priority. Normal blank-space gestures
/// are unchanged.
class RaftTapSlopBackground extends SingleChildRenderObjectWidget {
  const RaftTapSlopBackground({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderTapSlopBackground();
}

class RenderTapSlopBackground extends RenderProxyBox {
  bool ownsPointerReceiver(RenderPointerListener target) {
    RenderObject? receiver = child;
    if (receiver is RenderSemanticsGestureHandler) receiver = receiver.child;
    return identical(receiver, target);
  }
}

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

  /// Tests visual bounds while probing or preserving a direct control hit.
  bool get protectingDirectHit => _protectingDirectHit;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    // An outer host is probing the visual hit path. A nested host must not
    // introduce an expanded target into that path.
    if (raftTapSlopVisualBoundsOnly(this)) {
      return super.hitTest(result, position: position);
    }
    final previous = _protectingDirectHit;
    try {
      // Probe every direct hit with expansion disabled. A visible neighbouring
      // control has priority even when it is not an input or a slop anchor.
      _protectingDirectHit = true;
      final direct = BoxHitTestResult();
      super.hitTest(direct, position: position);
      final protected = _hasDirectControl(direct);
      _protectingDirectHit = protected;
      // The direct hit test retains normal child and scrollable gestures; the
      // host must not redirect this point to a neighbour's expanded target.
      if (protected) return super.hitTest(result, position: position);
      return _hitTestSlop(result, position);
    } finally {
      _protectingDirectHit = previous;
    }
  }

  bool _hasDirectControl(BoxHitTestResult direct) {
    for (final entry in direct.path) {
      final target = entry.target;
      // Scrollable's gesture listeners surround the viewport and own all
      // blank space too. Keep gap expansion inside its content while retaining
      // its normal drag recognizers in the final hit path.
      if (target is RenderAbstractViewport) break;
      if (target is RenderTapSlopGuard ||
          target is RenderEditable ||
          (target is RenderPointerListener &&
              _handlesContact(target) &&
              !_isBackgroundReceiver(target) &&
              !_wrapsViewport(target))) {
        return true;
      }
    }
    // AbsorbPointer consumes a hit without adding an entry for itself. The
    // deepest recorded ancestor still reports that consumed child hit; an
    // opaque background with no child hit does not. Keep such shields intact.
    final first = direct.path.firstOrNull;
    // A sliver recorded without a deeper box already owns this hit (including
    // a directly consumed box child). Keep its axis-specific path untouched.
    if (first is SliverHitTestEntry) return true;
    if (first is BoxHitTestEntry) {
      final childHit = BoxHitTestResult();
      return first.target.hitTestChildren(
            childHit,
            // Use the recorded hit coordinate: a Transform may deliberately
            // apply its paint transform without transforming hit tests.
            position: first.localPosition,
          ) &&
          childHit.path.isEmpty;
    }
    return false;
  }

  bool _isBackgroundReceiver(RenderPointerListener target) {
    RenderObject? ancestor = target.parent;
    while (ancestor != null && ancestor != this) {
      if (ancestor is RenderTapSlopBackground &&
          ancestor.ownsPointerReceiver(target)) {
        return true;
      }
      ancestor = ancestor.parent;
    }
    return false;
  }

  bool _handlesContact(RenderPointerListener target) =>
      target.onPointerDown != null ||
      target.onPointerMove != null ||
      target.onPointerUp != null ||
      target.onPointerCancel != null ||
      target.onPointerPanZoomStart != null ||
      target.onPointerPanZoomUpdate != null ||
      target.onPointerPanZoomEnd != null;

  bool _wrapsViewport(RenderObject target) {
    // A viewport can reject a blank content hit, leaving only Scrollable's
    // opaque listener in the path. Its single-child wrapper chain still
    // identifies that listener as belonging to the scrolling container.
    RenderObject? child = target;
    while (child is RenderProxyBox) {
      child = child.child;
    }
    return child is RenderAbstractViewport;
  }

  bool _hitTestSlop(BoxHitTestResult result, Offset position) {
    final anchors = <RenderTapSlopAnchor>[];
    void collect(RenderObject node) {
      if (node is RenderTapSlopAnchor && node.attached && node.hasSize) {
        anchors.add(node);
      }
      node.visitChildren(collect);
    }

    visitChildren(collect);
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

/// Whether an enclosing host is resolving the actual visual hit path.
bool raftTapSlopVisualBoundsOnly(RenderObject target) {
  RenderObject? ancestor = target.parent;
  while (ancestor != null) {
    if (ancestor is RenderTapSlopHost && ancestor.protectingDirectHit) {
      return true;
    }
    ancestor = ancestor.parent;
  }
  return false;
}
