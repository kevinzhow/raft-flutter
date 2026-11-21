import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

/// Paints [child] at a device-pixel-aligned position.
///
/// Blink keeps fractional layout (a `leading-[16.5px]` line, `items-center`
/// half pixels) but snaps every box edge to a physical pixel when it paints;
/// Flutter paints the fraction, anti-aliasing borders into two grey rows.
/// This wrapper reproduces the snap for a block: the paint origin moves to
/// `round(global * dpr) / dpr` (round half up), the layout is untouched.
class RaftCssPixelSnap extends SingleChildRenderObjectWidget {
  const RaftCssPixelSnap({super.key, super.child, this.devicePixelRatio});

  final double? devicePixelRatio;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCssPixelSnap(
    devicePixelRatio ?? MediaQuery.devicePixelRatioOf(context),
  );

  @override
  void updateRenderObject(BuildContext context, _RenderCssPixelSnap object) {
    object.devicePixelRatio =
        devicePixelRatio ?? MediaQuery.devicePixelRatioOf(context);
  }
}

class _RenderCssPixelSnap extends RenderProxyBox {
  _RenderCssPixelSnap(this._dpr);
  double _dpr;
  set devicePixelRatio(double value) {
    if (_dpr == value) return;
    _dpr = value;
    markNeedsPaint();
  }

  double _snap(double v) => ((v * _dpr + .5).floorToDouble()) / _dpr;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final global = localToGlobal(Offset.zero);
    // A panel mid-transition (scaled to nothing) has no finite position.
    if (!global.dx.isFinite || !global.dy.isFinite) {
      context.paintChild(child, offset);
      return;
    }
    final shift = Offset(
      _snap(global.dx) - global.dx,
      _snap(global.dy) - global.dy,
    );
    context.paintChild(child, offset + shift);
  }
}

/// A bordered box whose four edges are snapped to physical pixels when it
/// paints (Blink snaps `left`/`right`/`top`/`bottom` of every box separately,
/// so a 144.27px wide chip at x=186.27 paints from 186 to 331). The layout is
/// untouched: give [child] padding that already includes [borderWidth].
class RaftCssSnappedBox extends SingleChildRenderObjectWidget {
  const RaftCssSnappedBox({
    super.key,
    super.child,
    required this.color,
    required this.borderColor,
    required this.borderWidth,
    this.radius = 0,
    this.shadows = const [],
  });
  final Color color, borderColor;
  final double borderWidth, radius;
  final List<BoxShadow> shadows;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSnappedBox(
    MediaQuery.devicePixelRatioOf(context),
    color,
    borderColor,
    borderWidth,
    radius,
    shadows,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderSnappedBox object) {
    object
      ..dpr = MediaQuery.devicePixelRatioOf(context)
      ..color = color
      ..borderColor = borderColor
      ..borderWidth = borderWidth
      ..radius = radius
      ..shadows = shadows;
  }
}

class _RenderSnappedBox extends RenderProxyBox {
  _RenderSnappedBox(
    this.dpr,
    this.color,
    this.borderColor,
    this.borderWidth,
    this.radius,
    this.shadows,
  );
  double dpr, borderWidth, radius;
  Color color, borderColor;
  List<BoxShadow> shadows;

  double _snap(double v) => ((v * dpr + .5).floorToDouble()) / dpr;

  @override
  void paint(PaintingContext context, Offset offset) {
    final global = localToGlobal(Offset.zero);
    final left = _snap(global.dx), top = _snap(global.dy);
    final right = _snap(global.dx + size.width);
    final bottom = _snap(global.dy + size.height);
    final rect = Rect.fromLTRB(left, top, right, bottom).shift(offset - global);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final canvas = context.canvas;
    for (final shadow in shadows.reversed) {
      canvas.drawRRect(
        rrect.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      );
    }
    canvas.drawRRect(rrect, Paint()..color = color);
    if (borderWidth > 0) {
      canvas.drawDRRect(
        rrect,
        rrect.deflate(borderWidth),
        Paint()..color = borderColor,
      );
    }
    super.paint(context, offset);
  }
}
