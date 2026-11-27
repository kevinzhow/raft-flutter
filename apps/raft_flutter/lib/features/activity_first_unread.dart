import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:raft_ui/raft_ui.dart';

import '../data/activity_object_rows.dart' show isArtifactActivityRow;
import '../data/workspace_controller.dart';
import 'activity_retap.dart';
import 'artifacts/artifact_models.dart' show parseArtifactId;
import 'desktop_navigation_policy.dart';
import 'resource_list_updates.dart';
import 'stale_counts_notice.dart';

/// Web `focusFirstUnreadActivity` / `focusFirstUnreadInboxItem`: a double-click
/// on the Activity entry lands in the Activity surface and marks the first
/// unread row (scrolled into view, highlighted) without opening its
/// conversation. The intent is stored rather than resolved on the spot, so it
/// does not matter when the rows arrive; it stays pending while none is unread.
class ActivityFirstUnread {
  ActivityFirstUnread._();
  static final _owners = Expando<ActivityFirstUnread>();
  static ActivityFirstUnread of(WorkspaceController w) =>
      _owners[w] ??= ActivityFirstUnread._();

  /// Bumped when the located row (or the pending jump) changes, so the Activity
  /// page rebuilds on its own.
  final _changeListeners = <VoidCallback>[];
  void addChangeListener(VoidCallback f) => _changeListeners.add(f);
  void removeChangeListener(VoidCallback f) => _changeListeners.remove(f);
  void _changed() {
    for (final f in [..._changeListeners]) {
      f();
    }
  }

  bool _pending = false;
  String? _focused, _after;

  @visibleForTesting
  bool get pending => _pending;

  /// Arms the intent and has the Activity page build again.
  void request(WorkspaceController w) => _arm(w, null);

  /// ThreadsInbox `focusNextUnread` (double-click on the header title): the
  /// unread row after the marked one, wrapping round to the first.
  void requestNext(WorkspaceController w) => _arm(w, _focused);

  void _arm(WorkspaceController w, String? after) {
    _pending = true;
    _after = after;
    if (after == null) _focused = null;
    _changed();
    w.notifyListeners();
  }

  Timer? _locatedTimer;

  /// Web `setRetapTarget`: the row the phone re-tap went to is lit as
  /// located for [locatedDuration], then retired.
  void locate(WorkspaceController w, String key) {
    _focused = key;
    _locatedTimer?.cancel();
    _locatedTimer = Timer(locatedDuration, () {
      if (_focused == key) {
        _focused = null;
        _changed();
        w.notifyListeners();
      }
    });
    _changed();
    w.notifyListeners();
  }

  /// Web raft-ui `LOCATED_MS`.
  static const locatedDuration = Duration(milliseconds: 2000);

  /// A row open in the preview supersedes the marker, as a click moves Web's
  /// focused row.
  bool highlights(String? key) => key != null && key == _focused;

  /// Called while the Activity page builds its rows.
  void observe(
    WorkspaceController w,
    List<Map<String, dynamic>> rows,
    String? Function(Map) keyOf,
    ScrollController? scroll,
    BuildContext context,
  ) {
    if (!_pending) return;
    final unread = [
      for (final row in rows)
        if (keyOf(row) case final key?
            when ((row['unreadCount'] as num?) ?? 0) > 0)
          key,
    ];
    if (unread.isEmpty) return;
    final at = _after == null ? -1 : unread.indexOf(_after!);
    final key = unread[(at + 1) % unread.length];
    _pending = false;
    _focused = key;
    _locatedTimer?.cancel();
    _locatedTimer = Timer(locatedDuration, () {
      if (_focused == key) {
        _focused = null;
        _changed();
        w.notifyListeners();
      }
    });
    if (scroll != null) _reveal(context, scroll, ResourceRowListKey(key), 0);
  }

  // The list builds lazily: page towards the row until its element exists.
  void _reveal(BuildContext context, ScrollController scroll, Key key, int n) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted ||
          !scroll.hasClients ||
          scroll.positions.length != 1) {
        return;
      }
      final row = _find(context as Element, key);
      if (row != null) {
        Scrollable.ensureVisible(row, alignment: 0, duration: Duration.zero);
        return;
      }
      final position = scroll.position;
      if (n >= 60 || position.pixels >= position.maxScrollExtent) return;
      position.jumpTo(
        (position.pixels + position.viewportDimension).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      _reveal(context, scroll, key, n + 1);
    });
  }

  static BuildContext? _find(Element root, Key key) {
    BuildContext? hit;
    void visit(Element e) {
      if (hit != null) return;
      if (e.widget.key == key) {
        hit = e;
        return;
      }
      e.visitChildren(visit);
    }

    root.visitChildren(visit);
    return hit;
  }
}

/// Whether [row] is the item open in the Activity preview. Identity is the
/// task, thread channel, or channel ID. A mention action additionally matches
/// its own message ID.
bool activityRowOpen(DesktopContentTarget target, Map<String, dynamic> row) {
  final kind = row['kind'];
  if (isArtifactActivityRow(row)) {
    return target.kind == DesktopContentKind.artifact &&
        parseArtifactId(target.id) == row['objectId'];
  }
  if (kind == 'thread') {
    if (target.kind == DesktopContentKind.task) {
      return row['conversationKind'] == 'task' && target.id == row['taskId'];
    }
    return target.kind == DesktopContentKind.thread &&
        target.id == row['threadChannelId'];
  }
  if (target.kind != DesktopContentKind.channel ||
      target.id != row['channelId']) {
    return false;
  }
  return kind != 'mention_action' || target.messageId == row['messageId'];
}

/// The Activity page header as ThreadsInbox makes it: its tooltip says that a
/// double-click jumps to the next unread item (a mouse double-click does).
Widget activityHeaderJump(
  BuildContext context,
  WorkspaceController w,
  String section,
  Widget header, {
  bool loadFailed = false,
}) => section != 'activity'
    ? header
    : activityStaleNotice(
        w,
        loadFailed: loadFailed,
        RaftTooltip(
          message: raftText(
            context,
            'Double-click to jump to the next unread item',
          ),
          child: RaftMouseDoubleClick(
            onDoubleClick: () => ActivityFirstUnread.of(w).requestNext(w),
            child: header,
          ),
        ),
      );

/// The phone Activity tab root's header (Web TabRootBar: the name and the
/// counts line), with the task #164 notice under it.
Widget activityRootHeader(
  WorkspaceController w,
  String subtitle, {
  bool loadFailed = false,
}) => activityStaleNotice(
  w,
  loadFailed: loadFailed,
  // Web `headerContainerProps.onClick = goToNextUnread` on a phone.
  GestureDetector(
    key: const ValueKey('activity-header-retap'),
    behavior: HitTestBehavior.opaque,
    onTap: () => unawaited(ActivityRetap.of(w).trigger()),
    child: RaftMobileRootHeader(
      title: 'Activity',
      subtitle: subtitle,
      inset: RaftLayoutMetrics.panelInset,
    ),
  ),
);

/// ThreadsInbox: the Activity notice of task #164 sits under the head.
Widget activityStaleNotice(
  WorkspaceController w,
  Widget header, {
  bool loadFailed = false,
}) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  // Not with the failed state: that already says the list did not load.
  children: [header, if (!loadFailed) StaleCountsNotice.activity(w)],
);
