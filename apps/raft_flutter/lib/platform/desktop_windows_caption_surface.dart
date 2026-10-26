import 'package:flutter/material.dart';

/// Windows caption paint is separate from Linux circles. The runner opts in
/// only after it extends the client frame and implements native hit testing.
class DesktopWindowsCaptionSurface extends StatelessWidget {
  const DesktopWindowsCaptionSurface({
    super.key,
    required this.name,
    required this.maximized,
    required this.foreground,
    required this.glyph,
    required this.highlighted,
    required this.pressed,
  });
  final String name;
  final bool maximized, highlighted, pressed;
  final Color foreground, glyph;
  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted || pressed
            ? foreground.withValues(alpha: pressed ? .25 : .2)
            : null,
      ),
      child: Center(
        child: CustomPaint(
          // ds-allow: native caption glyph bounds, separate from themed component metrics.
          size: const Size.square(10),
          painter: _WindowsGlyph(name, maximized, glyph),
        ),
      ),
    ),
  );
}

class _WindowsGlyph extends CustomPainter {
  const _WindowsGlyph(this.name, this.maximized, this.color);
  final String name;
  final bool maximized;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1; // ds-allow: native Windows caption glyph stroke.
    if (name == 'minimize') {
      canvas.drawLine(const Offset(0, 5), const Offset(10, 5), p);
    } else if (name == 'close') {
      canvas.drawLine(Offset.zero, const Offset(10, 10), p);
      canvas.drawLine(const Offset(10, 0), const Offset(0, 10), p);
    } else if (maximized) {
      canvas.drawPath(
        Path()
          ..moveTo(2, 0)
          ..lineTo(10, 0)
          ..lineTo(10, 8)
          ..lineTo(8, 8),
        p,
      );
      canvas.drawRect(const Rect.fromLTWH(0, 2, 8, 8), p);
    } else {
      canvas.drawRect(Offset.zero & size, p);
    }
  }

  @override
  bool shouldRepaint(_WindowsGlyph old) =>
      name != old.name || maximized != old.maximized || color != old.color;
}
