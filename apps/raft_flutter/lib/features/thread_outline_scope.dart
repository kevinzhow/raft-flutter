import '../data/thread_outline.dart';
import '../data/workspace_controller.dart';

ThreadOutline? threadOutlineFor(WorkspaceController workspace) {
  final id = workspace.threadChannelId;
  final identity = workspace.threadIdentity;
  if (id == null || identity == null || identity.taskId != null) return null;
  final store = workspace.services.threadOutlines;
  final cached = store[id];
  if (cached != null && cached.current) return cached;
  cached?.dispose();

  final messages = workspace.messageDomain;
  Object authority() {
    final parent = workspace.threadIdentity?.parentChannelId;
    return (
      workspace.client.generation,
      workspace.client.user?.id,
      workspace.client.serverId,
      workspace.server?.string('role'),
      messages.replyToken(parent),
      parent == null ? null : messages.threadResourceAuthority(parent),
    );
  }

  final scope = authority();
  return store[id] = ThreadOutline(
    channelId: id,
    userId: workspace.client.user?.id,
    isCurrent: () => workspace.threadChannelId == id && authority() == scope,
    query: workspace.query,
    position: () {
      final anchor = workspace.messageWindows.readingAnchor(id)?.messageKey;
      final reading = anchor == null
          ? null
          : workspace.replies
                .where((row) => messages.messageKey(row) == anchor)
                .firstOrNull
                ?.seq;
      return (jump: messages.state.highlightedMessageId, reading: reading);
    },
  );
}
