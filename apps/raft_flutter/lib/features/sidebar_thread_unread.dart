import 'package:flutter/foundation.dart';

import '../data/thread_unread_by_parent.dart';
import '../data/workspace_controller.dart';
import 'activity_rollout_flags.dart';

/// What a sidebar channel row asks about followed-thread unread: the roll-up of
/// the followed-thread list behind the `thread_unread_badge_v0` gate
/// (Sidebar.tsx `useParentThreadUnread(threadUnreadEnabled && joined ? id : null)`).
///
/// The shell rebuilds on controller notifications, so a change of the flag or
/// of a channel's number or @ mark is one notification here; a reply into a
/// thread that is already unread repaints nothing.
class SidebarThreadUnread extends ChangeNotifier {
  SidebarThreadUnread._(this.w) : flags = ActivityRolloutFlags.of(w) {
    flags.addListener(_changed);
    w.followedThreads.addListener(_threadsChanged);
    w.services.disposeWithSession(dispose);
    _ensureThreads();
    _byParent = groupThreadUnreadByParent(w.followedThreads.threads);
  }
  static final _owners = Expando<SidebarThreadUnread>();
  static SidebarThreadUnread of(WorkspaceController w) =>
      _owners[w] ??= SidebarThreadUnread._(w);

  final WorkspaceController w;
  final ActivityRolloutFlags flags;
  Map<String, ParentThreadUnread> _byParent = const {};
  bool _disposed = false;

  /// Nothing while the flag is off or the channel is not joined.
  ParentThreadUnread forChannel(String channelId, {required bool joined}) =>
      flags.threadUnreadBadge && joined
      ? _byParent[channelId] ?? ParentThreadUnread.none
      : ParentThreadUnread.none;

  /// SidebarReadToggleMenuItem `readConversation` (a joined channel's menu):
  /// the read toggle reads the channel with its followed threads, and counts
  /// their unread, only while both flags are on.
  bool get readsConversation =>
      flags.threadUnreadBadge && flags.sidebarMarkAllRead;

  void _threadsChanged() {
    final next = groupThreadUnreadByParent(w.followedThreads.threads);
    if (mapEquals(next, _byParent)) return;
    _byParent = next;
    _changed();
  }

  void _changed() {
    if (_disposed) return;
    _ensureThreads();
    if (!w.services.isDisposed()) w.notifyListeners();
    notifyListeners();
  }

  /// The roll-up reads the followed-thread list: the session starts it, this
  /// covers a presentation that was opened before the flag arrived.
  void _ensureThreads() {
    if (flags.threadUnreadBadge) w.followedThreads.ensure();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    flags.removeListener(_changed);
    w.followedThreads.removeListener(_threadsChanged);
    super.dispose();
  }
}
