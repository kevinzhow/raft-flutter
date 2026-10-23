import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'panel_layout.dart' show RaftCssFocusOutline;
import 'theme.dart';

/// Web SenderAvatar `<button>`: `transition-[filter,transform] duration-75
/// hover:brightness-90`, scaled to .9 and darkened (`brightness-75`) while
/// pressed. The artwork stays the caller's. The shared interaction primitive
/// supplies keyboard activation, a visible focus outline and button semantics.
class RaftAvatarButton extends StatelessWidget {
  const RaftAvatarButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.onLongPress,
    this.semanticLabel,
  });
  final Widget child;
  final VoidCallback? onPressed;

  /// Web SenderAvatar `onLongPressMention`: a touch held 500ms (moving no more
  /// than 10px) runs this instead of [onPressed], and swallows the tap. A
  /// mouse click is never a long press.
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  /// CSS `brightness(x)`: scale the colour channels.
  static ColorFilter _brightness(double v) => ColorFilter.matrix([
    v, 0, 0, 0, 0, //
    0, v, 0, 0, 0, //
    0, 0, v, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final button = _button();
    final longPress = onLongPress;
    if (longPress == null) return button;
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: const Duration(milliseconds: 500),
                postAcceptSlopTolerance: 10,
                supportedDevices: const {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.stylus,
                },
              ),
              (recognizer) => recognizer.onLongPress = longPress,
            ),
      },
      child: button,
    );
  }

  Widget _button() => RaftInteractive(
    onPressed: onPressed,
    button: onPressed != null,
    semanticLabel: semanticLabel,
    builder: (context, state) {
      Widget artwork = child;
      if (state.enabled && (state.hovered || state.pressed)) {
        artwork = ColorFiltered(
          colorFilter: _brightness(state.pressed ? .75 : .9),
          child: artwork,
        );
      }
      if (state.enabled && state.pressed) {
        artwork = Transform.scale(scale: .9, child: artwork);
      }
      return CustomPaint(
        foregroundPainter: RaftCssFocusOutline(
          enabled: state.focusVisible,
          color: RaftTokens.of(context).colors['line-strong']!,
        ),
        child: ExcludeSemantics(child: artwork),
      );
    },
  );
}
