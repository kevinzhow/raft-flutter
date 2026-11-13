import 'package:flutter/foundation.dart';

import '../data/thread_unread_by_parent.dart';
import '../data/workspace_controller.dart';
import 'marked_unread_sync.dart';

/// What a sidebar channel row asks about followed-thread unread: the roll-up of
/// the followed-thread list (Web 1.24 ChannelRow.tsx:63
/// `useParentThreadUnread(channel.joined ? channel.id : null)`; the
/// `thread_unread_badge_v0` gate is retired).
///
/// The shell rebuilds on controller notifications, so a change of a channel's
/// number or @ mark is one notification here; a reply into a thread that is
/// already unread repaints nothing.
class SidebarThreadUnread extends ChangeNotifier {
  SidebarThreadUnread._(this.w) {
    w.followedThreads.addListener(_threadsChanged);
    w.services.disposeWithSession(dispose);
    // The sidebar paints the marked-unread dot from the same presentation.
    MarkedUnreadSync.of(w);
    _ensureThreads();
    _byParent = groupThreadUnreadByParent(w.followedThreads.threads);
  }
  static final _owners = Expando<SidebarThreadUnread>();
  static SidebarThreadUnread of(WorkspaceController w) =>
      _owners[w] ??= SidebarThreadUnread._(w);

  final WorkspaceController w;
  Map<String, ParentThreadUnread> _byParent = const {};
  bool _disposed = false;

  /// Nothing while the channel is not joined.
  ParentThreadUnread forChannel(String channelId, {required bool joined}) =>
      joined
      ? _byParent[channelId] ?? ParentThreadUnread.none
      : ParentThreadUnread.none;

  /// SidebarReadToggleMenuItem `readConversation` (a joined channel's menu):
  /// the read toggle reads the channel with its followed threads, and counts
  /// their unread. Always, since Web 1.24 (the two flags are retired).
  bool get readsConversation => true;

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
  /// covers a presentation opened before it did.
  void _ensureThreads() => w.followedThreads.ensure();

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    w.followedThreads.removeListener(_threadsChanged);
    super.dispose();
  }
}
