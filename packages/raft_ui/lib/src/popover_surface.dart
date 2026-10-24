import 'package:flutter/material.dart';

import 'tokens/tokens.dart';
import 'theme.dart';

/// CSS shadow atom. Blur is a CSS blur diameter, not Flutter blurRadius.
@immutable
class RaftPopoverShadow {
  const RaftPopoverShadow(this.color, this.offset, this.blur, this.spread);
  final Color color;
  final Offset offset;
  final double blur, spread;
  double get sigma => blur / 2;
}

/// Tier 3: actual RUI0.5.27 PopoverPopup, NOT the DropdownMenu recipe.
/// Original index.mjs5893/5902 maps Brutal→LG and Elegant→XL. There is no
/// Popover XS size API. Business padding/position/width belong to the caller.
@immutable
class RaftPopoverSurfaceRecipe {
  const RaftPopoverSurfaceRecipe(this.tokens);
  final RaftTokens tokens;
  double get borderWidth => 0;
  double get radius => tokens.size('radius.popover', fallback: 6);

  /// `ring-1 ring-line-seam`: an outer ring that reserves no layout.
  double get ringWidth => tokens.size('stroke.popoverRing', fallback: 0);
  Color get ringColor => tokens.colors['line-seam']!;
  Color get background => tokens.popover;
  Color get borderColor => tokens.colors['line-strong']!;
  RaftShadow get _shadow => tokens.themeShadows.xl;

  /// The Elegant dark popover drew a top-edge light and an inner hairline as inset
  /// layers. raft-ui 0.7.1 has none: its dark ring is the 1px outer layer of
  /// `elevation-float`, so there is nothing to paint inside the surface.
  Color? get topInset => _shadow.hasInset ? _shadow.inset[0].color : null;
  Color? get innerRing =>
      _shadow.inset.length > 1 ? _shadow.inset[1].color : null;

  /// Outer `--theme-shadow-lg` (Brutal) / `--theme-shadow-xl` (Elegant)
  /// layers. Order is CSS front-to-back; the painter draws it back-to-front.
  List<RaftPopoverShadow> get cssShadows => [
    for (final l in _shadow.layers)
      if (!l.inset) RaftPopoverShadow(l.color, l.offset, l.blur, l.spread),
  ];
}

/// Paint-only reusable popover. Shadows and Elegant inset rings never reserve
/// layout/hit-test space. Brutal's real 2px border does reserve source space.
/// Clipping applies to children/inset chrome, never the outside shadow.
class RaftPopoverSurface extends StatelessWidget {
  const RaftPopoverSurface({super.key, required this.child, this.recipe});
  final Widget child;
  final RaftPopoverSurfaceRecipe? recipe;
  @override
  Widget build(BuildContext context) {
    final r = recipe ?? RaftPopoverSurfaceRecipe(RaftTokens.of(context));
    return CustomPaint(
      painter: _PopoverOutside(r),
      foregroundPainter: _PopoverInset(r),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r.radius),
        child: Padding(padding: EdgeInsets.all(r.borderWidth), child: child),
      ),
    );
  }
}

class _PopoverOutside extends CustomPainter {
  const _PopoverOutside(this.recipe);
  final RaftPopoverSurfaceRecipe recipe;
  @override
  void paint(Canvas canvas, Size size) {
    final shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(recipe.radius),
    );
    for (final shadow in recipe.cssShadows.reversed) {
      final expanded = shape.inflate(shadow.spread).shift(shadow.offset);
      if (expanded.width <= 0 || expanded.height <= 0) continue;
      final paint = Paint()..color = shadow.color;
      if (shadow.sigma > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.sigma);
      }
      canvas.drawRRect(expanded, paint);
    }
    if (recipe.ringWidth > 0) {
      canvas.drawRRect(
        shape.inflate(recipe.ringWidth),
        Paint()..color = recipe.ringColor,
      );
    }
    canvas.drawRRect(shape, Paint()..color = recipe.background);
    if (recipe.borderWidth > 0) {
      final edge = recipe.borderWidth / 2;
      canvas.drawRRect(
        shape.deflate(edge),
        Paint()
          ..color = recipe.borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = recipe.borderWidth,
      );
    }
  }

  @override
  bool shouldRepaint(_PopoverOutside oldDelegate) =>
      oldDelegate.recipe.tokens != recipe.tokens;
}

class _PopoverInset extends CustomPainter {
  const _PopoverInset(this.recipe);
  final RaftPopoverSurfaceRecipe recipe;
  @override
  void paint(Canvas canvas, Size size) {
    if (recipe.innerRing == null && recipe.topInset == null) return;
    final shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(recipe.radius),
    );
    canvas.save();
    canvas.clipRRect(shape);
    // Source inset shadows have zero blur. Subtract the shifted/deflated hole
    // from the clipped outer area, so inset paint adds no Flutter border.
    void fillOutside(RRect hole, Color color) {
      final path = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect((Offset.zero & size).inflate(2))
        ..addRRect(hole);
      canvas.drawPath(path, Paint()..color = color);
    }

    if (recipe.innerRing != null) {
      fillOutside(shape.deflate(1), recipe.innerRing!);
    }
    if (recipe.topInset != null) {
      fillOutside(shape.shift(const Offset(0, 1)), recipe.topInset!);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PopoverInset oldDelegate) =>
      oldDelegate.recipe.tokens != recipe.tokens;
}
