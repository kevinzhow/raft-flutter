import 'package:flutter/widgets.dart';

/// Width of [span] laid out once on one line (or [maxLines]). The painter owns
/// a native paragraph, so it is disposed here rather than left to the GC.
double raftTextWidth(
  InlineSpan span, {
  TextDirection textDirection = TextDirection.ltr,
  TextScaler textScaler = TextScaler.noScaling,
  int? maxLines,
}) {
  final painter = TextPainter(
    text: span,
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: maxLines,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
