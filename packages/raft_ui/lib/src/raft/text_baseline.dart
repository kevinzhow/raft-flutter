// Where Blink puts a text baseline, so a Flutter label lines up with the raft-ui reference.
//
// Blink rounds a font's ascent and descent to whole pixels individually (and, with subpixel positioning, borrows one
// pixel from the ascent when the descent rounded down), then centres that content area in the line box. Flutter uses the
// unrounded metrics. The two differ by up to a pixel; Space Mono at 12px sits 1px lower in Flutter.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Ascent and descent of a bundled face in em (hhea, unitsPerEm 1000).
enum RaftFontMetrics {
  spaceGrotesk(0.984, 0.292),
  spaceMono(1.120, 0.361);

  const RaftFontMetrics(this.ascent, this.descent);
  final double ascent, descent;
}

/// Baseline distance from the top of a [lineHeight] line box, as Blink lays it out.
double raftBlinkBaseline(
  RaftFontMetrics font,
  double fontSize,
  double lineHeight,
) {
  var ascent = (font.ascent * fontSize).roundToDouble();
  var descent = (font.descent * fontSize).roundToDouble();
  if (descent < font.descent * fontSize && ascent > 1) {
    descent += 1;
    ascent -= 1;
  }
  return (lineHeight - (ascent + descent)) / 2 + ascent;
}

/// Baseline distance in Flutter (CSS half-leading, `leadingDistribution: even`, unrounded metrics).
double raftFlutterBaseline(
  RaftFontMetrics font,
  double fontSize,
  double lineHeight,
) =>
    (lineHeight - (font.ascent + font.descent) * fontSize) / 2 +
    font.ascent * fontSize;

/// Vertical paint offset that moves a Flutter label onto Blink's baseline (negative: up).
double raftBaselineShift(
  RaftFontMetrics font,
  double fontSize,
  double lineHeight,
) =>
    raftBlinkBaseline(font, fontSize, lineHeight) -
    raftFlutterBaseline(font, fontSize, lineHeight);

/// Paints [child] [dy] px lower (negative: higher) without touching layout, hit testing or the child's reported
/// geometry (so a label's line box still centres in its control; only the ink moves onto Blink's baseline).
class RaftBaselineShift extends SingleChildRenderObjectWidget {
  const RaftBaselineShift({super.key, required this.dy, super.child});
  final double dy;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBaselineShift(dy);

  @override
  void updateRenderObject(BuildContext context, _RenderBaselineShift object) {
    object.dy = dy;
  }
}

class _RenderBaselineShift extends RenderProxyBox {
  _RenderBaselineShift(this._dy);
  double _dy;
  set dy(double value) {
    if (_dy == value) return;
    _dy = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child != null) context.paintChild(child, offset + Offset(0, _dy));
  }
}
