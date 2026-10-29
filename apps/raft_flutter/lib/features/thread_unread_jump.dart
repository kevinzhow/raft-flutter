import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/thread_unread_by_parent.dart';
import '../data/workspace_controller.dart';
import 'activity_rollout_flags.dart';

/// Where a message row is relative to what the timeline shows right now
/// (Web `MessagePlacement`).
enum RowPlacement { above, visible, below }

/// The loaded window, to place unread threads whose parent row is not built
/// (Web `LoadedMessageRange`).
class LoadedRange {
  const LoadedRange({this.oldestAt, this.newestAt, this.hasNewer = false});
  final DateTime? oldestAt, newestAt;

  /// Newer messages exist past the loaded ones (reading history).
  final bool hasNewer;
}

/// The unread followed threads of a channel on either side of the viewport, in
/// jump order: [below] top to bottom, [above] top to bottom.
class ThreadJumpTargets {
  const ThreadJumpTargets(this.above, this.below);
  final List<Map<String, dynamic>> above, below;

  /// Web: "Below first: the nearest one below. Only when none is below: the
  /// earliest above."
  Map<String, dynamic>? get nearestBelow => below.firstOrNull;
  Map<String, dynamic>? get earliestAbove => above.firstOrNull;
}

DateTime? _time(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

/// Web `ThreadUnreadJumpPill`: a parent that is on screen already shows its
/// unread replies, so only the threads whose parent is above or below the
/// viewport count for the pill. [measured] holds the rows that are built.
/// A parent that is not built is placed by time against the rows that are in
/// view ([viewTop], [viewBottom] are the first and last visible row times);
/// without any, Web's rule: past the newest loaded message while newer ones
/// exist is below, anything else is older history above.
ThreadJumpTargets placeJumpTargets(
  List<Map<String, dynamic>> threads,
  Map<String, RowPlacement> measured,
  LoadedRange range, {
  DateTime? viewTop,
  DateTime? viewBottom,
}) {
  final above = <Map<String, dynamic>>[], below = <Map<String, dynamic>>[];
  for (final thread in threads) {
    final parent = thread['parentMessageId'];
    final at = _time(thread['parentMessageCreatedAt']);
    final placement =
        (parent is String ? measured[parent] : null) ??
        _placeUnbuilt(at, range, viewTop, viewBottom);
    switch (placement) {
      case RowPlacement.above:
        above.add(thread);
      case RowPlacement.below:
        below.add(thread);
      case RowPlacement.visible:
        break;
    }
  }
  return ThreadJumpTargets(above, below);
}

RowPlacement _placeUnbuilt(
  DateTime? at,
  LoadedRange range,
  DateTime? viewTop,
  DateTime? viewBottom,
) {
  if (at != null) {
    if (viewBottom != null && at.isAfter(viewBottom)) return RowPlacement.below;
    if (viewTop != null && at.isBefore(viewTop)) return RowPlacement.above;
    // Inside the span of the rows in view: it is on screen even when no row
    // of it is built (a hidden message, say).
    if (viewTop != null && viewBottom != null) return RowPlacement.visible;
  }
  final newest = range.newestAt;
  if (range.hasNewer && newest != null && at != null && at.isAfter(newest)) {
    return RowPlacement.below;
  }
  // Not loaded and not newer: older history above (or an older server
  // without the parent time).
  return RowPlacement.above;
}

/// The built message rows under [scope] against its viewport (a row is
/// `message-wrapper-<id>`): their placement, and the ids of those in view in
/// top-to-bottom order.
({Map<String, RowPlacement> placements, List<String> visible})
measureTimelineRows(Element scope) {
  final placements = <String, RowPlacement>{};
  final visible = <({double top, String id})>[];
  void visit(Element element) {
    final key = element.widget.key;
    if (key is ValueKey<String> && key.value.startsWith('message-wrapper-')) {
      final row = element.renderObject;
      final Object? clip = row == null
          ? null
          : RenderAbstractViewport.maybeOf(row);
      if (row is RenderBox &&
          clip is RenderBox &&
          row.attached &&
          row.hasSize &&
          clip.hasSize) {
        final top =
            row.localToGlobal(Offset.zero).dy -
            clip.localToGlobal(Offset.zero).dy;
        final id = key.value.substring('message-wrapper-'.length);
        final placement = top + row.size.height <= 0
            ? RowPlacement.above
            : top >= clip.size.height
            ? RowPlacement.below
            : RowPlacement.visible;
        placements[id] = placement;
        if (placement == RowPlacement.visible) visible.add((top: top, id: id));
      }
      return;
    }
    element.visitChildren(visit);
  }

  scope.visitChildren(visit);
  visible.sort((a, b) => a.top.compareTo(b.top));
  return (placements: placements, visible: [for (final v in visible) v.id]);
}

/// The timeline's bottom controls: "Back to Bottom" and, in a channel with
/// unread followed threads (`thread_unread_badge_v0`), the one jump pill.
/// - threads below the viewport: "Next unread thread (N)" beside "Back to
///   bottom" goes to the nearest one below;
/// - only above: "Earliest unread thread (N)" at the top goes to the topmost.
/// Repeated clicks walk the channel top to bottom; N (every unread thread of
/// the channel) shrinks as threads are read, and the cross stops the pill until
/// N changes. A click scrolls to the parent and flashes it; it does not open
/// the thread. Nothing is remembered between clicks.
///
/// Place in the timeline Stack: the built rows are measured against their
/// viewport (Web `useMessagePlacement`, an IntersectionObserver).
class ChatBottomControls extends StatefulWidget {
  const ChatBottomControls({
    super.key,
    required this.controller,
    required this.rows,
    required this.hasNewer,
    required this.scroll,
    required this.showBottom,
    required this.bottomCount,
    required this.onBottom,
    this.thread = false,
  });
  final WorkspaceController controller;

  /// The loaded messages, oldest first.
  final List<RaftMessage> rows;
  final bool hasNewer, showBottom, thread;
  final Listenable scroll;

  /// New messages behind the viewport: "N new messages" (a thread panel's
  /// shorter copy, ThreadPanel.tsx:2619) in place of "Back to Bottom".
  final int bottomCount;
  final VoidCallback onBottom;

  @override
  State<ChatBottomControls> createState() => _ChatBottomControlsState();
}

class _ChatBottomControlsState extends State<ChatBottomControls> {
  static const _settle = Duration(milliseconds: 120);

  WorkspaceController get w => widget.controller;
  Timer? _timer;
  ({Map<String, RowPlacement> placements, List<String> visible}) _measured = (
    placements: const {},
    visible: const [],
  );
  ({String channel, int count})? _dismissed;
  String _renderKey = '';
  bool _measuredOnce = false;

  RaftChannel? get _channel => w.channel;

  /// Channels only: not a DM, not a thread, not the thread panel.
  bool get _eligible {
    final channel = _channel;
    return !widget.thread &&
        channel != null &&
        channel.type != 'dm' &&
        channel.type != 'thread' &&
        ActivityRolloutFlags.peek(w)?.threadUnreadBadge == true;
  }

  List<Map<String, dynamic>> get _threads => _eligible
      ? orderParentUnreadThreadsForJump(w.followedThreads.threads, _channel!.id)
      : const [];

  @override
  void initState() {
    super.initState();
    w.followedThreads.addListener(_changed);
    widget.scroll.addListener(_scrolled);
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(ChatBottomControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.scroll, widget.scroll)) {
      oldWidget.scroll.removeListener(_scrolled);
      widget.scroll.addListener(_scrolled);
    }
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.followedThreads.removeListener(_changed);
      w.followedThreads.addListener(_changed);
    }
    // The rows may have changed: look again (Web `renderKey`).
    final key =
        '${widget.rows.length}:${widget.rows.firstOrNull?.id}:'
        '${widget.rows.lastOrNull?.id}';
    if (key != _renderKey) {
      _renderKey = key;
      _scheduleMeasure();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    w.followedThreads.removeListener(_changed);
    widget.scroll.removeListener(_scrolled);
    super.dispose();
  }

  void _changed() {
    // The session starts the list; this covers a surface opened before the
    // flag arrived.
    if (_eligible) w.followedThreads.ensure();
    if (mounted) setState(() {});
    _scheduleMeasure();
  }

  void _scrolled() => _scheduleMeasure(delay: _settle);

  void _scheduleMeasure({Duration delay = Duration.zero}) {
    if (_threads.isEmpty || _timer?.isActive == true && delay == _settle) {
      return;
    }
    _timer?.cancel();
    // ignore: raft_lints/avoid_unreviewed_idle_work -- One-shot measure of the built rows after a scroll settles or the rows change; it schedules nothing itself and is cancelled in dispose.
    _timer = Timer(delay, () {
      if (!mounted) return;
      // ignore: raft_lints/avoid_unreviewed_idle_work -- Single post-frame read of the laid-out rows after a rebuild.
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
      // A rebuild with no frame pending would never run the callback.
      // ignore: raft_lints/avoid_unreviewed_idle_work -- Requests the one frame the read above waits for.
      WidgetsBinding.instance.ensureVisualUpdate();
    });
  }

  void _measure() {
    if (!mounted) return;
    Element? scope;
    context.visitAncestorElements((element) {
      if (element.widget is Stack) {
        scope = element;
        return false;
      }
      return true;
    });
    if (scope == null) return;
    final next = measureTimelineRows(scope!);
    if (_sameMeasure(next)) return;
    setState(() => _measured = next);
  }

  bool _sameMeasure(
    ({Map<String, RowPlacement> placements, List<String> visible}) next,
  ) {
    if (next.visible.length != _measured.visible.length ||
        next.placements.length != _measured.placements.length) {
      return false;
    }
    for (var i = 0; i < next.visible.length; i++) {
      if (next.visible[i] != _measured.visible[i]) return false;
    }
    for (final entry in next.placements.entries) {
      if (_measured.placements[entry.key] != entry.value) return false;
    }
    return true;
  }

  LoadedRange get _range => LoadedRange(
    oldestAt: _time(widget.rows.firstOrNull?.json['createdAt']),
    newestAt: _time(widget.rows.lastOrNull?.json['createdAt']),
    hasNewer: widget.hasNewer,
  );

  ThreadJumpTargets _targets(List<Map<String, dynamic>> threads) {
    final created = <String, DateTime?>{
      if (_measured.visible.isNotEmpty)
        for (final row in widget.rows)
          if (_measured.visible.contains(row.id))
            row.id: _time(row.json['createdAt']),
    };
    return placeJumpTargets(
      threads,
      _measured.placements,
      _range,
      viewTop: created[_measured.visible.firstOrNull],
      viewBottom: created[_measured.visible.lastOrNull],
    );
  }

  void _jump(Map<String, dynamic> thread) {
    final channel = _channel, parent = thread['parentMessageId'];
    if (channel == null || parent is! String) return;
    unawaited(w.jumpToMessage(channel.id, parent));
  }

  Widget _pill(
    BuildContext context,
    bool up,
    Map<String, dynamic> target,
    int total,
  ) => RaftThreadUnreadJumpPill(
    up: up,
    label: raftFormat(
      context,
      up ? 'Earliest unread thread ({count})' : 'Next unread thread ({count})',
      {'count': total},
    ),
    dismissLabel: raftText(context, 'Dismiss'),
    onJump: () => _jump(target),
    onDismiss: () =>
        setState(() => _dismissed = (channel: _channel!.id, count: total)),
  );

  @override
  Widget build(BuildContext context) {
    final bottom = widget.showBottom
        ? RaftTimelineBottomButtonBody(
            label: widget.bottomCount > 0
                ? raftFormat(
                    context,
                    widget.thread ? '{count} New' : '{count} New Messages',
                    {'count': widget.bottomCount},
                  )
                : raftText(context, 'Back to Bottom'),
            onPressed: widget.onBottom,
          )
        : null;
    final threads = _threads;
    // The first unread thread (the flag arriving, a reply) is measured once.
    if (threads.isEmpty) {
      _measuredOnce = false;
    } else if (!_measuredOnce) {
      _measuredOnce = true;
      _scheduleMeasure();
    }
    if (threads.isEmpty) {
      return bottom == null
          ? const SizedBox.shrink()
          : RaftTimelineBottomControls(button: bottom);
    }
    final targets = _targets(threads);
    final total = threads.length;
    final dismissed =
        _dismissed?.channel == _channel!.id && _dismissed?.count == total;
    final below = dismissed ? null : targets.nearestBelow;
    final above = dismissed || below != null ? null : targets.earliestAbove;
    // Positioned.fill's own Stack hit-tests only its pills: the timeline
    // underneath keeps every other pointer event.
    return Positioned.fill(
      child: Stack(
        children: [
          if (above != null)
            RaftTimelineTopPill(child: _pill(context, true, above, total)),
          if (below != null || bottom != null)
            RaftTimelineBottomControls(
              button: bottom,
              pill: below == null ? null : _pill(context, false, below, total),
            ),
        ],
      ),
    );
  }
}
