import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;

import 'message_preparation.dart';
import 'timeline_scrollbar.dart';

/// A two-sided message timeline: older history grows away from a fixed
/// center, so loading it never moves the rows on screen.
///
/// Rows `[0, centerIndex)` live in the history sliver, built outward from the
/// center (history child `i` is row `centerIndex - 1 - i`); rows from
/// `centerIndex` on live in the forward (center) sliver. Prepending older rows
/// only appends children at the far end of the history sliver: no existing
/// child changes index or offset and no scroll position is corrected. Rows
/// arriving at the latest end are appended to the forward sliver, below the
/// reader. The center only moves on an explicit jump ([epoch]).
class RaftMessageTimeline extends StatefulWidget {
  const RaftMessageTimeline({
    super.key,
    required this.controller,
    required this.messages,
    required this.centerIndex,
    required this.epoch,
    required this.rowBuilder,
    required this.indexOfId,
    required this.slivers,
    this.estimateRow,
    this.empty,
    this.hasOlder = false,
    this.loadingOlder = false,
    this.onLoadOlder,
    this.hasNewer = false,
    this.onLoadNewer,
    this.onRecenter,
    this.cacheExtent,
    this.canPrepareNearbyRows,
  });

  final RaftTimelineScrollController controller;
  final List<chat.Message> messages;
  final int centerIndex;

  /// Changes whenever the center is re-chosen; both lists are rebuilt so no
  /// child keeps an offset measured against the previous center.
  final int epoch;
  final Widget Function(BuildContext context, int index) rowBuilder;
  final int? Function(String id) indexOfId;
  final double Function(int index)? estimateRow;

  /// The scroll view's slivers, top to bottom, around the history and the
  /// forward (center) lists (e.g. header, sentinels, footer).
  final List<Widget> Function(Widget history, Widget forward) slivers;
  final Widget? empty;
  final bool hasOlder, loadingOlder;
  final VoidCallback? onLoadOlder;
  final bool hasNewer;
  final VoidCallback? onLoadNewer;

  /// Re-centers the timeline on row [index] and positions the next layout at
  /// [alignment] (the host owns the center). A scrollbar drag to a distant
  /// target uses it so only the rows around the target are built.
  final void Function(int index, RaftTimelineAlignment alignment)? onRecenter;
  final double? cacheExtent;

  /// Whether this visible pane can prepare nearby rows between input frames.
  ///
  /// When supplied, the default cache grows in small steps while idle, up to
  /// one viewport on either side. An explicit [cacheExtent] takes precedence.
  final bool Function()? canPrepareNearbyRows;

  /// Older history is requested within this many viewports of the top.
  static const double prefetchViewports = 2;

  /// Rows built so far (tests measure per-frame layout work).
  @visibleForTesting
  static int debugRowBuilds = 0;

  @override
  State<RaftMessageTimeline> createState() => _RaftMessageTimelineState();
}

class _RaftMessageTimelineState extends State<RaftMessageTimeline>
    implements RaftTimelineThumbDriver {
  double nearbyCache = 250;
  final _keyboardOlderScroll = _KeyboardOlderScrollAction();

  /// Inside the timeline scrollable, so a key here resolves to this list.
  /// Traversal skips it; a tap requests it. Inner controls stay descendants.
  final _timelineFocus = FocusNode(debugLabel: 'timeline', skipTraversal: true);
  RaftMessageTimeline? listsOwner;
  Widget? historyList, forwardList;
  late final nearbyPreparation = MessagePreparation(
    isIdle: () =>
        mounted &&
        TickerMode.valuesOf(context).enabled &&
        widget.cacheExtent == null &&
        (widget.canPrepareNearbyRows?.call() ?? false),
  );

  void prepareNearbyRows() {
    nearbyPreparation.replace(
      List.generate(
        64,
        (_) => () {
          final position = singlePosition;
          if (position == null) return;
          final target = position.viewportDimension;
          if (nearbyCache >= target) {
            if (nearbyCache > target) setState(() => nearbyCache = target);
            nearbyPreparation.cancel();
            return;
          }
          setState(() => nearbyCache = math.min(target, nearbyCache + 128));
        },
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TickerMode.valuesOf(context).enabled &&
        widget.canPrepareNearbyRows != null) {
      prepareNearbyRows();
    } else {
      nearbyPreparation.cancel();
      nearbyCache = 250;
    }
  }

  @override
  void dispose() {
    _timelineFocus.dispose();
    nearbyPreparation.dispose();
    super.dispose();
  }

  /// The user's scroll direction ([UserScrollNotification]); programmatic
  /// moves (jumps, alignments, animations) leave it idle.
  ScrollDirection userDirection = ScrollDirection.idle;

  /// A page was requested in this reach of the top region. The next request
  /// needs the reader to leave the region, or the page to land and the user
  /// to move toward older history again (Web: one page per top-sentinel
  /// intersection). A page landing, a layout or a metrics change never
  /// requests one by itself.
  bool spent = false;
  bool newerSpent = false;

  @override
  void didUpdateWidget(RaftMessageTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Expanded layout is idle work; foreground updates restore the default margin.
    nearbyCache = 250;
    if (widget.canPrepareNearbyRows != null && widget.cacheExtent == null) {
      prepareNearbyRows();
    } else {
      nearbyPreparation.cancel();
    }
    if (!identical(oldWidget.controller, widget.controller)) {
      spent = false;
      newerSpent = false;
      userDirection = ScrollDirection.idle;
      thumb = null;
    }
    // Landed (or failed): the next user move toward older may request again.
    if (oldWidget.loadingOlder && !widget.loadingOlder) {
      spent = false;
      newerSpent = false;
    }
  }

  ScrollPosition? get singlePosition {
    final controller = widget.controller;
    if (controller.positions.length != 1) return null;
    final position = controller.position;
    return position.hasContentDimensions && position.hasViewportDimension
        ? position
        : null;
  }

  bool nearTop(ScrollPosition position) =>
      position.extentBefore <=
      math.max(
        200.0,
        position.viewportDimension * RaftMessageTimeline.prefetchViewports,
      );

  /// The user moved toward older history.
  void userMovedOlder() {
    final load = widget.onLoadOlder, position = singlePosition;
    if (position == null || !nearTop(position)) return;
    if (spent ||
        load == null ||
        !widget.hasOlder ||
        widget.loadingOlder ||
        widget.controller.pending != null) {
      return;
    }
    spent = true;
    load();
  }

  void rearmOutsideTop() {
    final position = singlePosition;
    if (spent &&
        !widget.loadingOlder &&
        position != null &&
        !nearTop(position)) {
      spent = false;
    }
  }

  void userMovedNewer() {
    final position = singlePosition, load = widget.onLoadNewer;
    if (position == null) return;
    final near =
        position.extentAfter <=
        math.max(
          200.0,
          position.viewportDimension * RaftMessageTimeline.prefetchViewports,
        );
    if (!near) {
      newerSpent = false;
      return;
    }
    if (newerSpent ||
        load == null ||
        !widget.hasNewer ||
        widget.loadingOlder ||
        widget.controller.pending != null) {
      return;
    }
    newerSpent = true;
    load();
  }

  bool onNotification(Notification notification) {
    // Only the timeline itself, not scrollables inside rows.
    if (notification is ScrollNotification && notification.depth != 0) {
      return false;
    }
    if (notification is ScrollStartNotification &&
        widget.cacheExtent == null &&
        widget.canPrepareNearbyRows != null) {
      nearbyPreparation.cancel();
      if (nearbyCache != 250) setState(() => nearbyCache = 250);
    } else if (notification is ScrollEndNotification &&
        widget.canPrepareNearbyRows != null) {
      prepareNearbyRows();
    }
    if (notification is UserScrollNotification) {
      userDirection = notification.direction;
    } else if (notification is ScrollUpdateNotification) {
      // Forward = toward the top (older history).
      if ((notification.scrollDelta ?? 0) < 0 &&
          userDirection == ScrollDirection.forward) {
        userMovedOlder();
      } else {
        rearmOutsideTop();
        if ((notification.scrollDelta ?? 0) > 0 &&
            userDirection == ScrollDirection.reverse) {
          userMovedNewer();
        }
      }
    } else if (notification is OverscrollNotification) {
      // Pulling at the temporary top (e.g. after a failed page).
      if (notification.overscroll < 0 &&
          userDirection == ScrollDirection.forward) {
        userMovedOlder();
      }
      if (notification.overscroll > 0 &&
          userDirection == ScrollDirection.reverse) {
        userMovedNewer();
      }
    } else if (notification is ScrollMetricsNotification) {
      rearmOutsideTop();
    }
    return false;
  }

  // Scrollbar thumb drags: the thumb maps to a model of the content frozen
  // at the press (row extents, scroll range), so the content moves exactly
  // with the pointer and nothing that lands or is measured meanwhile moves
  // the thumb under it. Corrections apply after release.
  _ThumbModel? thumb;

  @override
  double? beginThumbDrag() {
    final position = singlePosition;
    final messages = widget.messages;
    if (position == null || messages.isEmpty) return thumb = null;
    final n = messages.length;
    final estimate = widget.estimateRow ?? (_) => 96.0;
    final cum = Float64List(n + 1);
    for (var i = 0; i < n; i++) {
      cum[i + 1] = cum[i] + estimate(i);
    }
    final base =
        cum[widget.centerIndex.clamp(0, n)] -
        widget.controller.anchor * position.viewportDimension;
    final lo = base + position.minScrollExtent;
    final hi = base + position.maxScrollExtent;
    if (hi - lo < 1) return thumb = null;
    thumb = _ThumbModel(messages.first.id, cum, lo, hi);
    return ((base + position.pixels - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  @override
  void moveThumb(double fraction) {
    final model = thumb, position = singlePosition;
    if (model == null || position is! RaftTimelinePosition) return;
    final f = fraction.clamp(0.0, 1.0);
    // Rows prepended since the press shift every index (counted in the
    // built list: the host's window may already be ahead of this build).
    final messages = widget.messages;
    var shift = 0;
    while (shift < messages.length && messages[shift].id != model.firstId) {
      shift++;
    }
    if (shift == messages.length) return;
    final rows = model.cum.length - 1;
    final pending = widget.controller.pending != null;
    final center = widget.centerIndex.clamp(0, messages.length) - shift;
    final extent = position.viewportDimension;
    final anchor = widget.controller.anchor;
    // The model's y of the viewport top now (null while a re-center lays
    // out or the center row is not in the model).
    final current = !pending && center >= 0 && center <= rows
        ? model.cum[center] + position.pixels - anchor * extent
        : null;
    final top = f <= 0, bottom = f >= 1;
    if (top || bottom) {
      // The track's ends are the content's real ends (estimates measured
      // during the drag moved them) ...
      final real = top ? shift == 0 : shift + rows == messages.length;
      // ... unless rows landed there since the press: those stay beyond
      // the thumb until it is released, and the content stays put.
      if (!real || pending) return;
      model.edge = top ? -1 : 1;
      final edge = top ? position.minScrollExtent : position.maxScrollExtent;
      if ((edge - position.pixels).abs() <= extent * 3 ||
          widget.onRecenter == null) {
        position.thumbTo(edge);
      } else {
        widget.onRecenter!(
          top ? 0 : messages.length - 1,
          top ? RaftTimelineAlignment.start : RaftTimelineAlignment.end,
        );
      }
      // Holding the thumb at the top keeps reaching for older history.
      if (top) userMovedOlder();
      return;
    }
    if (model.edge != 0) {
      // Leaving an end the content snapped to: continue from where it is,
      // so the estimate error at that end is not jumped over.
      if (current == null) return;
      if (model.edge < 0) {
        model.lo = (current - f * model.hi) / (1 - f);
      } else {
        model.hi = model.lo + (current - model.lo) / f;
      }
      model.edge = 0;
    }
    final y = model.lo + f * (model.hi - model.lo);
    if (current != null) {
      final delta = y - current;
      // Near targets lay out only the rows in between: up to a few screens
      // that costs less than building a fresh center (a screen plus both
      // cache extents, every row mounted anew).
      if (delta.abs() <= extent * 3 || widget.onRecenter == null) {
        position.thumbTo(position.pixels + delta);
        return;
      }
    }
    // Far targets: build only the rows around the target (a new center)
    // instead of laying out the whole distance in one frame.
    var low = 0, high = rows - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (model.cum[mid] <= y) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    widget.onRecenter!(
      low + shift,
      RaftTimelineAlignment.row(leading: model.cum[low] - y),
    );
  }

  @override
  void endThumbDrag() {
    thumb = null;
    final position = singlePosition;
    if (position is RaftTimelinePosition) position.endThumb();
  }

  /// A blank tap joins the gesture arena inside the scroller. A child control
  /// is registered first and wins that tap. This recognizer leaves on the
  /// first move, before the scroller sees it, so a drag and its fling stay
  /// with the list. The page must still be the current route.
  void _focusTimelineOnBlankTap() {
    if (!mounted || _timelineFocus.hasFocus) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _timelineFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    widget.controller.olderPending = widget.hasOlder;
    final messages = widget.messages;
    final center = widget.centerIndex.clamp(0, messages.length);
    if (!identical(listsOwner, widget) &&
        (listsOwner == null || TickerMode.valuesOf(context).enabled)) {
      // Hidden panes keep their existing delegates. Their next visible build
      // accepts the latest presentation before layout and paint.
      final owner = listsOwner = widget;
      final estimate = widget.estimateRow;
      // Seed once for this presentation. Layout updates the measured entries;
      // scrolling queries sums without walking the unbuilt history again.
      final extents = estimate == null
          ? null
          : _TimelineExtentIndex(messages.length, estimate);
      Widget row(BuildContext context, int index) {
        RaftMessageTimeline.debugRowBuilds++;
        final body = extents == null
            ? owner.rowBuilder(context, index)
            : _TimelineExtentRecorder(
                onExtent: (height) => extents.update(index, height),
                child: owner.rowBuilder(context, index),
              );
        return KeyedSubtree(
          key: ValueKey<String>(messages[index].id),
          child: body,
        );
      }

      historyList = SliverList(
        key: ValueKey('timeline-history-${widget.epoch}'),
        delegate: _EstimatingChildDelegate(
          (context, i) => row(context, center - 1 - i),
          childCount: center,
          remainingExtent: extents == null
              ? null
              : (first) => extents.sum(0, center - first),
          findChildIndexCallback: (key) {
            if (key is! ValueKey<String>) return null;
            final index = owner.indexOfId(key.value);
            return index == null || index >= center ? null : center - 1 - index;
          },
        ),
      );
      final forwardKey = ValueKey('timeline-forward-${widget.epoch}');
      forwardList = SliverList(
        key: forwardKey,
        delegate: _EstimatingChildDelegate(
          (context, i) => row(context, center + i),
          childCount: messages.length - center,
          remainingExtent: extents == null
              ? null
              : (first) => extents.sum(center + first, messages.length),
          findChildIndexCallback: (key) {
            if (key is! ValueKey<String>) return null;
            final index = owner.indexOfId(key.value);
            return index == null || index < center ? null : index - center;
          },
        ),
      );
    }
    final forwardKey = ValueKey('timeline-forward-${widget.epoch}');
    final slivers = widget.slivers(historyList!, forwardList!);
    final behavior = ScrollConfiguration.of(context);
    final scrollbar = switch (behavior.getPlatform(context)) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };
    Widget list = Actions(
      actions: <Type, Action<Intent>>{ScrollIntent: _keyboardOlderScroll},
      child: NotificationListener<Notification>(
        onNotification: onNotification,
        child: _TimelineScrollView(
          controller: widget.controller,
          // The timeline's own scrollbar replaces the platform default.
          scrollBehavior: scrollbar
              ? behavior.copyWith(scrollbars: false)
              : null,
          center: forwardKey,
          anchor: widget.controller.anchor,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          semanticChildCount: messages.length,
          scrollCacheExtent: ScrollCacheExtent.pixels(
            widget.cacheExtent ?? nearbyCache,
          ),
          slivers: slivers,
        ),
      ),
    );
    if (scrollbar) {
      list = RaftTimelineScrollbar(
        controller: widget.controller,
        driver: this,
        child: list,
      );
    }
    final empty = widget.empty;
    if (empty == null || messages.isNotEmpty) return list;
    return Stack(
      children: [
        list,
        Positioned.fill(child: empty),
      ],
    );
  }
}

/// Page Up, and Control or Command plus an arrow, on this timeline.
///
/// [ScrollAction] animates and leaves the user direction idle. A key that is
/// already at the top does not move, so the existing gate is asked here too.
class _KeyboardOlderScrollAction extends ScrollAction {
  @override
  void invoke(ScrollIntent intent, [BuildContext? context]) {
    final current = context;
    if (current != null) {
      final scrollable = Scrollable.maybeOf(current);
      final position = scrollable?.position;
      final physics = scrollable?.resolvedPhysics;
      if (scrollable != null &&
          position is RaftTimelinePosition &&
          (physics == null || physics.shouldAcceptUserOffset(position)) &&
          ScrollAction.getDirectionalIncrement(scrollable, intent) < 0) {
        position.noteKeyboardTowardOlder();
        current
            .findAncestorStateOfType<_RaftMessageTimelineState>()
            ?.userMovedOlder();
      }
    }
    super.invoke(intent, context);
  }
}

/// One-shot position for the next layout of a timeline: applied inside the
/// viewport's layout from actual geometry, so the first painted frame is
/// already in place.
sealed class RaftTimelineAlignment {
  const RaftTimelineAlignment();

  /// The latest end (newest row and footer at the bottom edge).
  static const RaftTimelineAlignment end = _EndAlignment();

  /// The oldest end (history state at the top edge).
  static const RaftTimelineAlignment start = _StartAlignment();

  /// The row found by [find] (default: the first row of the center sliver),
  /// at [alignment] of the free space (0.5 = vertically centered, Source
  /// `scrollIntoView({block: "center"})`), or with its top [leading] pixels
  /// below the viewport's top edge.
  const factory RaftTimelineAlignment.row({
    RenderBox? Function()? find,
    double alignment,
    double? leading,
  }) = _RowAlignment;
}

class _EndAlignment extends RaftTimelineAlignment {
  const _EndAlignment();
}

class _StartAlignment extends RaftTimelineAlignment {
  const _StartAlignment();
}

class _RowAlignment extends RaftTimelineAlignment {
  const _RowAlignment({this.find, this.alignment = .5, this.leading});
  final RenderBox? Function()? find;
  final double alignment;
  final double? leading;
}

/// Scroll controller of a [RaftMessageTimeline].
///
/// The scroll range is the actual content range on both sides of the center
/// (no blank space beyond either end). A timeline shorter than its viewport
/// rests at its latest end ([bottomAnchored]) or at its top. While the reader
/// is at the latest end, layout keeps it there ([RaftTimelinePosition.followEnd]).
class RaftTimelineScrollController extends ScrollController {
  RaftTimelineScrollController({
    required this.bottomAnchored,
    RaftTimelineAlignment? initial = RaftTimelineAlignment.end,
    super.debugLabel,
  }) : _pending = initial,
       super(keepScrollOffset: false);

  /// Channels keep their bottom edge fixed (resize, short content); threads
  /// keep their top edge fixed.
  final bool bottomAnchored;
  double get anchor => bottomAnchored ? 1 : 0;

  RaftTimelineAlignment? _pending;
  RaftTimelineAlignment? get pending => _pending;

  /// More history may load above: the top is not the real beginning, so it
  /// is never held (history lands above the reader instead).
  bool olderPending = false;

  /// Positions the next layout (after a re-centered rebuild) at [alignment].
  /// Starts from the center so the rebuilt lists never lay out the distance
  /// between the old and the new position.
  void align(RaftTimelineAlignment alignment) {
    _pending = alignment;
    if (positions.length == 1) {
      final p = position as RaftTimelinePosition;
      p.followEnd = p.followStart = false;
      p.restart();
    }
  }

  /// A message's Show more / Collapse: an expansion keeps the row where the
  /// reader sees it, a collapse reveals a row that ended outside the viewport.
  void messageExpansionChanged(bool open, BuildContext row) =>
      open ? holdViewport(row) : keepVisible(row);

  /// Web `preserveTimelineViewport`: expanding a message is a reading action,
  /// even at the live tail. [row] (inside the message) keeps its place on the
  /// screen and the message grows downward from it, instead of the latest end
  /// being followed (which would push the message's top out of view).
  void holdViewport(BuildContext row) {
    for (final p in positions) {
      (p as RaftTimelinePosition).followEnd = false;
    }
    final box = row.findRenderObject();
    final view = box is RenderBox && box.attached
        ? RenderAbstractViewport.maybeOf(box)
        : null;
    if (view is! RenderObject) return;
    final leading = MatrixUtils.transformPoint(
      (box as RenderBox).getTransformTo(view),
      Offset.zero,
    ).dy;
    _pending = RaftTimelineAlignment.row(
      find: () {
        final now = row.mounted ? row.findRenderObject() : null;
        return now is RenderBox ? now : null;
      },
      leading: leading,
    );
  }

  /// Web `keepTimelineMessageVisible`: after [row] collapsed, a row that
  /// ended wholly outside the viewport is revealed at its nearest edge. A row
  /// that is still partly visible leaves the list untouched.
  void keepVisible(BuildContext row) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = row.mounted ? row.findRenderObject() : null;
      if (box is! RenderBox || !box.attached || positions.length != 1) return;
      final viewport = RenderAbstractViewport.maybeOf(box);
      final p = position;
      if (viewport == null || !p.hasPixels || !p.hasViewportDimension) return;
      final top = viewport.getOffsetToReveal(box, 0).offset;
      final height = box.size.height;
      double? target;
      if (p.pixels - top >= height) {
        target = top;
      } else if (top - p.pixels >= p.viewportDimension) {
        target = viewport.getOffsetToReveal(box, 1).offset;
      }
      if (target == null || (target - p.pixels).abs() <= .5) return;
      for (final position in positions) {
        (position as RaftTimelinePosition).followEnd = false;
      }
      p.jumpTo(target);
    });
  }

  /// Keeps the latest end pinned from the next layout on.
  void followEnd() {
    for (final p in positions) {
      (p as RaftTimelinePosition).followEnd = true;
    }
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => RaftTimelinePosition(
    owner: this,
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
  );
}

class RaftTimelinePosition extends ScrollPositionWithSingleContext {
  RaftTimelinePosition({
    required this.owner,
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  final RaftTimelineScrollController owner;
  RaftTimelineRenderViewport? viewport;

  /// The reader is at the latest end: content changes keep it there.
  bool followEnd = false;

  /// The reader is at the top: while it is the real beginning, content
  /// changes keep it there (a growing head never pushes the rows up).
  bool followStart = false;
  int _rounds = 0;

  void _trackEnd() {
    if (owner._pending == null && hasContentDimensions) {
      followEnd = pixels >= maxScrollExtent - .5;
      // Reaching a temporary top never holds it: the page landing there
      // goes above the reader, even when it turns out to be the last one.
      followStart = !owner.olderPending && pixels <= minScrollExtent + .5;
    }
  }

  @override
  double setPixels(double newPixels) {
    final overscroll = super.setPixels(newPixels);
    _trackEnd();
    return overscroll;
  }

  @override
  void forcePixels(double value) {
    super.forcePixels(value);
    _trackEnd();
  }

  // Overscroll (iOS/macOS bounce, Android stretch) belongs to the user's
  // drag or fling. The app's own moves (jump to a message, return to latest,
  // re-center) stay inside the scroll range: targets are clamped, and an
  // animation ends at rest instead of handing its velocity to a spring.
  double _inRange(double value) => hasContentDimensions
      ? math.min(math.max(value, minScrollExtent), maxScrollExtent)
      : value;

  /// Back to the center for a re-centered rebuild, whose range is not laid
  /// out yet (the next layout positions it).
  void restart() => super.jumpTo(0);

  @override
  void jumpTo(double value) => super.jumpTo(_inRange(value));

  @override
  Future<void> animateTo(
    double to, {
    required Duration duration,
    required Curve curve,
  }) => super.animateTo(_inRange(to), duration: duration, curve: curve);

  @override
  void goBallistic(double velocity) =>
      super.goBallistic(activity is DrivenScrollActivity ? 0 : velocity);

  /// Page Up and modified arrow keys animate without setting a direction.
  /// The load gate reads this the same way it reads a finger moving older.
  void noteKeyboardTowardOlder() {
    updateUserScrollDirection(ScrollDirection.forward);
  }

  /// Moves to [value] for a scrollbar thumb drag, as a user scroll (load
  /// triggers see the user's direction).
  void thumbTo(double value) {
    final target = value.clamp(minScrollExtent, maxScrollExtent);
    if ((target - pixels).abs() < .01) return;
    if (activity is! _ThumbScrollActivity) {
      beginActivity(_ThumbScrollActivity(this));
    }
    updateUserScrollDirection(
      target < pixels ? ScrollDirection.forward : ScrollDirection.reverse,
    );
    setPixels(target);
  }

  /// The thumb was released.
  void endThumb() {
    if (activity is _ThumbScrollActivity) goBallistic(0);
  }

  double? _rowTarget(_RowAlignment align, RaftTimelineRenderViewport view) =>
      view.measure(() {
        final box = align.find?.call() ?? view.centerLeadingRow();
        if (box == null || !box.attached || !box.hasSize) return null;
        final Object? host = RenderAbstractViewport.maybeOf(box);
        if (!identical(host, view)) return null;
        // Laid out in this pass: its current offset from the viewport's top.
        final top = MatrixUtils.transformPoint(
          box.getTransformTo(view),
          Offset.zero,
        ).dy;
        final want =
            align.leading ??
            (viewportDimension - box.size.height) * align.alignment;
        return pixels + top - want;
      });

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    var lo = minScrollExtent, hi = maxScrollExtent;
    var short = false;
    final view = viewport;
    if (view != null && view.attached && identical(view.offset, this)) {
      if (view.refreshSparseFill()) return false;
      final (reverse, forward) = view.contentExtents();
      final extent = viewportDimension, anchor = view.anchor;
      // The content edges, without the viewport's floor at the center.
      lo = extent * anchor - reverse;
      hi = forward - extent * (1 - anchor);
      if (lo > hi) {
        short = true;
        lo = hi = owner.bottomAnchored ? hi : lo;
      }
    }
    final pending = owner._pending;
    // A user's drag, or the spring of their fling past an edge, owns the
    // position: following an edge would pin the content there every frame
    // while the spring keeps running (no bounce, extra layout rounds). The
    // spring itself settles on the edge, where following resumes.
    final dragging =
        activity is DragScrollActivity ||
        activity is _ThumbScrollActivity ||
        (activity is BallisticScrollActivity &&
            (pixels > hi + .5 || pixels < lo - .5));
    double? target;
    if (pending != null && view != null) {
      target = switch (pending) {
        _EndAlignment() => hi,
        _StartAlignment() => lo,
        final _RowAlignment row => _rowTarget(row, view),
      };
    } else if (followEnd && !dragging) {
      target = hi;
    } else if (followStart && !dragging) {
      target = lo;
    } else if (short && !dragging) {
      target = lo;
    }
    if (target != null) {
      final clamped = target.clamp(lo, hi);
      if ((clamped - pixels).abs() > .5 && _rounds < 12) {
        _rounds++;
        correctPixels(clamped);
        return false;
      }
    }
    _rounds = 0;
    if (pending != null && view != null) {
      owner._pending = null;
      followEnd = pending is _EndAlignment || (pixels - hi).abs() <= .5;
      followStart = !owner.olderPending && (pixels - lo).abs() <= .5;
    }
    return super.applyContentDimensions(lo, hi);
  }
}

class _TimelineScrollView extends CustomScrollView {
  const _TimelineScrollView({
    super.controller,
    super.center,
    super.anchor,
    super.keyboardDismissBehavior,
    super.semanticChildCount,
    super.scrollBehavior,
    super.scrollCacheExtent,
    super.slivers,
  });

  @override
  Widget buildViewport(
    BuildContext context,
    ViewportOffset offset,
    AxisDirection axisDirection,
    List<Widget> slivers,
  ) {
    final viewport = _TimelineViewport(
      axisDirection: axisDirection,
      offset: offset,
      slivers: slivers,
      center: center,
      anchor: anchor,
      scrollCacheExtent: scrollCacheExtent,
      paintOrder: paintOrder,
      clipBehavior: clipBehavior,
    );
    final state = context.findAncestorStateOfType<_RaftMessageTimelineState>();
    final focus = state?._timelineFocus;
    if (focus == null || state == null) return viewport;
    // Inside the scrollable, so a move rejects this tap before the drag
    // recognizer handles that same event.
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        _BlankTapRecognizer:
            GestureRecognizerFactoryWithHandlers<_BlankTapRecognizer>(
              () => _BlankTapRecognizer(),
              (_BlankTapRecognizer instance) {
                instance.onBlankTap = state._focusTimelineOnBlankTap;
              },
            ),
      },
      child: Focus(
        key: const ValueKey('timeline-focus'),
        focusNode: focus,
        skipTraversal: true,
        child: viewport,
      ),
    );
  }
}

/// Tap recognizer that lives inside the timeline scroller.
///
/// Child controls are added to the pointer router first, so they win a tap.
/// A move past the slop rejects this recognizer before the scroller's drag
/// handles that event, which leaves the drag and the fling on the list.
class _BlankTapRecognizer extends OneSequenceGestureRecognizer {
  VoidCallback? onBlankTap;
  Offset? _down;
  bool _moved = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton) return;
    super.addAllowedPointer(event);
    _down = event.position;
    _moved = false;
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      final down = _down;
      if (!_moved &&
          down != null &&
          (event.position - down).distance > kTouchSlop) {
        _moved = true;
        resolve(GestureDisposition.rejected);
      }
      return;
    }
    if (event is PointerUpEvent) {
      // A child control wins the sweep when it was added first. Accepting
      // here would take that tap. A drag already rejected this recognizer.
      return;
    }
    if (event is PointerCancelEvent) {
      resolve(GestureDisposition.rejected);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void acceptGesture(int pointer) {
    if (!_moved) onBlankTap?.call();
    stopTrackingPointer(pointer);
  }

  @override
  void rejectGesture(int pointer) {
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'timeline blank tap';
}

class _TimelineViewport extends Viewport {
  _TimelineViewport({
    super.axisDirection,
    super.anchor,
    required super.offset,
    super.center,
    super.scrollCacheExtent,
    super.paintOrder,
    super.clipBehavior,
    super.slivers,
  });

  @override
  RenderViewport createRenderObject(BuildContext context) =>
      RaftTimelineRenderViewport(
        axisDirection: axisDirection,
        crossAxisDirection:
            crossAxisDirection ??
            Viewport.getDefaultCrossAxisDirection(context, axisDirection),
        anchor: anchor,
        offset: offset,
        scrollCacheExtent: scrollCacheExtent,
        paintOrder: paintOrder,
        clipBehavior: clipBehavior,
      );
}

/// The timeline's viewport: reports its content extents to its
/// [RaftTimelinePosition], which owns the scroll range.
class RaftTimelineRenderViewport extends RenderViewport {
  RaftTimelineRenderViewport({
    super.axisDirection,
    required super.crossAxisDirection,
    required super.offset,
    super.anchor,
    super.scrollCacheExtent,
    super.paintOrder,
    super.clipBehavior,
  });

  @override
  void performLayout() {
    final position = offset;
    if (position is RaftTimelinePosition) position.viewport = this;
    super.performLayout();
  }

  /// [RenderViewport.getOffsetToReveal] measures from the center as if it
  /// sat at the leading edge; with an [anchor] the zero offset sits
  /// `anchor * extent` below it. Without this, `ensureVisible`, focus
  /// traversal and accessibility `showOnScreen` miss in a bottom-anchored
  /// timeline.
  @override
  RevealedOffset getOffsetToReveal(
    RenderObject target,
    double alignment, {
    Rect? rect,
    Axis? axis,
  }) {
    final revealed = super.getOffsetToReveal(
      target,
      alignment,
      rect: rect,
      axis: axis,
    );
    final shift =
        anchor * (this.axis == Axis.vertical ? size.height : size.width);
    if (shift == 0 || !revealed.offset.isFinite) return revealed;
    final delta = switch (axisDirection) {
      AxisDirection.down => Offset(0, -shift),
      AxisDirection.up => Offset(0, shift),
      AxisDirection.right => Offset(-shift, 0),
      AxisDirection.left => Offset(shift, 0),
    };
    return RevealedOffset(
      offset: revealed.offset + shift,
      rect: revealed.rect.shift(delta),
    );
  }

  /// Reads the geometry of rows laid out in this pass (allowed inside the
  /// viewport's own layout callback).
  T measure<T>(T Function() read) {
    late T result;
    invokeLayoutCallback<BoxConstraints>((_) => result = read());
    return result;
  }

  /// Scroll extents before and after the center, from the last layout.
  (double, double) contentExtents() {
    var reverse = 0.0, forward = 0.0, after = false;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if (identical(child, center)) after = true;
      final extent = child.geometry?.scrollExtent ?? 0;
      if (after) {
        forward += extent;
      } else {
        reverse += extent;
      }
    }
    return (reverse, forward);
  }

  /// The first row of the center sliver, if it is laid out.
  RenderBox? centerLeadingRow() {
    final sliver = center;
    if (sliver is! RenderSliverMultiBoxAdaptor) return null;
    final first = sliver.firstChild;
    return first != null && sliver.indexOf(first) == 0 ? first : null;
  }

  /// A sparse fill sizes itself from its siblings; one laid out before later
  /// siblings changed is laid out again within this layout.
  bool refreshSparseFill() {
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if (child is _RenderSparseFill && child.stale()) {
        final fill = child;
        invokeLayoutCallback<BoxConstraints>((_) => fill.markNeedsLayout());
        return true;
      }
    }
    return false;
  }
}

/// Fills the viewport space the rest of the timeline leaves empty, so a
/// short timeline keeps [child] at its edge (Source flex-grow spacer). For a
/// timeline longer than its viewport it is just [child]'s own height.
///
/// Its extent never moves rows: it sits on the outer side of the history.
class RaftTimelineSparseFill extends SingleChildRenderObjectWidget {
  const RaftTimelineSparseFill({super.key, super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSparseFill();
}

class _RenderSparseFill extends RenderSliverSingleBoxAdapter {
  double _others = 0;

  double _siblingExtents() {
    final view = parent;
    if (view is! RenderViewport) return 0;
    var total = 0.0;
    for (
      var child = view.firstChild;
      child != null;
      child = view.childAfter(child)
    ) {
      if (!identical(child, this)) total += child.geometry?.scrollExtent ?? 0;
    }
    return total;
  }

  bool stale() => (_siblingExtents() - _others).abs() > .5;

  @override
  void performLayout() {
    final c = constraints;
    _others = _siblingExtents();
    final spare = math.max(0.0, c.viewportMainAxisExtent - _others);
    var extent = spare;
    final box = child;
    if (box != null) {
      box.layout(c.asBoxConstraints(), parentUsesSize: true);
      final natural = c.axis == Axis.vertical
          ? box.size.height
          : box.size.width;
      extent = math.max(natural, spare);
      if (extent != natural) {
        box.layout(
          c.asBoxConstraints(minExtent: extent, maxExtent: extent),
          parentUsesSize: true,
        );
      }
    }
    final painted = calculatePaintOffset(c, from: 0, to: extent);
    geometry = SliverGeometry(
      scrollExtent: extent,
      paintExtent: painted,
      cacheExtent: calculateCacheOffset(c, from: 0, to: extent),
      maxPaintExtent: extent,
      hitTestExtent: painted,
      hasVisualOverflow: extent > c.remainingPaintExtent || c.scrollOffset > 0,
    );
    if (box != null) setChildParentData(box, c, geometry!);
  }
}

/// A scrollbar thumb holds the position (no ballistic or alignment moves it).
class _ThumbScrollActivity extends ScrollActivity {
  _ThumbScrollActivity(super.delegate);
  @override
  bool get shouldIgnorePointer => false;
  @override
  bool get isScrolling => true;
  @override
  double get velocity => 0;
}

class _ThumbModel {
  _ThumbModel(this.firstId, this.cum, this.lo, this.hi);

  /// The first row at the press; rows prepended later shift indices.
  final String firstId;

  /// `cum[i]`: the top of row `i` from the first row's top.
  final Float64List cum;

  /// The viewport top's range in that model.
  double lo, hi;

  /// The content snapped to the real top (-1) or latest end (1).
  int edge = 0;
}

/// Builder delegate whose total extent sums per-row estimates for the rows
/// after the last laid-out child, instead of the framework's average-based
/// extrapolation (stable scrollbar for rows of very different heights).
class _EstimatingChildDelegate extends SliverChildBuilderDelegate {
  _EstimatingChildDelegate(
    super.builder, {
    required int super.childCount,
    required this.remainingExtent,
    super.findChildIndexCallback,
  });
  final double Function(int firstUnbuiltIndex)? remainingExtent;

  @override
  double? estimateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) {
    final remaining = remainingExtent;
    if (remaining == null) return null;
    return trailingScrollOffset + remaining(lastIndex + 1);
  }
}

// Fenwick sums retain measured variable row heights with O(log n) updates and
// range queries. Both sides of the center share the same message index.
class _TimelineExtentIndex {
  _TimelineExtentIndex(int count, double Function(int) estimate)
    : values = Float64List(count),
      tree = Float64List(count + 1) {
    for (var i = 0; i < count; i++) {
      final value = estimate(i);
      values[i] = value;
      tree[i + 1] += value;
      final parent = i + 1 + ((i + 1) & -(i + 1));
      if (parent < tree.length) tree[parent] += tree[i + 1];
    }
  }
  final Float64List values, tree;
  void update(int index, double height) {
    final delta = height - values[index];
    if (delta == 0) return;
    values[index] = height;
    for (var i = index + 1; i < tree.length; i += i & -i) {
      tree[i] += delta;
    }
  }

  double prefix(int end) {
    var value = 0.0;
    for (var i = end; i > 0; i -= i & -i) {
      value += tree[i];
    }
    return value;
  }

  double sum(int start, int end) => prefix(end) - prefix(start);
}

class _TimelineExtentRecorder extends SingleChildRenderObjectWidget {
  const _TimelineExtentRecorder({required this.onExtent, required super.child});
  final ValueChanged<double> onExtent;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTimelineExtentRecorder(onExtent);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTimelineExtentRecorder renderObject,
  ) {
    renderObject.onExtent = onExtent;
    // A new delegate may retain an already laid-out child without another
    // layout. Seed its new index from that size, then update if layout changes.
    if (renderObject.hasSize) onExtent(renderObject.size.height);
  }
}

class _RenderTimelineExtentRecorder extends RenderProxyBox {
  _RenderTimelineExtentRecorder(this.onExtent);
  ValueChanged<double> onExtent;
  @override
  void performLayout() {
    super.performLayout();
    onExtent(size.height);
  }
}
