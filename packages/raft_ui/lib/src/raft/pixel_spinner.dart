// raft-ui 0.7.0 `Spinner`: four square pixels in a 2x2 grid that light up clockwise (top-left, top-right,
// bottom-right, bottom-left), 1s per turn, `steps(1)`. With reduced motion only the first pixel is lit.
import 'package:flutter/material.dart';
import 'package:raft_theme/recipes/spinner.g.dart' as source;

import '../recipes/recipe_runtime.dart' show RaftTokenResolver;

import '../theme.dart';
import '../recipe_surface.dart' show RaftRecipeBinding;

/// `size` axis of the published `spinner` recipe.
enum RaftPixelSpinnerSize {
  xs,
  sm,
  md,
  lg;

  /// Resolve the modern-only painter from the existing generated source.
  /// The frozen ring renderer never enters this path. Its legacy-shaped
  /// router cannot represent the published `pixel` slot.
  source.RaftSpinnerRecipeStyle resolve(
    RaftTokenResolver? tokens, {
    bool inverse = false,
  }) => source.RaftSpinnerRecipe.resolve(
    size: source.RaftSpinnerRecipeSize.values.byName(name),
    variant: inverse
        ? source.RaftSpinnerRecipeVariant.inverse
        : source.RaftSpinnerRecipeVariant.default_,
    tokens: tokens,
  );

  // The grid inherits these custom properties from its root. Keep the
  // existing size API, but read its values from that generated declaration.
  double get pixel => resolve(null).root.length('--spinner-pixel')!;
  double get gap => resolve(null).root.length('--spinner-gap')!;

  /// Edge of the whole grid.
  double get extent => pixel * 2 + gap;
}

/// The Raft look's painter for raft-ui `Spinner`. App and product code uses
/// `RaftSpinner`, the one spinner: it paints this in the Raft look and the
/// frozen ring in Elegant and Brutal.
class RaftPixelSpinner extends StatefulWidget {
  const RaftPixelSpinner({
    super.key,
    this.size = RaftPixelSpinnerSize.sm,
    this.color,
    this.semanticLabel = 'Loading',
  });
  final RaftPixelSpinnerSize size;

  /// `text-current`; defaults to the ambient text colour.
  final Color? color;
  final String semanticLabel;

  @override
  State<RaftPixelSpinner> createState() => _RaftPixelSpinnerState();
}

class _RaftPixelSpinnerState extends State<RaftPixelSpinner>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  void _sync(bool animate, Duration period) {
    if (!animate) {
      _controller?.dispose();
      _controller = null;
      return;
    }
    final changed = _controller?.duration != period;
    _controller ??= AnimationController(vsync: this, duration: period);
    if (changed) _controller!.duration = period;
    if (changed || !_controller!.isAnimating) {
      // ignore: raft_lints/avoid_unreviewed_idle_work -- State vsync and TickerMode bound the loop; reduced motion disposes the controller, as does unmount.
      _controller!.repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final period = Duration(
      milliseconds: RaftTokens.of(context)
          .size('duration.spinnerTurn', fallback: 1000)
          .round(),
    );
    _sync(!MediaQuery.disableAnimationsOf(context), period);
    final color =
        widget.color ??
        DefaultTextStyle.of(context).style.color ??
        Colors.black;
    final recipe = widget.size.resolve(RaftTokens.of(context).recipeTokens);
    final pixel = recipe.root.length('--spinner-pixel')!;
    final gap = recipe.root.length('--spinner-gap')!;
    final radius = recipe.pixel.borderRadius!;
    final dimOpacity = recipe.pixel.opacity!;
    final extent = pixel * 2 + gap;
    final painter = (double? phase) =>
        _PixelPainter(pixel, gap, radius, dimOpacity, color, phase);
    return Semantics(
      label: widget.semanticLabel,
      liveRegion: true,
      child: SizedBox.square(
        dimension: extent,
        child: _controller == null
            ? CustomPaint(painter: painter(null))
            : AnimatedBuilder(
                animation: _controller!,
                builder: (context, _) =>
                    CustomPaint(painter: painter(_controller!.value)),
              ),
      ),
    );
  }
}

class _PixelPainter extends CustomPainter {
  _PixelPainter(
    this.pixel,
    this.gap,
    this.radius,
    this.dimOpacity,
    this.color,
    this.phase,
  );
  final double pixel, gap, dimOpacity;
  final BorderRadius radius;
  final Color color;

  /// 0..1 through the turn; null when motion is reduced.
  final double? phase;

  // Clockwise order of the grid cells (column, row).
  static const _cells = [(0, 0), (1, 0), (1, 1), (0, 1)];

  @override
  void paint(Canvas canvas, Size _) {
    final lit = phase == null ? 0 : (phase! * 4).floor().clamp(0, 3);
    for (var i = 0; i < 4; i++) {
      final (col, row) = _cells[i];
      final rect = Rect.fromLTWH(
        col * (pixel + gap),
        row * (pixel + gap),
        pixel,
        pixel,
      );
      final paint = Paint()
        ..color = color.withValues(
          alpha: color.a * (i == lit ? 1 : dimOpacity),
        );
      canvas.drawRRect(radius.toRRect(rect), paint);
    }
  }

  @override
  bool shouldRepaint(_PixelPainter old) =>
      old.pixel != pixel ||
      old.gap != gap ||
      old.radius != radius ||
      old.dimOpacity != dimOpacity ||
      old.color != color ||
      old.phase != phase;
}
