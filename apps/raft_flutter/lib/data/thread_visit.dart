import 'workspace_message_windows.dart';
import 'workspace_messages.dart';

/// The open thread's visit: the request that keeps the thread's parent
/// identity ([WorkspaceMessages.threadIdentity]) current.
abstract final class ThreadVisit {
  /// Holds while the navigation, the reply authority and the channel's
  /// visibility are unchanged and the thread window has not been replaced.
  static MessageWindowRequest request(
    WorkspaceMessages m,
    String parentChannelId,
  ) {
    final navigationWindow = m.presentation.navigationRevision,
        requestAuthority = m.replyToken(parentChannelId),
        messageAuthority = m.threadResourceAuthority(parentChannelId);
    return m.messageWindows.request(
      thread: true,
      allowed: () =>
          navigationWindow == m.presentation.navigationRevision &&
          requestAuthority == m.replyToken(parentChannelId) &&
          (messageAuthority == null ||
              messageAuthority == m.threadResourceAuthority(parentChannelId)) &&
          !m.session.revocations.revokedChannels.contains(parentChannelId) &&
          !m.session.revocations.revokedChannels.contains(
            m.state.threadChannelId,
          ) &&
          m.context.can(
            'viewChannel',
            resource: m.threadChannelResource(parentChannelId),
          ),
    );
  }

  /// A thread window reload that keeps the same thread open (return to the
  /// latest end) replaces the window epoch. The visit made at the old epoch
  /// would stop being current, and with it the thread's parent identity: the
  /// header loses its channel label and actions and the composer its scope.
  /// Call after the epoch changed, for a thread that was open before it.
  static void renew(WorkspaceMessages m) {
    final identity = m.state.threadIdentity;
    if (identity == null || m.state.threadVisit == null) return;
    m.state.threadVisit = request(m, identity.parentChannelId);
  }
}
