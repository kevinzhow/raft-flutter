import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// A DOM `dblclick` for pointer devices. Counts primary mouse / trackpad
/// presses without a double-tap recognizer, so the first click is never held
/// back; touch and stylus are ignored and keep their single-tap behaviour.
///
/// [onDoubleClick] runs once the second click has finished dispatching, after
/// the child's own tap for that click (as the browser orders `click` before
/// `dblclick`).
class RaftMouseDoubleClick extends StatefulWidget {
  /// True while the second click of a double-click is being dispatched, so a
  /// tap handler can skip it (`event.detail >= 2`). Touch never sets it.
  static bool get secondClick => _secondClick;
  static bool _secondClick = false;

  const RaftMouseDoubleClick({
    super.key,
    required this.onDoubleClick,
    required this.child,
    this.interval = kDoubleTapTimeout,
  });

  final VoidCallback? onDoubleClick;
  final Widget child;
  final Duration interval;

  @override
  State<RaftMouseDoubleClick> createState() => _RaftMouseDoubleClickState();
}

class _RaftMouseDoubleClickState extends State<RaftMouseDoubleClick> {
  Duration? _lastDown;
  Offset? _lastPosition;
  int? _armedPointer;

  static bool _pointer(PointerEvent e) =>
      e.kind == PointerDeviceKind.mouse || e.kind == PointerDeviceKind.trackpad;

  void _down(PointerDownEvent e) {
    if (!_pointer(e) || e.buttons != kPrimaryButton) {
      _lastDown = null;
      return;
    }
    final last = _lastDown, at = _lastPosition;
    final repeat =
        last != null &&
        at != null &&
        e.timeStamp - last <= widget.interval &&
        (e.position - at).distance <= kDoubleTapSlop;
    if (repeat) {
      _lastDown = null;
      _armedPointer = e.pointer;
      RaftMouseDoubleClick._secondClick = true;
    } else {
      _lastDown = e.timeStamp;
      _lastPosition = e.position;
    }
  }

  void _up(PointerUpEvent e) {
    if (_armedPointer != e.pointer) return;
    _armedPointer = null;
    final callback = widget.onDoubleClick;
    // ignore: raft_lints/avoid_unreviewed_idle_work -- One microtask per double click, not a loop: it runs the callback after the child's own tap of this click.
    scheduleMicrotask(() {
      RaftMouseDoubleClick._secondClick = false;
      callback?.call();
    });
  }

  void _cancel() {
    _armedPointer = null;
    RaftMouseDoubleClick._secondClick = false;
  }

  @override
  Widget build(BuildContext context) => widget.onDoubleClick == null
      ? widget.child
      : Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _down,
          onPointerUp: _up,
          onPointerCancel: (_) => _cancel(),
          child: widget.child,
        );
}
