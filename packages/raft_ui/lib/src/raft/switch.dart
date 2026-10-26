// raft-ui 0.7.1 `Switch` (dist `switchRecipe`): a 50x30 round track with a 1.5px ink border and a 22px thumb that
// carries its own 1.5px ring. Off is a `fill-muted` track; on is the `brand` sticker (ink border, `sticker-edge`
// ring) with a `sticker-paper` thumb; disabled reads `fill-muted` / `foreground-disabled`. Keyboard focus swaps the
// sticker ring for the `focus-ring`. The thumb slides 220ms on `ease-slide`, the track colours 150ms.
import 'package:flutter/material.dart';

import '../design_primitives.dart';
import '../theme.dart';
import '../switch_recipe.dart';
import '../hover_region.dart';
import '../primitive_tokens.dart';
import '../tokens/tokens.dart';
import 'css_box.dart';
import 'ui_tokens.dart';

export '../switch_recipe.dart' show RaftSwitchRecipe, RaftSwitchSize;

/// The fixed geometry of the 0.7.1 switch (`h-[30px] w-[50px] p-[2.5px]`, `size-[22px]`, `translate-x-5`).
abstract final class RaftSwitchMetrics {
  static const double width = 50, height = 30, padding = 2.5;
  static const double thumb = 22, travel = 20, ring = 1.5;
}

/// Controlled raft-ui 0.7.1 `Switch`, the one switch of the client. A null [onChanged] (or `enabled: false`) is `disabled` and never fires.
class RaftSwitch extends StatefulWidget {
  const RaftSwitch({
    super.key,
    required this.value,
    this.size = RaftSwitchSize.sm,
    this.onChanged,
    this.enabled = true,
    this.semanticLabel,
    this.semanticDescription,
    this.focusNode,
    this.minimumTargetSize,
  });

  final bool value, enabled;
  final RaftSwitchSize size;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel, semanticDescription;
  final FocusNode? focusNode;

  /// Layout minimum around the 50x30 track (a larger tap target that does take space); null adds none.
  final double? minimumTargetSize;

  /// The thumb's left offset inside the padding box. Blink lays out in CSS px under an emulated device scale
  /// factor and paints the box snapped to whole CSS px (`19.5` paints at `20`); [RaftBorderSnap] mirrors that.
  static double _thumbOffset(
    double slide,
    RaftSwitchRecipe recipe,
    double paintedBorder,
  ) {
    final offset = recipe.travel * slide;
    if (!RaftBorderSnap.emulatedDeviceScaleFactor) return offset;
    final origin =
        paintedBorder +
        (recipe.thumbInset - recipe.borderWidth).clamp(0, double.infinity);
    return (origin + offset).roundToDouble() - origin;
  }

  @override
  State<RaftSwitch> createState() => _RaftSwitchState();
}

class _RaftSwitchState extends State<RaftSwitch> {
  bool showHover = false;

  void hoverChanged(bool value) {
    if (mounted && value != showHover) setState(() => showHover = value);
  }

  bool get _enabled => widget.enabled && widget.onChanged != null;

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final size = widget.size;
    final onChanged = widget.onChanged;
    final semanticLabel = widget.semanticLabel;
    final semanticDescription = widget.semanticDescription;
    final focusNode = widget.focusNode;
    final minimumTargetSize = widget.minimumTargetSize;
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final recipe = RaftSwitchRecipe(tokens: t, size: size);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final disabled = !_enabled;
    // Touch density adds no layout (the 0.7.1 `after:` hit slop takes no space): [RaftInteractive] extends the 48px
    // hit target and semantics rect around the 50x30 track.
    final min =
        minimumTargetSize ??
        (RaftDensityScope.of(context) == RaftDensity.touch
            ? t.size('size.touchLayoutMin', fallback: 0)
            : 0);
    return RaftInteractive(
      onPressed: disabled ? null : () => onChanged!(!value),
      button: false,
      onShowHoverHighlight: hoverChanged,
      focusNode: focusNode,
      semanticLabel: semanticLabel,
      builder: (context, st) {
        // Ring edges need the source inset/shadow painter. Square edges also
        // use that painter, retaining the two-pixel inward outline.
        if (!recipe.inkBorder || recipe.square) {
          final hovered = st.hovered && showHover && RaftHoverScope.of(context);
          final control = TweenAnimationBuilder<double>(
            tween: Tween<double>(end: value ? 1 : 0),
            duration: reduced ? Duration.zero : recipe.colorDuration,
            curve: RaftPrimitives.switchCurve,
            builder: (context, colorProgress, _) =>
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: value ? 1 : 0),
                  duration: reduced ? Duration.zero : recipe.slideDuration,
                  curve: RaftPrimitives.switchCurve,
                  builder: (context, progress, _) => CustomPaint(
                    size: recipe.visualSize,
                    painter: _SwitchPainter(
                      recipe,
                      progress,
                      value,
                      disabled,
                      hovered,
                      !disabled && st.focusVisible,
                      colorProgress,
                    ),
                  ),
                ),
          );
          Widget result = Semantics(
            toggled: value,
            hint: semanticDescription,
            child: ExcludeSemantics(
              child: AnimatedScale(
                scale:
                    !disabled &&
                        st.pressed &&
                        t.option('press.effect', or: 'overlay') == 'scale' &&
                        !reduced
                    ? .96
                    : 1,
                duration: reduced ? Duration.zero : recipe.slideDuration,
                curve: RaftPrimitives.switchCurve,
                child: control,
              ),
            ),
          );
          if (min > 0)
            result = ConstrainedBox(
              constraints: BoxConstraints(minWidth: min, minHeight: min),
              child: Center(widthFactor: 1, heightFactor: 1, child: result),
            );
          return result;
        }
        final borderWidth = raftControlBorderPx(context, recipe.borderWidth);
        // [track]: the `transition-[background-color,box-shadow]` 150ms ease-out; the thumb slides on `ease-slide`
        // while its colours follow the value at once (`transition-transform` only).
        final control = TweenAnimationBuilder<double>(
          tween: Tween<double>(end: value ? 1 : 0),
          duration: reduced ? Duration.zero : recipe.colorDuration,
          curve: Curves.easeOut,
          builder: (context, on, _) => TweenAnimationBuilder<double>(
            tween: Tween<double>(end: value ? 1 : 0),
            duration: reduced ? Duration.zero : recipe.slideDuration,
            curve: RaftEase.slide,
            builder: (context, slide, _) {
              final offFill = ui.fillMuted;
              final trackFill = disabled
                  ? ui.fillMuted
                  : Color.lerp(offFill, ui.brand, on)!;
              final disabledInk = raftChromeBlend(
                ui.foregroundDisabled,
                ui.fillMuted,
              );
              final trackBorder = disabled
                  ? disabledInk
                  : Color.lerp(ui.lineStrong, ui.stickerInk, on)!;
              final thumbFill = disabled
                  ? ui.fillMuted
                  : (value ? ui.stickerPaper : ui.layerCard);
              final thumbRing = disabled
                  ? disabledInk
                  : (value ? ui.stickerInk : ui.lineStrong);
              return RaftCssBox(
                radius: recipe.visualSize.height / 2,
                fill: trackFill,
                borderWidth: borderWidth,
                borderColor: trackBorder,
                opaqueRings: true,
                rings: [
                  if (st.focusVisible)
                    for (final layer in ui.focusRing.layers)
                      RaftRing(layer.spread, layer.color)
                  else if (value &&
                      t.option('sticker.ring', or: 'dieCut') == 'dieCut')
                    RaftRing(RaftSwitchMetrics.ring, ui.stickerEdge),
                ],
                width: recipe.visualSize.width,
                height: recipe.visualSize.height,
                padding: EdgeInsets.all(
                  (recipe.thumbInset - recipe.borderWidth).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: RaftSwitch._thumbOffset(slide, recipe, borderWidth),
                  ),
                  child: RaftCssBox(
                    radius: recipe.thumbSize / 2,
                    fill: thumbFill,
                    opaqueRings: true,
                    rings: [RaftRing(RaftSwitchMetrics.ring, thumbRing)],
                    width: recipe.thumbSize,
                    height: recipe.thumbSize,
                  ),
                ),
              );
            },
          ),
        );
        Widget result = Semantics(
          toggled: value,
          hint: semanticDescription,
          child: ExcludeSemantics(child: control),
        );
        if (min > 0) {
          result = ConstrainedBox(
            constraints: BoxConstraints(minWidth: min, minHeight: min),
            child: Center(widthFactor: 1, heightFactor: 1, child: result),
          );
        }
        return result;
      },
    );
  }
}

class _SwitchPainter extends CustomPainter {
  const _SwitchPainter(
    this.recipe,
    this.progress,
    this.value,
    this.disabled,
    this.hovered,
    this.focused,
    this.colorProgress,
  );
  final RaftSwitchRecipe recipe;
  final double progress, colorProgress;
  final bool value, disabled, hovered, focused;
  @override
  void paint(Canvas canvas, Size size) {
    final t = recipe.tokens!;
    final rect = Offset.zero & size;
    final outer = recipe.radius.toRRect(rect);
    if (focused) {
      canvas.drawRRect(
        recipe.radius.toRRect(rect.inflate(3)),
        Paint()
          ..color = t.colors['line-strong']!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    void outerShadow(Color color, double offset, double sigma, double spread) {
      canvas.save();
      canvas.clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(rect.inflate(8)),
          Path()..addRRect(outer),
        ),
      );
      canvas.drawRRect(
        outer.inflate(spread).shift(Offset(0, offset)),
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
      );
      canvas.restore();
    }

    if (!recipe.square && !disabled) {
      if (t.dark && !value) {
        outerShadow(t.components.switchShadowBottom, 1, 0, 0);
      } else {
        outerShadow(
          Colors.black.withValues(
            alpha: t.dark
                ? .4
                : value
                ? .12
                : .08,
          ),
          1,
          .75,
          -1,
        );
      }
    }
    canvas.drawRRect(
      outer,
      Paint()
        ..color = Color.lerp(
          recipe.semantics.track(
            value: false,
            disabled: disabled,
            hovered: hovered,
          ),
          recipe.semantics.track(
            value: true,
            disabled: disabled,
            hovered: hovered,
          ),
          colorProgress,
        )!,
    );
    if (recipe.square) {
      canvas.drawRRect(
        outer.deflate(recipe.borderWidth / 2),
        Paint()
          ..color = t.colors[disabled ? 'line-hairline' : 'line-strong']!
          ..style = PaintingStyle.stroke
          ..strokeWidth = recipe.borderWidth,
      );
    } else {
      canvas.save();
      canvas.clipRRect(outer);
      void ring(Color color, double width) {
        canvas.drawPath(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addRRect(outer)
            ..addRRect(outer.deflate(width)),
          Paint()..color = color,
        );
      }

      void top(Color color, double sigma) {
        canvas.drawPath(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addRect(rect.inflate(4))
            ..addRRect(outer.shift(const Offset(0, 1))),
          Paint()
            ..color = color
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
        );
      }

      if (disabled) {
        ring(
          t.dark ? Colors.black.withValues(alpha: .5) : t.colors['line-muted']!,
          1,
        );
      } else if (t.dark && !value) {
        ring(Colors.black.withValues(alpha: .4), 1);
        top(Colors.black.withValues(alpha: .35), 1);
      } else {
        top(Colors.white.withValues(alpha: value ? .12 : .05), .25);
      }
      canvas.restore();
    }
    final thumbRect = Rect.fromLTWH(
      recipe.thumbInset + recipe.travel * progress,
      (size.height - recipe.thumbSize) / 2,
      recipe.thumbSize,
      recipe.thumbSize,
    );
    final thumb = RRect.fromRectAndRadius(
      thumbRect,
      Radius.circular(recipe.square ? 0 : recipe.thumbSize / 2),
    );
    if (!recipe.square && !disabled) {
      canvas.drawRRect(
        thumb.inflate(.5),
        Paint()..color = Colors.black.withValues(alpha: .04),
      );
      canvas.drawRRect(
        thumb.deflate(.5).shift(const Offset(0, 1)),
        Paint()
          ..color = Colors.black.withValues(alpha: .18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .75),
      );
    }
    canvas.drawRRect(
      thumb,
      Paint()..color = recipe.semantics.thumb(value: value, disabled: disabled),
    );
  }

  @override
  bool shouldRepaint(_SwitchPainter old) =>
      old.recipe.tokens != recipe.tokens ||
      old.recipe.size != recipe.size ||
      old.progress != progress ||
      old.colorProgress != colorProgress ||
      old.value != value ||
      old.disabled != disabled ||
      old.hovered != hovered ||
      old.focused != focused;
}
