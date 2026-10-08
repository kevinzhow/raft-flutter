import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_primitives.dart';
import 'primitive_tokens.dart';
import 'theme.dart';

enum RaftSwitchSize { sm, md }

/// Semantic roles resolved from the original raft-ui 0.5.27 switch recipe.
@immutable
class RaftSwitchSemanticTokens {
  const RaftSwitchSemanticTokens(this.tokens);
  final RaftTokens tokens;
  Color track({
    required bool value,
    bool disabled = false,
    bool hovered = false,
  }) {
    if (disabled) {
      return tokens.brutal
          ? tokens.colors['fill-muted']!
          : tokens.dark
          ? tokens.colors['layer-inset']!
          : tokens.panel;
    }
    if (value) {
      return hovered && !tokens.brutal
          ? tokens.colors['button-primary-hover']!
          : tokens.colors['primary-400']!;
    }
    if (tokens.brutal) {
      return hovered
          ? tokens.colors['primary-400']!.withValues(alpha: .3)
          : tokens.panel;
    }
    if (tokens.dark) {
      return hovered ? tokens.panel : tokens.card;
    }
    return tokens.strong.withValues(alpha: hovered ? .16 : .12);
  }

  Color thumb({required bool value, bool disabled = false}) {
    if (tokens.brutal) {
      return tokens.colors[disabled ? 'line' : 'line-strong']!;
    }
    if (disabled) {
      return value
          ? tokens.components.switchThumbCheckedDisabled
          : tokens.components.switchThumbDisabled;
    }
    return value
        ? tokens.components.switchThumbChecked
        : tokens.components.switchThumb;
  }
}

/// Source visual dimensions stay separate from the native touch layout.
@immutable
class RaftSwitchRecipe {
  const RaftSwitchRecipe(this.tokens, {this.size = RaftSwitchSize.sm});
  final RaftTokens tokens;
  final RaftSwitchSize size;
  Size get visualSize =>
      size == RaftSwitchSize.md ? const Size(36, 20) : const Size(28, 16);
  double get thumbSize => size == RaftSwitchSize.md
      ? tokens.brutal
            ? 14
            : 16
      : tokens.brutal
      ? 10
      : 12;
  double get thumbInset => tokens.brutal ? 3 : 2;
  double get travel => size == RaftSwitchSize.md ? 16 : 12;
  double get borderWidth => tokens.brutal ? 2 : 0;
  BorderRadius get radius =>
      BorderRadius.circular(tokens.brutal ? 0 : visualSize.height / 2);
  RaftSwitchSemanticTokens get semantics => RaftSwitchSemanticTokens(tokens);
}

/// Controlled source Switch. A disabled control never invokes [onChanged].
class RaftSwitch extends StatefulWidget {
  const RaftSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.size = RaftSwitchSize.sm,
    this.enabled = true,
    this.semanticLabel,
    this.semanticDescription,
    this.minimumTargetSize,
  });
  final bool value, enabled;
  final ValueChanged<bool>? onChanged;
  final RaftSwitchSize size;
  final String? semanticLabel, semanticDescription;
  final double? minimumTargetSize;
  @override
  State<RaftSwitch> createState() => _RaftSwitchState();
}

class _RaftSwitchState extends State<RaftSwitch> {
  final focus = FocusNode();
  bool hovered = false, pressed = false, focused = false, showFocus = false;
  bool get enabled => widget.enabled && widget.onChanged != null;
  void toggleValue() {
    if (!enabled) {
      return;
    }
    focus.requestFocus();
    widget.onChanged?.call(!widget.value);
  }

  @override
  void didUpdateWidget(RaftSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!enabled) {
      hovered = pressed = showFocus = false;
    }
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftSwitchRecipe(t, size: widget.size);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final target =
        widget.minimumTargetSize ??
        (RaftDensityScope.of(context) == RaftDensity.touch ? 48.0 : 0.0);
    return Semantics(
      label: widget.semanticLabel,
      hint: widget.semanticDescription,
      toggled: widget.value,
      enabled: enabled,
      focusable: enabled,
      focused: focused,
      onTap: enabled ? toggleValue : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        focusNode: focus,
        enabled: enabled,
        onFocusChange: (v) => setState(() => focused = v),
        onShowFocusHighlight: (v) => setState(() => showFocus = v),
        onShowHoverHighlight: (v) => setState(() => hovered = v),
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.space, includeRepeats: false):
              ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false):
              ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              toggleValue();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              toggleValue();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? toggleValue : null,
          onTapDown: enabled ? (_) => setState(() => pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => pressed = false) : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: target, minHeight: target),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: AnimatedScale(
                scale: enabled && pressed && !t.brutal && !reduced ? .96 : 1,
                duration: reduced
                    ? Duration.zero
                    : RaftPrimitives.switchDuration,
                curve: RaftPrimitives.switchCurve,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: widget.value ? 1 : 0),
                  duration: reduced
                      ? Duration.zero
                      : RaftPrimitives.switchDuration,
                  curve: RaftPrimitives.switchCurve,
                  builder: (context, progress, _) => CustomPaint(
                    size: recipe.visualSize,
                    painter: _SwitchPainter(
                      recipe,
                      progress,
                      widget.value,
                      !enabled,
                      hovered,
                      enabled && showFocus,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
  );
  final RaftSwitchRecipe recipe;
  final double progress;
  final bool value, disabled, hovered, focused;
  @override
  void paint(Canvas canvas, Size size) {
    final t = recipe.tokens;
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

    if (!t.brutal && !disabled) {
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
          progress,
        )!,
    );
    if (t.brutal) {
      canvas.drawRRect(
        outer.deflate(1),
        Paint()
          ..color = t.colors[disabled ? 'line-hairline' : 'line-strong']!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
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
      Radius.circular(t.brutal ? 0 : recipe.thumbSize / 2),
    );
    if (!t.brutal && !disabled) {
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
      old.value != value ||
      old.disabled != disabled ||
      old.hovered != hovered ||
      old.focused != focused;
}
