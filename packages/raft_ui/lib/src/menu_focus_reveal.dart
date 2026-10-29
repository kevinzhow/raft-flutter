import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reveals one menu row only in the explicitly supplied local scroll position.
/// Popup adapters retain focus, scheduling, lifecycle and placement ownership.
void revealRaftMenuRow({
  required RenderObject target,
  required ScrollPosition position,
  double paddingStart = 0,
  double paddingEnd = 0,
}) {
  if (!target.attached ||
      !position.hasPixels ||
      !position.hasContentDimensions) {
    return;
  }
  final viewport = RenderAbstractViewport.maybeOf(target);
  if (viewport == null) return;
  final start = viewport.getOffsetToReveal(target, 0).offset - paddingStart;
  final end = viewport.getOffsetToReveal(target, 1).offset + paddingEnd;
  final next = position.pixels > start
      ? start
      : position.pixels < end
      ? end
      : position.pixels;
  final bounded = next.clamp(
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  if (bounded != position.pixels) position.jumpTo(bounded);
}
