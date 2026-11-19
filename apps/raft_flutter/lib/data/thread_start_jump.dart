import 'workspace_messages.dart';

/// Pages to the oldest available replies with the same cursor and authority
/// as manual history scrolling.
abstract final class ThreadStartJump {
  static final _running = Expando<bool>();

  static Future<void> run(
    WorkspaceMessages messages,
    void Function() reveal,
  ) async {
    if (_running[messages] == true) return;
    final id = messages.state.threadChannelId;
    if (id == null || !messages.state.threadHasMore) {
      reveal();
      return;
    }
    final request = messages.windowRequest(id, thread: true);
    _running[messages] = true;
    try {
      while (request.current && messages.state.threadHasMore) {
        final before = messages.replies.firstOrNull?.seq;
        if (before == null || before <= BigInt.zero) break;
        await messages.older(thread: true);
        if (messages.replies.firstOrNull?.seq == before) break;
      }
      if (request.current) reveal();
    } finally {
      _running[messages] = null;
    }
  }
}
