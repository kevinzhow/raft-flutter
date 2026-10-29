import 'dart:math' as math;

import 'package:flutter/material.dart';

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
    this.toRight = false,
    this.gap = 4,
    this.collisionPadding = 5,
    this.snapToPixel = false,
  });
  final GlobalKey anchorKey;
  final Widget child;

  /// A portal's current anchor bounds in its overlay coordinate space.
  /// When supplied, placement uses the same delegate without re-measuring a
  /// different subtree or retaining the previous frame's bounds.
  final Rect? anchorRect;
  final Listenable? movement;
  final bool above, alignRight, toRight;
  final double gap, collisionPadding;

  /// floating-ui rounds the computed position to whole pixels.
  final bool snapToPixel;

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
        toRight: widget.toRight,
        gap: widget.gap,
        gutter: widget.collisionPadding,
        snap: widget.snapToPixel,
        insets: insets,
      ),
      child: SingleChildScrollView(child: widget.child),
    );
  }
}

class _PopupLayout extends SingleChildLayoutDelegate {
  const _PopupLayout(
    this.anchor, {
    required this.above,
    required this.alignRight,
    required this.toRight,
    required this.gap,
    required this.gutter,
    this.snap = false,
    required this.insets,
  });
  final bool snap;
  final Rect anchor;
  final bool above, alignRight, toRight;
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
        maxHeight: math.max(
          0,
          constraints.maxHeight - insets.vertical - gutter * 2,
        ),
      );

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
      return snap
          ? Offset(
              left.roundToDouble().clamp(minX, maxX),
              top.roundToDouble().clamp(minY, maxY),
            )
          : Offset(left, top);
    }

    if (toRight) {
      // LeftRail HelpMenu: PopoverContent side=right, align=end, offset8.
      final proposedLeft = anchor.right + gap;
      final left = proposedLeft + childSize.width <= rightEdge
          ? proposedLeft
          : anchor.left - gap - childSize.width;
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
    final below = anchor.bottom + gap;
    final upper = anchor.top - gap - childSize.height;
    final bottomFits = below + childSize.height <= bottomEdge;
    final upperFits = upper >= minY;
    final top = above
        ? (upperFits || !bottomFits ? upper : below)
        : (bottomFits ? below : upper);
    return position(left, top);
  }

  @override
  bool shouldRelayout(_PopupLayout old) =>
      anchor != old.anchor ||
      above != old.above ||
      alignRight != old.alignRight ||
      toRight != old.toRight ||
      gap != old.gap ||
      gutter != old.gutter ||
      insets != old.insets ||
      snap != old.snap;
}
