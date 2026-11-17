// Source: packages/web/src/features/thread/InboxRow.tsx (swipe sets) and
// ThreadsInbox.tsx (`openSwipeKey`, press elsewhere, scroll) at v1.24.0.
// A phone with touch swipes a row: left uncovers Done (and Unfollow, Mute),
// right uncovers Read / Unread. One row is open at a time.
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show RenderMetaData;
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/activity_object_rows.dart';
import 'activity_context_menu.dart'
    show canToggleActivityMute, canToggleActivityRowRead;
import 'activity_list_row.dart' show activityRowShowsUnread;
import 'activity_row_host.dart';
import 'activity_row_label.dart';
import 'activity_undo.dart';

/// Web `canUnfollowActivityRow`.
bool canUnfollowActivityRow(Map<String, dynamic> row) =>
    row['kind'] == 'thread' && row['isFollowing'] != false;

/// Web `canMuteActivityRow`: a channel, or a DM that can be muted, whose
/// Activity is not muted yet.
bool canMuteActivityRow(Map<String, dynamic> row, RaftChannel? channel) =>
    (row['kind'] == 'channel' || row['kind'] == 'dm') &&
    canToggleActivityMute(channel) &&
    channel?.flag('activityMuted') != true;

/// Web `canSwipeActivityRowRead`: a row whose read state can change, switch
/// back and be seen to: not an object row, a direct mention, a muted
/// conversation's or an unfollowed thread's.
bool canSwipeActivityRowRead(Map<String, dynamic> row, {required bool muted}) =>
    !muted &&
    !isActivityObjectRow(row) &&
    row['kind'] != 'mention_action' &&
    canToggleActivityRowRead(row);

/// The open row of one Activity list (Web `openSwipeKey`).
class ActivitySwipeOpen extends ChangeNotifier {
  String? _key;
  RaftSwipeEdge? _edge;
  bool get hasOpen => _key != null;
  String? get key => _key;
  RaftSwipeEdge? edgeOf(String key) => key == _key ? _edge : null;

  void set(String key, RaftSwipeEdge? edge) {
    if (edge == null) {
      if (_key != key) return;
      _key = null;
      _edge = null;
    } else {
      if (_key == key && _edge == edge) return;
      _key = key;
      _edge = edge;
    }
    notifyListeners();
  }

  void close() {
    if (_key == null) return;
    _key = null;
    _edge = null;
    notifyListeners();
  }

  /// The open row left the list: it counts as none open, with nothing to
  /// repaint (its row is gone).
  void forget(String key) {
    if (_key != key) return;
    _key = null;
    _edge = null;
  }
}

/// Web `channelLabel` of a row: the conversation a toast names.
String activityConversationLabel(
  BuildContext context,
  Map<String, dynamic> row,
  ActivityRowLookups lookups,
  String filter,
) => ActivityRowFacts.of(
  context,
  row,
  lookups: lookups,
  filter: filter,
  marked: false,
).channelLabel;

/// What a swiped row does: the page's own reads and the undoable actions.
class ActivitySwipeHooks {
  const ActivitySwipeHooks({
    required this.open,
    required this.undo,
    required this.muteChannel,
    required this.muted,
    required this.toggleRead,
    required this.key,
  });
  final ActivitySwipeOpen open;
  final ActivityUndo undo;
  final RaftChannel? Function(Map<String, dynamic> row) muteChannel;
  final bool Function(Map<String, dynamic> row) muted;
  final void Function(Map<String, dynamic> row, bool unread) toggleRead;
  final String? Function(Map<String, dynamic> row) key;
}

/// One row inside its [RaftSwipeRow]. Not a phone with touch: the row itself.
class ActivitySwipeRow extends StatefulWidget {
  const ActivitySwipeRow({
    super.key,
    required this.row,
    required this.host,
    required this.hooks,
    required this.child,
  });
  final Map<String, dynamic> row;
  final ActivityRowHost host;
  final ActivitySwipeHooks hooks;
  final Widget child;

  @override
  State<ActivitySwipeRow> createState() => _ActivitySwipeRowState();
}

class _ActivitySwipeRowState extends State<ActivitySwipeRow> {
  late String? _rowKey = widget.hooks.key(widget.row);
  bool? _blocked;
  RaftSwipeEdge? _edge;

  ActivitySwipeOpen get _open => widget.hooks.open;

  @override
  void initState() {
    super.initState();
    _open.addListener(_changed);
  }

  @override
  void didUpdateWidget(ActivitySwipeRow old) {
    super.didUpdateWidget(old);
    if (!identical(old.hooks.open, _open)) {
      old.hooks.open.removeListener(_changed);
      _open.addListener(_changed);
    }
    _rowKey = widget.hooks.key(widget.row);
  }

  @override
  void dispose() {
    _open.removeListener(_changed);
    // The open row left the list: nothing is open any more.
    if (_rowKey != null) _open.forget(_rowKey!);
    super.dispose();
  }

  // Only the row that opens or closes, and every other row when the first
  // one opens or the last one closes (a press elsewhere is swallowed), builds.
  void _changed() {
    final key = _rowKey;
    final edge = key == null ? null : _open.edgeOf(key);
    final blocked = _open.hasOpen && edge == null;
    if (edge != _edge || blocked != _blocked) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    final row = widget.row;
    final hooks = widget.hooks;
    final key = _rowKey;
    final enabled =
        key != null &&
        (host.phoneTouch ??
            (RaftAdaptiveWorkspace.compactOf(context) &&
                RaftInteraction.of(context).touch));
    if (!enabled) return widget.child;
    _edge = _open.edgeOf(key);
    _blocked = _open.hasOpen && _edge == null;
    final unread = activityRowShowsUnread(host.controller, row);
    final muted = hooks.muted(row);
    final channel = hooks.muteChannel(row);
    final object = isActivityObjectRow(row);
    final unfollow = canUnfollowActivityRow(row);
    final mute = canMuteActivityRow(row, channel);
    final readable = canSwipeActivityRowRead(row, muted: muted);
    String conversation() => activityConversationLabel(
      context,
      row,
      ActivityRowLookups(
        controller: host.controller,
        agents: host.agents,
        people: host.people,
        directorySenderLabel: host.directorySenderLabel,
        stableSender: host.stableSender,
        taskV2: host.taskV2,
      ),
      host.filter,
    );
    final trailing = RaftSwipeActions(
      // Outer edge first: Done, then Unfollow, then Mute.
      actions: [
        RaftSwipeAction(
          label: raftText(context, 'Done'),
          glyph: RaftGlyph.check,
          tone: RaftSwipeActionTone.success,
          buttonKey: const ValueKey('inbox-row-swipe-done'),
          onPressed: () => hooks.undo.done(row),
        ),
        if (!object && unfollow)
          RaftSwipeAction(
            label: raftText(context, 'Unfollow'),
            glyph: RaftGlyph.unfollowThread,
            buttonKey: const ValueKey('inbox-row-swipe-unfollow'),
            onPressed: () => hooks.undo.unfollow(row, conversation()),
          ),
        if (!object && mute && channel != null)
          RaftSwipeAction(
            label: raftText(context, 'Mute'),
            glyph: RaftGlyph.bellOff,
            buttonKey: const ValueKey('inbox-row-swipe-mute'),
            onPressed: () => hooks.undo.mute(
              row,
              channel,
              conversation(),
              muted: true,
              withToast: true,
            ),
          ),
      ],
    );
    final leading = readable
        ? RaftSwipeActions(
            full: RaftSwipeFull.keep,
            actions: [
              RaftSwipeAction(
                label: raftText(context, unread ? 'Read' : 'Unread'),
                glyph: unread
                    ? RaftGlyph.messageSquareCheck
                    : RaftGlyph.messageSquareDot,
                buttonKey: const ValueKey('inbox-row-swipe-read'),
                onPressed: () => hooks.toggleRead(row, unread),
              ),
            ],
          )
        : null;
    final swipe = RaftSwipeRow(
      enabled: true,
      open: _edge,
      onOpenChange: (edge) => _open.set(key, edge),
      leading: leading,
      trailing: trailing,
      child: widget.child,
    );
    // A press elsewhere is swallowed while a row is open: the other rows do
    // not hear it, the list closes the open one.
    final marked = MetaData(
      metaData: ActivitySwipeRowMark(key),
      behavior: HitTestBehavior.translucent,
      child: swipe,
    );
    return _blocked! ? IgnorePointer(child: marked) : marked;
  }
}

/// Around the Activity scroller on a phone with touch: scrolling closes the
/// open row, and so does a press anywhere else (a press in the list is
/// swallowed by its rows; one outside it, a toast or the tab bar, also acts).
class ActivitySwipeScope extends StatefulWidget {
  const ActivitySwipeScope({super.key, required this.open, required this.child});
  final ActivitySwipeOpen open;
  final Widget child;

  @override
  State<ActivitySwipeScope> createState() => _ActivitySwipeScopeState();
}

class _ActivitySwipeScopeState extends State<ActivitySwipeScope> {
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    widget.open.addListener(_changed);
  }

  @override
  void didUpdateWidget(ActivitySwipeScope old) {
    super.didUpdateWidget(old);
    if (!identical(old.open, widget.open)) {
      old.open.removeListener(_changed);
      widget.open.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.open.removeListener(_changed);
    _route(false);
    super.dispose();
  }

  void _changed() => _route(widget.open.hasOpen);

  void _route(bool on) {
    if (on == _routed) return;
    _routed = on;
    final router = GestureBinding.instance.pointerRouter;
    if (on) {
      router.addGlobalRoute(_pointer);
    } else {
      router.removeGlobalRoute(_pointer);
    }
  }

  // A press that lands on the open row (its buttons, its body) is the row's;
  // any other closes it. The rows hear a press in the list only after this
  // frame, and are blocked while a row is open, so it does nothing else.
  void _pointer(PointerEvent event) {
    if (event is! PointerDownEvent || !widget.open.hasOpen) return;
    final result = HitTestResult();
    GestureBinding.instance.hitTestInView(
      result,
      event.position,
      event.viewId,
    );
    final openKey = widget.open.key;
    final onOpenRow = result.path.any((entry) {
      final target = entry.target;
      return target is RenderMetaData &&
          target.metaData is ActivitySwipeRowMark &&
          (target.metaData as ActivitySwipeRowMark).key == openKey;
    });
    if (!onOpenRow) widget.open.close();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollStartNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.vertical) widget.open.close();
          return false;
        },
        child: widget.child,
      );
}

/// Marks the render box of a row for the press test.
@immutable
class ActivitySwipeRowMark {
  const ActivitySwipeRowMark(this.key);
  final String key;
}

/// The phone's pinned filter row ignores a press while a row is open: that
/// press closes the row and is swallowed, as the rows' own are.
class ActivitySwipeBarGuard extends StatelessWidget {
  const ActivitySwipeBarGuard({super.key, required this.open, required this.child});
  final ActivitySwipeOpen open;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: open,
    builder: (context, _) => IgnorePointer(ignoring: open.hasOpen, child: child),
  );
}
