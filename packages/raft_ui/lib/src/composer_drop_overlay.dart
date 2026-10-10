// Presentation of the Web MessageInput file-drag overlay
// (packages/web/src/components/message/MessageInput.tsx, `isDraggingFiles`):
// shown only while an OS file drag is over the composer root. The app owns
// the platform drop target and decides when it is active.
import 'package:flutter/widgets.dart';

import 'localization.dart';
import 'theme.dart';

/// `absolute inset-0 z-30 flex items-center justify-center border-2
/// border-dashed border-accent-strong bg-accent-soft/50` (Brutal:
/// `border-brutal-pink bg-brutal-pink/15`) with a centered label chip
/// `rounded-md border border-line-strong bg-layer-panel px-3 py-1.5 text-sm
/// font-bold text-foreground-strong shadow-raft-sm` (Brutal: square, 2px
/// black border, white fill, black text, brutal shadow).
///
/// Decorative (`aria-hidden`): it never takes pointer input, so the drop
/// target beneath keeps receiving the drag.
class RaftComposerDropOverlay extends StatelessWidget {
  const RaftComposerDropOverlay({
    super.key,
    this.label = 'Drop files to attach',
  });
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final pink = t.product.brutalPink;
    final frame = t.brutal ? pink : t.accent;
    final fill = t.brutal
        ? pink.withValues(alpha: .15)
        : t.accentSoft.withValues(alpha: t.accentSoft.a * .5);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(
          key: const ValueKey('composer-drop-overlay'),
          foregroundPainter: _DashedFramePainter(color: frame, width: 2),
          child: ColoredBox(
            color: fill,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: t.brutal ? const Color(0xffffffff) : t.panel,
                  border: Border.all(
                    color: t.brutal
                        ? const Color(0xff000000)
                        : t.colors['line-strong']!,
                    width: t.brutal ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(t.brutal ? 0 : 6),
                  boxShadow: t.shadows,
                ),
                child: Text(
                  raftText(context, label),
                  style: TextStyle(
                    fontFamily: t.bodyFont,
                    fontFamilyFallback: t.fontFallback,
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w700,
                    color: t.brutal ? const Color(0xff000000) : t.strong,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedFramePainter extends CustomPainter {
  _DashedFramePainter({required this.color, required this.width});
  final Color color;
  final double width;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    // CSS dashed: dash length = 2 * border width.
    final dash = width * 2, inset = width / 2;
    void edge(Offset a, Offset b) {
      final length = (b - a).distance;
      if (length <= 0) return;
      final dir = (b - a) / length;
      for (double d = 0; d < length; d += dash * 2) {
        canvas.drawLine(
          a + dir * d,
          a + dir * (d + dash).clamp(0, length),
          paint,
        );
      }
    }

    final r = Rect.fromLTWH(
      inset,
      inset,
      size.width - width,
      size.height - width,
    );
    edge(r.topLeft, r.topRight);
    edge(r.topRight, r.bottomRight);
    edge(r.bottomRight, r.bottomLeft);
    edge(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_DashedFramePainter old) =>
      old.color != color || old.width != width;
}
