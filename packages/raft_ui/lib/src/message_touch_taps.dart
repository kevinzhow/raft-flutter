import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// Taps on a message on a touch screen (Web 1.24 useMessageTouchTaps.ts,
// raft-design "Taps on a touch screen"): a tap opens the thread, a double tap
// opens the quick-reaction bar where the finger is, press and hold opens the
// menu (the row's own long press). Read from raw touch pointer events, so the
// selectable text, which takes taps for itself, does not hide them; controls
// inside the message (links, buttons, media, code, cards) keep their own.

/// A touch that moves farther than this is a scroll or a swipe, not a tap.
const raftMessageTapMoveTolerance = 10.0;

/// Longest gap from a tap's lift to the next touch for a double tap.
const raftMessageDoubleTapWindow = Duration(milliseconds: 300);

/// How long a tap waits for a second one before it opens the thread.
const raftMessageTapDelay = Duration(milliseconds: 250);

/// Marks a part of a message that keeps its own touch gestures (a code block,
/// display math, a diagram, an attachment): a tap there is no message tap.
const raftMessageTapControl = _TapMarker('control');

/// Marks the message row itself: the hit-test walk stops there.
const raftMessageTapBoundary = _TapMarker('boundary');

class _TapMarker {
  const _TapMarker(this.name);
  final String name;
}

/// Wraps [child] so that a touch tap on it is left to it.
Widget raftMessageTapControlRegion(Widget child) =>
    MetaData(metaData: raftMessageTapControl, child: child);

class RaftMessageTapLink {
  const RaftMessageTapLink(this.onTap);

  final VoidCallback onTap;
}

abstract interface class RaftMessageLinkHit implements HitTestTarget {
  RaftMessageTapLink? get tapLink;
}

/// Whether a touch at [position] lands on a control inside the message row
/// (anything between the hit target and [raftMessageTapBoundary] that acts on
/// a tap by itself).
bool raftTouchLandsOnControl(Offset position, int viewId) =>
    _touchHit(position, viewId).control;

({bool control, RaftMessageTapLink? link}) _touchHit(
  Offset position,
  int viewId,
) {
  final result = HitTestResult();
  WidgetsBinding.instance.hitTestInView(result, position, viewId);
  for (final entry in result.path) {
    final target = entry.target;
    if (target case RaftMessageLinkHit(tapLink: final link?)) {
      return (control: true, link: link);
    }
    if (target is RenderMetaData) {
      final data = target.metaData;
      if (data is RaftMessageTapLink) return (control: true, link: data);
      if (identical(data, raftMessageTapBoundary)) break;
      if (identical(data, raftMessageTapControl)) {
        return (control: true, link: null);
      }
    }
    if (target is TextSpan && target.recognizer != null ||
        target is RenderEditable ||
        target is RenderMouseRegion &&
            target.cursor == SystemMouseCursors.click ||
        target is RenderSemanticsGestureHandler &&
            (target.onTap != null || target.onLongPress != null)) {
      return (control: true, link: null);
    }
  }
  return (control: false, link: null);
}

/// The tap / double-tap state of one message row (Web useMessageTouchTaps).
class RaftMessageTouchTaps {
  RaftMessageTouchTaps({required this.onPressedChanged});

  /// The row shows a pending tap (it waits for a possible second one).
  final ValueChanged<bool> onPressedChanged;

  /// Opens the thread; null where a tap does nothing (inside a thread).
  VoidCallback? onTap;

  /// Opens the quick-reaction bar at the second tap's global point; null
  /// where the message has none.
  ValueChanged<Offset>? onDoubleTap;

  /// False while the row has no tap gestures (select mode, pending rows).
  bool enabled = true;
  bool inlineLinks = false;

  /// Set when the touch's long press opened the menu: then it was no tap.
  bool longPressFired = false;

  /// Whether the list the row is in is still moving: the touch stops it.
  bool Function() listMoving = () => false;

  ({Offset start, bool tap, RaftMessageTapLink? link})? _touch;
  int? _pointer;
  // Pointer event time stamps (not the wall clock): the window is measured
  // between the events themselves.
  ({Duration at, Offset point})? _lastTap;
  Timer? _pending;
  bool _owed = false;

  void _setPressed(bool value) => onPressedChanged(value);

  void _payOwedTap() {
    if (!_owed) return;
    _owed = false;
    _setPressed(false);
    onTap?.call();
  }

  void _clearPending() {
    _pending?.cancel();
    _pending = null;
  }

  static bool _within(Offset a, Offset b) =>
      (a - b).distance <= raftMessageTapMoveTolerance;

  void pointerDown(PointerDownEvent event) {
    final touch = event.kind == PointerDeviceKind.touch;
    if ((!enabled || !touch) && !inlineLinks) return;
    if (event.buttons != kPrimaryButton) return;
    if (_pointer != null) {
      // A second finger: a pinch, never a tap.
      _touch = null;
      return;
    }
    _pointer = event.pointer;
    longPressFired = false;
    final previous = _lastTap;
    if (previous != null &&
        event.timeStamp - previous.at > raftMessageDoubleTapWindow) {
      _lastTap = null;
    }
    final moving = listMoving();
    final hit = _touchHit(event.position, event.viewId);
    if (_pending != null) {
      _clearPending();
      _owed = true;
    }
    _touch = (
      start: event.position,
      tap: touch && enabled && !moving && !hit.control,
      link: inlineLinks && !moving ? hit.link : null,
    );
  }

  void pointerMove(PointerMoveEvent event) {
    final touch = _touch;
    if (touch == null || event.pointer != _pointer) return;
    if (!_within(touch.start, event.position)) {
      _touch = (start: touch.start, tap: false, link: null);
    }
  }

  void pointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _touch = null;
    _lastTap = null;
    // The list took the touch for a scroll: the tap before it still counts.
    _payOwedTap();
  }

  void pointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    final touch = _touch;
    _touch = null;
    if (touch == null) return;
    if (longPressFired) {
      // Press and hold opened the menu: neither this touch nor one before acts.
      _owed = false;
      _lastTap = null;
      _setPressed(false);
      return;
    }
    if (touch.link case final link? when _within(touch.start, event.position)) {
      _lastTap = null;
      _payOwedTap();
      if (identical(_touchHit(event.position, event.viewId).link, link)) {
        link.onTap();
      }
      return;
    }
    if (!touch.tap || !_within(touch.start, event.position)) {
      _lastTap = null;
      _payOwedTap();
      return;
    }
    final previous = _lastTap;
    final doubleTap = onDoubleTap;
    if (doubleTap != null &&
        previous != null &&
        _within(previous.point, touch.start)) {
      // The second tap of a double tap: the bar, and the first tap's thread
      // is dropped.
      _lastTap = null;
      _owed = false;
      _setPressed(false);
      doubleTap(event.position);
      return;
    }
    // A tap too far from the previous one: that one still opens its thread.
    _payOwedTap();
    _lastTap = doubleTap == null
        ? null
        : (at: event.timeStamp, point: touch.start);
    final tap = onTap;
    if (tap == null) return;
    if (doubleTap == null) {
      tap();
      return;
    }
    _setPressed(true);
    _pending = Timer(raftMessageTapDelay, () {
      _pending = null;
      // The thread opens now, so this tap can no longer be half of a double
      // tap.
      _lastTap = null;
      _setPressed(false);
      if (enabled) onTap?.call();
    });
  }

  void dispose() {
    _clearPending();
  }
}
