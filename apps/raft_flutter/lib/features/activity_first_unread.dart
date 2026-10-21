import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'desktop_navigation_policy.dart';
import 'resource_list_updates.dart';

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
    w.notifyListeners();
  }

  /// A row open in the preview supersedes the marker, as a click moves Web's
  /// focused row.
  bool highlights(String? key) => key != null && key == _focused;

  /// Called while the Activity page builds its rows.
  void observe(
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
/// content target's id (thread channel / channel), never the target's message
/// focus: that moves with unread state and refreshes, the row's identity does
/// not. A mention action additionally requires its own message, so opening an
/// ordinary channel row never lights up a mention row of that channel.
bool activityRowOpen(DesktopContentTarget target, Map<String, dynamic> row) {
  final kind = row['kind'];
  if (kind == 'thread') {
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
  Widget header,
) => section != 'activity'
    ? header
    : RaftTooltip(
        message: raftText(
          context,
          'Double-click to jump to the next unread item',
        ),
        child: RaftMouseDoubleClick(
          onDoubleClick: () => ActivityFirstUnread.of(w).requestNext(w),
          child: header,
        ),
      );
