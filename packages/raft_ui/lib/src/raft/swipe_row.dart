// Swipe a list row sideways to uncover action buttons, as Web v1.24
// `hooks/useRowSwipe.ts` (raft-ui 0.95.3 has no swipeable row; this is the
// Web app's own, ported 1:1): touch only, a claim rule against the list's
// vertical scroll, a 24px edge zone, a side's buttons 72px each, full swipe at
// 60% of the row, open past half the buttons or a 800px/s flick, 200ms settle.
//
// A gesture shell: it knows no store, API or toast. The parent owns which row
// is open ([open], [onOpenChange]) so one row is open at a time.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../icons.dart';
import '../theme.dart';
import '../tokens/tokens.dart';
import 'ui_tokens.dart';

/// A touch slop (px) before a press is a drag.
const double raftSwipeTouchSlop = 10;

/// A swipe claims the drag at twice the slop.
const double raftSwipeClaimDistance = 2 * raftSwipeTouchSlop;

/// A claim needs the horizontal distance to be more than this many times the vertical one.
const double raftSwipeDominanceRatio = 2;

/// A drag that starts this close to either row edge is never claimed.
const double raftSwipeEdgeZone = 24;

/// One action button's width.
const double raftSwipeButtonWidth = 72;

/// Past this share of a side's buttons' width a release leaves the row open.
const double raftSwipeOpenFraction = 0.5;

/// Past this share of the row's width the swipe is full.
const double raftSwipeFullFraction = 0.6;

/// A flick at least this fast (px/s) opens (away) or closes (back) the row.
const double raftSwipeFlingVelocity = 800;

/// How long the row takes to slide open, closed or away.
const Duration raftSwipeSettle = Duration(milliseconds: 200);

/// How long the full-swipe growth of the first button takes.
const Duration raftSwipeGrow = Duration(milliseconds: 150);

const Duration _velocityWindow = Duration(milliseconds: 100);

/// A side of the row, as in Web: the `end` buttons sit at the row's end and a
/// swipe left (LTR) uncovers them; the `start` buttons a swipe right.
enum RaftSwipeEdge { start, end }

/// How a stroke that moved ([dx], [dy]) is read (Web `rowSwipeDecision`).
enum RaftSwipeDecision { undecided, claim, release }

/// What a release does (Web `rowSwipeRelease`).
enum RaftSwipeRelease { full, open, close }

/// Web `rowSwipeDecision`. [left] / [right]: whether a move that way may be
/// claimed (physical directions).
RaftSwipeDecision raftSwipeDecision(
  double dx,
  double dy, {
  bool startsInEdgeZone = false,
  bool left = true,
  bool right = false,
}) {
  final adx = dx.abs(), ady = dy.abs();
  if (startsInEdgeZone) {
    return adx >= raftSwipeTouchSlop || ady >= raftSwipeTouchSlop
        ? RaftSwipeDecision.release
        : RaftSwipeDecision.undecided;
  }
  if (ady >= raftSwipeTouchSlop && adx <= raftSwipeDominanceRatio * ady) {
    return RaftSwipeDecision.release;
  }
  if (adx < raftSwipeClaimDistance || adx <= raftSwipeDominanceRatio * ady) {
    return RaftSwipeDecision.undecided;
  }
  return (dx < 0 ? left : right)
      ? RaftSwipeDecision.claim
      : RaftSwipeDecision.release;
}

/// Web `rowSwipeFull`.
bool raftSwipeIsFull(double reveal, double rowWidth) =>
    rowWidth > 0 && reveal >= rowWidth * raftSwipeFullFraction;

/// Web `rowSwipeRelease`: [velocity] px/s, positive further open.
RaftSwipeRelease raftSwipeRelease(
  double reveal,
  double velocity,
  double rowWidth,
  double actionsWidth,
) {
  if (raftSwipeIsFull(reveal, rowWidth)) return RaftSwipeRelease.full;
  if (velocity >= raftSwipeFlingVelocity) return RaftSwipeRelease.open;
  if (velocity <= -raftSwipeFlingVelocity) return RaftSwipeRelease.close;
  return reveal > 0 && reveal >= actionsWidth * raftSwipeOpenFraction
      ? RaftSwipeRelease.open
      : RaftSwipeRelease.close;
}

/// `success` is Done (solid, ink text); `quiet` the rest (muted fill).
enum RaftSwipeActionTone { quiet, success }

/// What a full swipe does with the row: [remove] slides it out across its
/// width (Done) and runs the action as it leaves; [keep] slides it back closed
/// and runs the action (Read / Unread).
enum RaftSwipeFull { remove, keep }

/// One 72px button under the row.
@immutable
class RaftSwipeAction {
  const RaftSwipeAction({
    required this.label,
    required this.glyph,
    required this.onPressed,
    this.tone = RaftSwipeActionTone.quiet,
    this.buttonKey,
  });
  final String label;
  final RaftGlyph glyph;
  final VoidCallback onPressed;
  final RaftSwipeActionTone tone;
  final Key? buttonKey;
}

/// One side's buttons. [actions] go outer edge first; the first is the one a
/// full swipe applies ([onFull] defaults to its [RaftSwipeAction.onPressed]).
@immutable
class RaftSwipeActions {
  const RaftSwipeActions({
    required this.actions,
    this.full = RaftSwipeFull.remove,
    this.onFull,
  }) : assert(actions.length > 0);
  final List<RaftSwipeAction> actions;
  final RaftSwipeFull full;
  final VoidCallback? onFull;

  double get width => actions.length * raftSwipeButtonWidth;
}

/// A row that swipes sideways to uncover buttons. Wraps any [child].
///
/// [leading] is uncovered by swiping right (Web `start`), [trailing] by
/// swiping left (Web `end`) in LTR; both flip in RTL. Swiping works only with
/// [enabled] (the app passes compact width and touch) and only for a touch
/// pointer: a mouse or pen never drags. [open] says which side rests open
/// (null: closed); the row asks for changes through [onOpenChange].
///
/// Semantics: each action is a custom semantics action on the row's node, as
/// the buttons themselves are decorative (Web `aria-hidden`).
class RaftSwipeRow extends StatefulWidget {
  const RaftSwipeRow({
    super.key,
    required this.child,
    required this.enabled,
    required this.open,
    required this.onOpenChange,
    this.leading,
    this.trailing,
    this.haptics = true,
  });

  final Widget child;
  final bool enabled;
  final RaftSwipeEdge? open;
  final ValueChanged<RaftSwipeEdge?> onOpenChange;
  final RaftSwipeActions? leading;
  final RaftSwipeActions? trailing;

  /// A tick on each crossing into full, on Android (where Web vibrates).
  final bool haptics;

  @override
  State<RaftSwipeRow> createState() => RaftSwipeRowState();
}

class _Commit {
  _Commit(this.apply, this.keep);
  final VoidCallback apply;
  final bool keep;
}

@visibleForTesting
class RaftSwipeRowState extends State<RaftSwipeRow>
    with TickerProviderStateMixin {
  final _reveal = ValueNotifier<double>(0);
  RaftSwipeEdge _edge = RaftSwipeEdge.end;
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: raftSwipeSettle,
  );
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: raftSwipeGrow,
  );
  bool _full = false;
  bool _dragging = false;
  _Commit? _commit;
  double _from = 0, _to = 0;
  double _rowWidth = 0;
  final _samples = <(Duration, double)>[];
  bool _startsInEdge = false, _wasOpen = false;
  double _startX = 0, _claimX = 0, _baseReveal = 0, _strokeReveal = 0;
  bool _rtl = false;

  RaftSwipeActions? _actionsOf(RaftSwipeEdge e) =>
      e == RaftSwipeEdge.start ? widget.leading : widget.trailing;

  @override
  void initState() {
    super.initState();
    _settle.addListener(_onSettleTick);
    _settle.addStatusListener(_onSettleStatus);
    final open = widget.open;
    if (open != null && _actionsOf(open) != null) {
      _edge = open;
      _reveal.value = _actionsOf(open)!.width;
    }
  }

  @override
  void didUpdateWidget(RaftSwipeRow old) {
    super.didUpdateWidget(old);
    if (_dragging || _commit != null) return;
    final open = widget.open;
    if (open == null) {
      if (_reveal.value > 0 && !_settle.isAnimating) _slideTo(_edge, 0);
    } else if (old.open != open || !widget.enabled) {
      final actions = _actionsOf(open);
      if (actions != null && widget.enabled) _slideTo(open, actions.width);
    }
    if (!widget.enabled && _reveal.value > 0) _slideTo(_edge, 0);
  }

  @override
  void dispose() {
    final commit = _commit;
    _commit = null;
    _settle.dispose();
    _grow.dispose();
    _reveal.dispose();
    // A row that leaves mid-slide still applies what the person released.
    // ignore: raft_lints/avoid_unreviewed_idle_work -- one-shot microtask, not idle work: the owner's setState cannot run while the tree is unmounting this row.
    if (commit != null) scheduleMicrotask(commit.apply);
    super.dispose();
  }

  void _onSettleTick() {
    _reveal.value =
        _from + (_to - _from) * Curves.easeOut.transform(_settle.value);
  }

  void _onSettleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _finishSettle();
  }

  void _finishSettle() {
    final commit = _commit;
    if (commit == null) {
      if (_reveal.value == 0 && _full) _setFull(false);
      return;
    }
    _commit = null;
    if (commit.keep) {
      _reveal.value = 0;
      _setFull(false);
      commit.apply();
      return;
    }
    commit.apply();
    if (mounted) {
      _reveal.value = 0;
      _setFull(false);
    }
  }

  void _slideTo(RaftSwipeEdge edge, double target) {
    _edge = edge;
    _settle.stop();
    _from = _reveal.value;
    _to = target;
    if (MediaQuery.disableAnimationsOf(context) || _from == _to) {
      _reveal.value = target;
      return;
    }
    _settle.forward(from: 0);
  }

  void _setFull(bool value) {
    if (_full == value) return;
    setState(() => _full = value);
    if (value) {
      _grow.forward();
    } else {
      _grow.reverse();
    }
  }

  // ---- stroke, called by the recognizer ----

  bool _canStart(PointerDownEvent e) {
    if (!widget.enabled || _commit != null) return false;
    if (widget.leading == null &&
        widget.trailing == null &&
        _reveal.value == 0) {
      return false;
    }
    return true;
  }

  void _down(PointerDownEvent e) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(e.position);
    _rowWidth = box.size.width;
    _rtl = Directionality.of(context) == TextDirection.rtl;
    _startsInEdge =
        local.dx < raftSwipeEdgeZone ||
        _rowWidth - local.dx < raftSwipeEdgeZone;
    _wasOpen = widget.open != null && _reveal.value > 0;
    _startX = e.position.dx;
    _claimX = _startX;
    _baseReveal = _reveal.value;
    _strokeReveal = _reveal.value;
    _samples
      ..clear()
      ..add((e.timeStamp, e.position.dx));
  }

  RaftSwipeDecision _decide(Offset delta) {
    final sgn = _rtl ? -1.0 : 1.0;
    final dx = delta.dx * sgn;
    bool has(RaftSwipeEdge e) => _actionsOf(e) != null;
    return raftSwipeDecision(
      dx,
      delta.dy,
      startsInEdgeZone: _startsInEdge,
      left: _wasOpen || has(RaftSwipeEdge.end),
      right: _wasOpen || has(RaftSwipeEdge.start),
    );
  }

  void _claim(double x) {
    _settle.stop();
    _dragging = true;
    final dx = (x - _startX) * (_rtl ? -1 : 1);
    final edge = _wasOpen
        ? _edge
        : (dx < 0 ? RaftSwipeEdge.end : RaftSwipeEdge.start);
    _baseReveal = edge == _edge ? _reveal.value : 0;
    _edge = edge;
    _claimX = x;
  }

  void _move(PointerMoveEvent e) {
    final sgn = _rtl ? -1.0 : 1.0;
    final moved = _edge == RaftSwipeEdge.end
        ? (_claimX - e.position.dx) * sgn
        : (e.position.dx - _claimX) * sgn;
    final width = _actionsOf(_edge)?.width ?? 0;
    // Pulled past the buttons the row keeps following up to its own width.
    _strokeReveal = (_baseReveal + moved).clamp(0.0, _rowWidth).toDouble();
    _samples.add((e.timeStamp, e.position.dx));
    if (_samples.length > 8) _samples.removeAt(0);
    final full = raftSwipeIsFull(_strokeReveal, _rowWidth) && width > 0;
    if (full &&
        !_full &&
        widget.haptics &&
        Theme.of(context).platform == TargetPlatform.android) {
      HapticFeedback.selectionClick();
    }
    _setFull(full);
    _reveal.value = _strokeReveal;
  }

  void _up(PointerUpEvent e) {
    _dragging = false;
    final edge = _edge;
    final recent = _samples.where((s) => e.timeStamp - s.$1 <= _velocityWindow);
    final first = recent.isEmpty ? null : recent.first;
    final elapsed = first == null ? 0 : (e.timeStamp - first.$1).inMicroseconds;
    final sgn = _rtl ? -1.0 : 1.0;
    final moved = first == null
        ? 0.0
        : (edge == RaftSwipeEdge.end
                  ? first.$2 - e.position.dx
                  : e.position.dx - first.$2) *
              sgn;
    final velocity = elapsed > 0 ? moved / elapsed * 1e6 : 0.0;
    final actions = _actionsOf(edge);
    final release = actions == null
        ? RaftSwipeRelease.close
        : raftSwipeRelease(_strokeReveal, velocity, _rowWidth, actions.width);
    switch (release) {
      case RaftSwipeRelease.full when actions != null:
        widget.onOpenChange(null);
        _fullSwipe(edge, actions);
      case RaftSwipeRelease.open when actions != null:
        _slideTo(edge, actions.width);
        widget.onOpenChange(edge);
      default:
        _slideTo(edge, 0);
        _setFull(false);
        widget.onOpenChange(null);
    }
  }

  void _cancel() {
    if (!_dragging) return;
    _dragging = false;
    _slideTo(_edge, 0);
    _setFull(false);
    widget.onOpenChange(null);
  }

  void _fullSwipe(RaftSwipeEdge edge, RaftSwipeActions actions) {
    final apply = actions.onFull ?? actions.actions.first.onPressed;
    final keep = actions.full == RaftSwipeFull.keep;
    _commit = _Commit(apply, keep);
    if (MediaQuery.disableAnimationsOf(context)) {
      _finishSettle();
      return;
    }
    _settle.stop();
    _from = _reveal.value;
    _to = keep ? 0 : _rowWidth;
    if (keep) _setFull(false);
    _settle.forward(from: 0);
  }

  void _press(RaftSwipeAction action) {
    action.onPressed();
    widget.onOpenChange(null);
  }

  Widget _layer(BuildContext context, double reveal) {
    final actions = _actionsOf(_edge);
    if (actions == null || reveal <= 0) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final list = actions.actions;
    final n = list.length;
    final base = math.max(raftSwipeButtonWidth, reveal / n);
    final f = Curves.easeOut.transform(_grow.value);
    double widthOf(int i) =>
        i == 0 ? base + f * (reveal - base) : base * (1 - f);
    final start = _edge == RaftSwipeEdge.start;
    // Outer edge first: the end layer lists them inward from its outer
    // (trailing) edge, so reverse for a left-to-right row.
    final children = <Widget>[
      for (var i = 0; i < n; i++)
        _button(context, t, ui, list[i], widthOf(i), single: n == 1 && start),
    ];
    final ordered = start ? children : children.reversed.toList();
    return Positioned.fill(
      child: Align(
        alignment: AlignmentDirectional(start ? -1 : 1, 0),
        child: ClipRect(
          child: SizedBox(
            width: reveal,
            child: OverflowBox(
              alignment: AlignmentDirectional(start ? -1 : 1, 0),
              minWidth: 0,
              maxWidth: double.infinity,
              child: Row(mainAxisSize: MainAxisSize.min, children: ordered),
            ),
          ),
        ),
      ),
    );
  }

  Widget _button(
    BuildContext context,
    RaftTokens t,
    RaftUiColors ui,
    RaftSwipeAction a,
    double width, {
    required bool single,
  }) {
    final success = a.tone == RaftSwipeActionTone.success;
    final bg = success ? ui.success : ui.fillMuted;
    final fg = success ? ui.stickerInk : ui.foreground;
    final label = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RaftIcon(a.glyph, size: 18, color: fg),
        const SizedBox(height: 4),
        Text(
          a.label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: t.scale(
            RaftTypeScale.caption,
            weight: FontWeight.w600,
            color: fg,
          ),
        ),
      ],
    );
    return ExcludeSemantics(
      child: GestureDetector(
        key: a.buttonKey,
        behavior: HitTestBehavior.opaque,
        onTap: () => _press(a),
        child: Container(
          width: width,
          color: bg,
          alignment: single && _full
              ? AlignmentDirectional.centerEnd
              : Alignment.center,
          child: SizedBox(
            width: single ? raftSwipeButtonWidth : null,
            child: label,
          ),
        ),
      ),
    );
  }

  Map<CustomSemanticsAction, VoidCallback> _semanticActions() => {
    for (final side in RaftSwipeEdge.values)
      if (_actionsOf(side) != null)
        for (final a in _actionsOf(side)!.actions)
          CustomSemanticsAction(label: a.label): () => _press(a),
  };

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final recognizers = widget.enabled
        ? <Type, GestureRecognizerFactory>{
            _RowSwipeRecognizer:
                GestureRecognizerFactoryWithHandlers<_RowSwipeRecognizer>(
                  () => _RowSwipeRecognizer(this),
                  (_) {},
                ),
          }
        : const <Type, GestureRecognizerFactory>{};
    final row = ListenableBuilder(
      listenable: Listenable.merge([_reveal, _grow]),
      builder: (context, content) {
        final reveal = _reveal.value;
        final shift =
            (_edge == RaftSwipeEdge.start ? reveal : -reveal) * (rtl ? -1 : 1);
        return Stack(
          children: [
            _layer(context, reveal),
            Transform.translate(offset: Offset(shift, 0), child: content),
            // Open: a tap on the row closes it and does nothing else.
            if (widget.open != null && reveal > 0 && !_dragging)
              Positioned.fill(
                left:
                    _edge == RaftSwipeEdge.start && !rtl ||
                        _edge == RaftSwipeEdge.end && rtl
                    ? reveal
                    : 0,
                right:
                    _edge == RaftSwipeEdge.end && !rtl ||
                        _edge == RaftSwipeEdge.start && rtl
                    ? reveal
                    : 0,
                child: ExcludeSemantics(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onOpenChange(null),
                  ),
                ),
              ),
          ],
        );
      },
      child: widget.child,
    );
    return Semantics(
      container: true,
      customSemanticsActions: widget.enabled ? _semanticActions() : null,
      child: ClipRect(
        child: RawGestureDetector(
          behavior: HitTestBehavior.translucent,
          gestures: recognizers,
          child: row,
        ),
      ),
    );
  }
}

/// Reads one touch stroke the way Web `useRowSwipe` does and takes part in the
/// gesture arena: claims on a clear sideways move, rejects as soon as the
/// stroke is vertical, so the list's scroll gets it.
class _RowSwipeRecognizer extends OneSequenceGestureRecognizer {
  _RowSwipeRecognizer(this._row)
    : super(supportedDevices: const {PointerDeviceKind.touch});

  final RaftSwipeRowState _row;
  int? _pointer;
  Offset _origin = Offset.zero;
  RaftSwipeDecision _decision = RaftSwipeDecision.undecided;

  @override
  String get debugDescription => 'row swipe';

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      _pointer == null &&
      _row._canStart(event) &&
      super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _pointer = event.pointer;
    _origin = event.position;
    _decision = RaftSwipeDecision.undecided;
    _row._down(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
      if (_decision == RaftSwipeDecision.release) return;
      if (_decision == RaftSwipeDecision.undecided) {
        _decision = _row._decide(event.position - _origin);
        if (_decision == RaftSwipeDecision.release) {
          resolve(GestureDisposition.rejected);
          return;
        }
        if (_decision == RaftSwipeDecision.claim) {
          _row._claim(event.position.dx);
          resolve(GestureDisposition.accepted);
        } else {
          return;
        }
      }
      _row._move(event);
    } else if (event is PointerUpEvent) {
      final claimed = _decision == RaftSwipeDecision.claim;
      _pointer = null;
      stopTrackingPointer(event.pointer);
      if (claimed) {
        _row._up(event);
      } else {
        resolve(GestureDisposition.rejected);
      }
    } else if (event is PointerCancelEvent) {
      final claimed = _decision == RaftSwipeDecision.claim;
      _pointer = null;
      stopTrackingPointer(event.pointer);
      if (claimed) _row._cancel();
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    super.rejectGesture(pointer);
    if (_pointer == pointer) _pointer = null;
  }
}
