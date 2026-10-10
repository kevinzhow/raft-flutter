import 'package:flutter/gestures.dart';

/// Pointer movement versus list scrolling, shared by every hover popup
/// (RaftTooltip, RaftHoverCard). A list scrolled under a resting pointer
/// moves rows under it and Flutter reports enter events for them; those are
/// not hover intent. A popup only opens after the pointer itself moved since
/// the last scroll (native desktop behaviour).
abstract final class RaftPointerIntent {
  static bool _installed = false;
  static int _moves = 0, _scrolledAtMove = -1;

  static void install() {
    if (_installed) return;
    _installed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute((event) {
      if (event is PointerHoverEvent && event.delta != Offset.zero) _moves++;
    });
  }

  /// A scrollable under the pointer moved its content.
  static void scrolled() => _scrolledAtMove = _moves;

  /// Whether the pointer moved since the last [scrolled].
  static bool get movedSinceScroll => _moves != _scrolledAtMove;
}
