import 'package:flutter/widgets.dart';

import 'icons.dart';
import 'localization.dart';
import 'tooltip.dart';

/// A small globe after the server's name when its public page is live (Web
/// `PublicPageGlobe`): the same Globe as Public access in settings. Screen
/// readers get the meaning as text, pointer users as a tooltip.
class RaftPublicPageGlobe extends StatelessWidget {
  const RaftPublicPageGlobe({
    super.key,
    required this.live,
    this.size = 13,
    this.color,
  });
  final bool live;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!live) return const SizedBox.shrink();
    final label = raftText(
      context,
      'Public: anyone can read its public channels without signing in',
    );
    return RaftTooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        label: label,
        excludeSemantics: true,
        child: RaftIcon(
          RaftGlyph.globe,
          key: const ValueKey('public-page-globe'),
          size: size,
          color: color,
        ),
      ),
    );
  }
}

/// A channel whose messages anyone can read on the public page (Web
/// `ChannelKindIcon onPublicPage`): the # carries a small globe, one glyph.
class RaftPublicChannelMark extends StatelessWidget {
  const RaftPublicChannelMark({
    super.key,
    this.size = 14,
    this.color,
    this.tooltip = true,
  });
  final double size;
  final Color? color;

  /// Native tooltip like Web's `title`; off where a row already owns hover.
  final bool tooltip;

  @override
  Widget build(BuildContext context) {
    final label = raftText(
      context,
      'Anyone can read this channel on the public page',
    );
    final glyph = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        key: const ValueKey('public-channel-mark'),
        painter: RaftHashGlobePainter(
          color:
              color ?? IconTheme.of(context).color ?? const Color(0xff000000),
        ),
      ),
    );
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: tooltip
          ? RaftTooltip(
              message: label,
              excludeFromSemantics: true,
              child: glyph,
            )
          : glyph,
    );
  }
}

/// `HashGlobeIcon` of Web channelKindIcon.tsx: lucide's # with its bottom-right
/// cell given over to a larger Globe (circle, meridian, equator); the hash
/// strokes stop short of it. Every stroke is 2 units of a 24 unit box.
class RaftHashGlobePainter extends CustomPainter {
  const RaftHashGlobePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    line(2.5, 8, 15, 8);
    line(2.5, 14, 8, 14);
    line(8.5, 2.5, 7, 17);
    line(13.5, 2.5, 13, 8);
    canvas.drawCircle(const Offset(16.5, 16.5), 6.5, paint);
    // M16.5 10a9 9 0 0 0 0 13 9 9 0 0 0 0-13
    canvas.drawPath(
      Path()
        ..moveTo(16.5, 10)
        ..arcToPoint(
          const Offset(16.5, 23),
          radius: const Radius.circular(9),
          clockwise: false,
        )
        ..arcToPoint(
          const Offset(16.5, 10),
          radius: const Radius.circular(9),
          clockwise: false,
        ),
      paint,
    );
    line(10, 16.5, 23, 16.5);
  }

  @override
  bool shouldRepaint(RaftHashGlobePainter old) => old.color != color;
}
