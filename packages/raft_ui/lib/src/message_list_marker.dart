import 'package:flutter/material.dart';

/// CSS outside-list marker metrics used by the original Chromium renderer.
/// Provenance: Blink ListMarker::InlineMarginsForOutside and
/// RelativeSymbolMarkerRect (list_marker.cc), plus pinned Web list-disc / pl-5.
/// These depend on font ascent and indentation, never fixture coordinates.
abstract final class MessageListMarkerPrimitive {
  static const outsidePadding = 7.0;
  static Rect disc({
    required double indent,
    required double ascent,
    required double baseline,
  }) {
    final integerAscent = ascent.round();
    final twoThirds = integerAscent * 2 ~/ 3;
    final diameter = ((twoThirds + 1) ~/ 2).toDouble();
    return Rect.fromLTWH(
      indent - ascent * 2 / 3 - outsidePadding,
      baseline - integerAscent + (3 * (integerAscent - twoThirds) ~/ 2),
      diameter,
      diameter,
    );
  }
}

/// Source list-disc is a painted circle, rather than a font's U+2022 glyph.
/// The hidden text supplies the same baseline/line height as list content.
class RaftMarkdownListMarker extends StatelessWidget {
  const RaftMarkdownListMarker({
    super.key,
    required this.style,
    required this.indent,
    this.orderedIndex,
  });
  final TextStyle style;
  final double indent;
  final int? orderedIndex;

  @override
  Widget build(BuildContext context) {
    if (orderedIndex != null) {
      // The CSS decimal counter includes its suffix space and aligns its end
      // immediately before list content; long ordinals may extend the gutter.
      return Text(
        '${orderedIndex! + 1}. ',
        style: style,
        textAlign: TextAlign.right,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
      );
    }
    final painter = TextPainter(
      text: TextSpan(text: 'M', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final metrics = painter.computeLineMetrics().single;
    final rect = MessageListMarkerPrimitive.disc(
      indent: indent,
      ascent: metrics.unscaledAscent,
      baseline: metrics.baseline,
    );
    painter.dispose();
    return Semantics(
      label: '•',
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: _DiscPainter(rect, style.color ?? DefaultTextStyle.of(context).style.color ?? Colors.black),
          child: Opacity(opacity: 0, child: Text('•', style: style)),
        ),
      ),
    );
  }
}

class _DiscPainter extends CustomPainter {
  const _DiscPainter(this.rect, this.color);
  final Rect rect;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawOval(rect, Paint()..color = color);
  @override
  bool shouldRepaint(_DiscPainter oldDelegate) => oldDelegate.rect != rect || oldDelegate.color != color;
}
