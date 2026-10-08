import 'package:flutter/material.dart';

import 'primitive_tokens.dart';
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

/// Tier 2: original foundation.css shadow ink, separate from foreground ink.
/// Tier 1 values reuse the generated original OKLCH → sRGB primitive atoms.
abstract final class RaftPopoverShadowRoles {
  static Color lightDrop(double alpha) =>
      RaftPrimitives.rgbaff0a0a09.withValues(alpha: alpha);
  static Color lightRing(double alpha) =>
      RaftPrimitives.rgbaff141411.withValues(alpha: alpha);
  static Color darkDrop(double alpha) =>
      RaftPrimitives.rgbaff000000.withValues(alpha: alpha);
  static Color darkInset(double alpha) =>
      RaftPrimitives.rgbafffafaf7.withValues(alpha: alpha);
}

/// Tier 3: actual RUI0.5.27 PopoverPopup, NOT the DropdownMenu recipe.
/// Original index.mjs5893/5902 maps Brutal→LG and Elegant→XL. There is no
/// Popover XS size API. Business padding/position/width belong to the caller.
@immutable
class RaftPopoverSurfaceRecipe {
  const RaftPopoverSurfaceRecipe(this.tokens);
  final RaftTokens tokens;
  double get borderWidth => tokens.brutal ? 2 : 0;
  double get radius => tokens.brutal ? 0 : 6;
  Color get background => tokens.popover;
  Color get borderColor => tokens.colors['line-strong']!;
  Color? get topInset => !tokens.brutal && tokens.dark
      ? RaftPopoverShadowRoles.darkInset(.06)
      : null;
  Color? get innerRing => !tokens.brutal && tokens.dark
      ? RaftPopoverShadowRoles.darkInset(.04)
      : null;

  /// Order is CSS front-to-back; the painter draws it back-to-front.
  List<RaftPopoverShadow> get cssShadows => tokens.brutal
      ? const [RaftPopoverShadow(Colors.black, Offset(4, 4), 0, 0)]
      : tokens.dark
      ? [
          RaftPopoverShadow(
            RaftPopoverShadowRoles.darkDrop(.6),
            Offset.zero,
            0,
            1,
          ),
          RaftPopoverShadow(
            RaftPopoverShadowRoles.darkDrop(.5),
            const Offset(0, 24),
            44,
            -12,
          ),
          RaftPopoverShadow(
            RaftPopoverShadowRoles.darkDrop(.45),
            const Offset(0, 10),
            16,
            -6,
          ),
          RaftPopoverShadow(
            RaftPopoverShadowRoles.darkDrop(.4),
            const Offset(0, 4),
            6,
            -3,
          ),
        ]
      : [
          RaftPopoverShadow(
            RaftPopoverShadowRoles.lightDrop(.071),
            const Offset(0, .5),
            0,
            0,
          ),
          RaftPopoverShadow(
            RaftPopoverShadowRoles.lightRing(.08),
            Offset.zero,
            0,
            1,
          ),
          RaftPopoverShadow(
            RaftPopoverShadowRoles.lightDrop(.031),
            const Offset(0, 18),
            24,
            -12,
          ),
          RaftPopoverShadow(
            RaftPopoverShadowRoles.lightDrop(.039),
            const Offset(0, 12),
            12,
            -6,
          ),
          RaftPopoverShadow(
            RaftPopoverShadowRoles.lightDrop(.039),
            const Offset(0, 4),
            6,
            -3,
          ),
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

    if (recipe.innerRing != null)
      fillOutside(shape.deflate(1), recipe.innerRing!);
    if (recipe.topInset != null)
      fillOutside(shape.shift(const Offset(0, 1)), recipe.topInset!);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PopoverInset oldDelegate) =>
      oldDelegate.recipe.tokens != recipe.tokens;
}
