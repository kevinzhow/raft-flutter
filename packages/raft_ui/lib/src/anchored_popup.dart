import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'native_surface_occlusion.dart';

/// Retains the caller's typography and local themes across a popover route.
/// Capture before pushing the route, then wrap content built below its themes.
CapturedThemes captureRaftPopoverThemes(
  BuildContext context, {
  required NavigatorState navigator,
}) => InheritedTheme.capture(from: context, to: navigator.context);

/// Viewport collision placement shared by authored dropdown consumers.
/// InlineBadgeEditor.tsx measures the natural popup, clamps x to an 8px gutter,
/// and flips below→above when its bottom would overflow; scrolling remeasures.
/// The popup keeps its natural size until the visual viewport requires a cap.
class RaftAnchoredPopup extends StatefulWidget {
  const RaftAnchoredPopup({
    super.key,
    required this.anchorKey,
    required this.child,
    this.anchorRect,
    this.movement,
    this.above = false,
    this.alignRight = false,
    this.centerVertically = false,
    this.toRight = false,
    this.toLeft = false,
    this.gap = 4,
    this.collisionPadding = 5,
    this.snapToPixel = false,
    this.snapToDevicePixels = false,
    this.flipVertically = true,
    this.scrollChild = true,
  }) : assert(!toRight || !toLeft);
  final GlobalKey anchorKey;
  final Widget child;

  /// A portal's current anchor bounds in its overlay coordinate space.
  /// When supplied, placement uses the same delegate without re-measuring a
  /// different subtree or retaining the previous frame's bounds.
  final Rect? anchorRect;
  final Listenable? movement;
  final bool above, alignRight, centerVertically, toRight, toLeft;
  final double gap, collisionPadding;

  /// Some anchored controls constrain the content to their requested side.
  final bool flipVertically;

  /// A popup with its own scroll area receives the available height directly.
  final bool scrollChild;

  /// floating-ui rounds the computed position to the selected pixel grid.
  final bool snapToPixel, snapToDevicePixels;

  @override
  State<RaftAnchoredPopup> createState() => _RaftAnchoredPopupState();
}

class _RaftAnchoredPopupState extends State<RaftAnchoredPopup>
    with WidgetsBindingObserver {
  Rect? anchor;
  bool queued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.movement?.addListener(refreshAfterLayout);
    refreshAfterLayout();
  }

  @override
  void didUpdateWidget(RaftAnchoredPopup old) {
    super.didUpdateWidget(old);
    if (old.movement != widget.movement) {
      old.movement?.removeListener(refreshAfterLayout);
      widget.movement?.addListener(refreshAfterLayout);
    }
    refreshAfterLayout();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.movement?.removeListener(refreshAfterLayout);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // SafeArea can consume an inset change before it reaches this portal's
    // inherited metrics. Re-measure the anchor in the committed new layout.
    refreshAfterLayout();
    setState(() {});
  }

  Rect? readAnchor() {
    if (widget.anchorRect != null) return widget.anchorRect;
    final box = widget.anchorKey.currentContext?.findRenderObject();
    final overlay = Overlay.of(context).context.findRenderObject();
    if (box is! RenderBox ||
        !box.attached ||
        !box.hasSize ||
        overlay is! RenderBox) {
      return null;
    }
    return box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  }

  void refreshAfterLayout() {
    if (queued) return;
    queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      queued = false;
      if (!mounted) return;
      // Source listens to scroll/resize then measures committed DOM geometry.
      // During Flutter layout, unrelated ancestor RenderBox sizes are private;
      // a post-layout receipt avoids both that assertion and old scroll offsets.
      final next = readAnchor();
      if (next != anchor) setState(() => anchor = next);
    });
    // ignore: raft_lints/avoid_unreviewed_idle_work -- Single request after a state change; nothing re-requests from the callback.
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    final rect = widget.anchorRect ?? anchor ?? readAnchor();
    if (rect == null) return const SizedBox.shrink();
    // OverlayPortal inherits the trigger's already-consumed SafeArea/IME
    // metrics. Placement belongs to the overlay viewport, not the trigger.
    final metrics = MediaQuery.of(Overlay.of(context).context);
    final insets = metrics.padding.copyWith(
      bottom: math.max(metrics.padding.bottom, metrics.viewInsets.bottom),
    );
    return CustomSingleChildLayout(
      delegate: _PopupLayout(
        rect,
        above: widget.above,
        alignRight: widget.alignRight,
        centerVertically: widget.centerVertically,
        toRight: widget.toRight,
        toLeft: widget.toLeft,
        gap: widget.gap,
        gutter: widget.collisionPadding,
        flipVertically: widget.flipVertically,
        pixelScale: widget.snapToDevicePixels
            ? metrics.devicePixelRatio
            : widget.snapToPixel
            ? 1
            : null,
        insets: insets,
      ),
      child: RaftNativeSurfaceOccluder(
        child: widget.scrollChild
            ? SingleChildScrollView(child: widget.child)
            : widget.child,
      ),
    );
  }
}

class _PopupLayout extends SingleChildLayoutDelegate {
  const _PopupLayout(
    this.anchor, {
    required this.above,
    required this.alignRight,
    required this.centerVertically,
    required this.toRight,
    required this.toLeft,
    required this.gap,
    required this.gutter,
    required this.flipVertically,
    this.pixelScale,
    required this.insets,
  });
  final bool flipVertically;
  final double? pixelScale;
  final Rect anchor;
  final bool above, alignRight, centerVertically, toRight, toLeft;
  final double gap;
  final double gutter;
  final EdgeInsets insets;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.max(
          0,
          constraints.maxWidth - insets.horizontal - gutter * 2,
        ),
        maxHeight: math.max(0, _availableHeight(constraints.maxHeight)),
      );

  double _availableHeight(double height) {
    final top = insets.top + gutter;
    final bottom = height - insets.bottom - gutter;
    if (flipVertically || toRight || toLeft || centerVertically) {
      return bottom - top;
    }
    return above ? anchor.top - gap - top : bottom - anchor.bottom - gap;
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final minX = insets.left + gutter;
    final minY = insets.top + gutter;
    final rightEdge = size.width - insets.right - gutter;
    final bottomEdge = size.height - insets.bottom - gutter;
    final maxX = math.max(minX, rightEdge - childSize.width);
    final maxY = math.max(minY, bottomEdge - childSize.height);
    Offset position(double x, double y) {
      final left = x.clamp(minX, maxX);
      final top = y.clamp(minY, maxY);
      final scale = pixelScale;
      if (scale == null) return Offset(left, top);
      return Offset(
        ((left * scale).round() / scale).clamp(minX, maxX),
        ((top * scale).round() / scale).clamp(minY, maxY),
      );
    }

    if (toRight || toLeft) {
      final onRight = anchor.right + gap;
      final onLeft = anchor.left - gap - childSize.width;
      final left = toLeft
          ? (onLeft >= minX ? onLeft : onRight)
          : (onRight + childSize.width <= rightEdge ? onRight : onLeft);
      return position(
        left,
        alignRight ? anchor.bottom - childSize.height : anchor.top,
      );
    }
    final double left =
        (alignRight ? anchor.right - childSize.width : anchor.left).clamp(
          minX,
          maxX,
        );
    if (centerVertically) {
      return position(left, anchor.center.dy - childSize.height / 2);
    }
    final below = anchor.bottom + gap;
    final upper = anchor.top - gap - childSize.height;
    final bottomFits = below + childSize.height <= bottomEdge;
    final upperFits = upper >= minY;
    final top = !flipVertically
        ? (above ? upper : below)
        : above
        ? (upperFits || !bottomFits ? upper : below)
        : (bottomFits ? below : upper);
    return position(left, top);
  }

  @override
  bool shouldRelayout(_PopupLayout old) =>
      anchor != old.anchor ||
      above != old.above ||
      alignRight != old.alignRight ||
      centerVertically != old.centerVertically ||
      toRight != old.toRight ||
      toLeft != old.toLeft ||
      gap != old.gap ||
      gutter != old.gutter ||
      flipVertically != old.flipVertically ||
      insets != old.insets ||
      pixelScale != old.pixelScale;
}
