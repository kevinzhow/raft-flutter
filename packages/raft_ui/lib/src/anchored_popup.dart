import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Viewport collision placement shared by authored dropdown consumers.
/// InlineBadgeEditor.tsx measures the natural popup, clamps x to an 8px gutter,
/// and flips below→above when its bottom would overflow; scrolling remeasures.
/// The popup keeps its natural size until the visual viewport requires a cap.
class RaftAnchoredPopup extends StatefulWidget {
  const RaftAnchoredPopup({
    super.key,
    required this.anchorKey,
    required this.child,
    this.movement,
    this.above = false,
    this.alignRight = false,
    this.gap = 4,
    this.collisionPadding = 5,
  });
  final GlobalKey anchorKey;
  final Widget child;
  final Listenable? movement;
  final bool above, alignRight;
  final double gap, collisionPadding;

  @override
  State<RaftAnchoredPopup> createState() => _RaftAnchoredPopupState();
}

class _RaftAnchoredPopupState extends State<RaftAnchoredPopup> {
  Rect? anchor;
  bool queued = false;

  @override
  void initState() {
    super.initState();
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
    widget.movement?.removeListener(refreshAfterLayout);
    super.dispose();
  }

  Rect? readAnchor() {
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
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    final rect = anchor ?? readAnchor();
    if (rect == null) return const SizedBox.shrink();
    return CustomSingleChildLayout(
      delegate: _PopupLayout(
        rect,
        above: widget.above,
        alignRight: widget.alignRight,
        gap: widget.gap,
        gutter: widget.collisionPadding,
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
    required this.gap,
    required this.gutter,
  });
  final Rect anchor;
  final bool above, alignRight;
  final double gap;
  final double gutter;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.max(0, constraints.maxWidth - gutter * 2),
        maxHeight: math.max(0, constraints.maxHeight - gutter * 2),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final right = math.max(gutter, size.width - gutter - childSize.width);
    final left = (alignRight ? anchor.right - childSize.width : anchor.left)
        .clamp(gutter, right);
    final below = anchor.bottom + gap;
    final upper = anchor.top - gap - childSize.height;
    final bottomFits = below + childSize.height <= size.height - gutter;
    final upperFits = upper >= gutter;
    final top = above
        ? (upperFits || !bottomFits ? upper : below)
        : (bottomFits ? below : upper);
    return Offset(
      left,
      top.clamp(
        gutter,
        math.max(gutter, size.height - gutter - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_PopupLayout old) =>
      anchor != old.anchor ||
      above != old.above ||
      alignRight != old.alignRight ||
      gap != old.gap ||
      gutter != old.gutter;
}
