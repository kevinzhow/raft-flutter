import 'package:flutter/material.dart';

/// Exact pinned raft-ui ThreadIcon (18-unit viewport; mixed stroke/fill).
class RaftMessageThreadGlyph extends StatelessWidget {
  const RaftMessageThreadGlyph({super.key, this.size = 13, this.color});
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ThreadPainter(
          color ??
              IconTheme.of(context).color ??
              Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ),
  );
}

class _ThreadPainter extends CustomPainter {
  const _ThreadPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 18, size.height / 18);
    final outline = Path()
      ..moveTo(16.25, 5)
      ..lineTo(16.25, 4.25)
      ..cubicTo(16.25, 3.15, 15.35, 2.25, 14.25, 2.25)
      ..lineTo(3.75, 2.25)
      ..cubicTo(2.65, 2.25, 1.75, 3.15, 1.75, 4.25)
      ..lineTo(1.75, 11.25)
      ..cubicTo(1.75, 12.35, 2.65, 13.25, 3.75, 13.25)
      ..lineTo(5.75, 13.25)
      ..lineTo(5.75, 16.25)
      ..lineTo(7.5, 14.85);
    canvas.drawPath(
      outline,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final filled = Path()
      ..moveTo(8.75, 5.5)
      ..lineTo(15.5, 5.5)
      ..cubicTo(16.6, 5.5, 17.5, 6.4, 17.5, 7.5)
      ..lineTo(17.5, 12.25)
      ..cubicTo(17.5, 13.35, 16.6, 14.25, 15.5, 14.25)
      ..lineTo(14, 14.25)
      ..lineTo(14, 16.75)
      ..lineTo(10.75, 14.25)
      ..lineTo(8.75, 14.25)
      ..cubicTo(7.65, 14.25, 6.75, 13.35, 6.75, 12.25)
      ..lineTo(6.75, 7.5)
      ..cubicTo(6.75, 6.4, 7.65, 5.5, 8.75, 5.5)
      ..close();
    canvas.drawPath(filled, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ThreadPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Exact installed Lucide SmilePlus (24-unit viewport; two-unit round strokes).
class RaftMessageAddReactionGlyph extends StatelessWidget {
  const RaftMessageAddReactionGlyph({super.key, this.size = 13, this.color});
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ReactionPainter(
          color ??
              IconTheme.of(context).color ??
              Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ),
  );
}

class _ReactionPainter extends CustomPainter {
  const _ReactionPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(22, 11)
        ..lineTo(22, 12)
        ..arcToPoint(
          const Offset(13, 2),
          radius: const Radius.circular(10),
          largeArc: true,
        ),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(8, 14)
        ..cubicTo(8, 14, 9.5, 16, 12, 16)
        ..cubicTo(14.5, 16, 16, 14, 16, 14),
      paint,
    );
    canvas.drawLine(const Offset(9, 9), const Offset(9.01, 9), paint);
    canvas.drawLine(const Offset(15, 9), const Offset(15.01, 9), paint);
    canvas.drawLine(const Offset(16, 5), const Offset(22, 5), paint);
    canvas.drawLine(const Offset(19, 2), const Offset(19, 8), paint);
  }

  @override
  bool shouldRepaint(covariant _ReactionPainter oldDelegate) =>
      oldDelegate.color != color;
}
