import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Pointer movement versus scrolling, shared by every hover popup
/// (RaftTooltip, RaftHoverCard).
///
/// Product rule: a popup opens only while the pointer rests, and closes at
/// once when anything scrolls. A list scrolled under a resting pointer moves
/// rows under it and Flutter reports enter events for them; those are not
/// hover intent. A popup only opens after the pointer itself moved since the
/// last scroll (native desktop behaviour).
abstract final class RaftPointerIntent {
  static bool _installed = false;
  static int _moves = 0, _scrolledAtMove = -1;
  static final List<VoidCallback> _signals = [];

  static void install() {
    if (_installed) return;
    _installed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute((event) {
      if (event is PointerHoverEvent && event.delta != Offset.zero) {
        _moves++;
      } else if (event is PointerScrollEvent ||
          (event is PointerPanZoomUpdateEvent &&
              event.panDelta != Offset.zero)) {
        // Wheel / trackpad scroll signal: reported before the scrollable
        // moves, and even when it cannot (already at its edge).
        scrolled();
        for (final signal in List.of(_signals)) {
          signal();
        }
      }
    });
  }

  /// Subscribes [signal] to wheel and trackpad scroll events. Popups hold the
  /// subscription only while hovered or open.
  static void listenScroll(VoidCallback signal) {
    if (!_signals.contains(signal)) _signals.add(signal);
  }

  static void unlistenScroll(VoidCallback signal) => _signals.remove(signal);

  /// A scrollable under the pointer moved its content.
  static void scrolled() => requireMovement();

  /// Navigation can expose a retained trigger without moving the pointer,
  /// just as scrolling can expose a new row underneath it.
  static void requireMovement() => _scrolledAtMove = _moves;

  /// Whether the pointer moved since the last [scrolled].
  static bool get movedSinceScroll => _moves != _scrolledAtMove;
}

/// Listens to the [ScrollPosition] of every ancestor [Scrollable] (nested and
/// both axes), so any scroll position change - wheel, trackpad, scrollbar
/// drag, keyboard - reaches [onScroll].
class RaftScrollWatch {
  RaftScrollWatch(this.onScroll);
  final VoidCallback onScroll;
  final Set<ScrollPosition> _positions = {};

  /// Re-reads the ancestor scrollables of [context].
  void sync(BuildContext context) {
    final next = <ScrollPosition>{};
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        next.add((element.state as ScrollableState).position);
      }
      return true;
    });
    for (final gone in _positions.difference(next)) {
      gone.removeListener(onScroll);
    }
    for (final added in next.difference(_positions)) {
      added.addListener(onScroll);
    }
    _positions
      ..clear()
      ..addAll(next);
  }

  void dispose() {
    for (final position in _positions) {
      position.removeListener(onScroll);
    }
    _positions.clear();
  }
}
