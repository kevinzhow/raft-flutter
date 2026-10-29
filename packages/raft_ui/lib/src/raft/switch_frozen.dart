// Compatibility geometry API and the frozen Elegant / Brutal switch painter.
// The Raft look paints from the generated `switchRecipe` in switch.dart.
part of 'switch.dart';

/// Compatibility geometry for callers of the original switch API. Insets
/// measure from the track's outside edge, including any track border.
@immutable
class RaftSwitchRecipe {
  const RaftSwitchRecipe({this.tokens, this.size = RaftSwitchSize.md});
  final RaftTokens? tokens;
  final RaftSwitchSize size;
  String get _size => size.name;
  double _value(String name, double fallback) =>
      tokens?.size(name, fallback: fallback) ?? fallback;
  Size get visualSize => Size(
    _value('size.switch.width.$_size', 50),
    _value('size.switch.height.$_size', 30),
  );
  double get thumbSize => _value('size.switch.thumb.$_size', 22);
  double get thumbInset => _value('space.switchInset', 4);
  double get travel => visualSize.width - thumbSize - 2 * thumbInset;
  double get borderWidth => _value('stroke.control', 1.5);
  bool get square => tokens?.option('switch.shape', or: 'pill') == 'square';
  bool get inkBorder =>
      tokens?.option('control.edge', or: 'inkBorder') != 'ring';
  BorderRadius get radius =>
      BorderRadius.circular(square ? 0 : visualSize.height / 2);
  Duration get slideDuration =>
      Duration(milliseconds: _value('motion.switchSlideMs', 220).round());
  Duration get colorDuration =>
      Duration(milliseconds: _value('motion.switchColorMs', 150).round());
  RaftSwitchSemanticTokens get semantics => RaftSwitchSemanticTokens(tokens!);
}

/// Existing colour roles of a ring or square switch (a57b9dab switch.dart).
/// The border and shape options describe paint, independently of pack identity.
@immutable
class RaftSwitchSemanticTokens {
  const RaftSwitchSemanticTokens(this.tokens);
  final RaftTokens tokens;
  bool get square => tokens.option('switch.shape', or: 'pill') == 'square';
  Color track({
    required bool value,
    bool disabled = false,
    bool hovered = false,
  }) {
    if (disabled) {
      return square
          ? tokens.colors['fill-muted']!
          : tokens.dark
          ? tokens.colors['layer-inset']!
          : tokens.panel;
    }
    if (value) {
      return hovered && !square
          ? tokens.colors['button-primary-hover']!
          : tokens.colors['primary-400']!;
    }
    if (square) {
      return hovered
          ? tokens.colors['primary-400']!.withValues(alpha: .3)
          : tokens.panel;
    }
    if (tokens.dark) return hovered ? tokens.panel : tokens.card;
    return tokens.strong.withValues(alpha: hovered ? .16 : .12);
  }

  Color thumb({required bool value, bool disabled = false}) {
    if (square) return tokens.colors[disabled ? 'line' : 'line-strong']!;
    if (disabled)
      return value
          ? tokens.components.switchThumbCheckedDisabled
          : tokens.components.switchThumbDisabled;
    return value
        ? tokens.components.switchThumbChecked
        : tokens.components.switchThumb;
  }
}

/// The frozen switch control, the part of [_RaftSwitchState.build] under the interaction wrapper.
Widget _frozenSwitchControl(
  BuildContext context, {
  required RaftTokens t,
  required RaftSwitchSize size,
  required bool value,
  required bool disabled,
  required bool showHover,
  required RaftInteractionState st,
  required bool reduced,
  required double min,
  required String? semanticDescription,
}) {
  final recipe = RaftSwitchRecipe(tokens: t, size: size);
  final hovered = st.hovered && showHover && RaftHoverScope.of(context);
  final control = TweenAnimationBuilder<double>(
    tween: Tween<double>(end: value ? 1 : 0),
    duration: reduced ? Duration.zero : recipe.colorDuration,
    curve: RaftPrimitives.switchCurve,
    builder: (context, colorProgress, _) => TweenAnimationBuilder<double>(
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
