// Exact installed lucide-react 0.575.0 geometry (ISC).
// Source files: map-pin.js, ellipsis-vertical.js, video.js, archive.js.
// Reuse packages/raft_ui/LICENSE-LUCIDE; no replacement Material glyphs.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

enum SourceChannelFileGlyph { image, video, pdf, archive, other, jump, more }

class ChannelFileGlyph extends StatelessWidget {
  const ChannelFileGlyph(this.glyph, {super.key, this.size = 18, this.color});
  final SourceChannelFileGlyph glyph;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final ink =
        color ?? IconTheme.of(context).color ?? RaftTokens.of(context).strong;
    final shared = switch (glyph) {
      SourceChannelFileGlyph.image => RaftGlyph.image,
      SourceChannelFileGlyph.pdf => RaftGlyph.fileText,
      SourceChannelFileGlyph.other => RaftGlyph.file,
      _ => null,
    };
    return shared != null
        ? RaftIcon(shared, size: size, color: ink)
        : SizedBox.square(
            dimension: size,
            child: CustomPaint(painter: _FileGlyphPainter(glyph, ink)),
          );
  }
}

class _FileGlyphPainter extends CustomPainter {
  const _FileGlyphPainter(this.glyph, this.color);
  final SourceChannelFileGlyph glyph;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (glyph) {
      case SourceChannelFileGlyph.jump:
        canvas.drawPath(
          Path()
            ..moveTo(20, 10)
            ..cubicTo(20, 14.993, 14.461, 20.193, 12.601, 21.799)
            ..arcToPoint(
              const Offset(11.399, 21.799),
              radius: const Radius.circular(1),
            )
            ..cubicTo(9.539, 20.193, 4, 14.993, 4, 10)
            ..arcToPoint(
              const Offset(20, 10),
              radius: const Radius.circular(8),
            ),
          p,
        );
        canvas.drawCircle(const Offset(12, 10), 3, p);
      case SourceChannelFileGlyph.more:
        for (final y in [12.0, 5.0, 19.0]) {
          canvas.drawCircle(Offset(12, y), 1, p);
        }
      case SourceChannelFileGlyph.video:
        canvas.drawPath(
          Path()
            ..moveTo(16, 13)
            ..lineTo(21.223, 16.482)
            ..arcToPoint(
              const Offset(22, 16.066),
              radius: const Radius.circular(.5),
              clockwise: false,
            )
            ..lineTo(22, 7.87)
            ..arcToPoint(
              const Offset(21.248, 7.438),
              radius: const Radius.circular(.5),
              clockwise: false,
            )
            ..lineTo(16, 10.5),
          p,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2, 6, 14, 12),
            const Radius.circular(2),
          ),
          p,
        );
      case SourceChannelFileGlyph.archive:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2, 3, 20, 5),
            const Radius.circular(1),
          ),
          p,
        );
        canvas.drawPath(
          Path()
            ..moveTo(4, 8)
            ..lineTo(4, 19)
            ..arcToPoint(
              const Offset(6, 21),
              radius: const Radius.circular(2),
              clockwise: false,
            )
            ..lineTo(18, 21)
            ..arcToPoint(
              const Offset(20, 19),
              radius: const Radius.circular(2),
              clockwise: false,
            )
            ..lineTo(20, 8),
          p,
        );
        canvas.drawLine(const Offset(10, 12), const Offset(14, 12), p);
      case SourceChannelFileGlyph.image:
      case SourceChannelFileGlyph.pdf:
      case SourceChannelFileGlyph.other:
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FileGlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}
