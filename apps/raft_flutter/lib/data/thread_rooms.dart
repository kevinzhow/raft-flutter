import 'workspace_messages.dart';

/// Source ThreadPanel socket rooms: an open thread joins its own room and its
/// parent channel's room (live replies, and the parent's messages when the
/// parent is not the open channel), joins them again after every reconnect,
/// and leaves its own room when it closes.
abstract final class ThreadRooms {
  static void join(WorkspaceMessages m) {
    final client = m.transport.client;
    for (final id in [m.state.threadChannelId, m.threadParentChannelId]) {
      if (id != null) client.joinChannel(id);
    }
  }

  static void leave(WorkspaceMessages m) {
    final id = m.state.threadChannelId;
    if (id != null) m.transport.client.leaveChannel(id);
  }
}
