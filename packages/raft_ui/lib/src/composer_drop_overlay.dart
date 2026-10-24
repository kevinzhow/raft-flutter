// Presentation of the Web MessageInput file-drag overlay
// (packages/web/src/components/message/MessageInput.tsx, `isDraggingFiles`):
// shown only while an OS file drag is over the composer root. The app owns
// the platform drop target and decides when it is active.
import 'package:flutter/widgets.dart';

import 'raft/css_box.dart' show raftControlBorderPx;
import 'raft/ui_tokens.dart';
import 'tokens/tokens.dart' show RaftTypeScale;

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

  /// raft-ui 0.7 `composerDropOverlay`: `rounded-container border-[1.5px]
  /// border-dashed border-line-seam` over an opaque `info-soft` wash with the
  /// label (`text-callout font-semibold`) centred bare.
  Widget _buildRaft(BuildContext context, RaftTokens t) {
    final ui = t.ui;
    final width = raftControlBorderPx(context, 1.5);
    final radius = t.size('radius.container', fallback: 10);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(
          key: const ValueKey('composer-drop-overlay'),
          foregroundPainter: _DashedRoundedPainter(
            color: ui.lineSeam,
            width: width,
            radius: radius,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color.alphaBlend(ui['info-soft'], ui.layerCard),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Center(
              child: Text(
                raftText(context, label),
                textAlign: TextAlign.center,
                style: t.scale(
                  RaftTypeScale.callout,
                  weight: FontWeight.w600,
                  color: ui.foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (t.option('composerAttachment.style', or: 'recipe') == 'raft') {
      return _buildRaft(context, t);
    }
    final frame = t.accent;
    final fill = t.accentSoft.withValues(
      // Chromium quantises the `/50` alpha to 8 bits before blending:
      // measured one level darker than float blending on white.
      alpha: t.dark
          ? t.accentSoft.a * .5
          : (t.accentSoft.a * 255 * .5).ceilToDouble() / 255,
    );
    // `absolute inset-0` resolves against the composer root's padding box,
    // below its `border-t` (2px Brutal, 1px Elegant).
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.only(top: t.border),
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
                    color: t.panel,
                    border: Border.all(
                      color: t.colors['line-strong']!,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
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
                      color: t.strong,
                    ),
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
    // Blink dashes a border side as 3*width dashes with a gap adjusted so
    // the side starts and ends on a dash.
    final dash = width * 3, inset = width / 2;
    void edge(Offset a, Offset b) {
      final length = (b - a).distance;
      if (length <= 0) return;
      final dir = (b - a) / length;
      final count = ((length + width * 2) / (dash + width * 2)).floor();
      final gap = count > 1 ? (length - count * dash) / (count - 1) : 0.0;
      for (var i = 0; i < count; i++) {
        final from = i * (dash + gap);
        canvas.drawLine(a + dir * from, a + dir * (from + dash), paint);
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

/// A dashed rounded border: dashes 3x the width along the whole outline, the gap
/// adjusted so the path closes on a dash.
class _DashedRoundedPainter extends CustomPainter {
  _DashedRoundedPainter({
    required this.color,
    required this.width,
    required this.radius,
  });
  final Color color;
  final double width, radius;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    ).deflate(width / 2);
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius - width / 2)),
      );
    final dash = width * 3;
    for (final metric in path.computeMetrics()) {
      final count = (metric.length / (dash * 2)).round().clamp(1, 100000);
      final step = metric.length / count;
      for (var i = 0; i < count; i++) {
        canvas.drawPath(metric.extractPath(i * step, i * step + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRoundedPainter old) =>
      old.color != color || old.width != width || old.radius != radius;
}
