import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'message_touch_taps.dart' show raftMessageTapControl;

// Drag the conversation left on a touch screen to see every message's time,
// as in iMessage (Web 1.24 components/message/useTimelineTimeReveal.ts,
// TimelineRevealTime.tsx). Every message row slides left together and its
// time comes in at the right edge; the release springs them back. Touch only;
// it claims a drag on the same terms as a row swipe (clearly sideways, past
// twice the touch slop, only to the left), counted from where the finger went
// down. It leaves alone a drag that starts within 24px of a screen edge, in a
// code block, display math, a diagram or media (the message's own controls),
// or in anything that scrolls sideways with something to scroll, and any drag
// while a popup is open. Read from raw pointer events: the list keeps its
// vertical scroll.

/// How far the rows slide before the rubber band: room for the time.
const raftTimeRevealDistance = 64.0;

/// Past [raftTimeRevealDistance] the rows follow the finger at this rate.
const raftTimeRevealRubberBand = .55;

/// The farthest the rows slide, however far the finger goes.
const raftTimeRevealMax = 88.0;

/// How long the rows take to spring back.
const raftTimeRevealSettle = Duration(milliseconds: 160);

/// A drag that starts this close to either edge of the screen is the system's.
const raftTimeRevealEdgeZone = 24.0;

const _touchSlop = 10.0, _claimDistance = 20.0, _dominance = 2.0;

/// How far the rows slide for a finger [pulled] px left of where it went down.
double raftTimeRevealOffset(double pulled) {
  if (!(pulled > 0)) return 0;
  if (pulled <= raftTimeRevealDistance) return pulled;
  final band =
      raftTimeRevealDistance +
      (pulled - raftTimeRevealDistance) * raftTimeRevealRubberBand;
  return band < raftTimeRevealMax ? band : raftTimeRevealMax;
}

enum _Decision { undecided, claim, release }

/// Web `rowSwipeDecision` for a leftward-only swipe.
_Decision _decide(double dx, double dy) {
  final adx = dx.abs(), ady = dy.abs();
  if (ady >= _touchSlop && adx <= _dominance * ady) return _Decision.release;
  if (adx < _claimDistance || adx <= _dominance * ady) {
    return _Decision.undecided;
  }
  return dx < 0 ? _Decision.claim : _Decision.release;
}

/// Whether a drag that starts at [position] is left to what it starts on.
bool _excludedStart(Offset position, int viewId) {
  final result = HitTestResult();
  WidgetsBinding.instance.hitTestInView(result, position, viewId);
  for (final entry in result.path) {
    final target = entry.target;
    if (target is RenderMetaData &&
        identical(target.metaData, raftMessageTapControl)) {
      return true;
    }
    if (target is RenderEditable) return true;
    if (target is RenderViewportBase &&
        target.axis == Axis.horizontal &&
        target.offset is ScrollPosition) {
      final position = target.offset as ScrollPosition;
      if (position.hasContentDimensions && position.maxScrollExtent > 0) {
        return true;
      }
    }
  }
  return false;
}

/// The rows' slide while the conversation is dragged (px to the left, 0 at
/// rest), for [RaftMessageRow]s under a [RaftTimelineTimeReveal].
class RaftTimeRevealScope extends InheritedWidget {
  const RaftTimeRevealScope({
    super.key,
    required this.offset,
    required super.child,
  });
  final ValueListenable<double> offset;

  static ValueListenable<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RaftTimeRevealScope>()?.offset;

  @override
  bool updateShouldNotify(RaftTimeRevealScope oldWidget) =>
      oldWidget.offset != offset;
}

/// Wraps a conversation's message list with the touch time reveal.
class RaftTimelineTimeReveal extends StatefulWidget {
  const RaftTimelineTimeReveal({super.key, required this.child, this.enabled});
  final Widget child;

  /// False while a popup is open over the list (a menu, the reaction bar) or
  /// the list has another mode (select mode): the drag is left alone.
  final bool Function()? enabled;

  @override
  State<RaftTimelineTimeReveal> createState() => _RaftTimelineTimeRevealState();
}

class _RaftTimelineTimeRevealState extends State<RaftTimelineTimeReveal>
    with SingleTickerProviderStateMixin {
  final offset = ValueNotifier<double>(0);
  late final settle = AnimationController(
    vsync: this,
    duration: raftTimeRevealSettle,
  )..addListener(_settled);
  double _settleFrom = 0;
  int? _pointer;
  Offset _start = Offset.zero;
  int _viewId = 0;
  var _decision = _Decision.release;
  int _pointers = 0;

  void _settled() {
    offset.value = _settleFrom * (1 - Curves.easeOut.transform(settle.value));
  }

  void _springBack() {
    if (offset.value == 0) return;
    _settleFrom = offset.value;
    settle.forward(from: 0);
  }

  void _end() {
    final claimed = _decision == _Decision.claim;
    _pointer = null;
    _decision = _Decision.release;
    if (claimed) _springBack();
  }

  void _down(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    _pointers++;
    // A second finger: a pinch, never a reveal. A new touch ends the last
    // stroke, springing it back if it was claimed.
    _end();
    if (_pointers != 1) return;
    final width = MediaQuery.sizeOf(context).width;
    final x = event.position.dx;
    if (x < raftTimeRevealEdgeZone || width - x < raftTimeRevealEdgeZone) {
      return;
    }
    // A reveal still settling from the last stroke ends here.
    settle.stop();
    offset.value = 0;
    _pointer = event.pointer;
    _start = event.position;
    _viewId = event.viewId;
    _decision = _Decision.undecided;
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer || _decision == _Decision.release) return;
    final delta = event.position - _start;
    if (_decision == _Decision.undecided) {
      _decision = _decide(delta.dx, delta.dy);
      if (_decision != _Decision.claim) return;
      // About to claim: leave the drag to what it started in, to any popup,
      // and to reduced motion (nothing slides).
      if (MediaQuery.disableAnimationsOf(context) ||
          !(widget.enabled?.call() ?? true) ||
          _excludedStart(_start, _viewId)) {
        _decision = _Decision.release;
        return;
      }
    }
    offset.value = raftTimeRevealOffset(_start.dx - event.position.dx);
  }

  void _up(PointerEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    if (_pointers > 0) _pointers--;
    if (event.pointer == _pointer) _end();
  }

  @override
  void dispose() {
    settle.dispose();
    offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _up,
    onPointerCancel: _up,
    child: RaftTimeRevealScope(offset: offset, child: widget.child),
  );
}

/// A row's slide and its time, 20px past its right edge, coming in as the
/// conversation is dragged left. Hidden from assistive technology (the row is
/// already named by its time).
class RaftTimeRevealRow extends StatelessWidget {
  const RaftTimeRevealRow({
    super.key,
    required this.time,
    required this.timeStyle,
    required this.timeTop,
    required this.child,
  });
  final String time;
  final TextStyle timeStyle;

  /// Where the time sits from the row's top (its first text line).
  final double timeTop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final offset = RaftTimeRevealScope.maybeOf(context);
    if (offset == null) return child;
    return ValueListenableBuilder<double>(
      valueListenable: offset,
      child: child,
      // One shape at rest and while dragged: the row is never remounted.
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(-value, 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              child!,
              if (value > 0)
                Positioned(
                  top: timeTop,
                  right: 0,
                  child: FractionalTranslation(
                    translation: const Offset(1, 0),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: ExcludeSemantics(
                        child: Text(
                          time,
                          key: const ValueKey('timeline-reveal-time'),
                          maxLines: 1,
                          softWrap: false,
                          style: timeStyle,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
