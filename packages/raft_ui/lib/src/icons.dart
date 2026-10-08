// Lucide glyph rendering. Geometry is generated (glyphs.g.dart, tool/gen-glyphs)
// from the pinned lucide-react builds the Web renders; see packages/raft_ui/LICENSE-LUCIDE.
import 'package:flutter/material.dart';

part 'glyphs.g.dart';
part 'reaction_sprite.dart';

/// A Lucide icon drawn like lucide-react's `<svg>`: 24-unit viewBox scaled to
/// [size], `stroke="currentColor"`, round caps and joins, `fill="none"` unless
/// [filled] (Web `fill="currentColor"`) or the node itself is filled.
///
/// [strokeWidth] is in viewBox units, so it scales with [size] exactly like the
/// Web default; with [absoluteStrokeWidth] it is in logical pixels instead
/// (lucide `absoluteStrokeWidth`: strokeWidth * 24 / size).
class RaftIcon extends StatelessWidget {
  const RaftIcon(
    this.glyph, {
    super.key,
    this.size = 18,
    this.color,
    this.strokeWidth = 2,
    this.absoluteStrokeWidth = false,
    this.filled,
    this.semanticLabel,
  });
  final RaftGlyph glyph;
  final double size, strokeWidth;
  final bool absoluteStrokeWidth;

  /// Overrides [RaftGlyph.filled] (whole-icon `fill="currentColor"`).
  final bool? filled;
  final Color? color;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    excludeSemantics: true,
    child: Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: RaftGlyphPainter(
            glyph,
            color:
                color ??
                IconTheme.of(context).color ??
                Theme.of(context).colorScheme.onSurface,
            strokeWidth: absoluteStrokeWidth
                ? strokeWidth * 24 / size
                : strokeWidth,
            filled: filled ?? glyph.filled,
          ),
        ),
      ),
    ),
  );
}

/// Paints one [RaftGlyph] into the painter's size (viewBox 0 0 24 24).
///
/// Each SVG element is painted on its own (fill, then stroke), as the browser
/// does, so overlapping elements composite the same way with translucent colours.
class RaftGlyphPainter extends CustomPainter {
  RaftGlyphPainter(
    RaftGlyph this.glyph, {
    required this.color,
    this.strokeWidth = 2,
    this.filled = false,
  }) : _nodes = glyph._nodes;

  /// Paints raw lucide `iconNode` elements (`[tag, attributes]`, SVG attribute
  /// names and string values) through the same element code as generated
  /// glyphs. Used by the glyph parity harness to cover element types the
  /// generated set lacks; app code uses [RaftGlyph]s.
  @visibleForTesting
  RaftGlyphPainter.debugNodes(
    List<(String, Map<String, String>)> nodes, {
    required this.color,
    this.strokeWidth = 2,
    this.filled = false,
  }) : glyph = null,
       _nodes = [for (final (tag, a) in nodes) _LucideNode.fromSvg(tag, a)];

  /// Null only for [RaftGlyphPainter.debugNodes].
  final RaftGlyph? glyph;
  final List<_LucideNode> _nodes;
  final Color color;

  /// Stroke width in viewBox units.
  final double strokeWidth;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final node in _nodes) {
      final path = node.path;
      if (filled || node.fill) canvas.drawPath(path, fill);
      if (strokeWidth > 0) canvas.drawPath(path, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(RaftGlyphPainter old) =>
      old.glyph != glyph ||
      !identical(old._nodes, _nodes) ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.filled != filled;
}

enum _LucideKind { path, circle, ellipse, rect, line, polyline, polygon }

/// One element of a Lucide `iconNode`. [values] follow SVG attribute order:
/// circle cx cy r; ellipse cx cy rx ry; rect x y width height rx ry (resolved
/// by the generator); line x1 y1 x2 y2; polyline/polygon the point list.
class _LucideNode {
  const _LucideNode(this.kind, this.values, {this.d = '', this.fill = false});
  const _LucideNode.path(this.d)
    : kind = _LucideKind.path,
      values = const [],
      fill = false;
  /// Mirrors tool/gen-glyphs `dart_node` (SVG attribute defaults, rect auto radii).
  factory _LucideNode.fromSvg(String tag, Map<String, String> a) {
    double n(String k) => double.parse(a[k] ?? '0');
    final fill = a['fill'] == 'currentColor';
    final kind = _LucideKind.values.byName(tag);
    final values = switch (kind) {
      _LucideKind.path => const <double>[],
      _LucideKind.circle => [n('cx'), n('cy'), n('r')],
      _LucideKind.ellipse => [n('cx'), n('cy'), n('rx'), n('ry')],
      _LucideKind.rect => [
        n('x'),
        n('y'),
        n('width'),
        n('height'),
        double.parse(a['rx'] ?? a['ry'] ?? '0'),
        double.parse(a['ry'] ?? a['rx'] ?? '0'),
      ],
      _LucideKind.line => [n('x1'), n('y1'), n('x2'), n('y2')],
      _LucideKind.polyline || _LucideKind.polygon => [
        for (final m in RegExp(
          r'[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?',
        ).allMatches(a['points']!))
          double.parse(m[0]!),
      ],
    };
    return _LucideNode(kind, values, d: a['d'] ?? '', fill: fill);
  }

  final _LucideKind kind;
  final List<double> values;
  final String d;

  /// Element-level `fill="currentColor"`.
  final bool fill;

  static final _cache = Expando<Path>('lucide path');
  Path get path => _cache[this] ??= _build();

  Path _build() {
    final v = values;
    switch (kind) {
      case _LucideKind.path:
        return _svgPath(d);
      case _LucideKind.circle:
        return Path()
          ..addOval(Rect.fromCircle(center: Offset(v[0], v[1]), radius: v[2]));
      case _LucideKind.ellipse:
        return Path()
          ..addOval(
            Rect.fromCenter(
              center: Offset(v[0], v[1]),
              width: v[2] * 2,
              height: v[3] * 2,
            ),
          );
      case _LucideKind.rect:
        // SVG clamps each radius to half the matching side.
        final rect = Rect.fromLTWH(v[0], v[1], v[2], v[3]);
        final rx = v[4].clamp(0.0, v[2] / 2), ry = v[5].clamp(0.0, v[3] / 2);
        return Path()
          ..addRRect(RRect.fromRectXY(rect, rx.toDouble(), ry.toDouble()));
      case _LucideKind.line:
        return Path()
          ..moveTo(v[0], v[1])
          ..lineTo(v[2], v[3]);
      case _LucideKind.polyline:
      case _LucideKind.polygon:
        final path = Path()..moveTo(v[0], v[1]);
        for (var i = 2; i + 1 < v.length; i += 2) {
          path.lineTo(v[i], v[i + 1]);
        }
        if (kind == _LucideKind.polygon) path.close();
        return path;
    }
  }
}

/// SVG path data (SVG 1.1 grammar, all commands incl. elliptical arcs) to a
/// [Path]. Arcs go through [Path.arcToPoint], which applies the SVG
/// out-of-range radius correction (F.6.6).
Path _svgPath(String source) {
  final path = Path();
  var i = 0;
  void skip() {
    while (i < source.length && ' \t\r\n,'.contains(source[i])) {
      i++;
    }
  }

  bool atNumber() {
    skip();
    return i < source.length && '+-.0123456789'.contains(source[i]);
  }

  final numberPattern = RegExp(r'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');
  double number() {
    skip();
    final m = numberPattern.matchAsPrefix(source, i);
    if (m == null) throw FormatException('Expected number', source, i);
    i = m.end;
    return double.parse(m[0]!);
  }

  bool flag() {
    skip();
    final c = source[i++];
    if (c != '0' && c != '1') throw FormatException('Bad arc flag', source, i);
    return c == '1';
  }

  var current = Offset.zero, start = Offset.zero;
  Offset? lastCubic, lastQuad;
  var command = '';
  while (true) {
    skip();
    if (i >= source.length) break;
    if (RegExp('[a-zA-Z]').hasMatch(source[i])) {
      command = source[i++];
    } else if (command.isEmpty) {
      throw FormatException('Path data must start with a command', source, i);
    }
    final rel = command == command.toLowerCase();
    Offset pt() {
      final p = Offset(number(), number());
      return rel ? current + p : p;
    }

    Offset? cubic, quad;
    switch (command.toUpperCase()) {
      case 'M':
        current = start = pt();
        path.moveTo(current.dx, current.dy);
        // Further coordinate pairs are implicit linetos.
        command = rel ? 'l' : 'L';
      case 'L':
        current = pt();
        path.lineTo(current.dx, current.dy);
      case 'H':
        current = Offset(number() + (rel ? current.dx : 0), current.dy);
        path.lineTo(current.dx, current.dy);
      case 'V':
        current = Offset(current.dx, number() + (rel ? current.dy : 0));
        path.lineTo(current.dx, current.dy);
      case 'C':
        final c1 = pt(), c2 = pt(), end = pt();
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        current = end;
        cubic = c2;
      case 'S':
        final c1 = lastCubic == null ? current : current * 2 - lastCubic;
        final c2 = pt(), end = pt();
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        current = end;
        cubic = c2;
      case 'Q':
        final c = pt(), end = pt();
        path.quadraticBezierTo(c.dx, c.dy, end.dx, end.dy);
        current = end;
        quad = c;
      case 'T':
        final c = lastQuad == null ? current : current * 2 - lastQuad;
        final end = pt();
        path.quadraticBezierTo(c.dx, c.dy, end.dx, end.dy);
        current = end;
        quad = c;
      case 'A':
        final rx = number().abs(), ry = number().abs(), rotation = number();
        final large = flag(), sweep = flag();
        final end = pt();
        if (rx == 0 || ry == 0) {
          path.lineTo(end.dx, end.dy);
        } else {
          path.arcToPoint(
            end,
            radius: Radius.elliptical(rx, ry),
            rotation: rotation,
            largeArc: large,
            clockwise: sweep,
          );
        }
        current = end;
      case 'Z':
        path.close();
        current = start;
        // A command letter must follow Z.
        command = '';
        if (atNumber()) {
          throw FormatException('Number after Z', source, i);
        }
      default:
        throw FormatException('Unsupported path command $command', source, i);
    }
    lastCubic = cubic;
    lastQuad = quad;
  }
  return path;
}

/// Compatibility bridge for existing app call sites. Known symbols use the
/// same Lucide geometry as Web; unsupported app-specific icons remain explicit.
class RaftSymbol extends StatelessWidget {
  const RaftSymbol(this.icon, {super.key, this.size = 18, this.color});
  final IconData icon;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final glyph = raftGlyphForMaterialIcon(icon);
    return glyph == null
        ? Icon(icon, size: size, color: color)
        : RaftIcon(glyph, size: size, color: color);
  }
}

RaftGlyph? raftGlyphForMaterialIcon(IconData icon) => {
  Icons.send: RaftGlyph.send,
  Icons.send_outlined: RaftGlyph.send,
  Icons.arrow_upward: RaftGlyph.arrowUp,
  Icons.add: RaftGlyph.plus,
  Icons.attach_file: RaftGlyph.paperclip,
  Icons.image: RaftGlyph.image,
  Icons.image_outlined: RaftGlyph.image,
  Icons.chevron_right: RaftGlyph.chevronRight,
  Icons.chevron_left: RaftGlyph.chevronLeft,
  Icons.keyboard_arrow_down: RaftGlyph.chevronDown,
  Icons.expand_more: RaftGlyph.chevronDown,
  Icons.check: RaftGlyph.check,
  Icons.close: RaftGlyph.x,
  Icons.more_horiz: RaftGlyph.ellipsis,
  Icons.more_vert: RaftGlyph.ellipsis,
  Icons.forum_outlined: RaftGlyph.messageSquare,
  Icons.chat_bubble_outline: RaftGlyph.messageSquare,
  Icons.circle_outlined: RaftGlyph.circle,
  Icons.check_circle_outline: RaftGlyph.circleCheck,
  Icons.reply: RaftGlyph.reply,
  Icons.description_outlined: RaftGlyph.fileText,
  Icons.delete_outline: RaftGlyph.trash2,
  Icons.download: RaftGlyph.download,
  Icons.copy: RaftGlyph.copy,
  Icons.visibility: RaftGlyph.eye,
  Icons.visibility_outlined: RaftGlyph.eye,
  Icons.visibility_off: RaftGlyph.eyeOff,
  Icons.search: RaftGlyph.search,
  Icons.settings: RaftGlyph.settings,
  Icons.settings_outlined: RaftGlyph.settings,
  Icons.person_outline: RaftGlyph.user,
  Icons.people_outline: RaftGlyph.users,
  Icons.smart_toy_outlined: RaftGlyph.bot,
  Icons.computer: RaftGlyph.monitor,
  Icons.bookmark_outline: RaftGlyph.bookmark,
  Icons.tag: RaftGlyph.hash,
  Icons.lock_outline: RaftGlyph.lock,
  Icons.link: RaftGlyph.link,
  Icons.menu: RaftGlyph.menu,
  Icons.open_in_new: RaftGlyph.externalLink,
  Icons.refresh: RaftGlyph.refreshCw,
  Icons.arrow_back: RaftGlyph.arrowLeft,
  Icons.play_arrow_outlined: RaftGlyph.play,
  Icons.pause: RaftGlyph.pause,
  Icons.block: RaftGlyph.ban,
  Icons.done_all: RaftGlyph.checkCheck,
}[icon];
