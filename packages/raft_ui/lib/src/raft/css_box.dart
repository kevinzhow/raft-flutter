// A CSS-like box for the raft-ui 0.7.1 controls: fill, border, an inset ring, and outer rings (`ring-*`, the
// focus ring) that are painted outside the border box only. Flutter's BoxShadow paints under the whole box, so a
// translucent ring or a ring around a transparent button would tint the inside; this clips the rings out.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Whether captures come from a browser with an emulated device scale factor (the parity reference, Playwright
/// `deviceScaleFactor: 3`): Blink then does not zoom layout by the DPR, so a CSS border width floors to whole CSS
/// pixels (`border-[1.5px]` paints 1px). Only the parity harness sets it.
abstract final class RaftBorderSnap {
  static bool emulatedDeviceScaleFactor = false;
}

/// A CSS border width as Blink paints it: floored to whole device pixels (a real browser at 3x draws 1.5px as
/// 4 device px), or to whole CSS pixels under [RaftBorderSnap.emulatedDeviceScaleFactor]. Never below one device pixel.
double raftControlBorderPx(BuildContext context, double css) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  if (RaftBorderSnap.emulatedDeviceScaleFactor) {
    return css >= 1 ? css.floorToDouble() : 1 / dpr;
  }
  return math.max(1.0, (css * dpr).floorToDouble()) / dpr;
}

/// [decoration] with every border side floored the way [raftControlBorderPx] floors a CSS width, for the
/// generated recipes' `border-[1.5px]` (a recipe box paints the CSS number as it is).
BoxDecoration raftSnapBorder(BuildContext context, BoxDecoration decoration) {
  final border = decoration.border;
  if (border is! Border) return decoration;
  BorderSide snap(BorderSide side) =>
      side.style == BorderStyle.none || side.width == 0
      ? side
      : side.copyWith(width: raftControlBorderPx(context, side.width));
  return decoration.copyWith(
    border: Border(
      top: snap(border.top),
      right: snap(border.right),
      bottom: snap(border.bottom),
      left: snap(border.left),
    ),
  );
}

/// One outer ring, `0 0 0 <spread>px <color>`.
@immutable
class RaftRing {
  const RaftRing(this.spread, this.color);
  final double spread;
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is RaftRing && other.spread == spread && other.color == color;

  @override
  int get hashCode => Object.hash(spread, color);
}

/// Rings in CSS box-shadow order (first = on top), as `ring-*` and `shadow-focus` compose them.
class RaftCssBox extends StatelessWidget {
  const RaftCssBox({
    super.key,
    this.radius = 0,
    this.fill,
    this.borderWidth = 0,
    this.borderColor,
    this.insetRingWidth = 0,
    this.insetRingColor,
    this.rings = const [],
    this.opaqueRings = false,
    this.width,
    this.height,
    this.minHeight,
    this.padding,
    this.alignment,
    this.child,
  });

  /// `rounded-*` of the border box.
  final double radius;
  final Color? fill;

  /// CSS `border` (layout: reduces the content box). Zero for none.
  final double borderWidth;
  final Color? borderColor;

  /// `inset-ring-*` / an inset box-shadow: painted inside the padding edge, no layout.
  final double insetRingWidth;
  final Color? insetRingColor;
  final List<RaftRing> rings;

  /// The fill and the box fill is opaque: paint each ring as a whole rounded rect under the fill, as Blink
  /// does for an opaque box (no AA seam where the fill edge meets the ring). Translucent rings need the cut-out.
  final bool opaqueRings;
  final double? width, height;

  /// `min-h-*`: the box grows past it with its content (large text scales).
  final double? minHeight;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    Widget box = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        border: borderWidth > 0 && borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
      ),
      position: DecorationPosition.background,
      child: _InsetRing(
        radius: radius - borderWidth,
        inset: borderWidth,
        width: insetRingWidth,
        color: insetRingColor,
        child: Padding(
          padding: EdgeInsets.all(borderWidth),
          child: child == null
              ? null
              : Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: Align(
                    alignment: alignment ?? Alignment.topLeft,
                    widthFactor: 1,
                    heightFactor: 1,
                    child: child,
                  ),
                ),
        ),
      ),
    );
    if (width != null || height != null) {
      box = SizedBox(width: width, height: height, child: box);
    }
    if (minHeight != null) {
      box = ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight!),
        child: box,
      );
    }
    // Always a CustomPaint: a ring appearing (focus) must not re-parent, and so rebuild, the child's state.
    return CustomPaint(
      painter: _RingsPainter(radius, rings, opaque: opaqueRings),
      child: box,
    );
  }
}

class _InsetRing extends StatelessWidget {
  const _InsetRing({
    required this.radius,
    required this.inset,
    required this.width,
    required this.color,
    required this.child,
  });
  final double radius, inset, width;
  final Color? color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (width <= 0 || color == null) return child;
    return CustomPaint(
      foregroundPainter: _InsetRingPainter(
        radius: math.max(0, radius),
        width: width,
        color: color!,
      ),
      child: child,
    );
  }
}

class _InsetRingPainter extends CustomPainter {
  _InsetRingPainter({
    required this.radius,
    required this.width,
    required this.color,
  });
  final double radius, width;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final inner = outer.deflate(width);
    canvas.drawDRRect(outer, inner, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_InsetRingPainter old) =>
      old.radius != radius || old.width != width || old.color != color;
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.radius, this.rings, {this.opaque = false});
  final double radius;
  final List<RaftRing> rings;
  final bool opaque;

  @override
  void paint(Canvas canvas, Size size) {
    final box = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    // CSS paints the first shadow on top: draw the last (largest) ring first.
    for (final ring in rings.reversed) {
      final outer = box.inflate(ring.spread);
      if (opaque) {
        canvas.drawRRect(outer, Paint()..color = ring.color);
      } else {
        canvas.drawDRRect(outer, box, Paint()..color = ring.color);
      }
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.radius != radius || old.opaque != opaque || !_same(old.rings, rings);

  static bool _same(List<RaftRing> a, List<RaftRing> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Outer rings (`ring-*`, the focus ring) around an arbitrary child whose own box has the given corner [radius]:
/// painted outside the child's bounds only, so the child keeps its own fill and layout.
class RaftOuterRings extends StatelessWidget {
  const RaftOuterRings({
    super.key,
    required this.radius,
    required this.rings,
    required this.child,
  });

  final double radius;
  final List<RaftRing> rings;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      // Always a CustomPaint: toggling the ring must not re-parent (and so rebuild the state of) the child.
      CustomPaint(painter: _RingsPainter(radius, rings), child: child);
}
