import 'package:flutter/widgets.dart';
import 'package:path_parsing/path_parsing.dart';

part 'brand_marks.g.dart';

/// Vector data of one Web brand SVG (see tool/gen-brand/gen.py).
@immutable
class RaftBrandSvg {
  const RaftBrandSvg({
    required this.width,
    required this.height,
    required this.paths,
  });
  final double width, height;
  final List<(int, String)> paths;
}

/// Brand marks the Web client renders as `<img>` SVG assets.
enum RaftBrandMarkKind {
  /// public/brand/raft-icon.svg (AuthBrandIntro, `size-9`).
  icon(_raftIcon),

  /// public/brand/raft-logo.svg (RaftBrandLockup).
  logo(_raftLogo),

  /// src/assets/icons/provider_*.svg (SocialProviderButton, `size-5`).
  google(_providerGoogle),
  github(_providerGithub),
  apple(_providerApple);

  const RaftBrandMarkKind(this.svg);
  final RaftBrandSvg svg;
}

/// Paints a brand SVG with its own fills, like the Web `<img>`. [height] sets
/// the rendered height; width follows the SVG aspect ratio (`w-auto`) unless
/// [width] is given. [invert] mirrors the Web `dark:invert` filter.
class RaftBrandMark extends StatelessWidget {
  const RaftBrandMark(
    this.kind, {
    super.key,
    required this.height,
    this.width,
    this.invert = false,
  });
  final RaftBrandMarkKind kind;
  final double height;
  final double? width;
  final bool invert;

  @override
  Widget build(BuildContext context) {
    final svg = kind.svg;
    return ExcludeSemantics(
      child: SizedBox(
        width: width ?? height * svg.width / svg.height,
        height: height,
        child: CustomPaint(painter: _BrandPainter(svg, invert)),
      ),
    );
  }
}

final Map<RaftBrandSvg, List<(Color, Path)>> _parsed = {};

List<(Color, Path)> _paths(RaftBrandSvg svg) => _parsed.putIfAbsent(svg, () {
  return [
    for (final (argb, d) in svg.paths)
      (Color(argb), _SvgPathProxy.parse(d)),
  ];
});

class _SvgPathProxy implements PathProxy {
  final Path path = Path();
  static Path parse(String d) {
    final proxy = _SvgPathProxy();
    writeSvgPathDataToPath(d, proxy);
    return proxy.path;
  }

  @override
  void close() => path.close();
  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);
  @override
  void lineTo(double x, double y) => path.lineTo(x, y);
  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
}

class _BrandPainter extends CustomPainter {
  const _BrandPainter(this.svg, this.invert);
  final RaftBrandSvg svg;
  final bool invert;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // `<img>` scales the viewBox to the box (preserveAspectRatio meet).
    final scale = (size.width / svg.width) < (size.height / svg.height)
        ? size.width / svg.width
        : size.height / svg.height;
    canvas.translate(
      (size.width - svg.width * scale) / 2,
      (size.height - svg.height * scale) / 2,
    );
    canvas.scale(scale);
    for (final (color, path) in _paths(svg)) {
      final c = invert
          ? Color.from(
              alpha: color.a,
              red: 1 - color.r,
              green: 1 - color.g,
              blue: 1 - color.b,
            )
          : color;
      canvas.drawPath(path, Paint()..color = c..isAntiAlias = true);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BrandPainter old) => old.svg != svg || old.invert != invert;
}
